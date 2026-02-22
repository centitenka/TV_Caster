# 项目结构说明

## 目录结构

```
hisense_caster/
├── android/                    # Android平台配置
│   ├── app/
│   │   ├── build.gradle       # App构建配置
│   │   └── src/main/
│   │       ├── AndroidManifest.xml    # 应用清单
│   │       ├── kotlin/com/example/hisense_caster/
│   │       │   └── MainActivity.kt    # 主Activity
│   │       └── res/xml/
│   │           └── network_security_config.xml  # 网络安全配置
│   ├── build.gradle           # 项目构建配置
│   ├── settings.gradle        # Gradle设置
│   └── gradle/wrapper/
│       └── gradle-wrapper.properties  # Gradle包装器配置
│
├── assets/                    # 静态资源
│   └── rules/
│       └── default_rules.json # 默认解析规则
│
├── lib/                       # Dart源代码
│   ├── main.dart              # 应用入口
│   ├── models/                # 数据模型
│   │   ├── models.dart        # 模型导出
│   │   ├── video_source.dart  # 视频源模型
│   │   ├── dlna_device.dart   # DLNA设备模型
│   │   └── parser_rule.dart   # 解析规则模型
│   │
│   ├── providers/             # 状态管理
│   │   ├── providers.dart     # Provider导出
│   │   ├── dlna_provider.dart # DLNA状态管理
│   │   ├── video_provider.dart# 视频状态管理
│   │   └── rule_provider.dart # 规则状态管理
│   │
│   ├── services/              # 业务服务
│   │   ├── services.dart      # 服务导出
│   │   ├── dlna_service.dart  # DLNA服务
│   │   ├── video_parser_service.dart  # 视频解析服务
│   │   └── storage_service.dart       # 存储服务
│   │
│   ├── screens/               # 页面
│   │   ├── screens.dart       # 页面导出
│   │   ├── splash_screen.dart # 启动页
│   │   ├── home_screen.dart   # 主页
│   │   ├── video_list_screen.dart     # 视频列表
│   │   ├── add_video_screen.dart      # 添加视频
│   │   ├── video_detail_screen.dart   # 视频详情
│   │   ├── dlna_devices_screen.dart   # 设备列表
│   │   ├── cast_screen.dart   # 投屏页面
│   │   ├── rules_screen.dart  # 规则列表
│   │   ├── edit_rule_screen.dart      # 编辑规则
│   │   └── settings_screen.dart       # 设置
│   │
│   └── utils/                 # 工具类
│       └── logger.dart        # 日志工具
│
├── test/                      # 测试文件
│   └── widget_test.dart       # Widget测试
│
├── pubspec.yaml               # 依赖配置
├── analysis_options.yaml      # 代码分析配置
├── build.sh                   # 构建脚本
├── README.md                  # 项目说明
└── PROJECT_STRUCTURE.md       # 本文件
```

## 核心模块说明

### 1. 数据模型 (models/)

#### VideoSource
视频源数据模型，用于存储视频信息。
- `id`: 唯一标识
- `name`: 视频名称
- `url`: 视频链接
- `thumbnail`: 缩略图URL
- `description`: 描述
- `createdAt`: 创建时间
- `ruleId`: 使用的解析规则ID

#### DLNADeviceModel
DLNA设备模型，封装设备信息。
- `id`: 设备UDN
- `name`: 设备名称
- `deviceType`: 设备类型
- `urlBase`: 设备URL
- `rawDevice`: 原始DLNA设备对象
- `isConnected`: 连接状态

#### ParserRule
解析规则模型，定义视频解析规则。
- `id`: 规则ID
- `name`: 规则名称
- `host`: 匹配的域名
- `rules`: XPath规则列表
- `headers`: 请求头
- `isEnabled`: 是否启用

### 2. 状态管理 (providers/)

使用Provider进行状态管理：

#### DLNAProvider
- 设备搜索和发现
- 设备选择
- 投屏控制（播放、暂停、停止、seek）

#### VideoProvider
- 视频列表管理
- 视频解析
- 当前视频状态

#### RuleProvider
- 规则CRUD操作
- 规则导入/导出
- 规则启用/禁用

### 3. 业务服务 (services/)

#### DLNAService
- DLNA设备发现
- 投屏操作封装
- 播放控制

#### VideoParserService
- 网页视频解析
- XPath规则执行
- 正则表达式处理

#### StorageService
- Hive本地存储
- 数据持久化

### 4. 页面 (screens/)

| 页面 | 功能 |
|------|------|
| SplashScreen | 应用启动页，初始化存储 |
| HomeScreen | 主页，底部导航 |
| VideoListScreen | 视频列表展示和管理 |
| AddVideoScreen | 添加视频，支持自动解析 |
| VideoDetailScreen | 视频详情和本地播放 |
| DLNADevicesScreen | DLNA设备搜索和选择 |
| CastScreen | 投屏控制界面 |
| RulesScreen | 解析规则管理 |
| EditRuleScreen | 创建/编辑规则 |
| SettingsScreen | 应用设置 |

## 数据流

```
用户操作 → Provider → Service → 外部服务/存储
                ↓
              UI更新 ← 状态变化通知
```

## 关键依赖

| 依赖 | 用途 |
|------|------|
| dlna_dart | DLNA协议实现 |
| dio/http | 网络请求 |
| html/xpath_selector | HTML解析 |
| hive | 本地存储 |
| provider | 状态管理 |

## 构建流程

1. 获取依赖: `flutter pub get`
2. 代码生成: `flutter pub run build_runner build`
3. 代码分析: `flutter analyze`
4. 构建APK: `flutter build apk --release`

或使用提供的脚本: `./build.sh`
