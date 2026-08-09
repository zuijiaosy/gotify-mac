#!/bin/bash
# 构建 GotifyMac 并组装为可运行的 .app bundle（ad-hoc 签名）。
# 用法: scripts/build-app.sh [debug|release]，默认 release。
# 环境变量 APP_VERSION / APP_BUILD 可覆盖 Info.plist 的版本号（发布流程从 git tag 传入）。
# 环境变量 APP_ARCHS 指定目标架构（如 "arm64 x86_64" 出通用二进制），
# 多架构走 xcbuild，需要完整 Xcode；纯 CLT 环境请留空用本机架构。
# 产物: build/Gotify Mac.app
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="Gotify Mac"
APP_DIR="build/${APP_NAME}.app"

ARCH_FLAGS=()
for arch in ${APP_ARCHS:-}; do
  ARCH_FLAGS+=(--arch "$arch")
done

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}

BIN_PATH="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/GotifyMac"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/GotifyMac"
cp Support/Info.plist "$APP_DIR/Contents/Info.plist"

if [ -n "${APP_VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_DIR/Contents/Info.plist"
fi
if [ -n "${APP_BUILD:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD" "$APP_DIR/Contents/Info.plist"
fi

codesign --force --sign - "$APP_DIR"

echo "已生成: $APP_DIR"
