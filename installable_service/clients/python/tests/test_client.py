from __future__ import annotations

import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from acer_control_client import AcerControlClient, ApiError


class _Handler(BaseHTTPRequestHandler):
    last_authorization: str | None = None
    last_payload: dict[str, object] | None = None

    def do_PUT(self) -> None:
        type(self).last_authorization = self.headers.get("Authorization")
        length = int(self.headers.get("Content-Length", "0"))
        type(self).last_payload = json.loads(self.rfile.read(length))
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(type(self).last_payload).encode("utf-8"))

    def do_GET(self) -> None:
        self.send_response(503)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(
            b'{"status":"error","error":{"code":"firmware_unavailable",'
            b'"message":"Firmware unavailable."}}'
        )

    def log_message(self, format: str, *args: object) -> None:
        pass


class AcerControlClientTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        host, port = cls.server.server_address
        cls.base_url = f"http://{host}:{port}"

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self) -> None:
        _Handler.last_authorization = None
        _Handler.last_payload = None
        self.client = AcerControlClient(base_url=self.base_url, token="local-token")

    def test_fan_update_sends_token_and_camel_case_payload(self) -> None:
        response = self.client.set_fan("custom", 60, 70)

        self.assertEqual("Bearer local-token", _Handler.last_authorization)
        self.assertEqual(
            {"mode": "custom", "cpuPercent": 60, "gpuPercent": 70},
            _Handler.last_payload,
        )
        self.assertEqual(_Handler.last_payload, response)

    def test_structured_api_error_is_preserved(self) -> None:
        with self.assertRaises(ApiError) as raised:
            self.client.get_status()

        self.assertEqual(503, raised.exception.status_code)
        self.assertEqual("Firmware unavailable.", str(raised.exception))


if __name__ == "__main__":
    unittest.main()