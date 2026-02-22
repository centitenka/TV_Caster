import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/parser_rule.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

class RuleProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<ParserRule> _rules = [];
  ParserRule? _selectedRule;
  bool _isLoading = false;
  String? _errorMessage;

  List<ParserRule> get rules => _rules;
  ParserRule? get selectedRule => _selectedRule;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<ParserRule> get enabledRules =>
      _rules.where((r) => r.isEnabled).toList();

  RuleProvider() {
    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      _isLoading = true;
      notifyListeners();

      _rules = await _storage.getRules();

      if (_rules.isEmpty) {
        // 添加默认示例规则
        await _addDefaultRules();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.e('加载规则失败', error: e);
      _errorMessage = '加载规则失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _addDefaultRules() async {
    final defaultRules = [
      ParserRule(
        id: 'default_video',
        name: '通用视频解析',
        host: '*',
        description: '解析常见的视频链接格式',
        rules: [
          RuleItem(
            name: 'video',
            xpath: '//video/@src',
          ),
          RuleItem(
            name: 'source',
            xpath: '//source[@type="video/mp4"]/@src',
          ),
          RuleItem(
            name: 'm3u8',
            xpath: '//script[contains(text(),".m3u8")]',
            regex: r'''["\']([^"\']+\.m3u8[^"\']*)["\']''',
          ),
          RuleItem(
            name: 'mp4',
            xpath: '//script[contains(text(),".mp4")]',
            regex: r'''["\']([^"\']+\.mp4[^"\']*)["\']''',
          ),
        ],
        createdAt: DateTime.now(),
      ),
      ParserRule(
        id: 'bilibili',
        name: 'Bilibili解析',
        host: 'bilibili.com|b23.tv',
        description: '解析Bilibili视频（支持移动端与短链）',
        rules: [
          // 尝试直接获取 m3u8 或 mp4
          RuleItem(
            name: 'video_src',
            xpath: '//video/@src',
          ),
          // 直接匹配 __playinfo__ / __INITIAL_STATE__ 中的地址字段
          RuleItem(
            name: 'playinfo_url',
            xpath: '//script',
            regex: r'''"(?:url|baseUrl|base_url)":"([^"]+)"''',
          ),
        ],
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://m.bilibili.com',
        },
        createdAt: DateTime.now(),
      ),
      ParserRule(
        id: 'novipnoad',
        name: 'NovipNoAd解析',
        host: 'novipnoad.cc',
        description: '影视站通用脚本解析（video/source/iframe/player）',
        rules: [
          RuleItem(
            name: 'video_src',
            xpath: '//video/@src',
          ),
          RuleItem(
            name: 'source_src',
            xpath: '//source/@src',
          ),
          RuleItem(
            name: 'iframe_src',
            xpath: '//iframe/@src',
          ),
          RuleItem(
            name: 'player_json_url',
            xpath: '//script',
            regex: r'''"url"\s*:\s*"([^"]+)"''',
          ),
          RuleItem(
            name: 'direct_media',
            xpath: '//script',
            regex: r'''(https?:\/\/[^"'\s]+(?:\.m3u8|\.mp4|\.m4s)[^"'\s]*)''',
          ),
        ],
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://www.novipnoad.cc',
        },
        createdAt: DateTime.now(),
      ),
      ParserRule(
        id: 'youku',
        name: '优酷解析',
        host: 'youku.com',
        description: '优酷移动端解析',
        rules: [
          RuleItem(
            name: 'video_src',
            xpath: '//video/@src',
          ),
          RuleItem(
            name: 'm3u8_script',
            xpath: '//script',
            regex: r'''["']([^"']+\.m3u8[^"']*)["']''',
          ),
        ],
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://m.youku.com',
        },
        createdAt: DateTime.now(),
      ),
      ParserRule(
        id: 'iqiyi',
        name: '爱奇艺解析',
        host: 'iqiyi.com',
        description: '爱奇艺移动端解析',
        rules: [
          RuleItem(
            name: 'video_src',
            xpath: '//video/@src',
          ),
          RuleItem(
            name: 'm3u8',
            xpath: '//video',
            regex: r'''src="([^"]+\.m3u8[^"]*)"''',
          ),
        ],
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://m.iqiyi.com',
        },
        createdAt: DateTime.now(),
      ),
      ParserRule(
        id: 'ixigua',
        name: '西瓜视频解析',
        host: 'ixigua.com',
        description: '西瓜视频解析',
        rules: [
          RuleItem(
            name: 'video_src',
            xpath: '//video/@src',
          ),
          RuleItem(
            name: 'main_url',
            xpath: '//script',
            regex: r'''"main_url":"([^"]+)"''',
            replacement:
                '', // Base64 decode might be needed in complex cases, but often it's direct or simple
          ),
        ],
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://m.ixigua.com',
        },
        createdAt: DateTime.now(),
      ),
    ];

    for (final rule in defaultRules) {
      await _storage.saveRule(rule);
      _rules.add(rule);
    }
  }

  Future<void> addRule(ParserRule rule) async {
    try {
      await _storage.saveRule(rule);
      _rules.add(rule);
      notifyListeners();
    } catch (e) {
      AppLogger.e('添加规则失败', error: e);
      _errorMessage = '添加规则失败: $e';
      notifyListeners();
    }
  }

  Future<void> updateRule(ParserRule rule) async {
    try {
      await _storage.saveRule(rule);
      final index = _rules.indexWhere((r) => r.id == rule.id);
      if (index != -1) {
        _rules[index] = rule;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('更新规则失败', error: e);
    }
  }

  Future<void> removeRule(String id) async {
    try {
      await _storage.deleteRule(id);
      _rules.removeWhere((r) => r.id == id);
      if (_selectedRule?.id == id) {
        _selectedRule = null;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.e('删除规则失败', error: e);
    }
  }

  void selectRule(ParserRule? rule) {
    _selectedRule = rule;
    notifyListeners();
  }

  ParserRule? getRuleById(String id) {
    try {
      return _rules.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  List<ParserRule> getRulesForHost(String host) {
    final normalizedHost = host.toLowerCase();
    return _rules
        .where((r) => r.isEnabled && _hostMatches(r.host, normalizedHost))
        .toList();
  }

  bool _hostMatches(String ruleHost, String host) {
    if (ruleHost == '*') return true;

    final candidates = ruleHost
        .toLowerCase()
        .split(RegExp(r'[|,]'))
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty);

    for (final candidate in candidates) {
      if (candidate == '*') return true;

      if (candidate.startsWith('*.')) {
        final suffix = candidate.substring(2);
        if (host == suffix || host.endsWith('.$suffix')) {
          return true;
        }
        continue;
      }

      if (host == candidate || host.endsWith('.$candidate')) {
        return true;
      }
    }

    return false;
  }

  Future<void> importRules(String jsonString) async {
    try {
      _isLoading = true;
      notifyListeners();

      final List<dynamic> jsonList = jsonDecode(jsonString);
      for (final json in jsonList) {
        final rule = ParserRule.fromJson(json);
        await _storage.saveRule(rule);
        if (!_rules.any((r) => r.id == rule.id)) {
          _rules.add(rule);
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.e('导入规则失败', error: e);
      _errorMessage = '导入失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  String exportRules() {
    return jsonEncode(_rules.map((r) => r.toJson()).toList());
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
