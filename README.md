# TV投屏 - TV Caster

一款基于Flutter开发的安卓应用，支持通过DLNA协议将视频投屏到同局域网下的电视。

## 功能特性

- **DLNA投屏**: 自动搜索局域网内DLNA设备，支持视频投屏播放
- **视频解析**: 支持自定义XPath规则解析视频网页，自动提取视频源
- **播放控制**: 支持播放、暂停、停止、进度控制等基本操作
- **本地代理**: 内置本地代理服务器，解决跨域和Referer验证问题
- **规则管理**: 支持自定义规则导入/导出，适配各种视频网站

## 技术实现

### 核心技术栈

| 功能 | 技术方案 |
|------|----------|
| 设备发现 | SSDP多播协议 (UDP 239.255.255.250:1900) |
| 设备控制 | DLNA/UPnP AVTransport SOAP接口 |
| 视频解析 | XPath + 正则表达式 |
| 状态管理 | Provider |
| 本地存储 | Hive |
| 网络请求 | Dio + http |

### 关键实现

**DLNA设备发现**
- 通过SSDP协议发送M-SEARCH广播，监听设备响应
- 解析设备描述XML，提取MediaRenderer服务控制URL
- 自动识别海信电视设备，优先显示

**视频投屏**
- 使用SOAP协议调用AVTransport服务
- 支持SetAVTransportURI、Play、Pause、Stop、Seek等操作
- 自动检测视频格式(MP4/M3U8/FLV等)，生成正确的ProtocolInfo

**本地代理服务**
- 动态启动本地HTTP代理服务器
- 转发远程视频流，添加必要的Referer/User-Agent头
- 支持本地视频文件直接投屏

## 部署与使用

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android SDK API 33+
- JDK 17+

### 构建步骤

```bash
# 1. 安装依赖
flutter pub get

# 2. 构建Release APK
flutter build apk --release

# 3. 安装到设备
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 使用方法

1. **添加视频**
   - 点击首页右下角"+"按钮
   - 输入视频网页链接（应用会自动解析视频源）
   - 或使用自定义XPath规则定向解析

2. **搜索设备**
   - 进入"设备"页面
   - 点击"搜索设备"
   - 确保手机和电视在同一WiFi网络

3. **投屏播放**
   - 选择要播放的视频
   - 点击"投屏到电视"
   - 选择目标设备开始播放

4. **自定义解析规则**
   - 进入"规则"页面
   - 新建规则，配置XPath选择器提取视频链接
   - 支持JSON格式规则导入/导出

### 规则示例

```json
{
  "name": "示例规则",
  "host": "example.com",
  "rules": [
    {
      "name": "video",
      "xpath": "//video/@src"
    },
    {
      "name": "m3u8",
      "xpath": "//script[contains(text(),'.m3u8')]",
      "regex": "[\"']([^\"']+\\.m3u8[^\"']*)[\"']"
    }
  ]
}
```

## 网络要求

- 手机和电视必须在同一WiFi网络
- 电视需要开启DLNA功能（通常在设置-网络-多屏互动中）
- 支持所有DLNA/UPnP MediaRenderer兼容设备

## 项目结构

```
lib/
├── models/           # 数据模型（视频源、DLNA设备、解析规则）
├── providers/        # Provider状态管理
├── services/         # 业务服务（DLNA、视频解析、存储）
├── screens/          # 页面UI
├── utils/            # 工具类
└── main.dart         # 应用入口
```

## 开源许可

MIT License

> 本应用仅供学习交流使用，请勿用于非法用途。
