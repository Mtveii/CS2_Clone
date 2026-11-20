#!/usr/bin/env python3
"""Статический сервер для web-сборки Godot с COOP/COEP и HTTPS.

Использование:
  python3 scripts/serve_web.py [порт] [папка] [cert.pem] [key.pem]

Если указаны cert/key — включается HTTPS (требуется Godot Web: Secure Context).
"""
import http.server
import mimetypes
import os
import socketserver
import ssl
import sys

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
ROOT = sys.argv[2] if len(sys.argv) > 2 else "build"
CERT = sys.argv[3] if len(sys.argv) > 3 else ""
KEY = sys.argv[4] if len(sys.argv) > 4 else ""


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # Godot Web требует cross-origin isolation для threads/GDExtension.
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

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
