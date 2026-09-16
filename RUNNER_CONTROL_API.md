# Runner Control API contract

The app never accepts arbitrary shell commands. Release builds call only the endpoints below over HTTPS with a bearer token stored in Keychain. Plain HTTP is accepted only by Debug builds for local development.

## Status

`GET /v1/status`

```json
{
  "vm_online": true,
  "service_active": true,
  "registered_runners": 8,
  "idle_runners": 8,
  "busy_runners": 0,
  "cpu_percent": 4.2,
  "memory_percent": 31.0,
  "disk_percent": 41.0,
  "last_health_check": "2026-09-16T04:00:00Z"
}
```

## Actions

- `POST /v1/health-check`
- `POST /v1/runners/pause`
- `POST /v1/runners/resume`
- `POST /v1/runners/restart-gracefully`
- `POST /v1/vm/shutdown`

Each action returns:

```json
{
  "request_id": "runner-20260916-001",
  "state": "accepted",
  "active_jobs": 0
}
```

The server must reject unknown operations, protect active jobs, redact secrets from logs and keep an audit trail. Restart and shutdown additionally require device-owner authentication in the app.
