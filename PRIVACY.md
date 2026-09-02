# Privacy

iOS Next connects directly from the user's device to the Home Assistant server selected by the user.

- The app stores only the server URL and authentication credential required to connect.
- Authentication credentials are stored in the iOS Keychain and are not written to the app's files, analytics, logs or source repository.
- Home Assistant entity states are processed on device to render the interface and control devices.
- This source project contains no analytics SDK, advertising SDK, tracking, cloud relay or third-party dependency.
- The user can remove the saved connection in System → Verbindung entfernen.

Before App Store submission, publish this policy at a public HTTPS URL and complete App Store Connect privacy declarations based on the final binary.
