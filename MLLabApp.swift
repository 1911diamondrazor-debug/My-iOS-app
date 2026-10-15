import SwiftUI

@main
struct MLLabApp: App {
    init() { ImportedFile.cleanPreviousSession() }
    var body: some Scene {
        WindowGroup { LabHome().tint(.cyan).preferredColorScheme(.dark) }
    }
}

struct LabHome: View {
    private let labs: [(String, String, String, String)] = [
        ("Vision", "viewfinder", "Read, recognize, segment, and understand images", "vision"),
        ("Language", "text.bubble", "Language, sentiment, entities, and embeddings", "language"),
        ("Translation", "character.bubble", "Translate English ↔ Spanish on device", "translation"),
        ("Speech & sound", "waveform", "Transcribe speech and classify recorded sounds", "audio"),
        ("Music Understanding", "music.note", "Explore six dimensions of an audio track", "music"),
        ("Core ML", "cpu", "Run a bundled model or bring your own", "coreml"),
        ("On-device updates", "arrow.triangle.2.circlepath", "Personalize a compatible model with labeled data", "update"),
        ("Core AI", "square.stack.3d.up", "Load and run your own iOS 27 tensor model", "coreai"),
        ("GPU compute", "square.grid.3x3", "Inspect a small neural graph on Metal", "gpu"),
        ("AR body tracking", "figure.walk", "Track a 3D skeleton with the rear camera", "ar"),
        ("Device & coverage", "checklist", "Requirements, framework scope, and limitations", "coverage")
    ]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Label("ON-DEVICE EXPLORER", systemImage: "sparkle"); Spacer(); Text("27") }
                        .font(.caption.monospaced()).foregroundStyle(.cyan)
                    Text("ML Lab").font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Discover what your iPhone can understand.")
                        .font(.title3).foregroundStyle(.secondary)
                    HStack { Label("Public APIs", systemImage: "checkmark.shield"); Label("Local processing", systemImage: "iphone") }
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(labs, id: \.3) { item in
                        NavigationLink(value: item.3) {
                            HStack(spacing: 16) {
                                Image(systemName: item.1).font(.title2).foregroundStyle(.cyan).frame(width: 40)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.0).font(.headline).foregroundStyle(.primary)
                                    Text(item.2).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }.padding(18).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22))
                        }.buttonStyle(.plain)
                    }
                }.padding(24)
            }.background(Color(.systemGroupedBackground))
                .navigationDestination(for: String.self) { route in
                    switch route {
                    case "vision": VisionLab()
                    case "language": LanguageLab()
                    case "translation": TranslationLab()
                    case "audio": AudioLab()
                    case "music": MusicLab()
                    case "coreml": CoreMLLab()
                    case "update": UpdateLab()
                    case "coreai": CoreAILab()
                    case "gpu": GPULab()
                    case "ar": ARLab()
                    default: CoverageView()
                    }
                }
        }
    }
}
