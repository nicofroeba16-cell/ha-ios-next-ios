# Internal Pre-Audit Findings

This is not an independent audit.

## Remediated before handoff

### PA-01 — Shared relay token crossed user boundaries — High

The initial relay accepted one global chat token. Any holder could register identities for another user or request another device queue. The server now maps independent 32+ character tokens to user principals and enforces principal ownership for identity registration, sender identity and queue retrieval. Tests cover cross-user rejection.

### PA-02 — Public device keys were silently replaceable — High

The initial SQLite upsert replaced keys for an existing `(user_id, device_id)`. Registration now rejects a changed key pair with HTTP 409. Rotation requires explicit revocation/new enrollment and client pins still block unexpected changes.

### PA-03 — Partial-message namespace collision — Medium

Assemblies were keyed only by group ID. They are now keyed by sender user, sender device and group ID.

### PA-04 — Relay capacity evicted existing chunks — Medium

Capacity pressure initially dropped old chunks. The relay now rejects new data with HTTP 507 and preserves accepted chunks until delivery/TTL.

### PA-05 — Request logs exposed chat queue query metadata — Medium

HTTP logs now contain only client address and status, never path, query, bearer token or envelope metadata.

## Open design risks for independent decision

### PA-06 — No Double Ratchet/post-compromise security — High design question

Fresh sender ephemeral keys do not protect recorded history after compromise of the recipient static X25519 key. The reviewer must decide whether this product may ship with the limitation, requires a ratchet, or should adopt an audited messaging protocol implementation.

### PA-07 — TOFU first-contact authenticity — Medium

Manual safety-number verification is necessary. A compromised directory/token before first contact can substitute a device. Consider QR-based mutual verification or an owner-signed device enrollment certificate.

### PA-08 — Replay state is memory-only — Medium

The relay and client reject duplicates in their active windows, but no persistent replay database exists by design. A valid envelope replayed after restart but within the timestamp window may be accepted. The reviewer should assess a privacy-preserving monotonic/session mechanism.

### PA-09 — Token lifecycle and device revocation — Medium

User tokens are process environment configuration and rotate on service restart. A production operator procedure and owner UI/API for device revocation are required before broad enrollment.

### PA-10 — WireGuardKit source freshness — Medium

The official Apple source tag currently integrated is `1.0.16-27` at the exact project revision `2fec12a6e1f6e3460b6ee483aa00ad29cddadab1`. Its manifest declares PackageDescription 5.3 while using platform constants introduced in 5.5, and its umbrella C header uses BSD integer aliases without directly importing `<sys/types.h>`, which Xcode 27's explicit module build rejects. `Scripts/prepare_wireguard_dependency.sh` verifies the commit and permits exactly these two compatibility changes. CI rejects every other source difference, then builds the required `wireguard-go` bridge. The external reviewer must still assess source freshness and upstream security updates before release.
