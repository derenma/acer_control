# Acer Control API v1

Base URL: `http://127.0.0.1:46934`

Every `/api/v1` request requires:

```text
Authorization: Bearer <contents of %ProgramData%\AcerControl\api-token>
```

PUT and POST requests require `Content-Type: application/json`. Requests carrying an `Origin` header are rejected. `GET /healthz` is the only unauthenticated endpoint.

## Endpoints

| Method | Path | Body |
|---|---|---|
| GET | `/healthz` | None |
| GET | `/api/v1/status` | None |
| GET | `/api/v1/fan` | None |
| PUT | `/api/v1/fan` | `{"mode":"Auto"}` or `{"mode":"Custom","cpuPercent":50,"gpuPercent":60}` |
| GET | `/api/v1/keyboard` | None |
| PUT | `/api/v1/keyboard` | `{"color":"0411FF","brightness":50}` |
| GET | `/api/v1/profile` | None |
| PUT | `/api/v1/profile` | `{"profile":"Performance"}` |
| POST | `/api/v1/profile/next` | `{}` |
| POST | `/api/v1/settings/apply` | `{}` |

Fan modes are `Auto`, `Max`, and `Custom`. Percentages must be integers from 0 through 100. Profile names are matched case-insensitively and checked against the firmware-supported profile mask.

## Errors

Errors use this shape:

```json
{
  "status": "error",
  "error": {
    "code": "invalid_request",
    "message": "Custom fan mode requires cpuPercent and gpuPercent."
  }
}
```

If hardware was updated but registry persistence failed, the response additionally includes `"applied": true` and `"persisted": false`.

Common statuses:

- `400`: Invalid command or value.
- `401`: Missing or invalid token.
- `403`: Non-loopback or browser-origin request.
- `415`: A write did not use JSON.
- `500`: Firmware/readback or persistence failure.
- `503`: Firmware interface or API token unavailable.