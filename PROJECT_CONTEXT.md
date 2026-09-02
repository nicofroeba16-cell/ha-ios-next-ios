# iOS Next — Project Context

## Mission
Native iOS/iPadOS 17+ SwiftUI Home Assistant client. Independent from Lovelace and the HA `/config/www/ios-next` web UI.

## Build
- XcodeGen source: `project.yml`; generate `IOSNext.xcodeproj` on macOS.
- App target: `IOSNext`; tests: `IOSNextTests`.
- No external dependencies.
- `.github/workflows/ios.yml` generates the Xcode project and runs iOS unit tests on macOS after repository publication.

## Architecture
- `App/`: application entry, tab shell, onboarding/connection UI.
- `Core/`: profile model, entity model, Keychain, WebSocket HA client, app state.
- `Features/`: five top-level native tabs.
- `Design/`: semantic SwiftUI component library; `Assets.xcassets`: App Store icon source.
- App-wide state uses Observation (`@Observable`), iOS 17+.

## Stable contracts
- `HomeAssistantClient.connect(configuration:)` authenticates and loads an entity-state snapshot.
- `HomeAssistantClient.callService(domain:service:target:serviceData:)` performs actions.
- `AppModel` owns connection/session state and profile selection.
- `ProfileCatalog` is the only profile-to-entity mapping source; it contains verified Timo/Mika IDs and no invented Juli/Gabi devices.
- `HomeAssistantOAuthService` implements authorization-code exchange; it becomes active only after `OAuthClientID/index.html` is deployed over HTTPS as the configured client ID.
- `AppTab` is the top-level navigation contract.

## Safety
- Tokens are stored only in `KeychainStore`.
- No dashboard mutation, secret files, or runtime HA configuration is included.
- The token setup is an explicit development-only connection; public distribution is blocked until OAuth uses a verified HTTPS client-ID and approved native redirect URI.

## Next work
1. Validate connection to a real HA instance on iPhone and iPad.
2. Publish the OAuth client-ID redirect page and wire the authorization-code/refresh-token lifecycle into onboarding.
3. Map each profile's verified HA entities and replace fixture content with semantic live widgets.
4. Add media commands, accessibility UI tests, TestFlight delivery and App Store metadata.
