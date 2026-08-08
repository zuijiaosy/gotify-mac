#!/bin/bash
# 构建 GotifyMac 并组装为可运行的 .app bundle（ad-hoc 签名）。
# 用法: scripts/build-app.sh [debug|release]，默认 release。
# 产物: build/Gotify Mac.app
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Gotify Mac"
APP_DIR="build/${APP_NAME}.app"

swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/GotifyMac"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/GotifyMac"
cp Support/Info.plist "$APP_DIR/Contents/Info.plist"

codesign --force --sign - "$APP_DIR"

echo "已生成: $APP_DIR"
