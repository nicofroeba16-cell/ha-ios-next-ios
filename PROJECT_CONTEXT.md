# iOS Next — Project Context

## Mission
Native iOS/iPadOS 27 SwiftUI Home Assistant client. Independent from Lovelace and the HA `/config/www/ios-next` web UI.

## Build
- XcodeGen source: `project.yml`; the hosted Xcode 27 job regenerates `IOSNext.xcodeproj`.
- App target: `IOSNext`; Packet Tunnel: `IOSNextPacketTunnel`; tests: `IOSNextTests`.
- WireGuardKit is pinned to official commit `2fec12a6e1f6e3460b6ee483aa00ad29cddadab1`; `WireGuardGoBridgeiOS` builds its Go bridge.
- `.github/workflows/ios.yml` verifies Xcode/SDK 27, the dependency commit and iPhone 17 Pro simulator tests.
- GitHub Pages hosts the production OAuth client-ID page.

## Architecture
- `App/`: application entry, tab shell, onboarding/connection UI.
- `Core/`: profile/entity models, Keychain, WebSocket HA client, chat crypto/relay, app state.
- `Features/`: five top-level native tabs.
- `Design/`: semantic SwiftUI component library; `Assets.xcassets`: App Store icon source.
- App-wide state uses Observation (`@Observable`), targets iOS 27 and uses native Liquid Glass only for controls and navigation chrome.
- The Home Assistant connection consumes live `state_changed` events and reconnects with bounded exponential backoff.
- Runner control uses a separate, fixed-endpoint API; no arbitrary shell is exposed.
- The hidden Owner Control area is not secured by obscurity: Face ID, a Keychain token and server-side `owner` verification are all mandatory.
- `Backend/admin_service` is the portable allowlisted Owner API implementation with SQLite audit state, maintenance mode, cache maintenance, log exports and safe backups.
- Chat uses a volatile ciphertext-only RAM relay, X25519/HKDF/ChaChaPoly, Ed25519 signatures and no message/media persistence.
- The five top-level tabs are Home, Rooms, Chat, Media and More; Scenes live below More.

## Stable contracts
- `HomeAssistantClient.connect(configuration:)` authenticates and loads an entity-state snapshot.
- `HomeAssistantClient.callService(domain:service:target:serviceData:)` performs actions.
- `AppModel` owns connection/session state and profile selection.
- `ProfileCatalog` is the only profile-to-entity mapping source; it contains verified Timo/Mika IDs and no invented Juli/Gabi devices.
- `HomeAssistantOAuthService` implements authorization-code exchange and uses the published production client ID `https://nicofroeba16-cell.github.io/ha-ios-next-ios/`.
- `AppTab` is the top-level navigation contract.

## Safety
- Tokens are stored only in `KeychainStore`.
- Chat private keys remain in the device-only Keychain; public device identities are the only persistent relay chat records.
- Chat payloads live only in bounded process memory and URLSession uses an ephemeral configuration.
- No dashboard mutation, secret files, or runtime HA configuration is included.
- The developer-token setup is compiled only in Debug. Release builds use OAuth and store credentials only in `KeychainStore`.

## Next work
1. Run the hosted Xcode 27 gate and resolve any compiler findings.
2. Validate connection and service calls against the real HA instance on iPhone and iPad.
3. Run accessibility/UI tests, Instruments, TestFlight delivery and App Store metadata checks.
4. Finish Apple signing/capability approval and physical-device WireGuard/On-Demand validation.
