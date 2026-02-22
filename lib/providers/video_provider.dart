import 'package:flutter/material.dart';
import '../models/parser_rule.dart';
import '../models/video_source.dart';
import '../services/local_media_service.dart';
import '../services/storage_service.dart';
import '../services/video_parser_service.dart';
import '../utils/logger.dart';

class VideoProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final VideoParserService _parser = VideoParserService();
  final LocalMediaService _localMediaService = LocalMediaService();

  List<VideoSource> _videos = [];
  VideoSource? _currentVideo;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _parsedResults = [];

  List<VideoSource> get videos => _videos;
  VideoSource? get currentVideo => _currentVideo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get parsedResults => _parsedResults;

  VideoProvider() {
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      _videos = await _storage.getVideos();
      notifyListeners();
    } catch (e) {
      AppLogger.e('加载视频列表失败', error: e);
    }
  }

  Future<void> addVideo(VideoSource video) async {
    try {
      await _storage.saveVideo(video);
      _videos.add(video);
      notifyListeners();
    } catch (e) {
      AppLogger.e('添加视频失败', error: e);
      _errorMessage = '添加失败: $e';
      notifyListeners();
    }
  }

  Future<void> removeVideo(String id) async {
    try {
      final target = _videos.where((v) => v.id == id).firstOrNull;
      if (target != null && _isLocalFileUri(target.url)) {
        try {
          await _localMediaService.deleteManagedLocalFileByUri(target.url);
        } catch (e) {
          AppLogger.e('删除本地托管文件失败', error: e);
        }
      }

      await _storage.deleteVideo(id);
      _videos.removeWhere((v) => v.id == id);
      if (_currentVideo?.id == id) {
        _currentVideo = null;
      }
      notifyListeners();
    } catch (e) {
      AppLogger.e('删除视频失败', error: e);
    }
  }

  bool _isLocalFileUri(String value) {
    final uri = Uri.tryParse(value);
    return uri?.scheme == 'file';
  }

  void setCurrentVideo(VideoSource video) {
    _currentVideo = video;
    notifyListeners();
  }

  Future<void> parseVideoWithRule(String url, ParserRule rule) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _parsedResults = [];
      notifyListeners();

      final results = await _parser.parseWithRule(url, rule);
      _parsedResults = results;

      if (results.isEmpty) {
        _errorMessage = '未解析到视频链接';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.e('解析视频失败', error: e);
      _errorMessage = '解析失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> parseVideo(String url, {Map<String, String>? headers}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _parsedResults = [];
      notifyListeners();

      final results = await _parser.parseVideo(url, headers: headers);
      _parsedResults = results;

      if (results.isEmpty) {
        _errorMessage = '未解析到视频链接';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.e('解析视频失败', error: e);
      _errorMessage = '解析失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> searchWithRule(String keyword, String ruleId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _parsedResults = [];
      notifyListeners();

      final results = await _parser.searchWithRule(keyword, ruleId);
      _parsedResults = results;

      if (results.isEmpty) {
        _errorMessage = '未搜索到结果';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      AppLogger.e('搜索失败', error: e);
      _errorMessage = '搜索失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearParsedResults() {
    _parsedResults = [];
    notifyListeners();
  }
}
