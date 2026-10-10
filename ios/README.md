# HOMETS iOS

Open `Homets.xcodeproj` and select the `Homets` scheme. Requires Xcode and iOS 17 or later.

The existing web app is bundled at build time from the repository root. Workout records use WKWebView's persistent local storage. JSON export opens the iOS share sheet; JSON import opens Files. Settings → Backup & restore shows record counts, the last export, replacement confirmation, and a pre-import safety backup. Optional iCloud Documents sync uses `iCloud.com.addvalue.homets` and the device's Apple ID, with a snapshot per installation and revision-based merging per exercise. Enable sync separately on each device. No network connection is required for local workout logging.

Before distribution:
- Developer team A7QB8PT33N is configured; confirm it is the intended distribution team.
- Bundle ID `com.addvalue.homets` is registered; App Store Connect app ID is `6820366752`.
- Test on a device: save/relaunch, midnight return, rest timer, JSON sharing, privacy link, iPad layout, and VoiceOver.
- Set the privacy policy URL and accurate privacy disclosures in App Store Connect.
- Archive the Release build and validate it in Organizer.

Signed Release archives and App Store Connect uploads have succeeded. JSON v2/v3 import, cancellation, safety backup recovery, malformed-file rejection, failed-write rollback, per-exercise cloud merge, stale revisions, reset/deletion propagation, and sync opt-out have automated coverage. Browser export/import and restoration have been verified. Native Files/share-sheet flows and iCloud transfer between two physical devices still require device QA; do not describe these checks as completed. The simulator previously exhibited WebKit/GPU errors. Google login is not included. Deleting the app may remove local records and the safety backup; exported and iCloud files remain until removed separately.
