// On a Mac: xcrun swift Tools/VerifyModel.swift MLLab/Resources/TinyRegressor.mlmodel
import Foundation
import CoreML

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let compiled = try MLModel.compileModel(at: source)
defer { try? FileManager.default.removeItem(at: compiled) }
let config = MLModelConfiguration(); config.computeUnits = .cpuOnly
let model = try MLModel(contentsOf: compiled, configuration: config)
for x in [-10.0, 0.0, 2.0, 10.0] {
    let input = try MLDictionaryFeatureProvider(dictionary: ["x": MLFeatureValue(double: x)])
    let prediction = try model.prediction(from: input)
    guard let y = prediction.featureValue(for: "y")?.doubleValue, abs(y - (2 * x + 0.1)) < 1e-9 else {
        fatalError("Model prediction failed for x=\(x)")
    }
}
print("PASS: bundled Core ML model compiled and predicted four reference inputs.")
