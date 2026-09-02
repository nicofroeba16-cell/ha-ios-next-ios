# Release Checklist

## Source readiness
- [x] Native SwiftUI app target, iOS/iPadOS 17+
- [x] Separate from Lovelace and HA web dashboards
- [x] Keychain-backed local credential storage
- [x] Home Assistant WebSocket authentication and entity loading
- [x] Light/switch and scene service actions
- [x] Profile-aware app shell and five top-level tabs
- [x] App icon source asset
- [x] Privacy and release documentation
- [x] macOS CI workflow for build and unit tests after repository publication

## Mandatory external gates
- [ ] Install Xcode 16+ and build the generated Xcode project without warnings/errors.
- [ ] Configure a unique production bundle identifier and Apple Developer signing team.
- [x] Implement native OAuth authorization-code and refresh-token lifecycle.
- [x] Publish the HTTPS OAuth client-ID page at `https://nicofroeba16-cell.github.io/ha-ios-next-ios/` and wire it into the production app.
- [ ] Validate login, token refresh and logout against the published client ID.
- [ ] Test login, reconnect, service actions, rotation, Dark Mode, Dynamic Type, VoiceOver and network changes on iPhone and iPad.
- [ ] Create App Store privacy labels, support URL and privacy-policy URL.
- [ ] Upload archive to TestFlight, complete beta review and test on real devices.

## Release blocker
The developer-token path is compiled only into Debug builds. A public build still requires successful OAuth login, refresh and logout validation against a real Home Assistant instance.
