#!/usr/bin/env python3

"""
Local server for the WASM demo.
Usage: python3 src/wasm/serve.py
"""

import http.server
import socketserver
from pathlib import Path
from functools import partial

PORT = 8002

ROOT = Path(__file__).resolve().parents[2]

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

if __name__ == "__main__":
    handler = partial(Handler, directory=str(ROOT))

    with socketserver.TCPServer(("", PORT), handler) as httpd:
        print(f"Serving {ROOT} on http://localhost:{PORT}")
        httpd.serve_forever()
