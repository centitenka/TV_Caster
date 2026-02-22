#!/bin/bash

# 海信投屏 - 构建脚本

echo "================================"
echo "海信投屏 - 构建脚本"
echo "================================"

# 检查Flutter
if ! command -v flutter &> /dev/null; then
    echo "错误: 未找到Flutter，请确保Flutter已安装并添加到PATH"
    exit 1
fi

# 显示Flutter版本
echo ""
echo "Flutter版本:"
flutter --version

# 获取依赖
echo ""
echo "[1/4] 获取依赖..."
flutter pub get

# 运行代码生成
echo ""
echo "[2/4] 运行代码生成..."
flutter pub run build_runner build --delete-conflicting-outputs || true

# 分析代码
echo ""
echo "[3/4] 分析代码..."
flutter analyze

# 构建APK
echo ""
echo "[4/4] 构建APK..."
flutter build apk --release

echo ""
echo "================================"
echo "构建完成!"
echo "APK路径: build/app/outputs/flutter-apk/app-release.apk"
echo "================================"
