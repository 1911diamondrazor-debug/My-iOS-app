import SwiftUI
import NaturalLanguage

struct LanguageLab: View {
    @State private var text = "Matt and Katia visited Mexico City. The food was fantastic, and we loved the trip."
    @State private var comparison = "We enjoyed our vacation."
    @State private var output = ""
    @State private var timing: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Natural Language • Language detection, tokenization, lemmas, parts of speech, named entities, sentiment, and sentence embeddings.")
                TextEditor(text: $text).frame(height: 160).padding(8).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                TextField("Sentence to compare", text: $comparison).textFieldStyle(.roundedBorder)
                Button("Analyze text", action: analyze).buttonStyle(.borderedProminent).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ResultPanel(text: output, milliseconds: timing)
                LabNote("Model and language availability varies. Missing sentiment or embeddings are reported rather than replaced with invented scores. Embedding distance is cosine distance: smaller means more similar.")
            }.padding()
        }.navigationTitle("Language")
    }
    private func analyze() {
        let start = Date()
        let recognizer = NLLanguageRecognizer(); recognizer.processString(text)
        let language = recognizer.dominantLanguage
        var lines = ["Language: \(language?.rawValue ?? "unknown")"]
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3).sorted { $0.value > $1.value }
        lines += hypotheses.map { "  \($0.key.rawValue): \(String(format: "%.1f%%", $0.value * 100))" }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma, .nameType, .sentimentScore]); tagger.string = text
        if let language { tagger.setLanguage(language, range: text.startIndex..<text.endIndex) }
        for scheme in [NLTagScheme.lexicalClass, .lemma, .nameType] {
            lines.append("\n\(scheme.rawValue):")
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: scheme, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
                if let tag { lines.append("  \(text[range]): \(tag.rawValue)") }
                return true
            }
        }
        let score = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0
        lines.append("\nFirst paragraph sentiment (−1…1): \(score?.rawValue ?? "unavailable")")
        if let language, let embedding = NLEmbedding.sentenceEmbedding(for: language) {
            let distance = embedding.distance(between: text, and: comparison)
            lines.append("Sentence cosine distance: \(String(format: "%.4f", distance))")
        } else { lines.append("Sentence embedding unavailable for this language/device.") }
        let tokenizer = NLTokenizer(unit: .sentence); tokenizer.string = text
        lines.append("\nSentences:")
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in lines.append(String(text[range])); return true }
        output = lines.joined(separator: "\n"); timing = Date().timeIntervalSince(start) * 1000
    }
}
