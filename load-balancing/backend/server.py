import json
import os
import random
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


SERVER_ID = os.getenv("SERVER_ID", "web")
BASE_DELAY_MS = int(os.getenv("RESPONSE_DELAY_MS", "300"))
JITTER_MS = int(os.getenv("JITTER_MS", "50"))
PORT = int(os.getenv("PORT", "8000"))


class DemoHandler(BaseHTTPRequestHandler):
    server_version = "LoadBalancingDemo/1.0"

    def do_GET(self):
        parsed_url = urlparse(self.path)

        if parsed_url.path == "/health":
            self._send_json({"status": "ok", "server": SERVER_ID})
            return

        if parsed_url.path == "/favicon.ico":
            self.send_response(204)
            self.end_headers()
            return

        query = parse_qs(parsed_url.query)
        delay_ms = self._delay_from_query(query)
        time.sleep(delay_ms / 1000)

        payload = {
            "server": SERVER_ID,
            "delay_ms": delay_ms,
            "path": parsed_url.path,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "message": "Antwort vom Backend-Server",
        }
        self._send_json(payload, headers={"X-Backend-Server": SERVER_ID})

    def log_message(self, format, *args):
        print(f"{SERVER_ID} - {self.address_string()} - {format % args}", flush=True)

    def _delay_from_query(self, query):
        requested_delay = query.get("delay_ms", [None])[0]
        if requested_delay is not None:
            try:
                return max(0, min(int(requested_delay), 10000))
            except ValueError:
                return BASE_DELAY_MS

        jitter = random.randint(0, max(JITTER_MS, 0))
        return BASE_DELAY_MS + jitter

    def _send_json(self, payload, headers=None):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    with ThreadingHTTPServer(("", PORT), DemoHandler) as httpd:
        print(f"{SERVER_ID} listening on port {PORT}", flush=True)
        httpd.serve_forever()
