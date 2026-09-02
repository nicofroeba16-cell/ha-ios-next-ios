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
- [ ] Publish `OAuthClientID/index.html` over HTTPS and use its final URL as the production client ID.
- [ ] Validate login, token refresh and logout against the published client ID.
- [ ] Test login, reconnect, service actions, rotation, Dark Mode, Dynamic Type, VoiceOver and network changes on iPhone and iPad.
- [ ] Create App Store privacy labels, support URL and privacy-policy URL.
- [ ] Upload archive to TestFlight, complete beta review and test on real devices.

## Release blocker
Do not ship publicly while the developer-token onboarding remains enabled. A public build requires the verified OAuth redirect and production authentication flow.
