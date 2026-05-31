#!/bin/bash
set -euo pipefail

# VlogPack DMG 打包脚本
# 用法: ./scripts/package-dmg.sh [--release]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION="0.1.0"
CONFIG="release"
APP_NAME="VlogPack"
BUILD_DIR="$PROJECT_ROOT/.build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="VlogPack-${VERSION}-macOS.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --release) CONFIG="release"; shift ;;
        *) echo "未知参数: $1"; exit 1 ;;
    esac
done

# 1. 先构建 App
echo "🔨 构建 App..."
"$SCRIPT_DIR/build-app.sh" --release

if [ ! -d "$APP_DIR" ]; then
    echo "❌ App Bundle 不存在: $APP_DIR"
    exit 1
fi

# 2. 创建 DMG
echo "💿 创建 DMG..."
rm -f "$DMG_PATH"

# 创建临时目录
TEMP_DIR=$(mktemp -d)
cp -R "$APP_DIR" "$TEMP_DIR/"

# 创建 Applications 链接
ln -s /Applications "$TEMP_DIR/Applications"

# 使用 hdiutil 创建 DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$TEMP_DIR" \
    -ov -format UDZO \
    "$DMG_PATH"

# 清理
rm -rf "$TEMP_DIR"

echo ""
echo "✅ DMG 打包完成!"
echo "   DMG 路径: $DMG_PATH"
echo "   大小: $(du -h "$DMG_PATH" | cut -f1)"
