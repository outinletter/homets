import UIKit
import WebKit
import UniformTypeIdentifiers

// Import user-selected JSON backups through the Files picker.
final class RecordBackup: NSObject, UIDocumentPickerDelegate {
    weak var controller: UIViewController?
    weak var webView: WKWebView?
    private let io = DispatchQueue(label: "com.addvalue.homets.backup")
    func handle(_ body: [String: Any]) {
        switch body["op"] as? String {
        case "import":
            guard controller?.presentedViewController == nil else { return }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
            picker.delegate = self
            controller?.present(picker, animated: true)
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
    private func literal(_ text: String) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: [text]), let encoded = String(data: data, encoding: .utf8) else { return nil }
        return String(encoded.dropFirst().dropLast())
    }
    private func call(_ function: String, _ text: String) {
        guard let value = literal(text) else { return }
        webView?.evaluateJavaScript("\(function)(\(value));", completionHandler: nil)
    }
}
