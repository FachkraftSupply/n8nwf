#!/usr/bin/env python3
"""HTTP endpoint noi bo cho vps_info.py - CHI n8n (chay tren cung VPS) goi
duoc, khong expose ra internet. Xac thuc bang shared-secret token trong
header X-Auth-Token. Chi dung Python stdlib."""
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INFO_SCRIPT = os.path.join(SCRIPT_DIR, "vps_info.py")
TOKEN = os.environ.get("VPS_MONITOR_TOKEN", "")
PORT = int(os.environ.get("VPS_MONITOR_PORT", "8787"))
BIND = os.environ.get("VPS_MONITOR_BIND", "127.0.0.1")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/vps-info":
            self.send_response(404)
            self.end_headers()
            return

        if not TOKEN or self.headers.get("X-Auth-Token") != TOKEN:
            self.send_response(401)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"error":"unauthorized"}')
            return

        try:
            result = subprocess.run(
                ["python3", INFO_SCRIPT],
                capture_output=True, text=True, timeout=20, check=True,
            )
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(result.stdout.encode("utf-8"))
        except Exception as exc:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(exc)}).encode("utf-8"))

    def log_message(self, format, *args):
        pass  # tat log mac dinh cua BaseHTTPRequestHandler (in ra stdout moi request)


def main():
    if not TOKEN:
        raise SystemExit("VPS_MONITOR_TOKEN chua duoc set trong environment - xem README.md")
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    print(f"vps-monitor dang chay tren {BIND}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
