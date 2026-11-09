# HOMETS iOS

Open `Homets.xcodeproj` and select the `Homets` scheme. Requires Xcode and iOS 17 or later.

HOMETS is implemented as a native SwiftUI app. Workout settings and records are stored locally with Codable data. No network connection is required for local workout logging.

Before distribution:
- Developer team A7QB8PT33N is configured; confirm it is the intended distribution team.
- Bundle ID `com.addvalue.homets` is registered; App Store Connect app ID is `6820366752`.
- Test on a device: save/relaunch, midnight return, rest timer, JSON sharing, privacy link, iPad layout, and VoiceOver.
- Set the privacy policy URL and accurate privacy disclosures in App Store Connect.
- Archive the Release build and validate it in Organizer.

Deleting the app may remove local records. StoreKit purchase and locked-screen notification delivery require sandbox or device QA before release.
