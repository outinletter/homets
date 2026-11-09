import SwiftUI
import UserNotifications
import CoreText

@main
struct HometsApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate
    @State private var store = WorkoutStore()
    @State private var purchases = PurchaseService()

    var body: some Scene {
        WindowGroup { RootView(store: store, purchases: purchases).task { await purchases.refresh() } }
    }
}

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        ["Barlow-Regular", "Barlow-SemiBold", "Barlow-ExtraBold"].forEach { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
