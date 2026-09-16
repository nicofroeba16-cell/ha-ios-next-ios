# iOS Next

Native iOS 27 SwiftUI client for Home Assistant. The app is intentionally separate from Lovelace and `/config/www/ios-next`.

## Open the project

1. Install Xcode 27 with the iOS 27 SDK and XcodeGen 2.38+ on macOS.
2. Run `bash Scripts/prepare_wireguard_dependency.sh`. It checks out the exact audited WireGuard commit and applies only two Xcode 27 compatibility changes: PackageDescription 5.5 and the missing system-type header import.
3. Run `xcodegen generate` in this directory.
4. Open `IOSNext.xcodeproj`, select an iOS 27 simulator or device, then build.

After pushing the project to GitHub, the included workflow uses GitHub's official `xcode-27` Apple-silicon image. It verifies the SDK/runtime versions, resolves the commit-pinned WireGuardKit source, builds the `wireguard-go` bridge, embeds the Packet Tunnel extension and runs the tests on an iPhone 17 Pro with iOS 27. The workflow can also be started manually with **Actions → iOS 27 Mac Gate → Run workflow**.

## Current milestone

The iOS 27 foundation provides an adaptive iPhone/iPad shell, semantic design system, profile-specific home context, live Home Assistant WebSocket state updates, reconnect handling, Keychain-backed credentials, native entity controls, media controls, runner management UI, OAuth authorization-code/refresh-token handling, a WhatsApp-familiar volatile E2EE chat for text/images/voice/video and release documentation. The production OAuth client ID is published at `https://nicofroeba16-cell.github.io/ha-ios-next-ios/`. Compilation and simulator tests can run on the hosted Mac workflow; Apple Developer signing, entitlement verification, VPN On Demand and real Home Assistant/VPN behavior still require a provisioned physical device.

The app does not require Nabu Casa. Home Assistant, Runner, Owner Control and chat can use private HTTPS addresses reachable through the user's VPN. See `CHAT_SECURITY.md` for the no-storage contract and the remaining Apple provisioning requirements for VPN On Demand.

## Linux-side validation

Run `bash Scripts/validate_without_macos.sh`. This checks repository whitespace, plist/XML, asset JSON, accidental secret patterns, backend tests and the declared iOS 27 deployment target. The GitHub Mac gate performs the missing Xcode build and simulator tests.

## Safety

- Home Assistant remains the backend; this project never edits HA dashboards.
- Do not commit credentials or export Keychain content.
- Release builds use native OAuth only. The Keychain-backed developer-token path is compiled only for Debug; see `RELEASE_CHECKLIST.md`.
