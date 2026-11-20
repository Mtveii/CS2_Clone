#!/usr/bin/env bash
# Запуск всего проекта в web-режиме (HTTPS + COOP/COEP).
# 1) экспорт Godot -> build/  2) самоподписанный сертификат  3) WSS игровой сервер
# 4) HTTPS статический сервер. Остановка: Ctrl+C.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WEB_PORT="${WEB_PORT:-8080}"
GAME_PORT="${GAME_PORT:-7777}"
BUILD_DIR="$ROOT/build"
CERT="$BUILD_DIR/cert.pem"
KEY="$BUILD_DIR/key.pem"

# --- выбор Godot ---
if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif [[ -x /tmp/opencode/godot_src/bin/godot.linuxbsd.editor.x86_64 ]]; then
  GODOT=/tmp/opencode/godot_src/bin/godot.linuxbsd.editor.x86_64
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
else
  echo "ОШИБКА: Godot не найден. Укажите GODOT_BIN=/путь/к/godot" >&2
  exit 1
fi

echo "==> Godot: $GODOT"

# --- экспорт web ---
echo "==> Экспорт web-сборки в build/ ..."
mkdir -p "$BUILD_DIR"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$BUILD_DIR/index.html"
cp "$ROOT/infra/cloudflare/_headers" "$BUILD_DIR/_headers"
echo "==> Экспорт готов"

# --- HTTPS сертификат (самоподписанного, для localhost) ---
if [[ ! -f "$CERT" || ! -f "$KEY" ]]; then
  echo "==> Генерация самоподписанного сертификата ..."
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$KEY" -out "$CERT" -days 365 \
    -subj "/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" >/dev/null 2>&1
fi

# --- игровой сервер (WSS) ---
echo "==> Запуск игрового сервера на порту $GAME_PORT ..."
GAME_SERVER_PORT="$GAME_PORT" node "$ROOT/server/smoke/ws_server.js" &
SERVER_PID=$!

# --- HTTPS статический сервер ---
echo "==> Запуск HTTPS web-сервера на порту $WEB_PORT ..."
python3 "$ROOT/scripts/serve_web.py" "$WEB_PORT" "$BUILD_DIR" "$CERT" "$KEY" &
WEB_PID=$!

cleanup() {
  echo
  echo "==> Остановка серверов..."
  kill "$SERVER_PID" "$WEB_PID" 2>/dev/null || true
  wait "$SERVER_PID" "$WEB_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo
echo "================================================"
echo " ГОТОВО"
echo " Игра:   https://127.0.0.1:$WEB_PORT/"
echo " Сервер: ws://127.0.0.1:$GAME_PORT"
echo " ВАЖНО: браузер покажет предупреждение о сертификате —"
echo "        нажмите «Дополнительно» → «Перейти на сайт»."
echo " Ctrl+C — остановить"
echo "================================================"

wait
