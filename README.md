# iOS Next

Native SwiftUI client for Home Assistant. The app is intentionally separate from Lovelace and `/config/www/ios-next`.

## Open the project

1. Install Xcode 16+ and XcodeGen 2.38+ on macOS.
2. Run `xcodegen generate` in this directory.
3. Open `IOSNext.xcodeproj`, select an iOS 17+ simulator or device, then build.

After pushing the project to GitHub, the included macOS workflow regenerates the project and runs the unit tests on each pull request and `main` push.

## Current milestone

The release candidate foundation provides the native app shell, profile-specific start context, a Home Assistant WebSocket client, Keychain-backed credentials, five feature tabs, app-icon source, OAuth authorization-code/refresh-token implementation and release documentation. The public-release blocker is publishing the included OAuth client-ID page over HTTPS and validating it with a real HA instance.

## Safety

- Home Assistant remains the backend; this project never edits HA dashboards.
- Do not commit credentials or export Keychain content.
- The connection screen stores a developer access token only in the iOS Keychain. Never submit a public build while this setup path is active; see `RELEASE_CHECKLIST.md`.
