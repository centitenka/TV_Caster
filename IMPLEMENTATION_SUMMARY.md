# 海信投屏 - 实现总结

## 项目概述

本项目是一款基于Flutter开发的安卓应用，实现了将视频通过DLNA协议投屏到同局域网下的海信电视。参考了[Kazumi](https://github.com/Predidit/Kazumi)项目的DLNA投屏实现。

## 核心功能实现

### 1. DLNA投屏功能

参考Kazumi项目的实现方式，使用`dlna_dart`包：

```dart
// 设备发现
final searcher = DLNAManager();
final dlna = await searcher.start();

// 投屏播放
DLNADevice(device.info).setUrl(videoUrl);
DLNADevice(device.info).play();
```

**实现文件**:
- `lib/services/dlna_service.dart` - DLNA服务封装
- `lib/providers/dlna_provider.dart` - 状态管理
- `lib/screens/cast_screen.dart` - 投屏界面

### 2. 自定义规则系统

支持使用XPath选择器自定义视频解析规则：

```dart
class ParserRule {
  final String id;
  final String name;
  final String host;
  final List<RuleItem> rules;
  final Map<String, String>? headers;
  final bool isEnabled;
}

class RuleItem {
  final String name;
  final String xpath;
  final String? attribute;
  final String? regex;
  final String? replacement;
}
```

**实现文件**:
- `lib/models/parser_rule.dart` - 规则模型
- `lib/services/video_parser_service.dart` - 解析服务
- `lib/screens/edit_rule_screen.dart` - 规则编辑

### 3. 视频解析流程

1. 获取网页HTML内容
2. 使用XPath选择器提取视频元素
3. 应用正则表达式进一步处理
4. 返回解析结果列表

```dart
Future<List<Map<String, dynamic>>> parseVideo(String url) async {
  final response = await dio.get(url);
  final document = parse(response.data);
  
  // 1. 查找video标签
  // 2. 查找source标签
  // 3. 在script中查找视频URL
  // 4. 返回结果列表
}
```

### 4. 海信电视优化

- 自动识别海信电视设备（通过设备名称匹配）
- 海信电视优先显示
- 针对海信电视的DLNA兼容性处理

```dart
bool get isHisenseTV {
  return name.toLowerCase().contains('hisense') || 
         name.toLowerCase().contains('海信');
}
```

## 技术栈

| 技术 | 用途 |
|------|------|
| Flutter 3.x | 跨平台UI框架 |
| Dart 3.x | 编程语言 |
| dlna_dart | DLNA协议实现 |
| dio/http | 网络请求 |
| html/xpath_selector | HTML解析 |
| hive | 本地存储 |
| provider | 状态管理 |

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型（3个）
├── providers/             # 状态管理（3个）
├── services/              # 业务服务（3个）
├── screens/               # 页面（10个）
└── utils/                 # 工具类
```

## 关键代码片段

### DLNA设备发现
```dart
class DLNAService {
  Future<void> startDiscovery() async {
    _manager = DLNAManager();
    _client = await _manager!.start();
    
    _client!.devices.stream.listen((deviceMap) {
      final devices = deviceMap.values.toList();
      _devicesController.add(devices);
    });
  }
}
```

### 视频解析
```dart
class VideoParserService {
  Future<List<Map<String, dynamic>>> parseVideo(String url) async {
    final results = <Map<String, dynamic>>[];
    final response = await _dio.get(url);
    final html = response.data.toString();
    final document = parse(html);
    
    // 查找video标签
    final videoElements = document.querySelectorAll('video');
    for (final video in videoElements) {
      final src = video.attributes['src'];
      if (src != null) {
        results.add({
          'type': 'video',
          'url': _resolveUrl(url, src),
        });
      }
    }
    
    return results;
  }
}
```

### 投屏控制
```dart
class DLNAProvider extends ChangeNotifier {
  Future<bool> castVideo(String videoUrl) async {
    if (_selectedDevice == null) return false;
    
    final success = await _dlnaService.castVideo(
      _selectedDevice!,
      videoUrl,
    );
    
    return success;
  }
  
  Future<bool> pause() => _dlnaService.pause(_selectedDevice!);
  Future<bool> play() => _dlnaService.play(_selectedDevice!);
  Future<bool> stop() => _dlnaService.stop(_selectedDevice!);
}
```

## 参考实现

本项目DLNA投屏功能参考了Kazumi项目的实现：

**Kazumi项目代码**:
```dart
// lib/utils/remote.dart
class RemotePlay {
  Future<void> castVideo(String video, String referer) async {
    final searcher = DLNAManager();
    final dlna = await searcher.start();
    
    dlna.devices.stream.listen((deviceList) {
      deviceList.forEach((key, value) {
        DLNADevice(value.info).setUrl(video);
        DLNADevice(value.info).play();
      });
    });
  }
}
```

## 扩展功能

相比Kazumi的参考实现，本项目增加了：

1. **完整的UI界面** - 10个页面，覆盖所有功能
2. **视频管理** - 本地保存和管理视频链接
3. **规则系统** - 完整的XPath规则CRUD
4. **海信优化** - 针对海信电视的特殊处理
5. **播放控制** - 完整的播放控制功能
6. **数据持久化** - Hive本地存储

## 构建说明

### 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK >= 21

### 构建命令
```bash
# 获取依赖
flutter pub get

# 构建APK
flutter build apk --release

# 或使用脚本
./build.sh
```

## 后续优化方向

1. **视频播放器** - 集成video_player实现本地播放
2. **弹幕支持** - 添加弹幕功能
3. **历史记录** - 播放历史追踪
4. **收藏功能** - 视频收藏管理
5. **多语言** - 国际化支持
6. **主题切换** - 深色/浅色主题

## 许可证

MIT License
