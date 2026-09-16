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
        for directory in (self.cache_dir, self.backup_dir, self.export_dir):
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
