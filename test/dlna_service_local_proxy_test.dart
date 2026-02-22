import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:hisense_caster/services/dlna_service.dart';

void main() {
  late Directory tempRoot;
  late File localVideoFile;
  late DLNAService service;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('dlna_local_proxy_test_');
    localVideoFile =
        File('${tempRoot.path}${Platform.pathSeparator}sample.mp4');
    await localVideoFile.writeAsBytes(
      List<int>.generate(4096, (index) => index % 255),
    );
    service = DLNAService();
  });

  tearDown(() async {
    service.dispose();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('local proxy returns 200 and full content for normal GET', () async {
    final url =
        await service.debugPrepareLocalFileProxyUrl(localVideoFile.path);
    final response = await http.get(Uri.parse(url));

    expect(response.statusCode, HttpStatus.ok);
    expect(response.bodyBytes.length, 4096);
    expect(response.headers['accept-ranges'], 'bytes');
  });

  test('local proxy returns 206 and range metadata for ranged GET', () async {
    final url =
        await service.debugPrepareLocalFileProxyUrl(localVideoFile.path);
    final response = await http.get(
      Uri.parse(url),
      headers: {HttpHeaders.rangeHeader: 'bytes=0-1023'},
    );

    expect(response.statusCode, HttpStatus.partialContent);
    expect(response.bodyBytes.length, 1024);
    expect(response.headers['content-range'], 'bytes 0-1023/4096');
    expect(response.headers['accept-ranges'], 'bytes');
  });

  test('local proxy returns 416 for invalid range', () async {
    final url =
        await service.debugPrepareLocalFileProxyUrl(localVideoFile.path);
    final response = await http.get(
      Uri.parse(url),
      headers: {HttpHeaders.rangeHeader: 'bytes=99999-100000'},
    );

    expect(response.statusCode, HttpStatus.requestedRangeNotSatisfiable);
    expect(response.headers['content-range'], 'bytes */4096');
  });
}
