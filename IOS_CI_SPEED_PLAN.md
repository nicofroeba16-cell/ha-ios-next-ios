# iOS CI Speed Preparation

Status: prepared only. Do not merge or activate while the current iOS 27 failure investigation is running.

## Goal

Keep the existing full validation path as the release-quality gate, while adding a faster feedback path for normal development.

## Fast Gate

The prepared workflow is `.github/workflows/ios-fast-gate.yml`.

It intentionally:
- has only `workflow_dispatch` while this branch is in preparation;
- runs portable backend/security validation in parallel on Linux;
- uses the existing Xcode 27 runner for native validation;
- skips a separate package-resolution command;
- installs XcodeGen only when it is missing;
- performs one `build-for-testing` and reuses it with `test-without-building`;
- verifies Packet Tunnel metadata but does not capture screenshots;
- does not run animation acceptance;
- does not change WireGuard sources or capabilities.

## Full Gate

Keep the existing `.github/workflows/ios.yml` as the full gate.

Full Gate remains responsible for:
- pinned WireGuard verification;
- full iOS 27 build/test;
- Packet Tunnel metadata/signing validation;
- simulator install;
- live HA card screenshots;
- evidence upload;
- later animation acceptance when explicitly activated.

## Activation plan after current CI is green

1. Prove the existing Full Gate green first.
2. Run the prepared Fast Gate manually against the same green SHA.
3. Compare build/test results with the Full Gate.
4. Only after equivalence is proven, enable Fast Gate for pull requests.
5. Keep Full Gate on important checkpoints / manual release validation.
6. Add path-aware skipping only after several green runs.

## Safe later optimizations

These are intentionally not enabled yet:
- SwiftPM cache keyed by Xcode version + WireGuard pin + Package.swift.
- WireGuard source cache keyed by pinned commit.
- DerivedData cache keyed by Xcode version + project.yml + source hash.
- UI screenshot skipping for backend/docs-only changes.
- WireGuard build skipping when no WireGuard/project/signing files changed.

DerivedData caching should be last because stale Xcode artifacts can hide real signing or extension problems.

## Non-goals

- No reduction in release validation coverage.
- No removal of WireGuard.
- No change to App IDs, entitlements, or Packet Tunnel structure.
- No automatic merge into `codex/ios27-owner-control`.
