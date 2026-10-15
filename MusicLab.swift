import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
#if canImport(MusicUnderstanding)
import MusicUnderstanding
#endif

struct MusicLab: View {
    @State private var importing = false
    @State private var url: URL?
    @State private var output = ""
    @State private var busy = false
    @State private var timing: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Music Understanding • iOS 27 • Analyze rhythm, key, loudness, pace, structure, and instrument activity. Choose a local unprotected audio file.")
                Button("Choose audio track") { importing = true }.disabled(busy)
                Text(url?.lastPathComponent ?? "No track selected").font(.caption)
                Button(busy ? "Analyzing…" : "Analyze all six dimensions", action: run).buttonStyle(.borderedProminent).disabled(busy || url == nil)
                if busy { ProgressView("Long tracks may take a while.") }
                ResultPanel(text: output, milliseconds: timing)
                LabNote("The structured result is shown as JSON so you can inspect every timestamp and measurement. DRM-protected Apple Music streams are not imported.")
            }.padding()
        }.navigationTitle("Music Understanding")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                do { let replacement = try ImportedFile.copy(result); ImportedFile.remove(url); url = replacement }
                catch { output = error.localizedDescription }
            }.onDisappear { if !busy { ImportedFile.remove(url) } }
    }
    private func run() {
        guard let url else { return }; busy = true; timing = nil
        Task {
            defer { busy = false }
            do {
                let start = Date()
                #if canImport(MusicUnderstanding)
                let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
                let session = try await MusicUnderstandingSession(asset: asset)
                let result = try await session.analyze()
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                output = String(decoding: try encoder.encode(result), as: UTF8.self)
                timing = Date().timeIntervalSince(start) * 1000
                #else
                throw LabError("Build this project with an iOS 27 SDK that includes MusicUnderstanding.")
                #endif
            } catch { output = error.localizedDescription }
        }
    }
}
