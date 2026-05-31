#!/bin/bash
# VlogPack — Quick dev run (build + open .app)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/build-app.sh" "$@"

APP_PATH="$SCRIPT_DIR/../.build/debug/VlogPack.app"
if [ -d "$APP_PATH" ]; then
    echo "🚀 Launching VlogPack..."
    open "$APP_PATH"
else
    echo "❌ App bundle not found at $APP_PATH"
    exit 1
fi
