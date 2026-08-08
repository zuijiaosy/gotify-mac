#!/bin/bash
# 端到端 UI 验证（半自动）：起服务端 → 重启应用 → 发 4 条不同优先级消息
# → AppleScript 点开菜单栏面板 → 截图到 build/e2e/ → 人工看图确认。
# 依赖两项系统权限（首次运行需授权当前终端）：
#   辅助功能（AppleScript 点击）、屏幕录制（screencapture）
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[1/5] 启动 Gotify 服务端…"
docker compose -f deploy/gotify/docker-compose.yml up -d >/dev/null
ok=""
for _ in $(seq 1 30); do
    if curl -sf http://127.0.0.1:18080/health >/dev/null; then ok=1; break; fi
    sleep 1
done
[ -n "$ok" ] || { echo "服务端健康检查超时"; exit 1; }

echo "[2/5] 构建并重启应用…"
./start.sh >/dev/null
sleep 3

echo "[3/5] 发送 4 条不同优先级消息…"
TS=$(date +%H%M%S)
APP_TOKEN=$(curl -s -u admin:admin -X POST http://127.0.0.1:18080/application \
    -H 'Content-Type: application/json' -d "{\"name\":\"E2E-$TS\"}" \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
for P in 0 2 5 9; do
    curl -s -X POST http://127.0.0.1:18080/message -H "X-Gotify-Key: $APP_TOKEN" \
        -H 'Content-Type: application/json' \
        -d "{\"title\":\"E2E-$TS 优先级 $P\",\"message\":\"端到端验证消息，priority=$P\",\"priority\":$P}" \
        -o /dev/null
done
sleep 2   # 等 WebSocket 送达；此时应看到系统通知横幅

echo "[4/5] 打开菜单栏面板…"
if ! osascript -e 'tell application "System Events" to tell (first process whose name is "GotifyMac") to click menu bar item 1 of menu bar 2' 2>/dev/null; then
    echo "  ⚠️ AppleScript 点击失败：请在 系统设置→隐私与安全性→辅助功能 授权当前终端；"
    echo "     本次请手动点击菜单栏铃铛，然后按回车继续…"
    read -r || true
fi
sleep 1.5

echo "[5/5] 截图…"
mkdir -p build/e2e
SHOT="build/e2e/panel-$TS.png"
if ! screencapture -x "$SHOT" 2>/dev/null || [ ! -s "$SHOT" ]; then
    echo "  ⚠️ 截图失败：请在 系统设置→隐私与安全性→屏幕录制 授权当前终端后重跑"
    exit 1
fi

echo "✅ 截图已保存: $SHOT"
echo "请人工确认：列表顶部应有 4 条 \"E2E-$TS\" 消息，色点自上而下为 红(9)/橙(5)/蓝(2)/灰(0)，"
echo "并且刚才屏幕右上角弹出过系统通知横幅。"
