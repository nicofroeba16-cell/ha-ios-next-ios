from __future__ import annotations

import tempfile
import threading
import unittest
import base64
import json
from http.client import HTTPConnection
from pathlib import Path

from admin_service.core import AdminStore, IdentityConflictError, OwnerIdentity
from admin_service.server import AdminHTTPServer, EphemeralChatRelay


class AdminStoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.store = AdminStore(
            state_dir=Path(self.temporary_directory.name),
            identity=OwnerIdentity(subject="nico", display_name="Nico"),
            version="test",
        )

    def tearDown(self) -> None:
        self.store.close()
        self.temporary_directory.cleanup()

    def test_status_is_healthy_by_default(self) -> None:
        status = self.store.status()
        self.assertTrue(status["healthy"])
        self.assertFalse(status["maintenance_mode"])
        self.assertTrue(status["database_healthy"])

    def test_maintenance_actions_are_persistent(self) -> None:
        self.store.perform("maintenance-enable", actor="nico")
        self.assertTrue(self.store.status()["maintenance_mode"])
        self.store.perform("maintenance-disable", actor="nico")
        self.assertFalse(self.store.status()["maintenance_mode"])

    def test_unknown_action_is_rejected_and_audited(self) -> None:
        with self.assertRaises(ValueError):
            self.store.perform("shell", actor="nico")
        self.assertEqual(self.store.audit_events()[0]["result"], "rejected")

    def test_cache_clear_never_leaves_cache_directory(self) -> None:
        cached_file = self.store.cache_dir / "nested" / "item.bin"
        cached_file.parent.mkdir()
        cached_file.write_bytes(b"cache")
        outside_file = Path(self.temporary_directory.name) / "keep.txt"
        outside_file.write_text("keep", encoding="utf-8")
        self.store.perform("clear-cache", actor="nico")
        self.assertFalse(cached_file.exists())
        self.assertEqual(outside_file.read_text(encoding="utf-8"), "keep")

    def test_backup_creates_sqlite_copy(self) -> None:
        self.store.perform("create-backup", actor="nico")
        backups = list(self.store.backup_dir.glob("admin-*.sqlite3"))
        self.assertEqual(len(backups), 1)
        self.assertIsNotNone(self.store.status()["last_backup"])

    def test_chat_envelope_is_validated_but_never_written_to_database(self) -> None:
        key = base64.b64encode(b"k" * 32).decode()
        signature = base64.b64encode(b"s" * 64).decode()
        ciphertext = base64.b64encode(b"encrypted-not-plaintext").decode()
        self.store.register_chat_identity({
            "user_id": "nico",
            "device_id": "iphone",
            "agreement_public_key": key,
            "signing_public_key": key,
        })
        envelope = self.store.validate_chat_envelope({
            "id": "message-1",
            "group_id": "group-1",
            "sender_user_id": "nico",
            "sender_device_id": "iphone",
            "recipient_user_id": "mika",
            "recipient_device_id": "ipad",
            "ephemeral_public_key": key,
            "ciphertext": ciphertext,
            "signature": signature,
            "message_type": "text",
            "content_type": "text/plain; charset=utf-8",
            "chunk_index": 0,
            "chunk_count": 1,
            "created_at": "2026-09-16T05:00:00Z",
        })
        self.assertEqual(envelope["ciphertext"], ciphertext)
        tables = self.store._database.execute(
            "SELECT name FROM sqlite_master WHERE type = 'table'"
        ).fetchall()
        self.assertNotIn("chat_messages", {row[0] for row in tables})

    def test_registered_device_keys_cannot_be_silently_replaced(self) -> None:
        key = base64.b64encode(b"k" * 32).decode()
        changed_key = base64.b64encode(b"x" * 32).decode()
        identity = {
            "user_id": "nico",
            "device_id": "iphone",
            "agreement_public_key": key,
            "signing_public_key": key,
        }
        self.store.register_chat_identity(identity)
        identity["signing_public_key"] = changed_key
        with self.assertRaises(IdentityConflictError):
            self.store.register_chat_identity(identity)


class EphemeralChatRelayTests(unittest.TestCase):
    def envelope(self, message_id: str = "message-1") -> dict:
        return {
            "id": message_id,
            "recipient_device_id": "ipad",
            "ciphertext": base64.b64encode(b"ciphertext").decode(),
        }

    def test_take_deletes_message_immediately(self) -> None:
        relay = EphemeralChatRelay(ttl_seconds=120)
        relay.enqueue(self.envelope())
        self.assertEqual(len(relay.take("ipad")["messages"]), 1)
        self.assertEqual(relay.take("ipad")["messages"], [])

    def test_expired_message_is_never_delivered(self) -> None:
        relay = EphemeralChatRelay(ttl_seconds=0)
        relay.enqueue(self.envelope())
        self.assertEqual(relay.take("ipad")["messages"], [])

    def test_duplicate_id_is_rejected_while_ttl_is_active(self) -> None:
        relay = EphemeralChatRelay(ttl_seconds=120)
        relay.enqueue(self.envelope())
        with self.assertRaises(KeyError):
            relay.enqueue(self.envelope())

    def test_capacity_rejects_new_data_without_evicting_existing_message(self) -> None:
        relay = EphemeralChatRelay(max_total_bytes=25, max_device_bytes=25)
        relay.enqueue(self.envelope("first"))
        with self.assertRaises(OverflowError):
            relay.enqueue(self.envelope("second"))
        messages = relay.take("ipad")["messages"]
        self.assertEqual([message["id"] for message in messages], ["first"])


class AdminHTTPServerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.store = AdminStore(
            state_dir=Path(self.temporary_directory.name),
            identity=OwnerIdentity(subject="nico", display_name="Nico"),
        )
        self.server = AdminHTTPServer(
            ("127.0.0.1", 0),
            self.store,
            "x" * 32,
            chat_tokens={"c" * 32: "nico", "m" * 32: "mika"},
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.store.close()
        self.temporary_directory.cleanup()

    def request(self, method: str, path: str, authorized: bool = True) -> tuple[int, bytes]:
        connection = HTTPConnection("127.0.0.1", self.server.server_port, timeout=2)
        headers = {"Authorization": f"Bearer {'x' * 32}"} if authorized else {}
        connection.request(method, path, headers=headers)
        response = connection.getresponse()
        body = response.read()
        connection.close()
        return response.status, body

    def chat_request(
        self,
        method: str,
        path: str,
        payload: dict | None = None,
        token: str = "c" * 32,
    ) -> tuple[int, bytes]:
        connection = HTTPConnection("127.0.0.1", self.server.server_port, timeout=2)
        headers = {"Authorization": f"Bearer {token}"}
        body = None
        if payload is not None:
            body = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
            headers["Content-Length"] = str(len(body))
        connection.request(method, path, body=body, headers=headers)
        response = connection.getresponse()
        response_body = response.read()
        connection.close()
        return response.status, response_body

    def test_owner_session_requires_token(self) -> None:
        status, _ = self.request("GET", "/v1/admin/session", authorized=False)
        self.assertEqual(status, 401)

    def test_owner_session_returns_owner_identity(self) -> None:
        status, body = self.request("GET", "/v1/admin/session")
        self.assertEqual(status, 200)
        self.assertIn(b'"role":"owner"', body)

    def test_owner_status_reports_only_aggregate_chat_memory(self) -> None:
        status, body = self.request("GET", "/v1/admin/status")
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertEqual(payload["chat_queued_chunks"], 0)
        self.assertEqual(payload["chat_queued_bytes"], 0)
        self.assertNotIn("recipient_device_id", payload)

    def test_shell_action_is_not_exposed(self) -> None:
        status, _ = self.request("POST", "/v1/admin/actions/shell")
        self.assertEqual(status, 404)

    def test_chat_identity_round_trip(self) -> None:
        key = base64.b64encode(b"k" * 32).decode()
        status, _ = self.chat_request("POST", "/v1/chat/identities", {
            "user_id": "nico",
            "device_id": "iphone",
            "agreement_public_key": key,
            "signing_public_key": key,
        })
        self.assertEqual(status, 200)
        status, body = self.chat_request("GET", "/v1/chat/identities/nico")
        self.assertEqual(status, 200)
        self.assertIn(b'"device_id":"iphone"', body)

    def test_chat_message_is_delivered_once_without_database_storage(self) -> None:
        key = base64.b64encode(b"k" * 32).decode()
        signature = base64.b64encode(b"s" * 64).decode()
        for token, user_id, device_id in [
            ("c" * 32, "nico", "iphone"),
            ("m" * 32, "mika", "ipad"),
        ]:
            status, _ = self.chat_request(
                "POST",
                "/v1/chat/identities",
                {
                    "user_id": user_id,
                    "device_id": device_id,
                    "agreement_public_key": key,
                    "signing_public_key": key,
                },
                token=token,
            )
            self.assertEqual(status, 200)
        envelope = {
            "id": "message-http-1",
            "group_id": "group-http-1",
            "sender_user_id": "nico",
            "sender_device_id": "iphone",
            "recipient_user_id": "mika",
            "recipient_device_id": "ipad",
            "ephemeral_public_key": key,
            "ciphertext": base64.b64encode(b"opaque").decode(),
            "signature": signature,
            "message_type": "image",
            "content_type": "image/jpeg",
            "chunk_index": 0,
            "chunk_count": 1,
            "created_at": "2026-09-16T05:00:00Z",
        }
        status, _ = self.chat_request("POST", "/v1/chat/messages", envelope)
        self.assertEqual(status, 201)
        status, body = self.chat_request(
            "GET", "/v1/chat/messages?recipient_device_id=ipad&wait=0", token="m" * 32
        )
        self.assertEqual(status, 200)
        self.assertIn(b'"message-http-1"', body)
        status, body = self.chat_request(
            "GET", "/v1/chat/messages?recipient_device_id=ipad&wait=0", token="m" * 32
        )
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {"messages": []})

    def test_chat_token_cannot_register_or_read_another_user_device(self) -> None:
        key = base64.b64encode(b"k" * 32).decode()
        status, _ = self.chat_request("POST", "/v1/chat/identities", {
            "user_id": "mika",
            "device_id": "ipad",
            "agreement_public_key": key,
            "signing_public_key": key,
        })
        self.assertEqual(status, 403)
        status, _ = self.chat_request(
            "GET", "/v1/chat/messages?recipient_device_id=ipad&wait=0"
        )
        self.assertEqual(status, 403)


if __name__ == "__main__":
    unittest.main()
