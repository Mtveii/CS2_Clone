#!/usr/bin/env bash
# Запуск проекта: HTTP :8080 -> редирект, игра на HTTPS :8443 (Secure Context для Godot Web).
# 1) Godot (скачивается при отсутствии) 2) экспорт 3) сертификат с IP в SAN
# 4) игровой WebSocket-сервер :7777 5) HTTPS :8443 + WS-прокси 6) HTTP-редирект :8080.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HTTP_PORT="${HTTP_PORT:-8080}"
HTTPS_PORT="${HTTPS_PORT:-8443}"
GAME_PORT="${GAME_PORT:-7777}"
export GAME_PORT
BUILD_DIR="$ROOT/build"
CERT="$BUILD_DIR/cert.pem"
KEY="$BUILD_DIR/key.pem"
GODOT_LOCAL="$ROOT/tools/godot/godot"
GODOT_URL="https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip"

TAIL_IP="$(hostname -I 2>/dev/null | tr ' ' '\n' | grep '^100\.' | head -n 1 || true)"
if [[ -z "$TAIL_IP" ]]; then TAIL_IP="127.0.0.1"; fi
PUBLIC_URL="https://${TAIL_IP}:${HTTPS_PORT}/"

# --- Godot ---
find_godot() {
  if [[ -n "${GODOT_BIN:-}" && -x "$GODOT_BIN" ]]; then echo "$GODOT_BIN"; return 0; fi
  if [[ -x "$GODOT_LOCAL" ]]; then echo "$GODOT_LOCAL"; return 0; fi
  if command -v godot >/dev/null 2>&1; then command -v godot; return 0; fi
  return 1
}
if GODOT="$(find_godot)"; then
  echo "==> Godot: $GODOT"
else
  echo "==> Godot не найден. Скачиваю 4.7.2 в tools/godot/ (один раз)..."
  mkdir -p "$(dirname "$GODOT_LOCAL")"
  curl -fL --retry 3 -o "$ROOT/tools/godot/godot.zip" "$GODOT_URL"
  unzip -oq "$ROOT/tools/godot/godot.zip" -d "$ROOT/tools/godot"
  mv "$ROOT/tools/godot/Godot_v4.7.2-stable_linux.x86_64" "$GODOT_LOCAL"
  chmod +x "$GODOT_LOCAL"
  rm -f "$ROOT/tools/godot/godot.zip"
  GODOT="$GODOT_LOCAL"
fi

# --- экспорт ---
echo "==> Экспорт web в build/ ..."
mkdir -p "$BUILD_DIR"
"$GODOT" --headless --path "$ROOT" --export-release "Web" "$BUILD_DIR/index.html"
cp "$ROOT/infra/cloudflare/_headers" "$BUILD_DIR/_headers"
echo "==> Экспорт готов"

# --- сертификат с SAN для localhost и Tailscale-IP ---
echo "==> Сертификат для localhost + $TAIL_IP ..."
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$KEY" -out "$CERT" -days 365 \
  -subj "/CN=$TAIL_IP" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:$TAIL_IP" >/dev/null 2>&1

# --- игровой сервер (plain WS, проксируется через HTTPS) ---
echo "==> Игровой сервер :$GAME_PORT ..."
GAME_SERVER_PORT="$GAME_PORT" node "$ROOT/server/smoke/ws_server.js" &
SERVER_PID=$!

# --- HTTPS игра + WS-прокси ---
echo "==> HTTPS-сервер :$HTTPS_PORT ..."
python3 "$ROOT/scripts/serve_web.py" "$HTTPS_PORT" "$BUILD_DIR" "$CERT" "$KEY" &
WEB_PID=$!

# --- HTTP-редирект ---
echo "==> HTTP-редирект :$HTTP_PORT -> $PUBLIC_URL ..."
python3 "$ROOT/scripts/redirect_http.py" "$HTTP_PORT" "$PUBLIC_URL" &
REDIR_PID=$!

cleanup() {
  echo
  echo "==> Остановка серверов..."
  kill "$SERVER_PID" "$WEB_PID" "$REDIR_PID" 2>/dev/null || true
  wait "$SERVER_PID" "$WEB_PID" "$REDIR_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo
echo "================================================"
echo " ВХОД:  http://${TAIL_IP}:${HTTP_PORT}/"
echo "   -> редирект на $PUBLIC_URL"
echo " Локально: https://127.0.0.1:${HTTPS_PORT}/"
echo " Игровой сервер: ws://127.0.0.1:$GAME_PORT (прокси /ws)"
echo " Браузер покажет предупреждение о самоподписанном сертификате:"
echo "   Дополнительно -> Перейти на сайт"
echo " Ctrl+C — остановить"
echo "================================================"

wait
