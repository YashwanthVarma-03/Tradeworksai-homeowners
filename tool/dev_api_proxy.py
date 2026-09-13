import json
import os
import socketserver
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler


TARGET_BASE = os.environ.get(
    "TRADEWORKS_PROXY_TARGET",
    "https://tradeworks-api-71668222585.us-east1.run.app/",
).rstrip("/") + "/"
PORT = int(os.environ.get("TRADEWORKS_PROXY_PORT", "8787"))


class ThreadingHTTPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    allow_reuse_address = True


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_OPTIONS(self):
        self.send_response(204)
        self._write_cors_headers()
        self.end_headers()

    def do_GET(self):
        self._forward()

    def do_POST(self):
        self._forward()

    def do_PUT(self):
        self._forward()

    def do_PATCH(self):
        self._forward()

    def do_DELETE(self):
        self._forward()

    def _forward(self):
        body = b""
        content_length = int(self.headers.get("Content-Length", "0") or "0")
        if content_length > 0:
            body = self.rfile.read(content_length)

        upstream_url = TARGET_BASE + self.path.lstrip("/")
        request = urllib.request.Request(
            upstream_url,
            data=body if self.command in {"POST", "PUT", "PATCH", "DELETE"} else None,
            method=self.command,
        )

        for key, value in self.headers.items():
            lower = key.lower()
            if lower in {"host", "content-length", "connection"}:
                continue
            request.add_header(key, value)

        try:
            with urllib.request.urlopen(request, timeout=20) as upstream:
                response_body = upstream.read()
                status = upstream.getcode()
                headers = upstream.headers
                self.send_response(status)
                self._write_cors_headers()
                for key, value in headers.items():
                    lower = key.lower()
                    if lower in {
                        "content-length",
                        "transfer-encoding",
                        "connection",
                        "content-encoding",
                    }:
                        continue
                    self.send_header(key, value)
                self.send_header("Content-Length", str(len(response_body)))
                self.end_headers()
                self.wfile.write(response_body)
        except urllib.error.HTTPError as error:
            response_body = error.read()
            self.send_response(error.code)
            self._write_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response_body)))
            self.end_headers()
            self.wfile.write(response_body)
        except Exception as error:
            payload = json.dumps(
                {
                    "success": False,
                    "error": f"TradeWorks local proxy error: {error}",
                }
            ).encode("utf-8")
            self.send_response(502)
            self._write_cors_headers()
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

    def _write_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header(
            "Access-Control-Allow-Headers",
            "Origin, X-Requested-With, Content-Type, Accept, Authorization",
        )
        self.send_header(
            "Access-Control-Allow-Methods",
            "GET, POST, PUT, PATCH, DELETE, OPTIONS",
        )


if __name__ == "__main__":
    with ThreadingHTTPServer(("127.0.0.1", PORT), ProxyHandler) as server:
        print(
            f"TradeWorks local proxy listening on http://127.0.0.1:{PORT}/ -> {TARGET_BASE}",
            flush=True,
        )
        server.serve_forever()
