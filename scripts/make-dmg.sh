#!/bin/bash
# 把 build/Gotify Mac.app 打包成可拖拽安装的 DMG（内含 /Applications 快捷方式）。
# 用法: scripts/make-dmg.sh [版本号]，默认取 .app 内的 CFBundleShortVersionString。
# 产物: build/Gotify-Mac-<版本号>.dmg
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Gotify Mac"
APP_DIR="build/${APP_NAME}.app"

if [ ! -d "$APP_DIR" ]; then
  echo "未找到 $APP_DIR，请先运行 scripts/build-app.sh" >&2
  exit 1
fi

VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")}"
DMG_PATH="build/Gotify-Mac-${VERSION}.dmg"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

cp -R "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null

echo "已生成: $DMG_PATH"
