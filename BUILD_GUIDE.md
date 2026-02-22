# 海信投屏 - APK构建指南

## 环境要求

- Flutter SDK 3.0.0 或更高版本
- Dart SDK 3.0.0 或更高版本
- Android SDK API 33+
- Android Build Tools 33.0.0+
- JDK 17 或更高版本

## 构建步骤

### 1. 安装 Flutter

```bash
# 下载 Flutter
git clone https://github.com/flutter/flutter.git -b stable

# 添加到 PATH
export PATH="$PWD/flutter/bin:$PATH"

# 验证安装
flutter doctor
```

### 2. 安装 Android SDK

```bash
# 下载 Android SDK 命令行工具
mkdir -p ~/android-sdk
cd ~/android-sdk
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip commandlinetools-linux-*.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/bin cmdline-tools/lib cmdline-tools/NOTICE.txt cmdline-tools/source.properties cmdline-tools/latest/

# 设置环境变量
export ANDROID_HOME="$HOME/android-sdk"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# 安装必要的 SDK 组件
sdkmanager "platforms;android-33" "build-tools;33.0.0" "platform-tools"

# 接受许可证
yes | sdkmanager --licenses
```

### 3. 获取项目依赖

```bash
cd hisense_caster
flutter pub get
```

### 4. 构建 APK

```bash
# 构建发布版 APK
flutter build apk --release

# 构建结果位置
# build/app/outputs/flutter-apk/app-release.apk
```

### 5. 安装 APK

```bash
# 连接到设备
adb devices

# 安装 APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 常见问题

### Q: Gradle 下载超时
**A:** 配置 Gradle 镜像

在 `android/build.gradle` 中添加：
```gradle
allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/jcenter' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        google()
        mavenCentral()
    }
}
```

### Q: Kotlin 版本不兼容
**A:** 更新 `android/build.gradle` 中的 Kotlin 版本：
```gradle
plugins {
    id "com.android.application" version "7.3.0" apply false
    id "org.jetbrains.kotlin.android" version "1.7.10" apply false
}
```

### Q: 构建失败，缺少依赖
**A:** 清理并重新构建：
```bash
flutter clean
flutter pub get
flutter build apk --release
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── models/                # 数据模型
│   ├── video_source.dart
│   ├── dlna_device.dart
│   └── parser_rule.dart
├── providers/             # 状态管理
│   ├── dlna_provider.dart
│   ├── video_provider.dart
│   └── rule_provider.dart
├── services/              # 业务服务
│   ├── dlna_service.dart
│   ├── video_parser_service.dart
│   └── storage_service.dart
├── screens/               # 页面
│   ├── splash_screen.dart
│   ├── home_screen.dart
│   ├── video_list_screen.dart
│   ├── dlna_devices_screen.dart
│   ├── cast_screen.dart
│   ├── rules_screen.dart
│   └── settings_screen.dart
└── utils/                 # 工具类
    └── logger.dart
```

## 功能特性

- **DLNA投屏**: 自动搜索并连接同网络的海信电视
- **视频解析**: 支持自定义XPath规则解析视频网页
- **设备管理**: 自动识别海信电视，优先显示和连接
- **播放控制**: 支持播放、暂停、停止、进度控制

## 参考项目

本项目参考了 [Kazumi](https://github.com/Predidit/Kazumi) 的DLNA投屏实现。

## 许可证

MIT License
