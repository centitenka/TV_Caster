import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/video_source.dart';
import '../models/parser_rule.dart';
import '../utils/logger.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Box<VideoSource>? _videoBox;
  Box<ParserRule>? _ruleBox;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    try {
      await Hive.initFlutter();
      
      // 注册适配器
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(VideoSourceAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ParserRuleAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(RuleItemAdapter());
      }
      
      _videoBox = await Hive.openBox<VideoSource>('videos');
      _ruleBox = await Hive.openBox<ParserRule>('rules');
      
      _initialized = true;
      AppLogger.i('存储服务初始化成功');
    } catch (e) {
      AppLogger.e('存储服务初始化失败', error: e);
      rethrow;
    }
  }

  // 视频相关操作
  Future<List<VideoSource>> getVideos() async {
    await init();
    return _videoBox?.values.toList() ?? [];
  }

  Future<void> saveVideo(VideoSource video) async {
    await init();
    await _videoBox?.put(video.id, video);
  }

  Future<void> deleteVideo(String id) async {
    await init();
    await _videoBox?.delete(id);
  }

  Future<VideoSource?> getVideo(String id) async {
    await init();
    return _videoBox?.get(id);
  }

  // 规则相关操作
  Future<List<ParserRule>> getRules() async {
    await init();
    return _ruleBox?.values.toList() ?? [];
  }

  Future<void> saveRule(ParserRule rule) async {
    await init();
    await _ruleBox?.put(rule.id, rule);
  }

  Future<void> deleteRule(String id) async {
    await init();
    await _ruleBox?.delete(id);
  }

  Future<ParserRule?> getRule(String id) async {
    await init();
    return _ruleBox?.get(id);
  }

  // 设置相关
  Future<void> saveSetting(String key, dynamic value) async {
    await init();
    final box = await Hive.openBox('settings');
    await box.put(key, value);
  }

  Future<dynamic> getSetting(String key, {dynamic defaultValue}) async {
    await init();
    final box = await Hive.openBox('settings');
    return box.get(key, defaultValue: defaultValue);
  }

  Future<void> clearAll() async {
    await init();
    await _videoBox?.clear();
    await _ruleBox?.clear();
  }
}

// Hive适配器
class VideoSourceAdapter extends TypeAdapter<VideoSource> {
  @override
  final int typeId = 0;

  @override
  VideoSource read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VideoSource(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      thumbnail: fields[3] as String?,
      description: fields[4] as String?,
      createdAt: fields[5] as DateTime,
      ruleId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, VideoSource obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.thumbnail)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.ruleId);
  }
}

class ParserRuleAdapter extends TypeAdapter<ParserRule> {
  @override
  final int typeId = 1;

  @override
  ParserRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ParserRule(
      id: fields[0] as String,
      name: fields[1] as String,
      host: fields[2] as String,
      rules: (fields[3] as List).cast<RuleItem>(),
      headers: (fields[4] as Map?)?.cast<String, String>(),
      isEnabled: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      description: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ParserRule obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.host)
      ..writeByte(3)
      ..write(obj.rules)
      ..writeByte(4)
      ..write(obj.headers)
      ..writeByte(5)
      ..write(obj.isEnabled)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.description);
  }
}

class RuleItemAdapter extends TypeAdapter<RuleItem> {
  @override
  final int typeId = 2;

  @override
  RuleItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RuleItem(
      name: fields[0] as String,
      xpath: fields[1] as String,
      attribute: fields[2] as String?,
      regex: fields[3] as String?,
      replacement: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, RuleItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.xpath)
      ..writeByte(2)
      ..write(obj.attribute)
      ..writeByte(3)
      ..write(obj.regex)
      ..writeByte(4)
      ..write(obj.replacement);
  }
}
