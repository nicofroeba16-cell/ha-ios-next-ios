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
- `HomeAssistantOAuthService` implements authorization-code exchange and uses the published production client ID `https://nicofroeba16-cell.github.io/ha-ios-next-ios/`.
- `AppTab` is the top-level navigation contract.

## Safety
- Tokens are stored only in `KeychainStore`.
- No dashboard mutation, secret files, or runtime HA configuration is included.
- The developer-token setup is compiled only in Debug. Release builds use OAuth and store credentials only in `KeychainStore`.

## Next work
1. Validate connection to a real HA instance on iPhone and iPad.
2. Map each profile's verified HA entities and replace fixture content with semantic live widgets.
3. Add media commands, accessibility UI tests, TestFlight delivery and App Store metadata.
