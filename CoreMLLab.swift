import SwiftUI
import CoreML
import CoreFoundation
import UniformTypeIdentifiers

private enum ComputeChoice: String, CaseIterable, Identifiable {
    case all = "Automatic", cpu = "CPU only", cpuGPU = "CPU + GPU", cpuANE = "CPU + Neural Engine"
    var id: String { rawValue }
    var units: MLComputeUnits {
        switch self { case .all: .all; case .cpu: .cpuOnly; case .cpuGPU: .cpuAndGPU; case .cpuANE: .cpuAndNeuralEngine }
    }
}

struct CoreMLLab: View {
    @State private var x = 2.0
    @State private var compute: ComputeChoice = .all
    @State private var importer = false
    @State private var modelURL: URL?
    @State private var inputJSON = "{\"x\": 2.0}"
    @State private var output = ""
    @State private var busy = false
    @State private var timing: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Core ML • Run the bundled linear regression model y = 2x + 0.1, or import a compatible model. The bundled model is an educational example, not a real-world predictor.")
                Picker("Allowed compute units", selection: $compute) { ForEach(ComputeChoice.allCases) { Text($0.rawValue).tag($0) } }.disabled(busy)
                LabNote("Compute units are a scheduling policy, not proof that the GPU or Neural Engine ran. The bundled GLM usually runs on CPU. Use Instruments for actual execution attribution.")
                if modelURL == nil {
                    Text("x = \(x, specifier: "%.2f")")
                    Slider(value: $x, in: -10...10).disabled(busy)
                } else {
                    Text(modelURL!.lastPathComponent).font(.caption)
                    TextEditor(text: $inputJSON).font(.system(.body, design: .monospaced)).frame(height: 160).disabled(busy)
                    LabNote("Input JSON supports required Double, Int64, String, and fixed-shape numeric MultiArray features. Supply arrays as flat numeric lists; check shapes in the model schema. Image, dictionary, sequence, state, and flexible-shape inputs need a custom adapter.")
                }
                HStack {
                    Button("Import model") { importer = true }
                    if modelURL != nil { Button("Use bundled model") { ImportedFile.remove(modelURL); modelURL = nil } }
                }.disabled(busy)
                Button(busy ? "Running…" : "Inspect & predict", action: run).buttonStyle(.borderedProminent).disabled(busy)
                ResultPanel(text: output, milliseconds: timing)
            }.padding()
        }.navigationTitle("Core ML")
            .fileImporter(isPresented: $importer, allowedContentTypes: [UTType(filenameExtension: "mlmodel") ?? .data, UTType(filenameExtension: "mlpackage") ?? .package, UTType(filenameExtension: "mlmodelc") ?? .folder], allowsMultipleSelection: false) { result in
                do { let replacement = try ImportedFile.copy(result); ImportedFile.remove(modelURL); modelURL = replacement; output = "Imported. Inspect & predict to view schema and validate input." }
                catch { output = error.localizedDescription }
            }.onDisappear { if !busy { ImportedFile.remove(modelURL) } }
    }
    private func run() {
        let url = modelURL ?? Bundle.main.url(forResource: "TinyRegressor", withExtension: "mlmodel") ?? Bundle.main.url(forResource: "TinyRegressor", withExtension: "mlmodelc")
        guard let url else { output = "Bundled model missing."; return }
        let json = modelURL == nil ? "{\"x\": \(x)}" : inputJSON
        let units = compute.units; busy = true; timing = nil
        Task {
            defer { busy = false }
            do {
                let result = try await Task.detached { try CoreMLEngine.run(url: url, json: json, units: units) }.value
                output = result.0; timing = result.1
            } catch { output = error.localizedDescription }
        }
    }
}

private enum CoreMLEngine {
    static func run(url: URL, json: String, units: MLComputeUnits) throws -> (String, Double) {
        let compiled = url.pathExtension == "mlmodelc" ? url : try MLModel.compileModel(at: url)
        defer { if compiled != url { try? FileManager.default.removeItem(at: compiled) } }
        let config = MLModelConfiguration(); config.computeUnits = units
        let startLoad = Date(); let model = try MLModel(contentsOf: compiled, configuration: config)
        let loadMS = Date().timeIntervalSince(startLoad) * 1000
        let description = model.modelDescription
        let schema = description.inputDescriptionsByName.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        do {
            guard let data = json.data(using: .utf8), let values = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw LabError("Input must be a JSON object.") }
            var features: [String: MLFeatureValue] = [:]
            for (name, feature) in description.inputDescriptionsByName {
                guard let value = values[name] else {
                    if feature.isOptional { continue }; throw LabError("Missing required input: \(name)")
                }
                switch feature.type {
                case .double:
                    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { throw LabError("\(name) must be a finite number.") }
                    features[name] = MLFeatureValue(double: number.doubleValue)
                case .int64:
                    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), let integer = Int64(number.stringValue) else { throw LabError("\(name) must be an Int64 integer.") }
                    features[name] = MLFeatureValue(int64: integer)
                case .string:
                    guard let string = value as? String else { throw LabError("\(name) must be a string.") }; features[name] = MLFeatureValue(string: string)
                case .multiArray:
                    guard let constraint = feature.multiArrayConstraint, let numbers = value as? [NSNumber], !constraint.shape.isEmpty else { throw LabError("\(name) requires a fixed-shape numeric array.") }
                    let count = constraint.shape.reduce(1) { $0 * $1.intValue }
                    guard count > 0, count <= 1_000_000, numbers.count == count, numbers.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite }) else { throw LabError("\(name) requires exactly \(count) finite numeric values (limit 1,000,000).") }
                    let array = try MLMultiArray(shape: constraint.shape, dataType: constraint.dataType)
                    for (index, number) in numbers.enumerated() { array[index] = number }
                    features[name] = MLFeatureValue(multiArray: array)
                default: throw LabError("Input type \(feature.type) requires a custom adapter; this demo does not fabricate it.")
                }
                if let provided = features[name], !feature.isAllowedValue(provided) { throw LabError("\(name) does not satisfy the model's feature constraints.") }
            }
            let provider = try MLDictionaryFeatureProvider(dictionary: features)
            let start = Date(); let prediction = try model.prediction(from: provider)
            let ms = Date().timeIntervalSince(start) * 1000
            let results = prediction.featureNames.sorted().map { name -> String in
                guard let value = prediction.featureValue(for: name) else { return "\(name): missing" }
                if let array = value.multiArrayValue {
                    return "\(name) shape \(array.shape): " + (0..<min(array.count, 32)).map { array[$0].stringValue }.joined(separator: ", ") + (array.count > 32 ? " …" : "")
                }
                return "\(name): \(value)"
            }.joined(separator: "\n")
            return ("INPUT SCHEMA\n\(schema)\n\nLoad: \(String(format: "%.1f", loadMS)) ms\n\nPREDICTION\n\(results)", ms)
        } catch { throw LabError("INPUT SCHEMA\n\(schema)\n\n\(error.localizedDescription)") }
    }
}
