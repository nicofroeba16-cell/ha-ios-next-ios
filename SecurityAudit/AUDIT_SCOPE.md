# External Security Review Scope

## Objective

Independently determine whether the iOS Next one-to-one chat protects message confidentiality, integrity, sender authenticity and device isolation under the stated threat model, and whether the volatile relay fulfills its no-payload-persistence contract.

This repository has received an internal pre-audit review only. Approval requires a separate qualified reviewer with no involvement in implementation.

## In scope

### iOS cryptography and state

- `Sources/Core/ChatCrypto.swift`
- `Sources/Core/ChatModels.swift`
- `Sources/Core/ChatModel.swift`
- `Sources/Core/ChatRelayClient.swift`
- `Sources/Core/KeychainStore.swift`
- `Sources/Features/ChatView.swift`
- `Sources/Core/InMemoryVoiceRecorder.swift`
- `Sources/Features/InMemoryMediaViews.swift`

### Relay and identity directory

- `Backend/admin_service/core.py`
- `Backend/admin_service/server.py`
- `Backend/tests/test_admin_service.py`

### WireGuard boundary

- `Sources/Core/WireGuardConfigurationValidator.swift`
- `Sources/Core/WireGuardKeychain.swift`
- `Sources/Core/WireGuardTunnelController.swift`
- `Sources/Features/WireGuardView.swift`
- `WireGuard/`
- `Scripts/prepare_wireguard_dependency.sh`
- app and extension entitlements

## Explicit security claims to verify

1. Relay operators cannot decrypt a valid chat payload without compromising an endpoint.
2. Modification of signed envelope fields or ciphertext is detected before plaintext is accepted.
3. A user-scoped bearer token cannot register a different user's device, send as another user or read another user's queue.
4. Registered `(user_id, device_id)` keys cannot be silently replaced.
5. Replayed envelope IDs and envelopes older/newer than the permitted clock window are rejected in-session.
6. Chat payloads and imported media are not intentionally written to app files, `UserDefaults`, SQLite, logs, URL cache or relay backups.
7. Relay ciphertext is bounded, expires after 120 seconds and is removed on first retrieval.
8. WireGuard private configuration is stored only as a this-device-only shared-Keychain item referenced by `NETunnelProviderProtocol.passwordReference`.
9. WireGuard configuration, E2EE keys, tokens and plaintext never appear in application logs or committed fixtures.

## Out of scope unless separately commissioned

- Cryptanalysis of Apple CryptoKit or WireGuard itself.
- The Home Assistant server, router, VPN server and TLS reverse proxy.
- Apple operating-system compromise, a jailbroken device, malicious keyboard, screen recording by the user or physical attacks after device unlock.
- Availability while the recipient is offline; delivery loss after TTL is intentional.
- Group messaging, calling, backups, server-side history and message search, which are not implemented.

## Required reviewer deliverables

- Findings with severity, exploit preconditions, affected code and reproducible proof.
- Review of protocol construction and canonical signed representation.
- Dependency/provenance review of the pinned WireGuard source.
- Confirmation or rejection of every explicit security claim above.
- Retest statement for every remediated High/Critical finding.
- Final disposition: approved, approved with accepted risks, or rejected.

## Acceptance gate

- No open Critical or High finding.
- Medium findings require documented remediation or explicit owner risk acceptance.
- Crypto-protocol findings require cryptography expertise; a generic mobile penetration test alone is insufficient.
- The reviewer must build the exact commit recorded in `AUDIT_MANIFEST.txt` and report its SHA-256 bundle hash.
