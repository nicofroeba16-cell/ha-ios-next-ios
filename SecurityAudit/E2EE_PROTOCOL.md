# iOS Next Chat Protocol v1

## Status

Custom, review-required one-to-one protocol. It uses standard primitives from CryptoKit but is not Signal Protocol, MLS or an independently standardized construction. It must not be described as externally audited until `AUDIT_REPORT.md` from an independent reviewer is attached and accepted.

## Long-term device keys

Each iOS installation creates:

- X25519 static agreement private key.
- Ed25519 static signing private key.

The private raw representations are stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and never transmitted. The relay stores only the corresponding 32-byte public keys and the `(user_id, device_id)` binding.

Device registration is authenticated by a bearer token scoped server-side to exactly one `user_id`. Once a `(user_id, device_id)` binding exists, different public keys are rejected. A key reset therefore requires an explicit administrative revocation or a new device identifier.

## Per-chunk encryption

For every recipient device and every chunk:

1. Generate a fresh X25519 ephemeral private key.
2. Calculate X25519 shared secret with the recipient's static agreement public key.
3. Derive 32 bytes through HKDF-SHA-256:
   - salt: UTF-8 `group_id`
   - shared info: UTF-8 `ios-next-chat-v1|<message_id>|<recipient_device_id>`
4. Seal the raw chunk with ChaCha20-Poly1305 using CryptoKit's combined nonce/ciphertext/tag representation.
5. Encode the combined sealed box as strict Base64.

The construction gives a unique content-encryption key per chunk. It does not provide Double Ratchet post-compromise security: compromise of a recipient static agreement key plus recorded envelopes may expose past content. This is a declared review item, not a hidden claim.

## Signed envelope

The sender constructs `ChatEnvelope` with:

- `id`, `group_id`
- sender and recipient user/device IDs
- ephemeral agreement public key
- Base64 combined ciphertext
- `message_type`, `content_type`
- `chunk_index`, `chunk_count`
- ISO-8601 `created_at`

For signing, `signature` is set to the empty string and the entire Codable structure is encoded by `JSONEncoder` with sorted keys and without escaped slashes. The sender signs those bytes with Ed25519. The receiver reconstructs the same representation and verifies before decryption.

Reviewers must specifically test cross-SDK canonicalization, future optional fields and whether any Foundation/SDK change can alter the byte representation.

## Identity trust

- First contact is TOFU: each device fingerprint is SHA-256 over agreement public key concatenated with signing public key.
- Users must compare formatted safety numbers through a second trusted channel.
- Pinned identities are stored in Keychain.
- Changed keys block send/receive until the user opens the security view and confirms replacement with Face ID.

TOFU does not prevent a first-contact directory attack. User-scoped tokens, TLS, WireGuard and out-of-band safety-number verification reduce but do not eliminate that risk.

## Chunking and assembly

- Plaintext chunk size: 384 KiB.
- Maximum 256 chunks.
- Assembly key: sender user ID, sender device ID and group ID.
- Each chunk is independently signed and encrypted and carries its signed index/count.
- Incomplete assemblies expire from app memory after 120 seconds.
- Total incomplete assembly memory is capped; completed session history is bounded to 200 items/160 MiB.

## Replay policy

- Relay rejects duplicate envelope IDs for their active TTL.
- Client retains accepted envelope IDs in process memory for ten minutes.
- Client rejects timestamps outside a ten-minute window.
- Replay protection intentionally does not persist across app restarts. The timestamp window bounds that residual exposure and is an explicit audit item.

## No-persistence contract

- Chat URLSession is ephemeral with URL cache and cookies disabled.
- App message/media collections exist only in process memory.
- The relay queue exists only in process memory, is capacity bounded, expires at 120 seconds and pops on retrieval.
- SQLite contains public identities, admin settings and admin audit events only. Startup drops any legacy `chat_messages` table.
- Request logs omit paths, queries, headers and chat metadata.

The OS, Photos provider and user-selected source file are outside the app's storage guarantee. Crash reports, device compromise and user screenshots require separate platform policy controls.
