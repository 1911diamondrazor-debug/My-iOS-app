import SwiftUI
import Translation

struct TranslationLab: View {
    @State private var text = "I’m learning Spanish. Tomorrow we’re going to the supermarket."
    @State private var toSpanish = true
    @State private var configuration: TranslationSession.Configuration?
    @State private var output = ""
    @State private var busy = false
    @State private var timing: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Translation • Local English ↔ Spanish translation. The system may ask to download language assets.")
                Toggle("English → Spanish", isOn: $toSpanish).disabled(busy)
                TextEditor(text: $text).frame(height: 180).disabled(busy)
                Button(busy ? "Translating…" : "Translate") {
                    busy = true
                    let source = Locale.Language(identifier: toSpanish ? "en" : "es")
                    let target = Locale.Language(identifier: toSpanish ? "es" : "en")
                    if configuration?.source == source && configuration?.target == target { configuration?.invalidate() }
                    else { configuration = .init(source: source, target: target) }
                }.buttonStyle(.borderedProminent).disabled(busy || text.isEmpty)
                ResultPanel(text: output, milliseconds: timing)
            }.padding()
        }.navigationTitle("Translation")
            .translationTask(configuration) { session in
                defer { busy = false }
                do {
                    try await session.prepareTranslation()
                    let start = Date()
                    output = try await session.translate(text).targetText
                    timing = Date().timeIntervalSince(start) * 1000
                } catch { output = error.localizedDescription; timing = nil }
            }
    }
}
