# HOMETS iOS

Open `Homets.xcodeproj` and select the `Homets` scheme. Requires Xcode and iOS 17 or later.

The existing web app is bundled at build time from the repository root. Workout records use WKWebView's persistent local storage. JSON export opens the iOS share sheet; the privacy policy opens in the external browser. No server or network connection is required for workout logging.

Before distribution:
- Developer team A7QB8PT33N is configured; confirm it is the intended distribution team.
- Confirm ownership/availability of `com.outinletter.homets`; adjust if necessary.
- Test on a device: save/relaunch, midnight return, rest timer, JSON sharing, privacy link, iPad layout, and VoiceOver.
- Set the privacy policy URL and accurate privacy disclosures in App Store Connect.
- Archive the Release build and validate it in Organizer.

An unsigned Release build, a signed device Debug build, and a simulator Debug build have been verified. Device installation timed out. The iOS 18.6 simulator showed a blank screen and WebKit/GPU process errors; UI behavior remains unverified. TestFlight and App Review remain unverified. Deleting the app removes its local records; export them first. JSON import is not implemented.
