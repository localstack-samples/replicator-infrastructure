#!/usr/bin/env python3

import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import json


class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        response_payload = {
            "status": "ok",
            "value": 42,
        }
        print("Handling GET request")
        self.send_response(200)
        self.end_headers()
        self.wfile.write(json.dumps(response_payload).encode())


port = int(os.getenv("BACKEND_PORT", "3000"))
print(f"Starting HTTP server on port {port}")
httpd = HTTPServer(("0.0.0.0", port), SimpleHTTPRequestHandler)
httpd.serve_forever()
