# Release Checklist

## Source readiness
- [x] Native SwiftUI app target, iOS/iPadOS 27+
- [x] Separate from Lovelace and HA web dashboards
- [x] Keychain-backed local credential storage
- [x] Home Assistant WebSocket authentication and entity loading
- [x] Light/switch and scene service actions
- [x] Profile-aware app shell and five top-level tabs
- [x] App icon source asset
- [x] Privacy and release documentation
- [x] Volatile E2EE chat for text, images, voice and video with no payload persistence
- [x] Privacy manifest and app-switcher protection for chat content
- [x] macOS CI workflow for build and unit tests after repository publication
- [x] Verify the official GitHub `xcode-27` runner, iOS 27 SDK and iPhone 17 Pro simulator; update CI.
- [ ] Run the committed workflow on GitHub and archive its green `.xcresult` evidence.

## Mandatory external gates
- [ ] Pass the hosted Xcode 27 build without warnings/errors.
- [ ] Configure a unique production bundle identifier and Apple Developer signing team.
- [x] Implement native OAuth authorization-code and refresh-token lifecycle.
- [x] Publish the HTTPS OAuth client-ID page at `https://nicofroeba16-cell.github.io/ha-ios-next-ios/` and wire it into the production app.
- [x] Verify the published OAuth page exposes `iosnext://auth` as its redirect URI.
- [ ] Validate login, token refresh and logout against the published client ID.
- [ ] Test login, reconnect, service actions, rotation, Dark Mode, Dynamic Type, VoiceOver and network changes on iPhone and iPad.
- [ ] Create App Store privacy labels, support URL and privacy-policy URL.
- [x] Implement WireGuard Packet Tunnel, strict import validation, shared Keychain reference and On-Demand rules.
- [ ] Enable Apple Network Extension capability, sign both targets and validate the tunnel on a physical device.
- [ ] Verify chat safety numbers out of band and test key-change blocking, TTL expiry and offline message loss.
- [ ] Upload archive to TestFlight, complete beta review and test on real devices.

## Release blocker
The developer-token path is compiled only into Debug builds. A public build still requires successful OAuth login, refresh and logout validation against a real Home Assistant instance.
