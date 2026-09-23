#!/usr/bin/env python3
"""HTTP endpoint noi bo cho vps_info.py - CHI n8n (chay tren cung VPS) goi
duoc, khong expose ra internet. Xac thuc bang shared-secret token trong
header X-Auth-Token. Chi dung Python stdlib.

Routes:
  GET  /vps-info                       -> tong quan he thong + top container
  GET  /container-info?id=<id>         -> chi tiet 1 container
  POST /container-restart {"id":"..."} -> restart 1 container
"""
import json
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, parse_qs

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INFO_SCRIPT = os.path.join(SCRIPT_DIR, "vps_info.py")
TOKEN = os.environ.get("VPS_MONITOR_TOKEN", "")
PORT = int(os.environ.get("VPS_MONITOR_PORT", "8787"))
BIND = os.environ.get("VPS_MONITOR_BIND", "127.0.0.1")

CONTAINER_ID_RE = re.compile(r"^[a-f0-9]{12,64}$")


class Handler(BaseHTTPRequestHandler):
    def _authorized(self):
        return bool(TOKEN) and self.headers.get("X-Auth-Token") == TOKEN

    def _send_json(self, status, payload):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode("utf-8"))

    def _run_script(self, *args):
        """Goi vps_info.py nhu 1 subprocess rieng (khong import module) - giu
        nguyen cach ly tien trinh da dung cho /vps-info tu truoc."""
        try:
            result = subprocess.run(
                ["python3", INFO_SCRIPT, *args],
                capture_output=True, text=True, timeout=30, check=True,
            )
            return 200, json.loads(result.stdout)
        except subprocess.CalledProcessError as exc:
            return 500, {"error": (exc.stderr or "").strip() or "script_failed"}
        except (subprocess.TimeoutExpired, json.JSONDecodeError, OSError) as exc:
            return 500, {"error": str(exc)}

    def do_GET(self):
        if not self._authorized():
            self._send_json(401, {"error": "unauthorized"})
            return

        parsed = urlsplit(self.path)
        qs = parse_qs(parsed.query)

        if parsed.path == "/vps-info":
            status, payload = self._run_script()
            self._send_json(status, payload)
            return

        if parsed.path == "/container-info":
            container_id = (qs.get("id") or [""])[0]
            if not CONTAINER_ID_RE.match(container_id):
                self._send_json(400, {"error": "invalid_id"})
                return
            status, payload = self._run_script("container-info", container_id)
            self._send_json(status, payload)
            return

        self.send_response(404)
        self.end_headers()

    def do_POST(self):
        if not self._authorized():
            self._send_json(401, {"error": "unauthorized"})
            return

        parsed = urlsplit(self.path)
        if parsed.path != "/container-restart":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0) or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            body = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid_json"})
            return

        container_id = (body or {}).get("id", "")
        if not CONTAINER_ID_RE.match(container_id or ""):
            self._send_json(400, {"error": "invalid_id"})
            return

        status, payload = self._run_script("container-restart", container_id)
        self._send_json(status, payload)

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
