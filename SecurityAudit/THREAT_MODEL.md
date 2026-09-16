# Threat Model

## Protected assets

- Chat plaintext and media.
- Device agreement/signing private keys.
- WireGuard private key and optional pre-shared key.
- Relay/user bearer tokens and Owner token.
- Integrity of public identity bindings.
- Owner-only maintenance capability.

## Trust boundaries

1. iOS app process and Keychain.
2. Packet Tunnel extension and its shared Keychain group.
3. WireGuard transport between iPhone and the private network.
4. HTTPS reverse proxy and relay process.
5. SQLite identity/admin state versus the nonpersistent RAM queue.
6. Other enrolled users/devices with their own scoped tokens.

## Adversaries and controls

| Adversary | Primary controls | Residual risk |
|---|---|---|
| Public-network observer | WireGuard, HTTPS, E2EE | Traffic timing/volume around VPN endpoint |
| Relay operator | ChaChaPoly ciphertext, endpoint-only private keys | Required routing metadata remains visible |
| User with another scoped token | Principal checks on register/send/take | May enumerate public identities; rate-limited DoS remains possible |
| Stolen chat token | Token scope, immutable device keys, safety numbers | Attacker can act as that user until token rotation/server restart |
| Malicious relay | Ed25519 verification, replay/time window | Can drop/delay/reorder chunks; first-contact directory substitution remains possible |
| Stolen unlocked iPhone | This-device-only Keychain, app-switcher cover | Active process memory and unlocked Keychain may be accessible |
| Compromised recipient static key | Per-chunk ephemeral sender key | Recorded historical envelopes can be decrypted; no recipient ratchet |
| Malicious media payload | Size/type bounds and Apple decoders | Decoder vulnerabilities remain platform risk |
| Configuration-file attacker | Strict WireGuard parser; blocked scripts/directives | Valid but malicious routes/DNS can redirect traffic; user/server provisioning must be trusted |

## Highest-value tests

1. Attempt identity registration, send and queue retrieval across principals.
2. Replace an existing device's signing/agreement keys.
3. Mutate every signed field independently.
4. Replay before and after relay/client windows and across process restart.
5. Flood incomplete chunk groups and oversized Base64 bodies.
6. Inspect app container, URL cache, SQLite, relay state directory, backups and unified logs after media exchange.
7. Import a WireGuard file containing `PostUp`, `Table`, invalid routes, malformed Base64 and hostile DNS/endpoint values.
8. Capture traffic with VPN disabled/enabled and verify release builds never downgrade to HTTP.

## Accepted functional tradeoffs

- No store-and-forward: offline messages expire.
- No read receipt or guaranteed delivery.
- No group chat or multi-party sender keys.
- Metadata minimization, not metadata elimination.

## Unaccepted risks blocking release

- Any plaintext or private key in files, logs, SQLite, backups or analytics.
- Cross-user queue read/write or identity registration.
- Silent key replacement.
- Signature-bypass, nonce/key reuse or signed-field ambiguity.
- Release HTTP fallback.
- Unsigned/unpinned WireGuard dependency source.
