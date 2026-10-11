# HOMETS iOS

Open `Homets.xcodeproj` and select the `Homets` scheme. Requires Xcode and iOS 17 or later.

The existing web app is bundled at build time from the repository root. Workout records use WKWebView's persistent local storage. JSON export opens the iOS share sheet; JSON import opens Files. Settings → Backup & restore shows record counts, the last export, replacement confirmation, and a pre-import safety backup. Automatic iCloud synchronization is not included. Users can choose their own backup location in Files. No network connection is required for local workout logging.

Before distribution:
- Developer team A7QB8PT33N is configured; confirm it is the intended distribution team.
- Bundle ID `com.addvalue.homets` is registered; App Store Connect app ID is `6820366752`.
- Test on a device: save/relaunch, midnight return, rest timer, JSON sharing, privacy link, iPad layout, and VoiceOver.
- Set the privacy policy URL and accurate privacy disclosures in App Store Connect.
- Archive the Release build and validate it in Organizer.

Signed Release archives and App Store Connect uploads have succeeded. JSON import, safety backups, malformed-file rejection and workout storage rollback have automated coverage. Browser export/import and restoration have been verified. Native Files/share-sheet flows still require device QA; do not describe these checks as completed. The simulator previously exhibited WebKit/GPU errors. Google login is not included. Deleting the app may remove local records and the safety backup; exported files remain until removed separately. Previously created iCloud snapshots are not deleted by this update.
