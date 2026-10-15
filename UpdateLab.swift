import SwiftUI
import CoreML
import CoreFoundation
import UniformTypeIdentifiers

struct UpdateLab: View {
    @State private var importing = false
    @State private var url: URL?
    @State private var json = "[\n  {\"input\": [1, 2], \"label\": \"example\"}\n]"
    @State private var output = ""
    @State private var busy = false
    @State private var updateTask: MLUpdateTask?
    @State private var trainedURL: URL?
    @State private var compiledURL: URL?
    @State private var schema = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Core ML Update • Import an updatable model and provide labeled examples matching its training schema. The bundled regression model is not updatable.")
                Button("Import updatable .mlmodel") { importing = true }.disabled(busy)
                Text(url?.lastPathComponent ?? "No updatable model selected").font(.caption)
                TextEditor(text: $json).font(.body.monospaced()).frame(height: 200).disabled(busy)
                LabNote("Training batch: a JSON array of objects. Features may be numbers, strings, or flat numeric arrays. Use the exact feature and label names required by your model.")
                Button(busy ? "Updating model…" : "Inspect & train", action: run).buttonStyle(.borderedProminent).disabled(busy || url == nil)
                if busy { ProgressView() }
                ResultPanel(text: output)
                if let trainedURL { ShareLink(item: trainedURL) { Label("Export updated model", systemImage: "square.and.arrow.up") } }
            }.padding()
        }.navigationTitle("On-device updates")
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "mlmodel") ?? .data, UTType(filenameExtension: "mlpackage") ?? .package], allowsMultipleSelection: false) { result in
                do { let replacement = try ImportedFile.copy(result); ImportedFile.remove(url); url = replacement }
                catch { output = error.localizedDescription }
            }
    }
    private func run() {
        guard let url else { return }; busy = true
        Task {
            do {
                let preparation = try await Task.detached { try UpdatePreparation.prepare(url, json: json) }.value
                compiledURL = preparation.url; schema = preparation.schema
                let task = try MLUpdateTask(forModelAt: preparation.url, trainingData: preparation.batch, configuration: nil) { context in
                    do {
                        if let error = context.task.error { throw error }
                        let folder = ImportedFile.root.appendingPathComponent(UUID().uuidString)
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        let destination = folder.appendingPathComponent("UpdatedModel.mlmodelc")
                        try context.model.write(to: destination)
                        let metrics = context.metrics.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
                        Task { @MainActor in
                            ImportedFile.remove(trainedURL); trainedURL = destination
                            output = "TRAINING SCHEMA\n\(schema)\n\nUpdate complete.\n\(metrics)\nExport the updated model, then import it in the Core ML lab to compare predictions."
                            cleanCompilation(); busy = false; updateTask = nil
                        }
                    } catch {
                        Task { @MainActor in output = error.localizedDescription; cleanCompilation(); busy = false; updateTask = nil }
                    }
                }
                updateTask = task; task.resume()
            } catch { output = error.localizedDescription; cleanCompilation(); busy = false }
        }
    }
    private func cleanCompilation() { if let compiledURL { try? FileManager.default.removeItem(at: compiledURL) }; compiledURL = nil }
}

private enum UpdatePreparation {
    static func prepare(_ source: URL, json: String) throws -> (url: URL, schema: String, batch: MLArrayBatchProvider) {
        let compiled = try MLModel.compileModel(at: source)
        do {
            let model = try MLModel(contentsOf: compiled)
            guard model.modelDescription.isUpdatable else { throw LabError("This model is not marked updatable. Export an updatable neural network or nearest-neighbor model.") }
            let training = model.modelDescription.trainingInputDescriptionsByName
            let schema = training.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
            do {
                guard let data = json.data(using: .utf8), let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], !rows.isEmpty, rows.count <= 1000 else { throw LabError("Provide 1–1,000 training rows.") }
                let providers = try rows.map { row -> MLDictionaryFeatureProvider in
                    var features: [String: MLFeatureValue] = [:]
                    for (name, description) in training {
                        guard let raw = row[name] else { throw LabError("Training row is missing \(name).") }
                        switch description.type {
                        case .string:
                            guard let value = raw as? String else { throw LabError("\(name) requires a string.") }; features[name] = MLFeatureValue(string: value)
                        case .double:
                            guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { throw LabError("\(name) requires a finite number.") }; features[name] = MLFeatureValue(double: value.doubleValue)
                        case .int64:
                            guard let value = raw as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(), let int = Int64(value.stringValue) else { throw LabError("\(name) requires an Int64 integer.") }; features[name] = MLFeatureValue(int64: int)
                        case .multiArray:
                            guard let values = raw as? [NSNumber], let constraint = description.multiArrayConstraint else { throw LabError("\(name) requires a numeric array.") }
                            let count = constraint.shape.reduce(1) { $0 * $1.intValue }
                            guard !constraint.shape.isEmpty, count > 0, count <= 1_000_000, count == values.count, values.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite }) else { throw LabError("\(name) requires \(count) finite values, with at most 1,000,000 elements.") }
                            let array = try MLMultiArray(shape: constraint.shape, dataType: constraint.dataType)
                            for (index, value) in values.enumerated() { array[index] = value }
                            features[name] = MLFeatureValue(multiArray: array)
                        default: throw LabError("Training input \(name) needs an adapter for \(description.type).")
                        }
                        if let value = features[name], !description.isAllowedValue(value) { throw LabError("Training feature \(name) fails its model constraints.") }
                    }
                    return try MLDictionaryFeatureProvider(dictionary: features)
                }
                return (compiled, schema, MLArrayBatchProvider(array: providers))
            } catch { throw LabError("TRAINING SCHEMA\n\(schema)\n\n\(error.localizedDescription)") }
        } catch { try? FileManager.default.removeItem(at: compiled); throw error }
    }
}
