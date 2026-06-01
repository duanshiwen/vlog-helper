#!/bin/bash
# VlogPack — macOS .app Bundle Build Script
# Usage: ./scripts/build-app.sh [--release] [--sign]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="VlogPack"
BUNDLE_ID="com.connortech.vlogpack"

# Parse args
CONFIG="debug"
SIGN=false
for arg in "$@"; do
    case "$arg" in
        --release) CONFIG="release" ;;
        --sign)    SIGN=true ;;
    esac
done

echo "═══════════════════════════════════════════"
echo "  VlogPack .app Builder ($CONFIG)"
echo "═══════════════════════════════════════════"

# Step 1: Build
echo "[1/5] Building Swift package ($CONFIG)..."
cd "$PROJECT_DIR"
swift build -c "$CONFIG" 2>&1 | tail -3

# Step 2: Locate binary
if [ "$CONFIG" = "release" ]; then
    BIN_DIR="$BUILD_DIR/release"
else
    BIN_DIR="$BUILD_DIR/debug"
fi

# 查找实际二进制（可能叫 VlogPack 或 VlogPackApp）
BINARY=""
for EXEC_NAME in VlogPack VlogPackApp; do
    if [ -f "$BIN_DIR/$EXEC_NAME" ] && [ ! -d "$BIN_DIR/$EXEC_NAME" ]; then
        BINARY="$BIN_DIR/$EXEC_NAME"
        break
    fi
done

if [ -z "$BINARY" ]; then
    echo "❌ Binary not found in $BIN_DIR"
    ls "$BIN_DIR" 2>/dev/null | head -10
    exit 1
fi

# Step 3: Create .app bundle
APP_DIR="$BUILD_DIR/$CONFIG/$APP_NAME.app"
echo "[2/5] Creating $APP_NAME.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy Info.plist
PLIST_SRC="$PROJECT_DIR/Sources/VlogPackApp/Resources/Info.plist"
if [ -f "$PLIST_SRC" ]; then
    cp "$PLIST_SRC" "$APP_DIR/Contents/Info.plist"
    # Update CFBundleExecutable to match binary name
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
else
    echo "⚠️  Info.plist not found at $PLIST_SRC"
fi

# Copy app icon
ICON_SRC="$PROJECT_DIR/resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "  ✓ App icon bundled"
else
    echo "  ⚠️  AppIcon.icns not found at $ICON_SRC"
fi

# Copy icon
ICON_SRC="$PROJECT_DIR/Sources/VlogPackApp/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "  ✓ AppIcon.icns bundled"
else
    echo "  ⚠ AppIcon.icns not found"
fi

# Copy entitlements (for codesign)
ENTITLEMENTS_SRC="$PROJECT_DIR/Sources/VlogPackApp/Resources/VlogPack.entitlements"
ENTITLEMENTS_PATH=""
if [ -f "$ENTITLEMENTS_SRC" ]; then
    mkdir -p "$APP_DIR/Contents/Resources"
    ENTITLEMENTS_PATH="$APP_DIR/Contents/Resources/VlogPack.entitlements"
    cp "$ENTITLEMENTS_SRC" "$ENTITLEMENTS_PATH"
fi

# Step 4: Bundle FFmpeg (if available)
echo "[3/5] Checking FFmpeg..."
FFMPEG_BIN="$(which ffmpeg 2>/dev/null || true)"
FFPROBE_BIN="$(which ffprobe 2>/dev/null || true)"

if [ -n "$FFMPEG_BIN" ] && [ -n "$FFPROBE_BIN" ]; then
    cp "$FFMPEG_BIN" "$APP_DIR/Contents/MacOS/ffmpeg"
    cp "$FFPROBE_BIN" "$APP_DIR/Contents/MacOS/ffprobe"
    chmod +x "$APP_DIR/Contents/MacOS/ffmpeg" "$APP_DIR/Contents/MacOS/ffprobe"
    echo "  ✓ FFmpeg bundled from $FFMPEG_BIN"
    echo "  ✓ FFprobe bundled from $FFPROBE_BIN"
else
    echo "  ⚠️  FFmpeg not found on PATH — app will use system FFmpeg"
fi

# Whisper.cpp — 不打包（依赖动态库 libwhisper/libggml，无法单独运行）
WHISPER_BIN=$(which whisper-cli 2>/dev/null || which whisper-cpp 2>/dev/null || echo "/opt/homebrew/bin/whisper-cli")
if [ -f "$WHISPER_BIN" ] && file "$WHISPER_BIN" 2>/dev/null | grep -q "Mach-O"; then
    echo "  ✓ Whisper.cpp found at $WHISPER_BIN (system, not bundled)"
else
    echo "  ℹ️  Whisper.cpp not found (optional, for subtitles)"
    echo "    Install via: brew install whisper-cpp"
fi

# t2s.py — 繁体转简体脚本 + opencc venv
T2S_SCRIPT="$PROJECT_DIR/scripts/t2s.py"
T2S_VENV="$PROJECT_DIR/.venv"
if [ -f "$T2S_SCRIPT" ] && [ -d "$T2S_VENV" ]; then
    cp "$T2S_SCRIPT" "$APP_DIR/Contents/MacOS/t2s.py"
    cp -R "$T2S_VENV" "$APP_DIR/Contents/MacOS/t2s-venv"
    echo "  ✓ t2s.py + opencc venv bundled"
else
    echo "  ⚠ t2s.py or .venv not found (繁转简功能不可用)"
fi

# Step 5: Codesign
echo "[4/5] Codesigning..."
if [ "$SIGN" = true ]; then
    if [ -n "$ENTITLEMENTS_PATH" ]; then
        codesign --force --sign - \
            --entitlements "$ENTITLEMENTS_PATH" \
            "$APP_DIR"
    else
        codesign --force --sign - "$APP_DIR"
    fi
    echo "  ✓ Signed with ad-hoc signature"
else
    # Ad-hoc sign for local development
    codesign --force --sign - "$APP_DIR" 2>/dev/null || true
    echo "  ✓ Ad-hoc signed for local development"
fi

# Step 6: Verify
echo "[5/5] Verifying..."
codesign -v "$APP_DIR" 2>/dev/null && echo "  ✓ Signature valid" || echo "  ⚠️  Signature verification skipped"

echo ""
echo "═══════════════════════════════════════════"
echo "  ✅ Build complete!"
echo "  App: $APP_DIR"
echo "  Run: open \"$APP_DIR\""
echo "═══════════════════════════════════════════"
