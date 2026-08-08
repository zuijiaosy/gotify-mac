#!/bin/bash
# 构建并启动 Gotify Mac：先退出正在运行的旧实例，再构建、打开新的 .app。
set -euo pipefail

cd "$(dirname "$0")"

# 旧实例在运行时 open 不会加载新二进制，先请它退出
osascript -e 'tell application "Gotify Mac" to quit' 2>/dev/null || true

scripts/build-app.sh
open "build/Gotify Mac.app"
