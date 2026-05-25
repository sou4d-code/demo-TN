#!/usr/bin/env python3
"""Serve Resources folder for sample HTML preview — avoids os.getcwd() at import time."""
import http.server
import os

SERVE_DIR = "/Users/ram/Documents/demo-TN/Resources"
PORT = 8081

os.chdir(SERVE_DIR)

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=SERVE_DIR, **kwargs)

with http.server.HTTPServer(("", PORT), Handler) as httpd:
    print(f"Serving {SERVE_DIR} → http://localhost:{PORT}/sample.html")
    httpd.serve_forever()
