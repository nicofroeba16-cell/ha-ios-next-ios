from __future__ import annotations

import hmac
import json
import os
import threading
import time
from collections import defaultdict, deque
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlparse

from .core import AdminStore, IdentityConflictError, store_from_environment


class SlidingWindowRateLimiter:
    def __init__(self, requests: int = 60, window_seconds: int = 60) -> None:
        self.requests = requests
        self.window_seconds = window_seconds
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def allow(self, key: str) -> bool:
        with self._lock:
            now = time.monotonic()
            events = self._events[key]
            while events and now - events[0] > self.window_seconds:
                events.popleft()
            if len(events) >= self.requests:
                return False
            events.append(now)
            return True


class EphemeralChatRelay:
    """Bounded, process-local ciphertext queue with delete-on-delivery semantics."""

    def __init__(
        self,
        ttl_seconds: int = 120,
        max_total_bytes: int = 128 * 1024 * 1024,
        max_device_bytes: int = 48 * 1024 * 1024,
    ) -> None:
        self.ttl_seconds = ttl_seconds
        self.max_total_bytes = max_total_bytes
        self.max_device_bytes = max_device_bytes
        self._queues: dict[str, deque[tuple[float, int, dict[str, Any]]]] = defaultdict(deque)
        self._device_bytes: dict[str, int] = defaultdict(int)
        self._seen: dict[str, float] = {}
        self._total_bytes = 0
        self._lock = threading.Lock()
        self.condition = threading.Condition(self._lock)

    def enqueue(self, envelope: dict[str, Any]) -> dict[str, Any]:
        encoded_size = len(envelope["ciphertext"].encode("ascii"))
        device_id = envelope["recipient_device_id"]
        now = time.monotonic()
        expires_at = now + self.ttl_seconds
        with self.condition:
            self._purge_locked(now)
            if envelope["id"] in self._seen:
                raise KeyError("duplicate_message")
            if encoded_size > self.max_device_bytes:
                raise OverflowError("message_too_large")
            if self._total_bytes + encoded_size > self.max_total_bytes:
                raise OverflowError("relay_full")
            if self._device_bytes[device_id] + encoded_size > self.max_device_bytes:
                raise OverflowError("device_queue_full")
            self._queues[device_id].append((expires_at, encoded_size, envelope))
            self._device_bytes[device_id] += encoded_size
            self._total_bytes += encoded_size
            self._seen[envelope["id"]] = expires_at
            self.condition.notify_all()
        return {
            "id": envelope["id"],
            "state": "queued_in_memory",
            "expires_in_seconds": self.ttl_seconds,
        }

    def take(self, device_id: str, max_messages: int = 64) -> dict[str, Any]:
        if not 1 <= max_messages <= 256:
            raise ValueError("invalid limit")
        now = time.monotonic()
        with self._lock:
            self._purge_locked(now)
            queue = self._queues.get(device_id)
            messages: list[dict[str, Any]] = []
            while queue and len(messages) < max_messages:
                _, size, envelope = queue.popleft()
                self._device_bytes[device_id] -= size
                self._total_bytes -= size
                messages.append(envelope)
            self._cleanup_device_locked(device_id)
        return {"messages": messages}

    def wait_for_messages(self, device_id: str, wait_seconds: int, max_messages: int = 64) -> dict[str, Any]:
        deadline = time.monotonic() + wait_seconds
        with self.condition:
            while True:
                now = time.monotonic()
                self._purge_locked(now)
                if self._queues.get(device_id) or now >= deadline:
                    break
                self.condition.wait(timeout=min(deadline - now, 1.0))
        return self.take(device_id, max_messages=max_messages)

    def snapshot(self) -> dict[str, int]:
        with self._lock:
            self._purge_locked(time.monotonic())
            return {
                "chat_queued_chunks": sum(len(queue) for queue in self._queues.values()),
                "chat_queued_bytes": self._total_bytes,
                "chat_device_queues": len(self._queues),
            }

    def _purge_locked(self, now: float) -> None:
        for message_id, expires_at in list(self._seen.items()):
            if expires_at <= now:
                del self._seen[message_id]
        for device_id in list(self._queues):
            queue = self._queues[device_id]
            while queue and queue[0][0] <= now:
                _, size, _ = queue.popleft()
                self._device_bytes[device_id] -= size
                self._total_bytes -= size
            self._cleanup_device_locked(device_id)

    def _cleanup_device_locked(self, device_id: str) -> None:
        if not self._queues.get(device_id):
            self._queues.pop(device_id, None)
            self._device_bytes.pop(device_id, None)


class AdminHTTPServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(
        self,
        address: tuple[str, int],
        store: AdminStore,
        owner_token: str,
        chat_tokens: dict[str, str] | None = None,
    ) -> None:
        super().__init__(address, AdminRequestHandler)
        self.store = store
        self.owner_token = owner_token
        self.chat_tokens = chat_tokens or {}
        self.rate_limiter = SlidingWindowRateLimiter()
        self.chat_rate_limiter = SlidingWindowRateLimiter(requests=600)
        self.chat_relay = EphemeralChatRelay()


class AdminRequestHandler(BaseHTTPRequestHandler):
    server: AdminHTTPServer
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:
        route = urlparse(self.path)
        if route.path.startswith("/v1/chat/"):
            principal = self._authorize_chat()
            if principal is None:
                return
            self._chat_get(route, principal)
            return
        if not self._authorize(self.server.owner_token):
            return
        if route.path == "/v1/admin/session":
            self._json(HTTPStatus.OK, self.server.store.identity.as_dict())
        elif route.path == "/v1/admin/status":
            payload = self.server.store.status()
            payload.update(self.server.chat_relay.snapshot())
            self._json(HTTPStatus.OK, payload)
        elif route.path == "/v1/admin/audit":
            query = parse_qs(route.query)
            try:
                limit = int(query.get("limit", ["50"])[0])
            except ValueError:
                limit = 50
            self._json(HTTPStatus.OK, self.server.store.audit_events(limit=limit))
        elif route.path == "/v1/admin/tickets":
            query = parse_qs(route.query)
            try:
                limit = int(query.get("limit", ["100"])[0])
            except ValueError:
                limit = 100
            self._json(HTTPStatus.OK, self.server.store.support_tickets(limit=limit))
        elif route.path.startswith("/v1/admin/tickets/"):
            ticket_id = route.path.removeprefix("/v1/admin/tickets/")
            try:
                payload = self.server.store.support_ticket(ticket_id)
            except (KeyError, ValueError):
                self._json(HTTPStatus.NOT_FOUND, {"error": "ticket_not_found"})
            else:
                self._json(HTTPStatus.OK, payload)
        else:
            self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})

    def do_POST(self) -> None:
        route = urlparse(self.path)
        if route.path.startswith("/v1/chat/"):
            principal = self._authorize_chat()
            if principal is None:
                return
            self._chat_post(route, principal)
            return
        if not self._authorize(self.server.owner_token):
            return
        if route.path.startswith("/v1/admin/tickets/"):
            self._admin_ticket_post(route)
            return
        prefix = "/v1/admin/actions/"
        if not route.path.startswith(prefix):
            self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})
            return
        action = route.path.removeprefix(prefix)
        try:
            receipt = self.server.store.perform(action, actor=self.server.store.identity.subject)
        except ValueError:
            self._json(HTTPStatus.NOT_FOUND, {"error": "action_not_allowed"})
        except Exception:
            self._json(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": "action_failed"})
        else:
            self._json(HTTPStatus.OK, receipt)

    def _chat_get(self, route: Any, principal: str) -> None:
        if route.path == "/v1/chat/session":
            self._json(
                HTTPStatus.OK,
                {
                    "user_id": principal,
                    "role": self.server.store.chat_role(principal),
                },
            )
            return

        identity_prefix = "/v1/chat/identities/"
        if route.path.startswith(identity_prefix):
            user_id = route.path.removeprefix(identity_prefix)
            try:
                identities = self.server.store.chat_identities(user_id)
            except ValueError:
                self._json(HTTPStatus.BAD_REQUEST, {"error": "invalid_user_id"})
            else:
                self._json(HTTPStatus.OK, identities)
            return

        if route.path == "/v1/chat/messages":
            query = parse_qs(route.query)
            device_id = query.get("recipient_device_id", [""])[0]
            try:
                device_id = self.server.store._validate_identifier(device_id, "recipient_device_id")
                if not self.server.store.chat_identity_exists(principal, device_id):
                    self._json(HTTPStatus.FORBIDDEN, {"error": "device_not_owned"})
                    return
                wait_seconds = min(max(int(query.get("wait", ["0"])[0]), 0), 25)
                limit = min(max(int(query.get("limit", ["64"])[0]), 1), 256)
                payload = self.server.chat_relay.wait_for_messages(device_id, wait_seconds, limit)
            except ValueError:
                self._json(HTTPStatus.BAD_REQUEST, {"error": "invalid_query"})
            else:
                self._json(HTTPStatus.OK, payload)
            return

        self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})

    def _chat_post(self, route: Any, principal: str) -> None:
        try:
            payload = self._read_json()
            if route.path == "/v1/chat/identities":
                if payload.get("user_id") != principal:
                    self._json(HTTPStatus.FORBIDDEN, {"error": "identity_scope_violation"})
                    return
                result = self.server.store.register_chat_identity(payload)
                self._json(HTTPStatus.OK, result)
            elif route.path == "/v1/chat/tickets":
                message = payload.get("message")
                result = self.server.store.create_support_ticket(principal, message)
                self._json(HTTPStatus.CREATED, result)
            elif route.path.startswith("/v1/chat/tickets/") and route.path.endswith("/messages"):
                ticket_id = route.path.removeprefix("/v1/chat/tickets/").removesuffix("/messages")
                result = self.server.store.add_support_ticket_message(
                    ticket_id,
                    principal,
                    "member",
                    payload.get("message"),
                )
                self._json(HTTPStatus.CREATED, result)
            elif route.path == "/v1/chat/messages":
                envelope = self.server.store.validate_chat_envelope(payload)
                if envelope["sender_user_id"] != principal:
                    self._json(HTTPStatus.FORBIDDEN, {"error": "sender_scope_violation"})
                    return
                if not self.server.store.chat_identity_exists(
                    envelope["sender_user_id"], envelope["sender_device_id"]
                ):
                    self._json(HTTPStatus.FORBIDDEN, {"error": "sender_device_not_registered"})
                    return
                if not self.server.store.chat_identity_exists(
                    envelope["recipient_user_id"], envelope["recipient_device_id"]
                ):
                    self._json(HTTPStatus.NOT_FOUND, {"error": "recipient_device_not_found"})
                    return
                result = self.server.chat_relay.enqueue(envelope)
                self._json(HTTPStatus.CREATED, result)
            else:
                self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})
        except (ValueError, json.JSONDecodeError):
            self._json(HTTPStatus.BAD_REQUEST, {"error": "invalid_payload"})
        except KeyError as error:
            if error.args and error.args[0] == "ticket_not_found":
                self._json(HTTPStatus.NOT_FOUND, {"error": "ticket_not_found"})
            else:
                self._json(HTTPStatus.CONFLICT, {"error": "duplicate_message"})
        except PermissionError:
            self._json(HTTPStatus.FORBIDDEN, {"error": "ticket_scope_violation"})
        except IdentityConflictError:
            self._json(HTTPStatus.CONFLICT, {"error": "identity_key_conflict"})
        except OverflowError:
            self._json(HTTPStatus.INSUFFICIENT_STORAGE, {"error": "relay_capacity_exceeded"})

    def _admin_ticket_post(self, route: Any) -> None:
        suffix = route.path.removeprefix("/v1/admin/tickets/")
        try:
            payload = self._read_json()
            if suffix.endswith("/messages"):
                ticket_id = suffix.removesuffix("/messages")
                result = self.server.store.add_support_ticket_message(
                    ticket_id,
                    self.server.store.identity.subject,
                    "owner",
                    payload.get("message"),
                )
                self._json(HTTPStatus.CREATED, result)
                return
            if suffix.endswith("/status"):
                ticket_id = suffix.removesuffix("/status")
                result = self.server.store.update_support_ticket_status(
                    ticket_id,
                    payload.get("status"),
                    self.server.store.identity.subject,
                )
                self._json(HTTPStatus.OK, result)
                return
            self._json(HTTPStatus.NOT_FOUND, {"error": "not_found"})
        except (ValueError, json.JSONDecodeError):
            self._json(HTTPStatus.BAD_REQUEST, {"error": "invalid_payload"})
        except KeyError:
            self._json(HTTPStatus.NOT_FOUND, {"error": "ticket_not_found"})

    def _read_json(self) -> dict[str, Any]:
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ValueError("invalid content length") from error
        if not 1 <= content_length <= 1_200_000:
            raise ValueError("invalid body size")
        payload = json.loads(self.rfile.read(content_length))
        if not isinstance(payload, dict):
            raise ValueError("object expected")
        return payload

    def _authorize(self, expected_token: str) -> bool:
        client = self.client_address[0]
        if not self.server.rate_limiter.allow(client):
            self._json(HTTPStatus.TOO_MANY_REQUESTS, {"error": "rate_limited"})
            return False
        authorization = self.headers.get("Authorization", "")
        supplied = authorization.removeprefix("Bearer ") if authorization.startswith("Bearer ") else ""
        if not expected_token or not supplied or not hmac.compare_digest(supplied, expected_token):
            self._json(HTTPStatus.UNAUTHORIZED, {"error": "unauthorized"})
            return False
        return True

    def _authorize_chat(self) -> str | None:
        client = self.client_address[0]
        if not self.server.chat_rate_limiter.allow(client):
            self._json(HTTPStatus.TOO_MANY_REQUESTS, {"error": "rate_limited"})
            return None
        authorization = self.headers.get("Authorization", "")
        supplied = authorization.removeprefix("Bearer ") if authorization.startswith("Bearer ") else ""
        principal: str | None = None
        for expected_token, user_id in self.server.chat_tokens.items():
            if supplied and hmac.compare_digest(supplied, expected_token):
                principal = user_id
        if principal is None:
            self._json(HTTPStatus.UNAUTHORIZED, {"error": "unauthorized"})
        return principal

    def _json(self, status: HTTPStatus, payload: Any) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        # Never log request paths, query parameters, message metadata or credentials.
        status = str(args[1]) if len(args) > 1 else "-"
        print(f"{self.address_string()} - HTTP {status}")


def main() -> None:
    owner_token = os.environ.get("IOSNEXT_OWNER_TOKEN", "")
    if len(owner_token) < 32:
        raise SystemExit("IOSNEXT_OWNER_TOKEN must contain at least 32 characters")
    try:
        raw_chat_tokens = json.loads(os.environ.get("IOSNEXT_CHAT_TOKENS_JSON", "{}"))
    except json.JSONDecodeError as error:
        raise SystemExit("IOSNEXT_CHAT_TOKENS_JSON must be valid JSON") from error
    if not isinstance(raw_chat_tokens, dict) or not raw_chat_tokens:
        raise SystemExit("IOSNEXT_CHAT_TOKENS_JSON must map tokens to user IDs")
    chat_tokens: dict[str, str] = {}
    for token, user_id in raw_chat_tokens.items():
        if not isinstance(token, str) or len(token) < 32:
            raise SystemExit("Every chat token must contain at least 32 characters")
        try:
            chat_tokens[token] = AdminStore._validate_identifier(user_id, "user_id")
        except ValueError as error:
            raise SystemExit("Every chat token must map to a valid user ID") from error
    host = os.environ.get("IOSNEXT_ADMIN_HOST", "127.0.0.1")
    port = int(os.environ.get("IOSNEXT_ADMIN_PORT", "8787"))
    store = store_from_environment()
    server = AdminHTTPServer(
        (host, port),
        store=store,
        owner_token=owner_token,
        chat_tokens=chat_tokens,
    )
    try:
        print(f"iOS Next admin service listening on {host}:{port}")
        server.serve_forever(poll_interval=0.5)
    finally:
        server.server_close()
        store.close()


if __name__ == "__main__":
    main()
