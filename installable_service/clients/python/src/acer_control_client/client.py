from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


class AcerControlError(RuntimeError):
    """Base error raised by the Acer Control client."""


class AuthenticationError(AcerControlError):
    """The service rejected or could not load the API token."""


class ApiError(AcerControlError):
    def __init__(self, message: str, status_code: int, payload: dict[str, Any] | None):
        super().__init__(message)
        self.status_code = status_code
        self.payload = payload


class AcerControlClient:
    def __init__(
        self,
        base_url: str | None = None,
        token: str | None = None,
        token_path: str | os.PathLike[str] | None = None,
        timeout: float = 10.0,
    ) -> None:
        self.base_url = (
            base_url
            or os.environ.get("ACER_CONTROL_BASE_URL")
            or "http://127.0.0.1:46934"
        ).rstrip("/")
        self._token = token
        self.token_path = Path(token_path) if token_path else self.default_token_path()
        self.timeout = timeout

    @staticmethod
    def default_token_path() -> Path:
        override = os.environ.get("ACER_CONTROL_TOKEN_FILE")
        if override:
            return Path(override)
        program_data = os.environ.get("PROGRAMDATA", r"C:\ProgramData")
        return Path(program_data) / "AcerControl" / "api-token"

    def get_status(self) -> dict[str, Any]:
        return self._request("GET", "/api/v1/status")

    def get_fan(self) -> dict[str, Any]:
        return self._request("GET", "/api/v1/fan")

    def set_fan(
        self,
        mode: str,
        cpu_percent: int | None = None,
        gpu_percent: int | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, Any] = {"mode": mode}
        if cpu_percent is not None:
            payload["cpuPercent"] = _percentage(cpu_percent)
        if gpu_percent is not None:
            payload["gpuPercent"] = _percentage(gpu_percent)
        return self._request("PUT", "/api/v1/fan", payload)

    def get_keyboard(self) -> dict[str, Any]:
        return self._request("GET", "/api/v1/keyboard")

    def set_keyboard(self, color: str, brightness: int) -> dict[str, Any]:
        normalized = color.strip().lstrip("#")
        if len(normalized) != 6 or any(character not in "0123456789abcdefABCDEF" for character in normalized):
            raise ValueError(f"{color!r} is not a six-digit RGB color")
        return self._request(
            "PUT",
            "/api/v1/keyboard",
            {"color": normalized.upper(), "brightness": _percentage(brightness)},
        )

    def get_profile(self) -> dict[str, Any]:
        return self._request("GET", "/api/v1/profile")

    def set_profile(self, profile: str) -> dict[str, Any]:
        return self._request("PUT", "/api/v1/profile", {"profile": profile})

    def next_profile(self) -> dict[str, Any]:
        return self._request("POST", "/api/v1/profile/next", {})

    def apply_settings(self) -> None:
        self._request("POST", "/api/v1/settings/apply", {})

    def _request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        token = self._get_token()
        data = None if payload is None else json.dumps(payload).encode("utf-8")
        headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
        if data is not None:
            headers["Content-Type"] = "application/json"
        request = Request(self.base_url + path, data=data, headers=headers, method=method)
        try:
            with urlopen(request, timeout=self.timeout) as response:
                body = response.read()
        except HTTPError as error:
            body = error.read()
            parsed = _decode_json(body)
            message = _error_message(parsed) or f"Service returned HTTP {error.code}"
            if error.code in (401, 403):
                raise AuthenticationError(message) from error
            raise ApiError(message, error.code, parsed) from error
        except URLError as error:
            raise AcerControlError(f"Could not connect to Acer Control service: {error.reason}") from error

        if not body:
            return {}
        parsed = _decode_json(body)
        if parsed is None:
            raise AcerControlError("The service returned invalid JSON")
        return parsed

    def _get_token(self) -> str:
        if self._token is None:
            try:
                self._token = self.token_path.read_text(encoding="utf-8").strip()
            except OSError as error:
                raise AuthenticationError(
                    f"Could not read Acer Control API token at {self.token_path}: {error}"
                ) from error
        if not self._token:
            raise AuthenticationError("The Acer Control API token is empty")
        return self._token


def _percentage(value: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not 0 <= value <= 100:
        raise ValueError(f"{value!r} is not a percentage from 0 through 100")
    return value


def _decode_json(body: bytes) -> dict[str, Any] | None:
    try:
        value = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def _error_message(payload: dict[str, Any] | None) -> str | None:
    if not payload:
        return None
    error = payload.get("error")
    return error.get("message") if isinstance(error, dict) else None