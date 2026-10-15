import SwiftUI
import UniformTypeIdentifiers
#if canImport(CoreAI)
import CoreAI
#endif

struct CoreAILab: View {
    @State private var importing = false
    @State private var url: URL?
    @State private var functionName = "main"
    @State private var inputName = "input"
    @State private var outputName = "prediction"
    @State private var shapeText = "1,4"
    @State private var valuesText = "1,2,3,4"
    @State private var output = ""
    @State private var busy = false
    @State private var timing: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Core AI • iOS 27 • Import your own .aimodel. This adapter runs a stateless function with one Float32 tensor input and one Float32 tensor output. No Apple Intelligence model is used.")
                Button("Import .aimodel") { importing = true }.disabled(busy)
                Text(url?.lastPathComponent ?? "Requires a compatible model asset").font(.caption)
                Group {
                    TextField("Function name", text: $functionName)
                    TextField("Input name", text: $inputName)
                    TextField("Output name", text: $outputName)
                    TextField("Shape, e.g. 1,4", text: $shapeText)
                    TextField("Flat values, e.g. 1,2,3,4", text: $valuesText)
                }.textFieldStyle(.roundedBorder).disabled(busy).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button(busy ? "Specializing & running…" : "Run tensor model", action: run).buttonStyle(.borderedProminent).disabled(busy || url == nil)
                if busy { ProgressView() }
                ResultPanel(text: output, milliseconds: timing)
                LabNote("First use includes device specialization and model loading. Match the function signature shown by Xcode's model viewer. Multi-input, stateful, image, and non-Float32 models require another adapter.")
            }.padding()
        }.navigationTitle("Core AI")
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "aimodel") ?? .data], allowsMultipleSelection: false) { result in
                do { let replacement = try ImportedFile.copy(result); ImportedFile.remove(url); url = replacement }
                catch { output = error.localizedDescription }
            }.onDisappear { if !busy { ImportedFile.remove(url) } }
    }
    private func run() {
        guard let url else { return }
        let shapeParts = shapeText.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let valueParts = valuesText.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        let shape = shapeParts.compactMap(Int.init); let values = valueParts.compactMap(Float.init)
        var count = 1
        for dimension in shape {
            guard dimension > 0, dimension <= 1_000_000, count <= 1_000_000 / dimension else { output = "Positive dimensions required; input is limited to 1,000,000 elements."; return }
            count *= dimension
        }
        guard !shape.isEmpty, shape.count == shapeParts.count, values.count == valueParts.count, count == values.count, values.allSatisfy(\.isFinite) else { output = "Provide valid positive dimensions and exactly the matching number of finite Float32 values."; return }
        let selectedFunction = functionName; let selectedInput = inputName; let selectedOutput = outputName
        busy = true; timing = nil
        Task {
            defer { busy = false }
            do {
                #if canImport(CoreAI)
                let start = Date()
                let model = try await AIModel(contentsOf: url)
                guard let function = try model.loadFunction(named: selectedFunction) else { throw LabError("Function not found: \(selectedFunction)") }
                guard let descriptor = function.descriptor.inputDescriptor(of: selectedInput), case .ndArray(let arrayDescriptor) = descriptor, arrayDescriptor.scalarType == .float32 else { throw LabError("Named input must be a Float32 NDArray.") }
                let expected = arrayDescriptor.shape
                guard expected.count == shape.count, zip(expected, shape).allSatisfy({ $0.0 == -1 || $0.0 == $0.1 }) else { throw LabError("Input shape must match \(expected).") }
                let input = NDArray(scalars: values, shape: shape)
                var outputs = try await function.run(inputs: [selectedInput: input])
                guard let value = outputs.remove(selectedOutput), let tensor = value.ndArray, tensor.scalarType == .float32 else { throw LabError("Named output is missing or is not a Float32 tensor.") }
                let view = tensor.view(as: Float.self)
                guard let elements = view.contiguousElements else { throw LabError("Output has non-contiguous storage; use a model-specific view adapter.") }
                var preview: [String] = []
                for index in 0..<min(elements.count, 32) { preview.append(String(elements[index])) }
                output = "Shape: \(tensor.shape)\nFloat32 output:\n" + preview.joined(separator: ", ") + (elements.count > 32 ? " …" : "")
                timing = Date().timeIntervalSince(start) * 1000
                #else
                throw LabError("Build with the iOS 27 SDK to enable CoreAI.")
                #endif
            } catch { output = error.localizedDescription }
        }
    }
}
