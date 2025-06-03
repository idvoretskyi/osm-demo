#!/usr/bin/env python3
"""
Secure Application - Demo for OCM Signing
This application demonstrates a component that will be cryptographically signed.
"""

import http.server
import socketserver
import json
from datetime import datetime

class SecurityHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'version': 'v1.0.0',
                'signed': True
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            html = """
            <html><body>
            <h1>🔐 Signed Application</h1>
            <p>This application was packaged and signed using OCM.</p>
            <p>Signature verification ensures integrity and authenticity.</p>
            <a href="/health">Health Check</a>
            </body></html>
            """
            self.wfile.write(html.encode())

if __name__ == "__main__":
    PORT = 8080
    with socketserver.TCPServer(("", PORT), SecurityHandler) as httpd:
        print(f"🚀 Secure app serving at port {PORT}")
        httpd.serve_forever()
