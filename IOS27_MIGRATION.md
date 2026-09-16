# iOS 27 migration

## Completed in code

- iOS 27 deployment target and native Liquid Glass button styles.
- Adaptive tab navigation on iPhone and split navigation on iPad.
- Semantic colors, Dynamic Type, Reduce Transparency support and 44-point controls.
- Rebuilt Home, Rooms, Media, Scenes, System, Diagnostics and Runner screens.
- Native detail controls for lights, switches, media players, climate entities, covers and scenes.
- Home Assistant `state_changed` subscription with incremental entity updates.
- Bounded reconnect backoff without clearing the last known UI state.
- Action-level progress and errors rather than treating service failures as connection loss.
- Slider updates are sent on interaction completion to avoid flooding Home Assistant.
- Runner API token storage in Keychain and device authentication for critical actions.
- Hidden Owner Control area with Face ID-only unlock, server-side `owner` verification, fresh biometric approval for mutations and audited allowlisted maintenance actions.
- Portable Owner Admin service with bearer-token verification, loopback-only default binding, rate limiting, SQLite audit trail, maintenance mode, cache cleanup, log export and database backups.
- WhatsApp-familiar chat UI for text, images, in-memory voice recording and in-memory video playback.
- X25519/HKDF/ChaChaPoly encryption, Ed25519 signatures, safety-number display and contact-key pinning.
- Bounded ciphertext-only RAM relay with a 120-second TTL and immediate delete-on-delivery; no chat payload database or files.
- Ephemeral chat networking, app-switcher privacy cover and a privacy manifest declaring no tracking or collected data.
- WireGuard Packet Tunnel target, strict configuration importer, this-device-only shared-Keychain reference and On-Demand controls.
- Official GitHub `xcode-27` build gate for iOS 27 simulator compilation and tests without a private Mac.

## Intentionally left for macOS

- Execute the committed hosted Xcode 27 workflow and resolve any compiler/SDK failures it reports.
- Run UI and accessibility inspection in the iOS 27 simulator.
- Verify Liquid Glass composition, Dynamic Type and iPad window resizing visually.
- Profile launch, scrolling, memory, networking and energy with Instruments.
- Validate OAuth callback, live HA entities and Runner-Control API on physical devices.
- Validate PhotosPicker imports, microphone/Bluetooth routing, VoiceOver chat controls and large-video memory pressure.
- Enable Apple Network Extension capability, sign the WireGuard app/extension and approve/test VPN On Demand on hardware.
- Archive, sign and distribute through TestFlight.

No Home Assistant dashboard or runtime configuration is modified by this project.
