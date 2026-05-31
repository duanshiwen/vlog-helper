#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== VlogPack Verification ==="
echo "Project: $PROJECT_DIR"
echo ""

echo "[1/2] Building..."
cd "$PROJECT_DIR"
swift build
echo "✅ Build passed"
echo ""

echo "[2/2] Testing..."
swift test
echo ""
echo "✅ All tests passed"
echo ""
echo "=== Verification complete ==="
