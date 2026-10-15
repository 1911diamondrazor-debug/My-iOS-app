import SwiftUI
import AVFoundation
import Speech
import SoundAnalysis
import UniformTypeIdentifiers

@MainActor
final class Recorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var recording = false
    @Published var errorText = ""
    private var recorder: AVAudioRecorder?
    private(set) var url: URL?
    func start() async {
        guard await AVAudioApplication.requestRecordPermission() else { errorText = "Microphone access denied. Enable it in Settings."; return }
        guard !Task.isCancelled else { return }
        do {
            ImportedFile.remove(url)
            let folder = ImportedFile.root.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            url = folder.appendingPathComponent("recording.caf")
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default); try session.setActive(true)
            let recorder = try AVAudioRecorder(url: url!, settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false])
            recorder.delegate = self; recorder.prepareToRecord()
            guard recorder.record(forDuration: 30) else { throw LabError("Unable to start recording.") }
            self.recorder = recorder; recording = true; errorText = ""
        } catch { errorText = error.localizedDescription; stop() }
    }
    func stop() {
        recorder?.stop(); recorder = nil; recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in self.stop(); if !flag { self.errorText = "Recording failed." } }
    }
}

struct AudioLab: View {
    @StateObject private var recorder = Recorder()
    @State private var url: URL?
    @State private var importing = false
    @State private var output = ""
    @State private var busy = false
    @State private var localeID = "en-US"
    @State private var timing: Double?
    @State private var job: Task<Void, Never>?
    @State private var permissionJob: Task<Void, Never>?
    @State private var leftScreen = false
    @Environment(\.scenePhase) private var scenePhase
    private var input: URL? { url ?? recorder.url }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("SpeechAnalyzer + SpeechTranscriber • On-device file transcription. Sound Analysis • Built-in sound classification. Record up to 30 seconds or import an audio file.")
                Button("Import audio") { importing = true }.disabled(busy || recorder.recording)
                Button(recorder.recording ? "Stop recording" : "Record microphone") {
                    if recorder.recording { recorder.stop() }
                    else { ImportedFile.remove(url); url = nil; permissionJob = Task { await recorder.start() } }
                }.buttonStyle(.bordered).disabled(busy)
                if recorder.recording { Label("Recording · maximum 30 seconds", systemImage: "record.circle").foregroundStyle(.red) }
                if !recorder.errorText.isEmpty { Text(recorder.errorText).foregroundStyle(.orange) }
                Text(input?.lastPathComponent ?? "No audio selected").font(.caption)
                Picker("Speech language", selection: $localeID) { Text("English (US)").tag("en-US"); Text("Spanish (Mexico)").tag("es-MX") }.disabled(busy)
                HStack {
                    Button("Transcribe") { run(speech: true) }
                    Button("Classify sounds") { run(speech: false) }
                }.buttonStyle(.borderedProminent).disabled(input == nil || busy || recorder.recording)
                if busy { ProgressView("Processing audio…") }
                ResultPanel(text: output, milliseconds: timing)
                LabNote("Speech models may require an initial Apple-managed download. Unsupported languages or hardware produce an error. Imported audio stays in temporary app storage until you leave this screen.")
            }.padding()
        }.navigationTitle("Speech & sound")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                do { let replacement = try ImportedFile.copy(result); ImportedFile.remove(url); url = replacement; output = "" }
                catch { output = error.localizedDescription }
            }
            .onAppear { leftScreen = false }
            .onDisappear { leftScreen = true; permissionJob?.cancel(); job?.cancel(); recorder.stop(); if !busy { ImportedFile.remove(url); ImportedFile.remove(recorder.url) } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { permissionJob?.cancel(); recorder.stop() } }
    }
    private func run(speech: Bool) {
        guard let input else { return }; busy = true; output = ""; timing = nil
        let selectedLocale = localeID
        job = Task {
            defer { busy = false; if leftScreen { ImportedFile.remove(url); ImportedFile.remove(recorder.url) } }
            let start = Date()
            do {
                let result: String
                if speech { result = try await SpeechEngine.transcribe(input, locale: Locale(identifier: selectedLocale)) }
                else { result = try await Task.detached { try SoundEngine.analyze(input) }.value }
                try Task.checkCancellation()
                output = result; timing = Date().timeIntervalSince(start) * 1000
            } catch { if !Task.isCancelled { output = error.localizedDescription } }
        }
    }
}

private enum SpeechEngine {
    static func transcribe(_ url: URL, locale: Locale) async throws -> String {
        guard SpeechTranscriber.isAvailable else { throw LabError("SpeechTranscriber is unavailable on this device.") }
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else { throw LabError("This speech language is unsupported.") }
        let module = SpeechTranscriber(locale: supported, preset: .transcription)
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) { try await installation.downloadAndInstall() }
        try Task.checkCancellation()
        let analyzer = SpeechAnalyzer(modules: [module])
        let collector = Task { () throws -> String in
            var pieces: [String] = []
            for try await result in module.results { pieces.append(String(result.text.characters)) }
            return pieces.joined(separator: " ")
        }
        do {
            let file = try AVAudioFile(forReading: url)
            if let last = try await analyzer.analyzeSequence(from: file) { try await analyzer.finalizeAndFinish(through: last) }
            else { await analyzer.cancelAndFinishNow() }
            let text = try await collector.value
            return text.isEmpty ? "No speech recognized." : text
        } catch {
            collector.cancel(); await analyzer.cancelAndFinishNow(); throw error
        }
    }
}

private final class SoundObserver: NSObject, SNResultsObserving {
    private let lock = NSLock()
    private var scores: [String: (Double, Int)] = [:]
    private var failure: Error?
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        lock.lock(); defer { lock.unlock() }
        for item in result.classifications {
            let old = scores[item.identifier] ?? (0, 0)
            scores[item.identifier] = (old.0 + item.confidence, old.1 + 1)
        }
    }
    func request(_ request: SNRequest, didFailWithError error: Error) { lock.lock(); failure = error; lock.unlock() }
    func requestDidComplete(_ request: SNRequest) {}
    func report() throws -> String {
        lock.lock(); defer { lock.unlock() }
        if let failure { throw failure }
        let ranked = scores.map { ($0.key, $0.value.0 / Double($0.value.1)) }.sorted { $0.1 > $1.1 }.prefix(10)
        return ranked.isEmpty ? "No sound classifications produced." : "Mean confidence across analysis windows:\n" + ranked.map { "\($0.0): \(String(format: "%.1f%%", $0.1 * 100))" }.joined(separator: "\n")
    }
}
private enum SoundEngine {
    static func analyze(_ url: URL) throws -> String {
        let analyzer = try SNAudioFileAnalyzer(url: url)
        let observer = SoundObserver()
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        try analyzer.add(request, withObserver: observer)
        analyzer.analyze()
        return try observer.report()
    }
}
