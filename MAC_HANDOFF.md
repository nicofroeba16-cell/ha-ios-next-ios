# Xcode 27 handoff

The compile and simulator portion no longer requires a privately owned Mac. GitHub's official `xcode-27` runner executes sections 1 and 2 through `.github/workflows/ios.yml`. Sections 3–7 still require human review and, where noted, a provisioned physical Apple device.

## 1. Regenerate the project

The hosted workflow performs this automatically. For a local Mac:

```bash
brew install xcodegen
bash Scripts/prepare_wireguard_dependency.sh
xcodegen generate
```

Do not use the previously generated project file as the source of truth. `project.yml` owns the iOS 27 deployment target, the Packet Tunnel target, the commit-pinned WireGuardKit package and the external `wireguard-go` build target.

## 2. Compile and run tests

Push the branch and run **Actions → iOS 27 Mac Gate → Run workflow**, or use this on a local Xcode 27 Mac:

```bash
xcodebuild test \
  -project IOSNext.xcodeproj \
  -scheme IOSNext \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  CODE_SIGNING_ALLOWED=NO
```

If the installed simulator has a different device name, list destinations with:

```bash
xcodebuild -showdestinations -project IOSNext.xcodeproj -scheme IOSNext
```

## 3. Required visual matrix

- Small and large iPhone in portrait.
- iPad in portrait, landscape, Split View and resizable windows.
- Light Mode, Dark Mode and increased contrast.
- Dynamic Type from default through accessibility sizes.
- Reduce Motion, Reduce Transparency and Differentiate Without Color.
- German strings with long entity names.
- Online, reconnecting, offline, unavailable-entity and failed-action states.
- Liquid Glass toolbars, buttons, tab bar, sheets and Owner Control.

## 4. Required live validation

- OAuth callback and refresh-token rotation.
- Home Assistant initial snapshot and live `state_changed` events.
- Reconnect after Wi-Fi loss, HA restart and app backgrounding.
- Light, switch, lock, media, climate, cover and scene service calls.
- Runner status and every allowlisted runner action.
- Owner role rejection, Face ID cancellation, maintenance actions and audit log.
- Admin service through the real HTTPS/VPN route; never through exposed plain HTTP.
- Chat text, 12 MiB image, long in-memory voice recording and 30 MiB video in both directions.
- Compare safety numbers, rotate one device identity and confirm that key pinning blocks delivery.
- Confirm relay payloads disappear on first delivery and after the 120-second TTL.
- Confirm the app-switcher snapshot hides chat content.

## 5. VPN and anywhere access

WireGuard is selected and implemented in code. The generated project includes the Packet Tunnel Network Extension, the pinned official WireGuardKit source and the required external `wireguard-go` bridge. Remaining device-only steps:

- Add both bundle identifiers to the Apple Developer account and request/enable the Network Extension capability.
- Select the signing team for the app and `IOSNextPacketTunnel`, then create matching provisioning profiles.
- Install the server-issued `.conf` through the app and accept iOS's one-time VPN permission sheet.
- Verify On-Demand reconnect, private DNS, route containment and revocation on the physical device.
- For zero-touch installation on managed devices, deploy the signed app and VPN configuration with MDM; a normal App Store install cannot silently grant VPN permission.

In every variant, private DNS must resolve the internal HTTPS names for Home Assistant, Runner, Admin and Chat. Verify kill-switch behavior and ensure those services are not exposed as plain HTTP on the public internet.

## 6. Performance acceptance

- Record launch, scrolling, SwiftUI updates, networking, memory and energy in Instruments.
- Confirm bursty HA events stay responsive and do not create repeated full reloads.
- Confirm image/media screens do not grow memory after repeated navigation.
- Confirm the chat stays within its 160 MiB in-session cap, incomplete chunks expire and 30 MiB video does not terminate the app under memory pressure.
- Exercise AirPods/Bluetooth route changes and interrupted voice recording.
- Confirm no Main Thread Checker, purple runtime or concurrency warnings.
- Test a 30-minute foreground session and repeated background/foreground transitions.

## 7. Release gates

- Archive with production signing.
- Validate privacy manifest and App Store metadata.
- Upload to TestFlight and repeat the physical-device smoke test.
- Require a green `iOS 27 Mac Gate` result and retain its `.xcresult` evidence.
