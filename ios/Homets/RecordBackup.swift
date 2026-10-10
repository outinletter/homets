import UIKit
import WebKit
import UniformTypeIdentifiers

// Each installation owns a snapshot file; changes from other files merge by exercise revision.
final class RecordBackup: NSObject, UIDocumentPickerDelegate {
    weak var controller: UIViewController?
    weak var webView: WKWebView?
    private let query = NSMetadataQuery()
    private let io = DispatchQueue(label: "com.addvalue.homets.backup")
    private var container: URL?
    private var enabled = false
    private var generation = 0
    private var gathering = false
    private var reading = false
    private var readAgain = false
    private var lastContent: Data?
    private var installation: String {
        if let id = UserDefaults.standard.string(forKey: "backupInstallation") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "backupInstallation")
        return id
    }
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(gathered), name: .NSMetadataQueryDidFinishGathering, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(changed), name: .NSMetadataQueryDidUpdate, object: query)
        NotificationCenter.default.addObserver(self, selector: #selector(accountChanged), name: .NSUbiquityIdentityDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resume), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    deinit { query.stop(); NotificationCenter.default.removeObserver(self) }
    func handle(_ body: [String: Any]) {
        switch body["op"] as? String {
        case "import":
            guard controller?.presentedViewController == nil else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
            picker.delegate = self
            controller?.present(picker, animated: true)
        case "configure": configure(body["enabled"] as? Bool == true)
        case "sync": if enabled, !gathering { readCloud() }
        default: break
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        io.async { [weak self] in
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                let text = try String(contentsOf: url, encoding: .utf8)
                DispatchQueue.main.async { self?.call("receiveBackup", text) }
            } catch { DispatchQueue.main.async { self?.call("showToast", "Could not read this backup. Choose a JSON file smaller than 10 MB.") } }
        }
    }
    private func configure(_ value: Bool) {
        enabled = value; generation += 1; query.stop(); container = nil; lastContent = nil; reading = false; readAgain = false
        guard value else { call("cloudStatus", "iCloud sync is off. Local records remain saved."); return }
        let token = generation
        call("cloudStatus", "Connecting to iCloud…")
        io.async { [weak self] in
            let url = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.addvalue.homets")
            DispatchQueue.main.async {
                guard let self, self.enabled, self.generation == token else { return }
                guard let url else { self.call("cloudStatus", "iCloud is unavailable. Sign in to Apple ID and enable iCloud Drive in iOS Settings, then tap Sync now."); return }
                self.container = url.appendingPathComponent("Documents", isDirectory: true)
                self.gathering = true
                self.query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
                self.query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "homets-*.json")
                if !self.query.start() {
                    self.gathering = false
                    self.call("cloudStatus", "Could not start iCloud sync. Check iCloud Drive in iOS Settings, then tap Sync now.")
                }
            }
        }
    }
    @objc private func accountChanged() { DispatchQueue.main.async { self.configure(false); self.call("cloudAccountChanged", "") } }
    @objc private func resume() { if enabled { configure(true) } }
    @objc private func gathered() { gathering = false; readCloud() }
    @objc private func changed() { if !gathering { readCloud() } }
    private func readCloud() {
        guard enabled, let container else { return }
        if reading { readAgain = true; return }
        query.disableUpdates()
        let items = query.results.compactMap { $0 as? NSMetadataItem }
        var urls: [URL] = [], pending = false
        for item in items {
            guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            if status == NSMetadataUbiquitousItemDownloadingStatusNotDownloaded || status == NSMetadataUbiquitousItemDownloadingStatusDownloaded {
                try? FileManager.default.startDownloadingUbiquitousItem(at: url); pending = true
            } else { urls.append(url) }
        }
        query.enableUpdates()
        guard !pending else { call("cloudStatus", "Downloading existing iCloud records. Your local records are safe."); return }
        reading = true
        let token = generation
        io.async { [weak self] in
            var texts: [String] = [], failed = false
            for url in urls {
                let versions = [url] + (NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? []).map(\.url)
                for version in versions {
                var coordinationError: NSError?
                NSFileCoordinator().coordinate(readingItemAt: version, options: [], error: &coordinationError) { coordinated in
                    do {
                        guard (try coordinated.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
                        texts.append(try String(contentsOf: coordinated, encoding: .utf8))
                    } catch { failed = true }
                }
                if coordinationError != nil { failed = true }
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.enabled, self.generation == token else { return }
                self.reading = false
                guard !failed else { self.call("cloudStatus", "Could not read iCloud records. Tap Sync now to retry."); return }
                let encoded = texts.compactMap { self.literal($0) }.map { "receiveCloud(\($0));" }.joined()
                self.webView?.evaluateJavaScript(encoded + "backupJSON();") { result, error in
                    guard self.enabled, self.generation == token else { return }
                    guard error == nil, let text = result as? String else { self.call("cloudStatus", "Could not merge iCloud records. Tap Sync now to retry."); return }
                    self.writeCloud(text, directory: container, token: token)
                    if self.readAgain { self.readAgain = false; self.readCloud() }
                }
            }
        }
    }
    private func writeCloud(_ text: String, directory: URL, token: Int) {
        guard let data = text.data(using: .utf8), var content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        content.removeValue(forKey: "exportedAt")
        guard let stable = try? JSONSerialization.data(withJSONObject: content, options: [.sortedKeys]) else { return }
        guard stable != lastContent else { return }
        let url = directory.appendingPathComponent("homets-\(installation).json")
        let account = FileManager.default.ubiquityIdentityToken as? NSObject
        io.async { [weak self] in
            guard let account, account.isEqual(FileManager.default.ubiquityIdentityToken) else { return }
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var coordinationError: NSError?, writeError: Error?
                NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinated in
                    do { try data.write(to: coordinated, options: .atomic) } catch { writeError = error }
                }
                if let error = coordinationError ?? writeError as NSError? { throw error }
                for version in NSFileVersion.unresolvedConflictVersionsOfItem(at: url) ?? [] { version.isResolved = true }
                DispatchQueue.main.async {
                    guard let self, self.enabled, self.generation == token else { return }
                    self.lastContent = stable
                    self.call("cloudStatus", "Last iCloud backup: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)). Saved to iCloud Drive; transfer continues automatically when online.")
                }
            } catch { DispatchQueue.main.async { self?.call("cloudStatus", "iCloud backup could not be saved. Check iCloud storage and tap Sync now.") } }
        }
    }
    private func literal(_ text: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: [text]), let encoded = String(data: data, encoding: .utf8) else { return nil }
        return String(encoded.dropFirst().dropLast())
    }
    private func call(_ function: String, _ text: String) {
        guard let value = literal(text) else { return }
        webView?.evaluateJavaScript("\(function)(\(value));", completionHandler: nil)
    }
}
