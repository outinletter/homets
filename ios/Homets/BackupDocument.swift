import SwiftUI
import UniformTypeIdentifiers

struct HometsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: StoredData

    init(data: StoredData) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let raw = configuration.file.regularFileContents, raw.count <= 10 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        data = try JSONDecoder().decode(StoredData.self, from: raw)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(data))
    }
}
