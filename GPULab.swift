import SwiftUI
import Metal
import MetalPerformanceShadersGraph

struct GPULab: View {
    @State private var output = ""
    @State private var busy = false
    @State private var timing: Double?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Metal Performance Shaders Graph • Run a tiny dense layer and softmax. Weights are fixed for illustration; this is tensor computation, not a trained recognition model.")
                Text("[1, 2] × [[1, −1], [0.5, 0.5]]\n→ [2, 0]\n→ softmax ≈ [0.8808, 0.1192]").font(.body.monospaced())
                Button(busy ? "Running…" : "Run graph") {
                    busy = true
                    Task {
                        defer { busy = false }
                        do { let result = try await Task.detached { try GPUExperiment.run() }.value; output = result.0; timing = result.1 }
                        catch { output = error.localizedDescription; timing = nil }
                    }
                }.buttonStyle(.borderedProminent).disabled(busy)
                ResultPanel(text: output, milliseconds: timing)
                LabNote("A Metal device is required. Timing includes graph construction, compilation, execution, and synchronized output readback.")
            }.padding()
        }.navigationTitle("GPU compute")
    }
}
private enum GPUExperiment {
    static func bytes(_ values: [Float]) -> Data { values.withUnsafeBytes { Data($0) } }
    static func run() throws -> (String, Double) {
        guard let device = MTLCreateSystemDefaultDevice() else { throw LabError("No Metal device available.") }
        let start = Date(); let graph = MPSGraph()
        let input = graph.constant(bytes([1.0, 2.0]), shape: [1, 2], dataType: .float32)
        let weights = graph.constant(bytes([1.0, -1.0, 0.5, 0.5]), shape: [2, 2], dataType: .float32)
        let logits = graph.matrixMultiplication(primary: input, secondary: weights, name: "dense")
        let probabilities = graph.softMax(with: logits, axis: -1, name: "probabilities")
        guard let queue = device.makeCommandQueue() else { throw LabError("Could not create a Metal command queue.") }
        let results = graph.run(with: queue, feeds: [:], targetTensors: [probabilities], targetOperations: nil)
        guard let tensor = results[probabilities] else { throw LabError("The graph returned no tensor.") }
        var values = [Float](repeating: 0, count: 2)
        values.withUnsafeMutableBytes { buffer in tensor.mpsndarray().readBytes(buffer.baseAddress!, strideBytes: nil) }
        guard abs(values[0] - 0.880797) < 0.0001, abs(values[1] - 0.119203) < 0.0001 else { throw LabError("Graph output did not match the reference: \(values)") }
        return ("Device: \(device.name)\nShape: \(tensor.shape)\nProbabilities: \(values)\nReference check: passed", Date().timeIntervalSince(start) * 1000)
    }
}
