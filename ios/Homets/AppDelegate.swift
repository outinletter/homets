import UIKit
import WebKit
import AudioToolbox
import UserNotifications

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = WorkoutViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class WorkoutViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, UNUserNotificationCenterDelegate {
    private var webView: WKWebView!
    private var exportURL: URL?
    private var restNotificationToken = UUID()
    private let backup = RecordBackup()
    override func viewDidLoad() {
        super.viewDidLoad()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController.add(self, name: "exportRecords")
        configuration.userContentController.add(self, name: "backupRecords")
        configuration.userContentController.add(self, name: "devicePreferences")
        UNUserNotificationCenter.current().delegate = self
        configuration.userContentController.addUserScript(WKUserScript(source: """
            window.exportRecords = function() {
                window.webkit.messageHandlers.exportRecords.postMessage(backupJSON());
            };
            """, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        backup.controller = self
        backup.webView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        view.backgroundColor = .systemBackground
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") else {
            showError("The workout screen is missing. Please reinstall HOMETS."); return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.navigationType == .linkActivated {
            decisionHandler(.cancel)
            if url.scheme == "https", url.host == "outinletter.github.io" { UIApplication.shared.open(url) }
            return
        }
        decisionHandler(url.isFileURL ? .allow : .cancel)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showError("Could not open your workout screen. Please restart HOMETS.")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("refreshBackup();", completionHandler: nil)
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "devicePreferences", message.frameInfo.isMainFrame,
           message.frameInfo.request.url?.isFileURL == true, let body = message.body as? [String: Any] {
            switch body["op"] as? String {
            case "awake": UIApplication.shared.isIdleTimerDisabled = body["enabled"] as? Bool ?? false
            case "sound": AudioServicesPlayAlertSound(1005)
            case "cancelTimer":
                restNotificationToken = UUID()
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["homets-rest"])
            case "timer":
                restNotificationToken = UUID()
                let token = restNotificationToken
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: ["homets-rest"])
                guard let seconds = body["seconds"] as? Double, seconds > 0, seconds <= 86400,
                      body["sound"] as? Bool != false else { return }
                let deadline = Date().addingTimeInterval(seconds)
                center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                    DispatchQueue.main.async {
                        guard granted, let self, self.restNotificationToken == token else { return }
                        let content = UNMutableNotificationContent()
                        content.title = "HOMETS"
                        content.body = "Rest complete. Ready for your next set?"
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
                        center.add(UNNotificationRequest(identifier: "homets-rest", content: content, trigger: trigger))
                    }
                }
            default: break
            }
            return
        }
        if message.name == "backupRecords", message.frameInfo.isMainFrame, message.frameInfo.request.url?.isFileURL == true,
           let body = message.body as? [String: Any] { backup.handle(body); return }
        guard message.name == "exportRecords", message.frameInfo.isMainFrame,
              message.frameInfo.request.url?.isFileURL == true,
              let text = message.body as? String, let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return }
        guard presentedViewController == nil else { return }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("homets-records.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
            let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            share.popoverPresentationController?.sourceView = view
            share.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            share.completionWithItemsHandler = { [weak self] _, completed, _, _ in
                if completed { self?.webView.evaluateJavaScript("backupExported();", completionHandler: nil) }
                try? FileManager.default.removeItem(at: directory)
                self?.exportURL = nil
            }
            present(share, animated: true)
        } catch { showError("Could not export your records. Please try again.") }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // The web timer plays the foreground alert; notifications cover background/locked operation.
        completionHandler([])
    }
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "HOMETS", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
