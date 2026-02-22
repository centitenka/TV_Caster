import 'dart:async';
import 'package:flutter/material.dart';
import '../models/dlna_device.dart';
import '../services/dlna_service.dart';
import '../utils/logger.dart';

class DLNAProvider extends ChangeNotifier {
  final DLNAService _dlnaService = DLNAService();

  List<DLNADeviceModel> _devices = [];
  DLNADeviceModel? _selectedDevice;
  bool _isSearching = false;
  bool _isCasting = false;
  String? _errorMessage;
  StreamSubscription? _deviceSubscription;

  List<DLNADeviceModel> get devices => _devices;
  DLNADeviceModel? get selectedDevice => _selectedDevice;
  bool get isSearching => _isSearching;
  bool get isCasting => _isCasting;
  String? get errorMessage => _errorMessage;

  List<DLNADeviceModel> get hisenseDevices =>
      _devices.where((d) => d.isHisenseTV).toList();

  List<DLNADeviceModel> get mediaRenderers =>
      _devices.where((d) => d.isMediaRenderer).toList();

  DLNAProvider() {
    _init();
  }

  void _init() {
    _dlnaService.devicesStream.listen(
      (devices) {
        _devices = devices;

        // 优先选择海信电视
        if (_selectedDevice == null && hisenseDevices.isNotEmpty) {
          _selectedDevice = hisenseDevices.first;
        }

        notifyListeners();
      },
      onError: (error) {
        AppLogger.e('DLNA设备流错误', error: error);
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> startSearch() async {
    try {
      _isSearching = true;
      _errorMessage = null;
      _devices = [];
      notifyListeners();

      await _dlnaService.startDiscovery();

      // 搜索10秒后自动停止
      Timer(const Duration(seconds: 10), () {
        if (_isSearching) {
          stopSearch();
        }
      });
    } catch (e) {
      AppLogger.e('开始搜索失败', error: e);
      _errorMessage = '搜索失败: $e';
      _isSearching = false;
      notifyListeners();
    }
  }

  void stopSearch() {
    _isSearching = false;
    _dlnaService.stopDiscovery();
    notifyListeners();
  }

  void selectDevice(DLNADeviceModel device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<bool> castVideo(String videoUrl, {String? title}) async {
    if (_selectedDevice == null) {
      _errorMessage = '请先选择投屏设备';
      notifyListeners();
      return false;
    }

    try {
      _isCasting = true;
      _errorMessage = null;
      notifyListeners();

      final success = await _dlnaService.castVideo(
        _selectedDevice!,
        videoUrl,
        title: title,
      );

      if (!success) {
        _errorMessage = _dlnaService.lastErrorMessage ?? '投屏失败，请检查设备连接';
      }

      _isCasting = false;
      notifyListeners();
      return success;
    } catch (e) {
      AppLogger.e('投屏失败', error: e);
      _errorMessage = '投屏错误: $e';
      _isCasting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> pause() async {
    if (_selectedDevice == null) return false;
    try {
      return await _dlnaService.pause(_selectedDevice!);
    } catch (e) {
      AppLogger.e('暂停失败', error: e);
      return false;
    }
  }

  Future<bool> play() async {
    if (_selectedDevice == null) return false;
    try {
      return await _dlnaService.play(_selectedDevice!);
    } catch (e) {
      AppLogger.e('播放失败', error: e);
      return false;
    }
  }

  Future<bool> stop() async {
    if (_selectedDevice == null) return false;
    try {
      _isCasting = false;
      notifyListeners();
      return await _dlnaService.stop(_selectedDevice!);
    } catch (e) {
      AppLogger.e('停止失败', error: e);
      return false;
    }
  }

  Future<bool> seek(int seconds) async {
    if (_selectedDevice == null) return false;
    try {
      return await _dlnaService.seek(_selectedDevice!, seconds);
    } catch (e) {
      AppLogger.e('seek失败', error: e);
      return false;
    }
  }

  Future<int?> getPosition() async {
    if (_selectedDevice == null) return null;
    try {
      return await _dlnaService.getPosition(_selectedDevice!);
    } catch (e) {
      AppLogger.e('获取位置失败', error: e);
      return null;
    }
  }

  Future<int?> getDuration() async {
    if (_selectedDevice == null) return null;
    try {
      return await _dlnaService.getDuration(_selectedDevice!);
    } catch (e) {
      AppLogger.e('获取时长失败', error: e);
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    _dlnaService.dispose();
    super.dispose();
  }
}
