import 'package:dio/dio.dart';
import 'package:html/parser.dart' show parse;
import '../models/parser_rule.dart';
import '../utils/logger.dart';

class VideoParserService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    },
  ));

  Future<List<Map<String, dynamic>>> parseWithRule(
    String url,
    ParserRule rule, {
    Map<String, String>? customHeaders,
  }) async {
    try {
      // 1. 如果规则中有特定规则项，优先使用规则解析
      if (rule.rules.isNotEmpty) {
        final ruleResults = await parseWithRuleItems(url, rule);
        // 将规则结果转换为统一格式
        final mappedResults = ruleResults
            .map((r) => {
                  'type': getVideoType(r['value'] ?? ''),
                  'url': r['url'],
                  'title': '${rule.name} 结果',
                })
            .toList();

        if (mappedResults.isNotEmpty) {
          return mappedResults;
        }
      }

      // 2. 如果规则解析没有结果，或者没有特定规则项，使用通用解析但带上特定 Header
      // 合并 headers: customHeaders > rule.headers
      final headers = Map<String, String>.from(rule.headers ?? {});
      if (customHeaders != null) {
        headers.addAll(customHeaders);
      }

      return await parseVideo(url, headers: headers);
    } catch (e) {
      AppLogger.e('使用规则解析失败', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> parseVideo(
    String url, {
    Map<String, String>? headers,
  }) async {
    final results = <Map<String, dynamic>>[];

    try {
      // 合并 headers，如果没有提供 User-Agent 则使用默认的
      final requestHeaders = Map<String, String>.from(headers ?? {});
      if (!requestHeaders.containsKey('User-Agent')) {
        requestHeaders['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
      }

      // 请求页面
      final response = await _dio.get(
        url,
        options: Options(headers: requestHeaders),
      );

      final html = response.data.toString();
      final document = parse(html);

      // 1. 查找video标签
      final videoElements = document.querySelectorAll('video');
      for (final video in videoElements) {
        final src = video.attributes['src'];
        if (src != null && src.isNotEmpty) {
          results.add({
            'type': 'video',
            'url': _resolveUrl(url, src),
            'title': '视频 ${results.length + 1}',
          });
        }
      }

      // 2. 查找source标签
      final sourceElements = document.querySelectorAll('source');
      for (final source in sourceElements) {
        final src = source.attributes['src'];
        final type = source.attributes['type'];
        if (src != null && src.isNotEmpty) {
          results.add({
            'type': type?.contains('m3u8') == true ? 'm3u8' : 'video',
            'url': _resolveUrl(url, src),
            'title': '视频源 ${results.length + 1}',
          });
        }
      }

      // 3. 查找iframe
      final iframes = document.querySelectorAll('iframe');
      for (final iframe in iframes) {
        final src = iframe.attributes['src'];
        if (src != null && src.isNotEmpty) {
          results.add({
            'type': 'iframe',
            'url': _resolveUrl(url, src),
            'title': '嵌入页面 ${results.length + 1}',
          });
        }
      }

      // 4. 在script标签中查找视频URL
      final scripts = document.querySelectorAll('script');
      for (final script in scripts) {
        final text = script.text;

        // 查找.m3u8链接
        final m3u8Matches = RegExp(
          r'''["\']([^"\']+\.m3u8[^"\']*)["\']''',
          caseSensitive: false,
        ).allMatches(text);

        for (final match in m3u8Matches) {
          final videoUrl = match.group(1);
          if (videoUrl != null && videoUrl.isNotEmpty) {
            results.add({
              'type': 'm3u8',
              'url': _resolveUrl(url, videoUrl),
              'title': 'M3U8流 ${results.length + 1}',
            });
          }
        }

        // 查找.mp4链接
        final mp4Matches = RegExp(
          r'''["\']([^"\']+\.(?:mp4|m4s)[^"\']*)["\']''',
          caseSensitive: false,
        ).allMatches(text);

        for (final match in mp4Matches) {
          final videoUrl = match.group(1);
          if (videoUrl != null && videoUrl.isNotEmpty) {
            results.add({
              'type': 'mp4',
              'url': _resolveUrl(url, videoUrl),
              'title': 'MP4视频 ${results.length + 1}',
            });
          }
        }

        // 查找常见的视频URL模式
        final videoMatches = RegExp(
          r'''(https?://[^"'\s]+\.(?:mp4|m4s|m3u8|flv|avi|mkv)[^"'\s]*)''',
          caseSensitive: false,
        ).allMatches(text);

        for (final match in videoMatches) {
          final videoUrl = match.group(1);
          if (videoUrl != null &&
              videoUrl.isNotEmpty &&
              !results.any((r) => r['url'] == videoUrl)) {
            results.add({
              'type': 'video',
              'url': videoUrl,
              'title': '视频链接 ${results.length + 1}',
            });
          }
        }
      }

      // 5. 查找常见的视频播放器容器
      final playerContainers = document.querySelectorAll(
          '.player, #player, .video-player, #video-player, [class*="player"], [id*="player"]');

      for (final container in playerContainers) {
        // 查找data属性中的视频URL
        container.attributes.forEach((key, value) {
          final keyStr = key.toString();
          if (keyStr.startsWith('data-') &&
              (value.contains('.mp4') || value.contains('.m3u8'))) {
            results.add({
              'type': value.contains('.m3u8') ? 'm3u8' : 'video',
              'url': _resolveUrl(url, value),
              'title': '播放器视频 ${results.length + 1}',
            });
          }
        });
      }

      // 去重
      final uniqueResults = <Map<String, dynamic>>[];
      final seenUrls = <String>{};

      for (final result in results) {
        final videoUrl = result['url'] as String;
        if (!seenUrls.contains(videoUrl)) {
          seenUrls.add(videoUrl);
          uniqueResults.add(result);
        }
      }

      return uniqueResults;
    } catch (e) {
      AppLogger.e('解析视频失败', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchWithRule(
    String keyword,
    String ruleId,
  ) async {
    try {
      // 实现基于规则的搜索
      // 这里简化实现
      return [];
    } catch (e) {
      AppLogger.e('搜索失败', error: e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> parseWithRuleItems(
    String url,
    ParserRule rule,
  ) async {
    final results = <Map<String, dynamic>>[];

    try {
      final response = await _dio.get(
        url,
        options: Options(headers: rule.headers),
      );

      final html = response.data.toString();
      final doc = parse(html);

      for (final ruleItem in rule.rules) {
        try {
          // 处理简单的 XPath (目前简化为 script 内容查找或 CSS 选择器)
          // 真正的 XPath 在 Flutter 中支持有限，这里做一些简单的映射

          List<String> values = [];

          if (ruleItem.xpath.contains('script')) {
            final scripts = doc.querySelectorAll('script');
            for (final script in scripts) {
              final text = script.text;
              if (ruleItem.regex != null) {
                final matches = RegExp(ruleItem.regex!, caseSensitive: false)
                    .allMatches(text);
                for (final match in matches) {
                  if (match.groupCount > 0) {
                    values.add(match.group(1)!);
                  }
                }
              }
            }
          } else {
            // 简单的 CSS 选择器映射
            // 将 XPath //video/@src 转换为 video 和属性 src
            String selector = ruleItem.xpath.replaceAll('//', '');
            String? attribute;

            if (selector.contains('/@')) {
              final parts = selector.split('/@');
              selector = parts[0];
              attribute = parts[1];
            }
            // 处理 [@type="..."] -> [type="..."]
            if (selector.contains('[@')) {
              selector = selector.replaceAll('[@', '[');
            }

            final elements = doc.querySelectorAll(selector);
            for (final element in elements) {
              String? val;
              if (attribute != null) {
                val = element.attributes[attribute];
              } else {
                val = element.text;
              }
              if (val != null) values.add(val);
            }
          }

          for (var value in values) {
            // 再次应用正则提取，确保从属性值中也能提取
            if (ruleItem.regex != null && !ruleItem.xpath.contains('script')) {
              final match = RegExp(ruleItem.regex!).firstMatch(value);
              if (match != null && match.groupCount > 0) {
                value = match.group(1)!;
              }
            }

            value = _normalizeExtractedValue(value);

            // 替换
            if (ruleItem.replacement != null &&
                ruleItem.replacement!.isNotEmpty) {
              // 简单支持空替换
              // value = value.replaceAll(..., ...);
            }

            final resolvedUrl = _resolveUrl(url, value);
            if (resolvedUrl.isNotEmpty) {
              results.add({
                'name': ruleItem.name,
                'value': resolvedUrl,
                'url': resolvedUrl,
              });
            }
          }
        } catch (e) {
          AppLogger.e('规则解析失败: ${ruleItem.name}', error: e);
        }
      }

      return results;
    } catch (e) {
      AppLogger.e('规则解析失败', error: e);
      rethrow;
    }
  }

  String _resolveUrl(String baseUrl, String relativeUrl) {
    if (relativeUrl.isEmpty) return '';
    if (relativeUrl.startsWith('javascript:') ||
        relativeUrl.startsWith('data:')) {
      return '';
    }

    if (relativeUrl.startsWith('http://') ||
        relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    if (relativeUrl.startsWith('//')) {
      return 'https:$relativeUrl';
    }

    final uri = Uri.parse(baseUrl);

    if (relativeUrl.startsWith('/')) {
      return '${uri.scheme}://${uri.host}$relativeUrl';
    }

    final basePath = baseUrl.substring(0, baseUrl.lastIndexOf('/') + 1);
    return '$basePath$relativeUrl';
  }

  bool isVideoUrl(String url) {
    final videoExtensions = [
      '.mp4',
      '.m4s',
      '.m3u8',
      '.flv',
      '.avi',
      '.mkv',
      '.mov',
      '.wmv',
      '.webm',
      '.ts'
    ];

    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.contains(ext));
  }

  String getVideoType(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.m3u8')) return 'm3u8';
    if (lowerUrl.contains('.mp4')) return 'mp4';
    if (lowerUrl.contains('.m4s')) return 'm4s';
    if (lowerUrl.contains('.flv')) return 'flv';
    if (lowerUrl.contains('.avi')) return 'avi';
    if (lowerUrl.contains('.mkv')) return 'mkv';
    return 'unknown';
  }

  String _normalizeExtractedValue(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) return normalized;

    // 常见转义恢复：B站/播放器脚本中常见
    normalized = normalized.replaceAll(r'\/', '/');

    if (normalized.contains(r'\u')) {
      try {
        normalized = normalized.replaceAllMapped(
          RegExp(r'\\u([0-9a-fA-F]{4})'),
          (match) => String.fromCharCode(
            int.parse(match.group(1)!, radix: 16),
          ),
        );
      } catch (_) {
        // ignore
      }
    }

    normalized = normalized
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x2F;', '/');

    if (normalized.startsWith('http%3A') || normalized.startsWith('https%3A')) {
      try {
        normalized = Uri.decodeFull(normalized);
      } catch (_) {
        // ignore
      }
    }

    return normalized;
  }
}
