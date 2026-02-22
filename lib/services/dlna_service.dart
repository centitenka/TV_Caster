import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/dlna_device.dart';
import '../utils/logger.dart';

/// DLNA服务 - 实现设备发现和投屏控制
class DLNAService {
  RawDatagramSocket? _socket;
  final _devicesController =
      StreamController<List<DLNADeviceModel>>.broadcast();
  final Map<String, DLNADeviceModel> _devices = {};
  HttpServer? _proxyServer;
  final HttpClient _proxyHttpClient = HttpClient();
  final Map<String, _ProxyTarget> _proxyTargets = {};
  String? _lastErrorMessage;

  Stream<List<DLNADeviceModel>> get devicesStream => _devicesController.stream;
  String? get lastErrorMessage => _lastErrorMessage;

  // SSDP多播地址和端口
  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  /// 开始搜索DLNA设备
  Future<void> startDiscovery() async {
    try {
      _devices.clear();

      // 创建UDP socket
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.multicastHops = 4;

      // 加入多播组
      _socket!.joinMulticast(InternetAddress(_ssdpAddress));

      // 发送SSDP搜索请求
      _sendSearchRequest();

      // 监听响应
      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();
          if (datagram != null) {
            _handleResponse(datagram);
          }
        }
      });

      // 定期发送搜索请求
      Timer.periodic(const Duration(seconds: 5), (_) {
        if (_socket != null) {
          _sendSearchRequest();
        }
      });

      AppLogger.i('DLNA搜索已启动');
    } catch (e) {
      AppLogger.e('启动DLNA搜索失败', error: e);
      throw Exception('启动DLNA搜索失败: $e');
    }
  }

  /// 发送SSDP搜索请求
  void _sendSearchRequest() {
    final request = '''
M-SEARCH * HTTP/1.1
HOST: $_ssdpAddress:$_ssdpPort
MAN: "ssdp:discover"
MX: 3
ST: urn:schemas-upnp-org:device:MediaRenderer:1

'''
        .trim();

    _socket?.send(
      utf8.encode(request),
      InternetAddress(_ssdpAddress),
      _ssdpPort,
    );

    // 同时搜索所有设备
    final allDevicesRequest = '''
M-SEARCH * HTTP/1.1
HOST: $_ssdpAddress:$_ssdpPort
MAN: "ssdp:discover"
MX: 3
ST: ssdp:all

'''
        .trim();

    _socket?.send(
      utf8.encode(allDevicesRequest),
      InternetAddress(_ssdpAddress),
      _ssdpPort,
    );
  }

  /// 处理SSDP响应
  void _handleResponse(Datagram datagram) {
    try {
      final response = utf8.decode(datagram.data);

      // 解析LOCATION头
      final locationMatch = RegExp(r'LOCATION:\s*(.+)', caseSensitive: false)
          .firstMatch(response);

      if (locationMatch != null) {
        final location = locationMatch.group(1)?.trim();
        if (location != null && location.isNotEmpty) {
          _fetchDeviceDescription(location);
        }
      }
    } catch (e) {
      AppLogger.e('处理SSDP响应失败', error: e);
    }
  }

  /// 获取设备描述
  Future<void> _fetchDeviceDescription(String url) async {
    try {
      if (_devices.containsKey(url)) return;

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final document = XmlDocument.parse(response.body);
      final device = document.findAllElements('device').firstOrNull;

      if (device != null) {
        final deviceType =
            device.findElements('deviceType').firstOrNull?.text ?? '';
        final friendlyName =
            device.findElements('friendlyName').firstOrNull?.text ??
                'Unknown Device';
        final udn = device.findElements('UDN').firstOrNull?.text ?? '';

        // 只添加MediaRenderer设备
        if (deviceType.contains('MediaRenderer') ||
            friendlyName.toLowerCase().contains('tv') ||
            friendlyName.toLowerCase().contains('电视') ||
            friendlyName.toLowerCase().contains('hisense') ||
            friendlyName.toLowerCase().contains('海信')) {
          final deviceModel = DLNADeviceModel(
            id: udn.isEmpty ? url : udn,
            name: friendlyName,
            deviceType: deviceType,
            urlBase: url,
          );

          _devices[url] = deviceModel;
          _devicesController.add(_devices.values.toList());

          AppLogger.i('发现设备: $friendlyName');
        }
      }
    } catch (e) {
      AppLogger.e('获取设备描述失败: $url', error: e);
    }
  }

  /// 停止搜索
  void stopDiscovery() {
    _socket?.close();
    _socket = null;
    AppLogger.i('DLNA搜索已停止');
  }

  /// 投屏视频
  Future<bool> castVideo(
    DLNADeviceModel device,
    String videoUrl, {
    String? title,
    String? thumbnail,
  }) async {
    try {
      _lastErrorMessage = null;

      // 获取控制URL
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) {
        throw Exception('无法获取控制URL');
      }

      final prepared = await _prepareCastSource(videoUrl);

      // 设置AVTransportURI
      await _setAVTransportURI(
        controlUrl,
        prepared.castUrl,
        title: title,
        contentType: prepared.contentType,
      );

      // 播放
      await _play(controlUrl);

      AppLogger.i('投屏成功: ${device.name} - ${prepared.castUrl}');
      return true;
    } catch (e) {
      _lastErrorMessage = e.toString().replaceFirst('Exception: ', '');
      AppLogger.e('投屏失败', error: e);
      return false;
    }
  }

  /// 获取控制URL
  Future<String?> _getControlURL(String deviceUrl) async {
    try {
      final response = await http.get(Uri.parse(deviceUrl));
      if (response.statusCode != 200) return null;

      final document = XmlDocument.parse(response.body);

      // 查找 AVTransport 服务
      // 某些电视（如海信）的 ServiceType 可能不完全符合标准，或者有多个版本
      // 这里优先查找标准的 AVTransport:1，如果没有则查找任何包含 AVTransport 的服务
      var service = document.findAllElements('service').firstWhere(
        (s) {
          final type = s.findElements('serviceType').firstOrNull?.text ?? '';
          return type.contains(':AVTransport:1') ||
              type.contains(':AVTransport');
        },
        orElse: () => document.findAllElements('service').first,
      );

      var controlPath = service.findElements('controlURL').firstOrNull?.text;
      if (controlPath == null || controlPath.isEmpty) {
        return null;
      }

      // 处理 URL 拼接
      if (controlPath.startsWith('http')) {
        return controlPath;
      }

      final baseUri = Uri.parse(deviceUrl);

      // 检查是否有 URLBase 标签
      final urlBase = document.findAllElements('URLBase').firstOrNull?.text;
      if (urlBase != null && urlBase.isNotEmpty) {
        var baseUrl = urlBase;
        if (baseUrl.endsWith('/') && controlPath.startsWith('/')) {
          controlPath = controlPath.substring(1);
        } else if (!baseUrl.endsWith('/') && !controlPath.startsWith('/')) {
          controlPath = '/$controlPath';
        }
        return '$baseUrl$controlPath';
      }

      // 如果没有 URLBase，使用 description.xml 的 base
      // 如果 controlPath 以 / 开头，则是绝对路径
      if (controlPath.startsWith('/')) {
        return '${baseUri.scheme}://${baseUri.host}:${baseUri.port}$controlPath';
      } else {
        // 相对路径，相对于 description.xml 的路径
        // 注意：有些电视的 description url 本身就没有 path，例如 http://192.168.1.5:55000/
        final path = baseUri.path;
        final lastSlash = path.lastIndexOf('/');
        final basePath =
            lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '/';
        return '${baseUri.scheme}://${baseUri.host}:${baseUri.port}$basePath$controlPath';
      }
    } catch (e) {
      AppLogger.e('获取控制URL失败', error: e);
      return null;
    }
  }

  /// 设置AVTransportURI
  Future<void> _setAVTransportURI(
    String controlUrl,
    String videoUrl, {
    String? title,
    String? contentType,
  }) async {
    final safeTitle = _escapeXml(title ?? 'Unknown Video');
    final safeUrl = _escapeXml(videoUrl);
    final protocolInfo = _buildProtocolInfo(contentType);

    final metaData = '''
<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">
  <item id="1" parentID="0" restricted="1">
    <dc:title>$safeTitle</dc:title>
    <upnp:class>object.item.videoItem</upnp:class>
    <res protocolInfo="$protocolInfo">$safeUrl</res>
  </item>
</DIDL-Lite>''';

    final safeMetaData = _escapeXml(metaData);

    final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:SetAVTransportURI xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <CurrentURI>$safeUrl</CurrentURI>
      <CurrentURIMetaData>$safeMetaData</CurrentURIMetaData>
    </u:SetAVTransportURI>
  </s:Body>
</s:Envelope>
'''
        .trim();

    final response = await http.post(
      Uri.parse(controlUrl),
      headers: {
        'Content-Type': 'text/xml; charset=utf-8',
        'SOAPAction':
            '"urn:schemas-upnp-org:service:AVTransport:1#SetAVTransportURI"',
      },
      body: soapBody,
    );

    if (response.statusCode != 200) {
      throw Exception('SetAVTransportURI failed: ${response.statusCode}');
    }
  }

  Future<_PreparedCastSource> _prepareCastSource(String videoUrl) async {
    final contentType = _detectContentType(videoUrl);
    final uri = Uri.tryParse(videoUrl);

    if (uri == null) {
      return _PreparedCastSource(
        castUrl: videoUrl,
        contentType: contentType,
      );
    }
    if (uri.scheme == 'file') {
      return _prepareLocalFileSource(uri, contentType);
    }
    if (!_shouldUseProxy(uri.host)) {
      return _PreparedCastSource(
        castUrl: videoUrl,
        contentType: contentType,
      );
    }

    final localIp = await _getLocalIPv4();
    if (localIp == null) {
      return _PreparedCastSource(
        castUrl: videoUrl,
        contentType: contentType,
      );
    }

    await _ensureProxyServer();
    if (_proxyServer == null) {
      return _PreparedCastSource(
        castUrl: videoUrl,
        contentType: contentType,
      );
    }

    final token = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    _proxyTargets[token] = _ProxyTarget.remote(
      uri: uri,
      headers: _buildProxyHeaders(uri.host),
    );

    final proxyUrl = 'http://$localIp:${_proxyServer!.port}/proxy/$token';
    return _PreparedCastSource(
      castUrl: proxyUrl,
      contentType: contentType,
    );
  }

  Future<_PreparedCastSource> _prepareLocalFileSource(
    Uri fileUri,
    String contentType,
  ) async {
    final localFile = File.fromUri(fileUri);
    if (!await localFile.exists()) {
      throw Exception('本地文件不可用，请重新导入');
    }

    final localIp = await _getLocalIPv4();
    if (localIp == null) {
      throw Exception('无法获取手机局域网地址，请连接与电视同一WiFi');
    }

    await _ensureProxyServer();
    if (_proxyServer == null) {
      throw Exception('无法启动本地媒体服务');
    }

    final token = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    _proxyTargets[token] = _ProxyTarget.local(file: localFile);

    final proxyUrl = 'http://$localIp:${_proxyServer!.port}/proxy/$token';
    return _PreparedCastSource(
      castUrl: proxyUrl,
      contentType: contentType,
    );
  }

  Future<void> _ensureProxyServer() async {
    if (_proxyServer != null) return;

    try {
      _proxyServer = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _proxyServer!.listen(_handleProxyRequest);
      AppLogger.i('本地代理已启动: ${_proxyServer!.port}');
    } catch (e) {
      AppLogger.e('启动本地代理失败', error: e);
      _proxyServer = null;
    }
  }

  @visibleForTesting
  Future<String> debugPrepareLocalFileProxyUrl(
    String filePath, {
    String host = '127.0.0.1',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('测试文件不存在');
    }

    await _ensureProxyServer();
    if (_proxyServer == null) {
      throw Exception('本地代理启动失败');
    }

    final token = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    _proxyTargets[token] = _ProxyTarget.local(file: file);
    return 'http://$host:${_proxyServer!.port}/proxy/$token';
  }

  Future<void> _handleProxyRequest(HttpRequest request) async {
    try {
      if (request.uri.pathSegments.length < 2 ||
          request.uri.pathSegments.first != 'proxy') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final token = request.uri.pathSegments[1];
      final target = _proxyTargets[token];
      if (target == null) {
        request.response.statusCode = HttpStatus.gone;
        await request.response.close();
        return;
      }

      if (request.method != 'GET' && request.method != 'HEAD') {
        request.response.statusCode = HttpStatus.methodNotAllowed;
        await request.response.close();
        return;
      }
      if (target.isLocalFile) {
        await _serveLocalFile(request, target.file!);
        return;
      }
      await _forwardRemoteProxyRequest(request, target);
    } catch (e) {
      AppLogger.e('代理转发失败', error: e);
      request.response.statusCode = HttpStatus.badGateway;
      await request.response.close();
    }
  }

  Future<void> _forwardRemoteProxyRequest(
    HttpRequest request,
    _ProxyTarget target,
  ) async {
    final upstream =
        await _proxyHttpClient.openUrl(request.method, target.uri!);
    target.headers!.forEach((key, value) {
      upstream.headers.set(key, value);
    });

    final range = request.headers.value(HttpHeaders.rangeHeader);
    if (range != null && range.isNotEmpty) {
      upstream.headers.set(HttpHeaders.rangeHeader, range);
    }

    final upstreamResp = await upstream.close();

    request.response.statusCode = upstreamResp.statusCode;
    for (final headerName in [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.cacheControlHeader,
      HttpHeaders.expiresHeader,
      HttpHeaders.lastModifiedHeader,
    ]) {
      final value = upstreamResp.headers.value(headerName);
      if (value != null && value.isNotEmpty) {
        request.response.headers.set(headerName, value);
      }
    }

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    await upstreamResp.pipe(request.response);
  }

  Future<void> _serveLocalFile(HttpRequest request, File localFile) async {
    if (!await localFile.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final fileLength = await localFile.length();
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final range = _resolveRequestedRange(rangeHeader, fileLength);

    if (rangeHeader != null && range == null) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers
          .set(HttpHeaders.contentRangeHeader, 'bytes */$fileLength');
      await request.response.close();
      return;
    }

    final effectiveRange = range ?? _ByteRange(start: 0, end: fileLength - 1);
    final contentLength = effectiveRange.end - effectiveRange.start + 1;
    final contentType =
        _normalizeHttpContentType(_detectContentType(localFile.path));

    request.response.statusCode =
        range == null ? HttpStatus.ok : HttpStatus.partialContent;
    request.response.headers.set(HttpHeaders.contentTypeHeader, contentType);
    request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    request.response.headers
        .set(HttpHeaders.contentLengthHeader, '$contentLength');
    if (range != null) {
      request.response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes ${effectiveRange.start}-${effectiveRange.end}/$fileLength',
      );
    }

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    await localFile
        .openRead(effectiveRange.start, effectiveRange.end + 1)
        .pipe(request.response);
  }

  _ByteRange? _resolveRequestedRange(String? rangeHeader, int fileLength) {
    if (rangeHeader == null || rangeHeader.isEmpty) return null;

    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(rangeHeader.trim());
    if (match == null) return null;

    final startRaw = match.group(1) ?? '';
    final endRaw = match.group(2) ?? '';
    if (startRaw.isEmpty && endRaw.isEmpty) return null;

    if (startRaw.isEmpty) {
      final suffixLength = int.tryParse(endRaw);
      if (suffixLength == null || suffixLength <= 0) return null;
      if (suffixLength >= fileLength) {
        return _ByteRange(start: 0, end: fileLength - 1);
      }
      return _ByteRange(start: fileLength - suffixLength, end: fileLength - 1);
    }

    final start = int.tryParse(startRaw);
    if (start == null || start < 0 || start >= fileLength) return null;

    if (endRaw.isEmpty) {
      return _ByteRange(start: start, end: fileLength - 1);
    }

    final end = int.tryParse(endRaw);
    if (end == null || end < start) return null;

    final cappedEnd = end >= fileLength ? fileLength - 1 : end;
    return _ByteRange(start: start, end: cappedEnd);
  }

  Map<String, String> _buildProxyHeaders(String host) {
    final lowerHost = host.toLowerCase();
    final headers = <String, String>{
      HttpHeaders.userAgentHeader:
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      HttpHeaders.acceptHeader: '*/*',
    };

    if (lowerHost.contains('douyin') ||
        lowerHost.contains('amemv') ||
        lowerHost.contains('byte')) {
      headers[HttpHeaders.refererHeader] = 'https://www.douyin.com/';
      headers['Origin'] = 'https://www.douyin.com';
    }

    return headers;
  }

  String _detectContentType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (lower.contains('.mp4') ||
        lower.contains('.m4s') ||
        lower.contains('.m4v')) {
      return 'video/mp4';
    }
    if (lower.contains('.mkv')) return 'video/x-matroska';
    if (lower.contains('.mov')) return 'video/quicktime';
    if (lower.contains('.webm')) return 'video/webm';
    if (lower.contains('.avi')) return 'video/x-msvideo';
    if (lower.contains('.flv')) return 'video/x-flv';
    if (lower.contains('.ts')) return 'video/mp2t';
    return '*';
  }

  String _normalizeHttpContentType(String contentType) {
    if (contentType == '*' || contentType.isEmpty) {
      return 'application/octet-stream';
    }
    return contentType;
  }

  String _buildProtocolInfo(String? contentType) {
    if (contentType == null || contentType.isEmpty || contentType == '*') {
      return 'http-get:*:*:*';
    }
    return 'http-get:*:$contentType:*';
  }

  bool _shouldUseProxy(String host) {
    final lower = host.toLowerCase();
    return lower.contains('douyin.com') ||
        lower.contains('amemv.com') ||
        lower.contains('douyinvod.com') ||
        lower.contains('bytecdn') ||
        lower.contains('bytedance');
  }

  Future<String?> _getLocalIPv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (_isPrivateIPv4(addr.address)) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      AppLogger.e('获取本机IP失败', error: e);
    }
    return null;
  }

  bool _isPrivateIPv4(String ip) {
    return ip.startsWith('10.') ||
        ip.startsWith('192.168.') ||
        RegExp(r'^172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(ip);
  }

  /// 播放
  Future<void> _play(String controlUrl) async {
    final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Speed>1</Speed>
    </u:Play>
  </s:Body>
</s:Envelope>
'''
        .trim();

    final response = await http.post(
      Uri.parse(controlUrl),
      headers: {
        'Content-Type': 'text/xml; charset=utf-8',
        'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#Play"',
      },
      body: soapBody,
    );

    if (response.statusCode != 200) {
      throw Exception('Play failed: ${response.statusCode}');
    }
  }

  /// 恢复播放
  Future<bool> play(DLNADeviceModel device) async {
    try {
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) return false;

      await _play(controlUrl);
      return true;
    } catch (e) {
      AppLogger.e('恢复播放失败', error: e);
      return false;
    }
  }

  /// 暂停
  Future<bool> pause(DLNADeviceModel device) async {
    try {
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) return false;

      final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:Pause>
  </s:Body>
</s:Envelope>
'''
          .trim();

      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#Pause"',
        },
        body: soapBody,
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('暂停失败', error: e);
      return false;
    }
  }

  /// 停止
  Future<bool> stop(DLNADeviceModel device) async {
    try {
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) return false;

      final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Stop xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:Stop>
  </s:Body>
</s:Envelope>
'''
          .trim();

      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#Stop"',
        },
        body: soapBody,
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('停止失败', error: e);
      return false;
    }
  }

  /// Seek
  Future<bool> seek(DLNADeviceModel device, int seconds) async {
    try {
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) return false;

      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final secs = seconds % 60;
      final timeStr = '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';

      final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u>Seek xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Unit>REL_TIME</Unit>
      <Target>$timeStr</Target>
    </u:Seek>
  </s:Body>
</s:Envelope>
'''
          .trim();

      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction': '"urn:schemas-upnp-org:service:AVTransport:1#Seek"',
        },
        body: soapBody,
      );

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e('Seek失败', error: e);
      return false;
    }
  }

  /// 获取播放位置
  Future<int?> getPosition(DLNADeviceModel device) async {
    try {
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) return null;

      final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetPositionInfo>
  </s:Body>
</s:Envelope>
'''
          .trim();

      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction':
              '"urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo"',
        },
        body: soapBody,
      );

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final relTime = document.findAllElements('RelTime').firstOrNull?.text;

        if (relTime != null) {
          final parts = relTime.split(':');
          if (parts.length == 3) {
            return int.parse(parts[0]) * 3600 +
                int.parse(parts[1]) * 60 +
                int.parse(parts[2]);
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.e('获取位置失败', error: e);
      return null;
    }
  }

  /// 获取总时长
  Future<int?> getDuration(DLNADeviceModel device) async {
    try {
      final controlUrl = await _getControlURL(device.urlBase);
      if (controlUrl == null) return null;

      final soapBody = '''
<?xml version="1.0" encoding="utf-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:GetMediaInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
    </u:GetMediaInfo>
  </s:Body>
</s:Envelope>
'''
          .trim();

      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {
          'Content-Type': 'text/xml; charset=utf-8',
          'SOAPAction':
              '"urn:schemas-upnp-org:service:AVTransport:1#GetMediaInfo"',
        },
        body: soapBody,
      );

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final duration =
            document.findAllElements('MediaDuration').firstOrNull?.text;

        if (duration != null) {
          final parts = duration.split(':');
          if (parts.length == 3) {
            return int.parse(parts[0]) * 3600 +
                int.parse(parts[1]) * 60 +
                int.parse(parts[2]);
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.e('获取时长失败', error: e);
      return null;
    }
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  void dispose() {
    stopDiscovery();
    _proxyServer?.close(force: true);
    _proxyServer = null;
    _proxyHttpClient.close(force: true);
    _devicesController.close();
  }
}

class _PreparedCastSource {
  final String castUrl;
  final String contentType;

  _PreparedCastSource({
    required this.castUrl,
    required this.contentType,
  });
}

class _ProxyTarget {
  final Uri? uri;
  final Map<String, String>? headers;
  final File? file;

  bool get isLocalFile => file != null;

  _ProxyTarget.remote({
    required this.uri,
    required this.headers,
  }) : file = null;

  _ProxyTarget.local({
    required this.file,
  })  : uri = null,
        headers = null;
}

class _ByteRange {
  final int start;
  final int end;

  _ByteRange({
    required this.start,
    required this.end,
  });
}
