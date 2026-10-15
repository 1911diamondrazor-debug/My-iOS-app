import SwiftUI
import Speech
import ARKit
import Metal

struct CoverageView: View {
    var body: some View {
        List {
            Section("This device") {
                LabeledContent("System", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                LabeledContent("Speech transcriber", value: SpeechTranscriber.isAvailable ? "Available" : "Unavailable")
                LabeledContent("AR body tracking", value: ARBodyTrackingConfiguration.isSupported ? "Available" : "Unavailable")
                LabeledContent("Metal", value: MTLCreateSystemDefaultDevice()?.name ?? "Unavailable")
                #if canImport(CoreAI)
                Text("Core AI compiled in; individual model support is checked when loading.")
                #else
                Text("Core AI missing from this build's SDK.")
                #endif
                #if canImport(MusicUnderstanding)
                Text("Music Understanding compiled in; audio analysis errors are shown at runtime.")
                #else
                Text("Music Understanding missing from this build's SDK.")
                #endif
            }
            Section("Included") {
                Text("Vision: 16 image experiments")
                Text("Natural Language: text analysis and sentence embeddings")
                Text("Translation: English ↔ Spanish")
                Text("SpeechAnalyzer / SpeechTranscriber: file and recorded speech")
                Text("Sound Analysis: built-in sound classifier")
                Text("Music Understanding: all six analysis dimensions")
                Text("Core ML: bundled regression, custom inputs, compute policy")
                Text("Core AI: custom stateless Float32 tensor model adapter")
                Text("MPSGraph: dense layer, softmax, GPU readback")
                Text("ARKit: live body skeleton")
                Text("Core ML Update: custom updatable model and training batch")
            }
            Section("Excluded by design") {
                Text("Siri, App Intents integration, Foundation Models, Apple Intelligence, Writing Tools, Image Playground, Private Cloud Compute.")
            }
            Section("Scope") {
                Text("This is a broad framework demonstration, not exhaustive coverage of every public ML API. See COVERAGE.md for implemented paths and remaining extensions.")
                Text("Create ML is a model-authoring tool for macOS. Core ML Update demonstrates supported on-device model updates; the provided regression model is not updatable.")
                Text("No analytics, account, backend, or third-party SDK. System-managed speech and translation downloads can require network access. The app makes no application-level network requests.")
                Text("Inference timing is wall-clock elapsed time, not a Neural Engine utilization measurement. New iOS 27 integrations need verification in Xcode 27 and on a physical device.")
            }
        }.navigationTitle("Device & coverage")
    }
}
