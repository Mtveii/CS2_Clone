#!/usr/bin/env python3
"""Статический сервер web-сборки: HTTPS + COOP/COEP + WebSocket-прокси.

Использование:
  GAME_PORT=7777 python3 scripts/serve_web.py [порт] [папка] [cert.pem] [key.pem]

WebSocket-прокси: upgrade-запросы с того же origin (/ws) пересылаются на
локальный игровой сервер (plain ws), что решает проблему mixed content.
"""
import http.server
import mimetypes
import os
import socket
import socketserver
import ssl
import sys
import threading

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = sys.argv[2] if len(sys.argv) > 2 else "build"
CERT = sys.argv[3] if len(sys.argv) > 3 else ""
KEY = sys.argv[4] if len(sys.argv) > 4 else ""
GAME_PORT = int(os.environ.get("GAME_PORT", "7777"))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() == "websocket":
            self._proxy_websocket()
            return
        super().do_GET()

    def _proxy_websocket(self):
        try:
            upstream = socket.create_connection(("127.0.0.1", GAME_PORT), timeout=5)
        except OSError as e:
            self.send_error(502, f"game server unavailable: {e}")
            return
        req = f"{self.command} {self.path} {self.request_version}\r\n"
        keep = {"host", "connection", "upgrade", "sec-websocket-key",
                "sec-websocket-version", "origin", "sec-websocket-extensions",
                "sec-websocket-protocol"}
        for k, v in self.headers.items():
            if k.lower() in keep:
                req += f"{k}: {v}\r\n"
        req += "\r\n"
        try:
            upstream.sendall(req.encode("latin1"))
        except OSError:
            upstream.close()
            return

        def relay(src, dst):
            try:
                while True:
                    data = src.recv(65536)
                    if not data:
                        break
                    dst.sendall(data)
            except OSError:
                pass
            try:
                dst.shutdown(socket.SHUT_WR)
            except OSError:
                pass

        t1 = threading.Thread(target=relay, args=(self.connection, upstream), daemon=True)
        t2 = threading.Thread(target=relay, args=(upstream, self.connection), daemon=True)
        t1.start()
        t2.start()
        t1.join()
        t2.join()
        upstream.close()

    def log_message(self, fmt, *args):
        print("[web] " + (fmt % args))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    if not os.path.isdir(ROOT):
        print(f"Папка '{ROOT}' не найдена. Сначала запустите scripts/run_web.sh", file=sys.stderr)
        sys.exit(1)

    scheme = "http"
    if CERT and KEY:
        if not os.path.exists(CERT) or not os.path.exists(KEY):
            print(f"Сертификат не найден: {CERT} / {KEY}", file=sys.stderr)
            sys.exit(1)
        scheme = "https"

    print(f"Web-сервер: {scheme}://127.0.0.1:{PORT}/  (папка {ROOT})")
    print(f"WebSocket-прокси -> 127.0.0.1:{GAME_PORT}")
    print("Заголовки COOP/COEP включены — SharedArrayBuffer доступен.")
    if scheme == "https":
        print("HTTPS активен (самоподписанный сертификат — примите предупреждение браузера).")
    print("Ctrl+C для остановки.")

    with Server(("0.0.0.0", PORT), Handler) as httpd:
        if scheme == "https":
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(certfile=CERT, keyfile=KEY)
            httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nОстановлено.")
