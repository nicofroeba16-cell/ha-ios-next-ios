# iOS Next Owner Admin Service

This standard-library Python service implements the API consumed by the hidden Owner Control area. It exposes only allowlisted maintenance actions and never accepts shell commands.

## Run locally

```bash
export IOSNEXT_OWNER_TOKEN='use-a-random-secret-with-at-least-32-characters'
export IOSNEXT_CHAT_TOKENS_JSON='{"replace-with-random-token-for-nico":"nico","replace-with-random-token-for-mika":"mika"}'
export IOSNEXT_OWNER_SUBJECT='nico'
export IOSNEXT_OWNER_DISPLAY_NAME='Nico'
export IOSNEXT_ADMIN_STATE_DIR='./admin-state'
python3 -m admin_service.server
```

Run from the `Backend` directory. The default listener is `127.0.0.1:8787`. Keep it on loopback and expose it to the iPhone only through an authenticated VPN or a TLS reverse proxy. Never expose the plain HTTP listener directly to the internet.

## Test

```bash
PYTHONPATH=Backend python3 -m unittest discover -s Backend/tests -v
```

The state directory contains SQLite admin state, audit records, public chat device identities, cache, audit exports and backups. Owner and user-scoped chat tokens are supplied only through the environment and are never written to the database or logs. Every chat token is bound to exactly one user ID; the service rejects attempts to register or send as another user.

Chat payloads and media are never written to SQLite, files, backups or request logs. The relay holds encrypted chunks only in a bounded process-memory queue for at most 120 seconds and removes them on first delivery. Offline delivery is intentionally not guaranteed. Keep the listener on loopback; use an authenticated VPN plus HTTPS for iPhone access.
