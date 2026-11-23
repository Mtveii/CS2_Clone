#!/usr/bin/env python3
"""HTTP -> HTTPS редирект (для адресов вида http://100.x.x.x:8080/).

Использование: python3 scripts/redirect_http.py [порт] https://host:port/
"""
import http.server
import socketserver
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
TARGET = sys.argv[2] if len(sys.argv) > 2 else "https://127.0.0.1:8443/"


class Redirect(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(301)
        self.send_header("Location", TARGET.rstrip("/") + self.path)
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(f"Redirecting to {TARGET}".encode())

    def do_HEAD(self):
        self.send_response(301)
        self.send_header("Location", TARGET.rstrip("/") + self.path)
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

    def log_message(self, fmt, *args):
        print("[redirect] " + (fmt % args))


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    print(f"HTTP {PORT} -> {TARGET}")
    with Server(("0.0.0.0", PORT), Redirect) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
