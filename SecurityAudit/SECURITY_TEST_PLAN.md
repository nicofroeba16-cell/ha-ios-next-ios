# Security Test Plan

## Automated relay tests

- Owner authentication and allowlist.
- Identity creation and immutable key binding.
- User-principal isolation for registration and queue retrieval.
- Sender principal and registered-device enforcement.
- Recipient existence enforcement.
- Strict envelope/Base64/chunk/size validation.
- Duplicate rejection, TTL expiry and delete-on-delivery.
- Total/device queue capacity without eviction.
- Absence of a chat payload table in SQLite.
- Aggregate-only Owner status.

Run:

```bash
PYTHONPATH=Backend python3 -m unittest discover -s Backend/tests -v
```

## Required Xcode tests

1. Crypto round-trip on iOS 27 simulator and physical arm64 device.
2. Flip one bit in every signed envelope field and require rejection.
3. Wrong recipient key, wrong sender signing key and truncated sealed box.
4. Deterministic signing bytes across clean builds and supported devices.
5. Concurrent multi-device send/receive with reordered chunks.
6. Relaunch during incomplete assembly and confirm no payload recovery.
7. Inspect app sandbox, Keychain access groups, URL cache and unified logs.
8. Background/app-switcher snapshot and device-lock behavior.
9. Fuzz `WireGuardConfigurationValidator` and envelope decoding.
10. Packet tunnel on Wi-Fi/cellular transitions, sleep/wake, captive portal and server outage.

## Dynamic network tests

- Prove release builds reject `http://` relay/admin/runner/HA OAuth endpoints.
- Confirm private DNS and all configured home subnets route through WireGuard.
- Verify On-Demand resumes after reboot and does not leak protected destinations before tunnel establishment.
- Capture relay traffic and confirm no plaintext/message media appears outside TLS/WireGuard.
- Attempt replay, reordering, omission and duplication through an intercepting test relay.

## External tools requested

- Xcode static analyzer and Thread Sanitizer where compatible.
- Instruments: Allocations, Leaks, Network, Energy and hangs.
- MobSF or equivalent iOS IPA inspection.
- Semgrep/custom Swift rules for logging and insecure persistence.
- Secret scan of Git history and produced IPA.
- Dependency/SBOM and signature/provenance scan for WireGuardKit/wireguard-go.
- Independent manual cryptographic protocol review.
