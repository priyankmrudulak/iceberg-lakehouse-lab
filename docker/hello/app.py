"""A tiny web app used only to practise Docker concepts in Milestone 0.

You don't need to change this file. It shows three things a container gets from
outside itself:
  - config from an environment variable (LAB_NAME)
  - code from a bind mount (this file lives on your Mac, mounted at /app)
  - state from a named volume (the visit counter in /data survives restarts)

Endpoints:
  /        greets you and counts the visit
  /health  returns 200 OK, used by the Docker healthcheck
"""

import os
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

PORT = 8000  # the port *inside* the container
DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
COUNTER = DATA_DIR / "visits.txt"
LAB_NAME = os.environ.get("LAB_NAME", "(LAB_NAME not set)")


def next_visit() -> int:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    count = int(COUNTER.read_text()) + 1 if COUNTER.exists() else 1
    COUNTER.write_text(str(count))
    return count


class Handler(BaseHTTPRequestHandler):
    def _send(self, status: int, body: str) -> None:
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send(200, "ok\n")
        elif self.path == "/":
            visits = next_visit()
            self._send(
                200,
                f"Hello from {LAB_NAME}!\n"
                f"container hostname: {socket.gethostname()}\n"
                f"visits: {visits}\n",
            )
        else:
            self._send(404, "not found\n")


if __name__ == "__main__":
    print(f"listening on 0.0.0.0:{PORT} (inside the container)", flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
