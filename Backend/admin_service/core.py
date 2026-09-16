from __future__ import annotations

import json
import os
import shutil
import sqlite3
import threading
import uuid
import base64
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class ConfigurationError(RuntimeError):
    pass


class IdentityConflictError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


@dataclass(frozen=True)
class OwnerIdentity:
    subject: str
    display_name: str
    role: str = "owner"

    def as_dict(self) -> dict[str, str]:
        return {
            "subject": self.subject,
            "display_name": self.display_name,
            "role": self.role,
        }


PROJECT_ROUTES: dict[str, dict[str, Any]] = {
    "ios-app": {
        "id": "ios-app",
        "title": "iOS App",
        "repository": "nicofroeba16-cell/ha-ios-next-ios",
        "keywords": ("ios next", "ios", "iphone", "ipad", "chat", "owner", "wireguard", "vpn"),
    },
    "fire-tv": {
        "id": "fire-tv",
        "title": "Fire TV Companion",
        "repository": "nicofroeba16-cell/AmazonTV-App",
        "keywords": ("fire tv", "firetv", "fernseher", "tv", "media player", "mediaplayer"),
    },
    "ha-dashboard": {
        "id": "ha-dashboard",
        "title": "Home Assistant Dashboard",
        "repository": "nicofroeba16-cell/HA-CONFIG",
        "keywords": ("dashboard", "lovelace", "karte", "card", "gradient", "raum", "zimmer", "licht"),
    },
    "intelligence-suite": {
        "id": "intelligence-suite",
        "title": "Intelligence Suite",
        "repository": "nicofroeba16-cell/Intelligence-Suite-",
        "keywords": ("intelligence", "entity intelligence", "audit", "aggregator", "system health"),
    },
    "file-bridge": {
        "id": "file-bridge",
        "title": "File Bridge",
        "repository": "nicofroeba16-cell/File-Bridge-mcp",
        "keywords": ("bridge", "file bridge", "datei", "sync", "queue", "poller"),
    },
    "ha-simulation": {
        "id": "ha-simulation",
        "title": "HA Simulation",
        "repository": None,
        "keywords": ("simulation", "simulator", "fake ha", "testserver", "test server"),
    },
    "global-health": {
        "id": "global-health",
        "title": "Global Project Health",
        "repository": None,
        "keywords": ("global health", "duplikat", "veraltet", "reconciliation", "health audit"),
    },
    "general": {
        "id": "general",
        "title": "General / Triage",
        "repository": None,
        "keywords": (),
    },
}


class AdminStore:
    ALLOWED_ACTIONS = frozenset(
        {
            "health-check",
            "maintenance-enable",
            "maintenance-disable",
            "reconnect-sessions",
            "clear-cache",
            "rotate-logs",
            "create-backup",
        }
    )

    def __init__(
        self,
        state_dir: Path,
        identity: OwnerIdentity,
        version: str = "1.0.0",
        environment: str = "local",
    ) -> None:
        self.state_dir = state_dir.resolve()
        if self.state_dir == Path(self.state_dir.anchor):
            raise ConfigurationError("state_dir must not be a filesystem root")
        self.state_dir.mkdir(parents=True, exist_ok=True)
        self.cache_dir = self.state_dir / "cache"
        self.backup_dir = self.state_dir / "backups"
        self.export_dir = self.state_dir / "audit-exports"
        self.project_queue_dir = self.state_dir / "project-queue"
        for directory in (self.cache_dir, self.backup_dir, self.export_dir, self.project_queue_dir):
            directory.mkdir(parents=True, exist_ok=True)

        self.identity = identity
        self.version = version
        self.environment = environment
        self.started_at = datetime.now(timezone.utc)
        self._lock = threading.RLock()
        self._database_path = self.state_dir / "admin.sqlite3"
        self._database = sqlite3.connect(self._database_path, check_same_thread=False)
        self._database.row_factory = sqlite3.Row
        self._initialize_database()

    def close(self) -> None:
        with self._lock:
            self._database.close()

    def status(self) -> dict[str, Any]:
        with self._lock:
            maintenance = self._get_setting("maintenance_mode", "false") == "true"
            websocket_sessions = int(self._get_setting("active_websocket_sessions", "0"))
            queue_depth = int(self._get_setting("queue_depth", "0"))
            cache_entries = sum(1 for path in self.cache_dir.rglob("*") if path.is_file())
            last_backup = self._get_setting("last_backup", "") or None
            database_healthy = self._database.execute("PRAGMA quick_check").fetchone()[0] == "ok"
            uptime = (datetime.now(timezone.utc) - self.started_at).total_seconds()

        return {
            "version": self.version,
            "environment": self.environment,
            "healthy": database_healthy,
            "maintenance_mode": maintenance,
            "uptime_seconds": uptime,
            "active_websocket_sessions": websocket_sessions,
            "queue_depth": queue_depth,
            "cache_entries": cache_entries,
            "database_healthy": database_healthy,
            "last_backup": last_backup,
        }

    def audit_events(self, limit: int = 50) -> list[dict[str, Any]]:
        safe_limit = min(max(limit, 1), 200)
        with self._lock:
            rows = self._database.execute(
                "SELECT id, timestamp, actor, action, result FROM audit ORDER BY rowid DESC LIMIT ?",
                (safe_limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    def perform(self, action: str, actor: str) -> dict[str, Any]:
        if action not in self.ALLOWED_ACTIONS:
            self._write_audit(actor, action, "rejected")
            raise ValueError("action is not allowlisted")

        request_id = f"admin-{uuid.uuid4()}"
        try:
            with self._lock:
                if action == "health-check":
                    self._assert_state_is_writable()
                    if self._database.execute("PRAGMA quick_check").fetchone()[0] != "ok":
                        raise RuntimeError("database quick_check failed")
                elif action == "maintenance-enable":
                    self._set_setting("maintenance_mode", "true")
                elif action == "maintenance-disable":
                    self._set_setting("maintenance_mode", "false")
                elif action == "reconnect-sessions":
                    generation = int(self._get_setting("connection_generation", "0")) + 1
                    self._set_setting("connection_generation", str(generation))
                elif action == "clear-cache":
                    self._clear_cache()
                elif action == "rotate-logs":
                    self._export_audit_log()
                elif action == "create-backup":
                    self._create_backup()
            self._write_audit(actor, action, "success", event_id=request_id)
        except Exception:
            self._write_audit(actor, action, "failed", event_id=request_id)
            raise

        return {"request_id": request_id, "state": "completed"}

    def register_chat_identity(self, payload: dict[str, Any]) -> dict[str, Any]:
        user_id = self._required_identifier(payload, "user_id")
        device_id = self._required_identifier(payload, "device_id")
        agreement_key = self._required_base64(payload, "agreement_public_key", expected_bytes=32)
        signing_key = self._required_base64(payload, "signing_public_key", expected_bytes=32)
        updated_at = utc_now()
        with self._lock:
            existing = self._database.execute(
                """
                SELECT agreement_public_key, signing_public_key
                FROM chat_identities WHERE user_id = ? AND device_id = ?
                """,
                (user_id, device_id),
            ).fetchone()
            if existing and (
                existing["agreement_public_key"] != agreement_key
                or existing["signing_public_key"] != signing_key
            ):
                raise IdentityConflictError("device identity is immutable")
            self._database.execute(
                """
                INSERT INTO chat_identities(
                    user_id, device_id, agreement_public_key, signing_public_key, updated_at
                ) VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(user_id, device_id) DO UPDATE SET
                    agreement_public_key = excluded.agreement_public_key,
                    signing_public_key = excluded.signing_public_key,
                    updated_at = excluded.updated_at
                """,
                (user_id, device_id, agreement_key, signing_key, updated_at),
            )
            self._database.commit()
        return {
            "user_id": user_id,
            "device_id": device_id,
            "agreement_public_key": agreement_key,
            "signing_public_key": signing_key,
            "updated_at": updated_at,
        }

    def chat_identities(self, user_id: str) -> list[dict[str, Any]]:
        user_id = self._validate_identifier(user_id, "user_id")
        with self._lock:
            rows = self._database.execute(
                """
                SELECT user_id, device_id, agreement_public_key, signing_public_key, updated_at
                FROM chat_identities WHERE user_id = ? ORDER BY updated_at DESC
                """,
                (user_id,),
            ).fetchall()
        return [dict(row) for row in rows]

    def chat_identity_exists(self, user_id: str, device_id: str) -> bool:
        user_id = self._validate_identifier(user_id, "user_id")
        device_id = self._validate_identifier(device_id, "device_id")
        with self._lock:
            row = self._database.execute(
                "SELECT 1 FROM chat_identities WHERE user_id = ? AND device_id = ?",
                (user_id, device_id),
            ).fetchone()
        return row is not None

    def chat_role(self, user_id: str) -> str:
        user_id = self._validate_identifier(user_id, "user_id")
        return "owner" if user_id == self.identity.subject else "member"

    def create_support_ticket(self, requester_user_id: str, message: str) -> dict[str, Any]:
        requester_user_id = self._validate_identifier(requester_user_id, "requester_user_id")
        message = self._validate_ticket_message(message)
        ticket_id = f"ticket-{uuid.uuid4()}"
        message_id = f"ticket-message-{uuid.uuid4()}"
        created_at = utc_now()
        with self._lock:
            self._database.execute(
                """
                INSERT INTO support_tickets(id, requester_user_id, status, created_at, updated_at)
                VALUES (?, ?, 'open', ?, ?)
                """,
                (ticket_id, requester_user_id, created_at, created_at),
            )
            self._database.execute(
                """
                INSERT INTO support_ticket_messages(
                    id, ticket_id, author_user_id, author_role, body, created_at
                ) VALUES (?, ?, ?, 'member', ?, ?)
                """,
                (message_id, ticket_id, requester_user_id, message, created_at),
            )
            self._database.commit()
        self._write_audit(requester_user_id, "ticket-create", "success")
        return self.support_ticket(ticket_id)

    def support_tickets(self, limit: int = 100) -> list[dict[str, Any]]:
        safe_limit = min(max(limit, 1), 200)
        with self._lock:
            rows = self._database.execute(
                """
                SELECT id, requester_user_id, status, created_at, updated_at
                FROM support_tickets ORDER BY updated_at DESC LIMIT ?
                """,
                (safe_limit,),
            ).fetchall()
        return [self._ticket_summary(dict(row)) for row in rows]

    def support_ticket(self, ticket_id: str) -> dict[str, Any]:
        ticket_id = self._validate_identifier(ticket_id, "ticket_id", max_length=80)
        with self._lock:
            row = self._database.execute(
                """
                SELECT id, requester_user_id, status, created_at, updated_at
                FROM support_tickets WHERE id = ?
                """,
                (ticket_id,),
            ).fetchone()
            if row is None:
                raise KeyError("ticket_not_found")
            messages = self._database.execute(
                """
                SELECT id, author_user_id, author_role, body, created_at
                FROM support_ticket_messages
                WHERE ticket_id = ? ORDER BY rowid ASC
                """,
                (ticket_id,),
            ).fetchall()
        payload = dict(row)
        payload["messages"] = [dict(message) for message in messages]
        with self._lock:
            dispatch = self._database.execute(
                """
                SELECT project_id, state FROM project_dispatches
                WHERE ticket_id = ?
                """,
                (ticket_id,),
            ).fetchone()
        payload["suggested_project_id"] = self._suggest_project_from_messages(payload["messages"])
        payload["dispatched_project_id"] = dispatch["project_id"] if dispatch else None
        payload["dispatch_state"] = dispatch["state"] if dispatch else None
        return payload

    def add_support_ticket_message(
        self,
        ticket_id: str,
        author_user_id: str,
        author_role: str,
        message: str,
    ) -> dict[str, Any]:
        ticket_id = self._validate_identifier(ticket_id, "ticket_id", max_length=80)
        author_user_id = self._validate_identifier(author_user_id, "author_user_id")
        if author_role not in {"owner", "member"}:
            raise ValueError("invalid author_role")
        message = self._validate_ticket_message(message)
        created_at = utc_now()
        with self._lock:
            ticket = self._database.execute(
                "SELECT requester_user_id FROM support_tickets WHERE id = ?",
                (ticket_id,),
            ).fetchone()
            if ticket is None:
                raise KeyError("ticket_not_found")
            if author_role != "owner" and ticket["requester_user_id"] != author_user_id:
                raise PermissionError("ticket_scope_violation")
            self._database.execute(
                """
                INSERT INTO support_ticket_messages(
                    id, ticket_id, author_user_id, author_role, body, created_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    f"ticket-message-{uuid.uuid4()}",
                    ticket_id,
                    author_user_id,
                    author_role,
                    message,
                    created_at,
                ),
            )
            self._database.execute(
                "UPDATE support_tickets SET updated_at = ? WHERE id = ?",
                (created_at, ticket_id),
            )
            self._database.commit()
        self._write_audit(author_user_id, "ticket-message", "success")
        return self.support_ticket(ticket_id)

    def update_support_ticket_status(self, ticket_id: str, status: str, actor: str) -> dict[str, Any]:
        ticket_id = self._validate_identifier(ticket_id, "ticket_id", max_length=80)
        actor = self._validate_identifier(actor, "actor")
        if status not in {"open", "in_progress", "approved", "resolved"}:
            raise ValueError("invalid ticket status")
        updated_at = utc_now()
        with self._lock:
            cursor = self._database.execute(
                "UPDATE support_tickets SET status = ?, updated_at = ? WHERE id = ?",
                (status, updated_at, ticket_id),
            )
            if cursor.rowcount != 1:
                self._database.rollback()
                raise KeyError("ticket_not_found")
            self._database.commit()
        self._write_audit(actor, f"ticket-status-{status}", "success")
        return self.support_ticket(ticket_id)

    def _ticket_summary(self, ticket: dict[str, Any]) -> dict[str, Any]:
        with self._lock:
            row = self._database.execute(
                """
                SELECT body FROM support_ticket_messages
                WHERE ticket_id = ? ORDER BY rowid DESC LIMIT 1
                """,
                (ticket["id"],),
            ).fetchone()
            dispatch = self._database.execute(
                """
                SELECT project_id, state FROM project_dispatches
                WHERE ticket_id = ?
                """,
                (ticket["id"],),
            ).fetchone()
        ticket["last_message"] = row["body"] if row else ""
        with self._lock:
            messages = self._database.execute(
                """
                SELECT body FROM support_ticket_messages
                WHERE ticket_id = ? ORDER BY rowid ASC
                """,
                (ticket["id"],),
            ).fetchall()
        ticket["suggested_project_id"] = self._suggest_project_from_messages(
            [dict(message) for message in messages]
        )
        ticket["dispatched_project_id"] = dispatch["project_id"] if dispatch else None
        ticket["dispatch_state"] = dispatch["state"] if dispatch else None
        return ticket

    def project_routes(self) -> list[dict[str, Any]]:
        return [
            {
                "id": route["id"],
                "title": route["title"],
                "repository": route["repository"],
            }
            for route in PROJECT_ROUTES.values()
        ]

    def suggest_project(self, ticket_id: str) -> str:
        return self.support_ticket(ticket_id)["suggested_project_id"]

    @staticmethod
    def _suggest_project_from_messages(messages: list[dict[str, Any]]) -> str:
        text = " ".join(str(message.get("body", "")) for message in messages).lower()
        best_project = "general"
        best_score = 0
        for project_id, route in PROJECT_ROUTES.items():
            if project_id == "general":
                continue
            score = sum(1 for keyword in route["keywords"] if keyword in text)
            if score > best_score:
                best_project = project_id
                best_score = score
        return best_project

    def approve_support_ticket(
        self,
        ticket_id: str,
        project_id: str,
        actor: str,
    ) -> dict[str, Any]:
        ticket_id = self._validate_identifier(ticket_id, "ticket_id", max_length=80)
        actor = self._validate_identifier(actor, "actor")
        if project_id not in PROJECT_ROUTES:
            raise ValueError("invalid project_id")

        with self._lock:
            existing = self._database.execute(
                """
                SELECT id, ticket_id, project_id, state, approved_by, approved_at, queue_file
                FROM project_dispatches WHERE ticket_id = ?
                """,
                (ticket_id,),
            ).fetchone()
            if existing is not None:
                if existing["project_id"] != project_id:
                    raise RuntimeError("ticket_already_dispatched")
                return dict(existing)

            ticket = self.support_ticket(ticket_id)
            dispatch_id = f"dispatch-{uuid.uuid4()}"
            approved_at = utc_now()
            route = PROJECT_ROUTES[project_id]
            queue_dir = self.project_queue_dir / project_id
            queue_dir.mkdir(parents=True, exist_ok=True)
            queue_path = queue_dir / f"{dispatch_id}.json"
            payload = {
                "schema_version": 1,
                "dispatch_id": dispatch_id,
                "ticket_id": ticket_id,
                "project": {
                    "id": project_id,
                    "title": route["title"],
                    "repository": route["repository"],
                },
                "approved_by": actor,
                "approved_at": approved_at,
                "ticket": ticket,
                "instruction": "Bearbeite das freigegebene Owner-Ticket im Zielprojekt. Änderungen müssen den Regeln des Zielprojekts folgen.",
            }
            temporary_path = queue_path.with_suffix(".json.tmp")
            try:
                self._database.execute(
                    """
                    INSERT INTO project_dispatches(
                        id, ticket_id, project_id, state, approved_by, approved_at, queue_file
                    ) VALUES (?, ?, ?, 'queued', ?, ?, ?)
                    """,
                    (
                        dispatch_id,
                        ticket_id,
                        project_id,
                        actor,
                        approved_at,
                        str(queue_path),
                    ),
                )
                self._database.execute(
                    "UPDATE support_tickets SET status = 'approved', updated_at = ? WHERE id = ?",
                    (approved_at, ticket_id),
                )
                temporary_path.write_text(
                    json.dumps(payload, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
                temporary_path.replace(queue_path)
                self._database.commit()
            except Exception:
                self._database.rollback()
                temporary_path.unlink(missing_ok=True)
                queue_path.unlink(missing_ok=True)
                raise

        self._write_audit(actor, f"ticket-approve-{project_id}", "success")
        return {
            "id": dispatch_id,
            "ticket_id": ticket_id,
            "project_id": project_id,
            "state": "queued",
            "approved_by": actor,
            "approved_at": approved_at,
            "queue_file": str(queue_path),
        }

    def project_dispatches(self, limit: int = 100) -> list[dict[str, Any]]:
        safe_limit = min(max(limit, 1), 200)
        with self._lock:
            rows = self._database.execute(
                """
                SELECT id, ticket_id, project_id, state, approved_by, approved_at, queue_file
                FROM project_dispatches ORDER BY rowid DESC LIMIT ?
                """,
                (safe_limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    @staticmethod
    def _validate_ticket_message(value: Any) -> str:
        if not isinstance(value, str):
            raise ValueError("invalid ticket message")
        normalized = value.strip()
        if not 1 <= len(normalized) <= 4000:
            raise ValueError("invalid ticket message")
        return normalized

    def validate_chat_envelope(self, payload: dict[str, Any]) -> dict[str, Any]:
        message_id = self._required_identifier(payload, "id", max_length=80)
        group_id = self._required_identifier(payload, "group_id", max_length=80)
        sender_user_id = self._required_identifier(payload, "sender_user_id")
        sender_device_id = self._required_identifier(payload, "sender_device_id")
        recipient_user_id = self._required_identifier(payload, "recipient_user_id")
        recipient_device_id = self._required_identifier(payload, "recipient_device_id")
        ephemeral_key = self._required_base64(payload, "ephemeral_public_key", expected_bytes=32)
        ciphertext = self._required_base64(payload, "ciphertext", max_bytes=786432)
        signature = self._required_base64(payload, "signature", expected_bytes=64)
        message_type = payload.get("message_type")
        if message_type not in {"text", "image", "voice", "video"}:
            raise ValueError("invalid message_type")
        content_type = payload.get("content_type")
        if not isinstance(content_type, str) or not 1 <= len(content_type) <= 100:
            raise ValueError("invalid content_type")
        chunk_index = payload.get("chunk_index")
        chunk_count = payload.get("chunk_count")
        if not isinstance(chunk_index, int) or not isinstance(chunk_count, int):
            raise ValueError("invalid chunk metadata")
        if not 0 <= chunk_index < chunk_count <= 256:
            raise ValueError("invalid chunk metadata")
        created_at = payload.get("created_at")
        if not isinstance(created_at, str) or len(created_at) > 40:
            raise ValueError("invalid created_at")
        return {
            "id": message_id,
            "group_id": group_id,
            "sender_user_id": sender_user_id,
            "sender_device_id": sender_device_id,
            "recipient_user_id": recipient_user_id,
            "recipient_device_id": recipient_device_id,
            "ephemeral_public_key": ephemeral_key,
            "ciphertext": ciphertext,
            "signature": signature,
            "message_type": message_type,
            "content_type": content_type,
            "chunk_index": chunk_index,
            "chunk_count": chunk_count,
            "created_at": created_at,
        }

    def _initialize_database(self) -> None:
        with self._lock:
            self._database.executescript(
                """
                PRAGMA foreign_keys=ON;
                PRAGMA journal_mode=WAL;
                CREATE TABLE IF NOT EXISTS settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS audit (
                    id TEXT PRIMARY KEY,
                    timestamp TEXT NOT NULL,
                    actor TEXT NOT NULL,
                    action TEXT NOT NULL,
                    result TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS chat_identities (
                    user_id TEXT NOT NULL,
                    device_id TEXT NOT NULL,
                    agreement_public_key TEXT NOT NULL,
                    signing_public_key TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    PRIMARY KEY(user_id, device_id)
                );
                CREATE TABLE IF NOT EXISTS support_tickets (
                    id TEXT PRIMARY KEY,
                    requester_user_id TEXT NOT NULL,
                    status TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS support_ticket_messages (
                    id TEXT PRIMARY KEY,
                    ticket_id TEXT NOT NULL,
                    author_user_id TEXT NOT NULL,
                    author_role TEXT NOT NULL,
                    body TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    FOREIGN KEY(ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS support_tickets_updated_idx
                    ON support_tickets(updated_at DESC);
                CREATE INDEX IF NOT EXISTS support_ticket_messages_ticket_idx
                    ON support_ticket_messages(ticket_id, created_at);
                CREATE TABLE IF NOT EXISTS project_dispatches (
                    id TEXT PRIMARY KEY,
                    ticket_id TEXT NOT NULL UNIQUE,
                    project_id TEXT NOT NULL,
                    state TEXT NOT NULL,
                    approved_by TEXT NOT NULL,
                    approved_at TEXT NOT NULL,
                    queue_file TEXT NOT NULL,
                    FOREIGN KEY(ticket_id) REFERENCES support_tickets(id) ON DELETE CASCADE
                );
                CREATE INDEX IF NOT EXISTS project_dispatches_project_idx
                    ON project_dispatches(project_id, approved_at);
                DROP TABLE IF EXISTS chat_messages;
                """
            )
            self._database.commit()

    def _get_setting(self, key: str, default: str) -> str:
        row = self._database.execute("SELECT value FROM settings WHERE key = ?", (key,)).fetchone()
        return row[0] if row else default

    def _set_setting(self, key: str, value: str) -> None:
        self._database.execute(
            "INSERT INTO settings(key, value) VALUES (?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value",
            (key, value),
        )
        self._database.commit()

    def _write_audit(
        self,
        actor: str,
        action: str,
        result: str,
        event_id: str | None = None,
    ) -> None:
        with self._lock:
            self._database.execute(
                "INSERT INTO audit(id, timestamp, actor, action, result) VALUES (?, ?, ?, ?, ?)",
                (event_id or f"audit-{uuid.uuid4()}", utc_now(), actor, action, result),
            )
            self._database.commit()

    def _assert_state_is_writable(self) -> None:
        probe = self.state_dir / f".health-{uuid.uuid4()}"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink()

    def _clear_cache(self) -> None:
        cache_root = self.cache_dir.resolve()
        if cache_root.parent != self.state_dir:
            raise RuntimeError("unsafe cache path")
        for child in cache_root.iterdir():
            if child.is_dir():
                shutil.rmtree(child)
            else:
                child.unlink()

    def _export_audit_log(self) -> Path:
        destination = self.export_dir / f"audit-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.json"
        destination.write_text(
            json.dumps(self.audit_events(limit=200), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return destination

    def _create_backup(self) -> Path:
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        destination = self.backup_dir / f"admin-{timestamp}.sqlite3"
        backup_database = sqlite3.connect(destination)
        try:
            self._database.backup(backup_database)
        finally:
            backup_database.close()
        self._set_setting("last_backup", utc_now())
        return destination

    @staticmethod
    def _validate_identifier(value: Any, field: str, max_length: int = 64) -> str:
        if not isinstance(value, str) or not 1 <= len(value) <= max_length:
            raise ValueError(f"invalid {field}")
        if not all(character.isalnum() or character in "-_.@" for character in value):
            raise ValueError(f"invalid {field}")
        return value

    @classmethod
    def _required_identifier(cls, payload: dict[str, Any], field: str, max_length: int = 64) -> str:
        return cls._validate_identifier(payload.get(field), field, max_length=max_length)

    @staticmethod
    def _required_base64(
        payload: dict[str, Any],
        field: str,
        expected_bytes: int | None = None,
        max_bytes: int | None = None,
    ) -> str:
        value = payload.get(field)
        if not isinstance(value, str):
            raise ValueError(f"invalid {field}")
        try:
            decoded = base64.b64decode(value, validate=True)
        except Exception as error:
            raise ValueError(f"invalid {field}") from error
        if expected_bytes is not None and len(decoded) != expected_bytes:
            raise ValueError(f"invalid {field}")
        if max_bytes is not None and len(decoded) > max_bytes:
            raise ValueError(f"invalid {field}")
        return value


def store_from_environment() -> AdminStore:
    state_dir = Path(os.environ.get("IOSNEXT_ADMIN_STATE_DIR", "./admin-state"))
    subject = os.environ.get("IOSNEXT_OWNER_SUBJECT", "owner")
    display_name = os.environ.get("IOSNEXT_OWNER_DISPLAY_NAME", "Owner")
    return AdminStore(
        state_dir=state_dir,
        identity=OwnerIdentity(subject=subject, display_name=display_name),
        version=os.environ.get("IOSNEXT_ADMIN_VERSION", "1.0.0"),
        environment=os.environ.get("IOSNEXT_ADMIN_ENVIRONMENT", "local"),
    )
