import SwiftUI
import UniformTypeIdentifiers

struct LabError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

struct ResultPanel: View {
    var text: String
    var milliseconds: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RESULT").font(.caption.monospaced()).foregroundStyle(.cyan)
                Spacer()
                if let milliseconds { Text(String(format: "%.1f ms", milliseconds)).font(.caption.monospaced()) }
            }
            Text(text.isEmpty ? "Run an experiment to see its output." : text)
                .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct LabNote: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.footnote).foregroundStyle(.secondary) }
}

/// Copy once while the security-scoped picker URL is accessible. Never retain external access.
enum ImportedFile {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("MLLabSession", isDirectory: true)
    static func cleanPreviousSession() {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    static func copy(_ result: Result<[URL], Error>) throws -> URL {
        guard let source = try result.get().first else { throw LabError("No file was selected.") }
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let folder = root.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(source.lastPathComponent)
        do { try FileManager.default.copyItem(at: source, to: target) }
        catch { try? FileManager.default.removeItem(at: folder); throw error }
        return target
    }
    static func remove(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }
}
