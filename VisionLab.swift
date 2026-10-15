import SwiftUI
import PhotosUI
import Vision
import CoreImage

private enum VisionMode: String, CaseIterable, Identifiable {
    case text = "Read text", classify = "Classify image", faces = "Face landmarks", body = "Body pose"
    case hands = "Hand pose", animals = "Animals", segment = "Person mask", foreground = "Foreground mask"
    case saliency = "Attention saliency", objects = "Object saliency", rectangles = "Rectangles", barcode = "Barcodes"
    case contours = "Contours", quality = "Face quality", feature = "Image similarity", pose3D = "3D body pose"
    var id: String { rawValue }
}

struct VisionLab: View {
    @State private var selection: PhotosPickerItem?
    @State private var referenceSelection: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var referenceData: Data?
    @State private var mode: VisionMode = .text
    @State private var output = ""
    @State private var mask: UIImage?
    @State private var boxes: [CGRect] = []
    @State private var points: [CGPoint] = []
    @State private var busy = false
    @State private var timing: Double?
    @State private var imageLoad: Task<Void, Never>?
    @State private var referenceLoad: Task<Void, Never>?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LabNote("Vision • Select a photo, choose an experiment, and inspect model output. Images are normalized before analysis so overlays match their orientation.")
                PhotosPicker(selection: $selection, matching: .images) { Label("Choose photo", systemImage: "photo") }.disabled(busy)
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .overlay { GeometryReader { geometry in
                            Path { path in
                                for box in boxes { path.addRect(CGRect(x: box.minX * geometry.size.width, y: (1 - box.maxY) * geometry.size.height, width: box.width * geometry.size.width, height: box.height * geometry.size.height)) }
                                for point in points { path.addEllipse(in: CGRect(x: point.x * geometry.size.width - 3, y: (1 - point.y) * geometry.size.height - 3, width: 6, height: 6)) }
                            }.stroke(.cyan, lineWidth: 2)
                        }}.clipShape(RoundedRectangle(cornerRadius: 14))
                }
                Picker("Experiment", selection: $mode) { ForEach(VisionMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu).disabled(busy)
                if mode == .feature {
                    PhotosPicker(selection: $referenceSelection, matching: .images) { Label(referenceData == nil ? "Choose comparison photo" : "Comparison photo selected", systemImage: "photo.on.rectangle") }.disabled(busy)
                }
                Button(busy ? "Analyzing…" : "Run Vision", action: run).buttonStyle(.borderedProminent).disabled(imageData == nil || busy || (mode == .feature && referenceData == nil))
                if busy { ProgressView() }
                if let mask { Image(uiImage: mask).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 14)); LabNote("Model-generated grayscale mask or saliency heatmap.") }
                ResultPanel(text: output, milliseconds: timing)
            }.padding()
        }.navigationTitle("Vision")
            .onChange(of: selection) { _, item in
                imageLoad?.cancel()
                imageLoad = Task { do {
                    guard let data = try await item?.loadTransferable(type: Data.self) else { return }
                    let normalized = try await Task.detached { try VisionEngine.normalize(data) }.value
                    guard !Task.isCancelled else { return }
                    imageData = normalized; boxes = []; points = []; mask = nil; output = ""
                } catch { if !Task.isCancelled { output = error.localizedDescription } } }
            }
            .onChange(of: referenceSelection) { _, item in
                referenceLoad?.cancel()
                referenceLoad = Task { do {
                    guard let data = try await item?.loadTransferable(type: Data.self) else { return }
                    let normalized = try await Task.detached { try VisionEngine.normalize(data) }.value
                    guard !Task.isCancelled else { return }; referenceData = normalized
                } catch { if !Task.isCancelled { output = error.localizedDescription } } }
            }
            .onDisappear { imageLoad?.cancel(); referenceLoad?.cancel() }
    }
    private func run() {
        guard let imageData else { return }
        busy = true; output = ""; boxes = []; points = []; mask = nil; timing = nil
        let selectedMode = mode; let reference = referenceData
        Task {
            defer { busy = false }
            do {
                let result = try await Task.detached(priority: .userInitiated) { try VisionEngine.run(imageData, mode: selectedMode, reference: reference) }.value
                output = result.text; boxes = result.boxes; points = result.points
                mask = result.maskData.flatMap { UIImage(data: $0) }; timing = result.ms
            } catch { output = error.localizedDescription }
        }
    }
}

private struct VisionOutput {
    var text: String = ""
    var boxes: [CGRect] = []
    var points: [CGPoint] = []
    var maskData: Data?
    var ms: Double = 0
}

private enum VisionEngine {
    static func normalize(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data) else { throw LabError("The photo could not be decoded.") }
        let scale = min(1, 2048 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let result = normalized.pngData() else { throw LabError("Image normalization failed.") }
        return result
    }
    static func maskPNG(_ buffer: CVPixelBuffer) -> Data? {
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }
    static func run(_ data: Data, mode: VisionMode, reference: Data?) throws -> VisionOutput {
        let start = Date(); var result = VisionOutput()
        let handler = VNImageRequestHandler(data: data, orientation: .up)
        switch mode {
        case .text:
            let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            try handler.perform([request])
            result.text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            result.boxes = (request.results ?? []).map(\.boundingBox)
        case .classify:
            let request = VNClassifyImageRequest(); try handler.perform([request])
            result.text = (request.results ?? []).prefix(10).map { "\($0.identifier): \(String(format: "%.1f%%", $0.confidence * 100))" }.joined(separator: "\n")
        case .faces:
            let request = VNDetectFaceLandmarksRequest(); try handler.perform([request])
            let faces = request.results ?? []; result.boxes = faces.map(\.boundingBox)
            for face in faces {
                for point in face.landmarks?.allPoints?.normalizedPoints ?? [] {
                    result.points.append(CGPoint(x: face.boundingBox.minX + point.x * face.boundingBox.width, y: face.boundingBox.minY + point.y * face.boundingBox.height))
                }
            }
            result.text = "Faces: \(faces.count)\nLandmark points: \(result.points.count)"
        case .body:
            let request = VNDetectHumanBodyPoseRequest(); try handler.perform([request])
            for pose in request.results ?? [] { result.points += try pose.recognizedPoints(.all).values.filter { $0.confidence > 0.3 }.map(\.location) }
            result.text = "Bodies: \(request.results?.count ?? 0)\nConfident joints: \(result.points.count)"
        case .hands:
            let request = VNDetectHumanHandPoseRequest(); request.maximumHandCount = 4; try handler.perform([request])
            for hand in request.results ?? [] { result.points += try hand.recognizedPoints(.all).values.filter { $0.confidence > 0.3 }.map(\.location) }
            result.text = "Hands: \(request.results?.count ?? 0)\nConfident joints: \(result.points.count)"
        case .animals:
            let request = VNRecognizeAnimalsRequest(); try handler.perform([request])
            result.boxes = (request.results ?? []).map(\.boundingBox)
            result.text = (request.results ?? []).compactMap { $0.labels.first }.map { "\($0.identifier): \(String(format: "%.1f%%", $0.confidence * 100))" }.joined(separator: "\n")
        case .segment:
            let request = VNGeneratePersonSegmentationRequest(); request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8; try handler.perform([request])
            if let buffer = request.results?.first?.pixelBuffer { result.maskData = maskPNG(buffer) }
            result.text = "Person segmentation: \(request.results?.count ?? 0) mask(s). A mask may be empty when no person is visible."
        case .foreground:
            let request = VNGenerateForegroundInstanceMaskRequest(); try handler.perform([request])
            if let observation = request.results?.first {
                if !observation.allInstances.isEmpty {
                    result.maskData = maskPNG(try observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler))
                }
                result.text = "Foreground instances: \(observation.allInstances.count)"
            }
        case .saliency, .objects:
            let request: VNImageBasedRequest = mode == .saliency ? VNGenerateAttentionBasedSaliencyImageRequest() : VNGenerateObjectnessBasedSaliencyImageRequest()
            try handler.perform([request])
            if let observation = request.results?.first as? VNSaliencyImageObservation {
                result.maskData = maskPNG(observation.pixelBuffer); result.boxes = (observation.salientObjects ?? []).map(\.boundingBox)
                result.text = "Salient regions: \(result.boxes.count)"
            }
        case .rectangles:
            let request = VNDetectRectanglesRequest(); request.maximumObservations = 12; try handler.perform([request])
            result.boxes = (request.results ?? []).map(\.boundingBox); result.text = "Rectangles: \(result.boxes.count)"
        case .barcode:
            let request = VNDetectBarcodesRequest(); try handler.perform([request])
            result.boxes = (request.results ?? []).map(\.boundingBox)
            result.text = (request.results ?? []).map { "\($0.symbology.rawValue): \($0.payloadStringValue ?? "no text payload")" }.joined(separator: "\n")
        case .contours:
            let request = VNDetectContoursRequest(); try handler.perform([request])
            result.text = "Contours: \(request.results?.first?.contourCount ?? 0)"
        case .quality:
            let request = VNDetectFaceCaptureQualityRequest(); try handler.perform([request])
            result.boxes = (request.results ?? []).map(\.boundingBox)
            result.text = (request.results ?? []).enumerated().map { "Face \($0.offset + 1) capture quality: \($0.element.faceCaptureQuality?.stringValue ?? "unavailable")" }.joined(separator: "\n")
        case .feature:
            guard let reference else { throw LabError("Select a comparison image.") }
            let first = VNGenerateImageFeaturePrintRequest(); let second = VNGenerateImageFeaturePrintRequest()
            try handler.perform([first]); try VNImageRequestHandler(data: reference, orientation: .up).perform([second])
            guard let a = first.results?.first, let b = second.results?.first else { throw LabError("No feature print produced.") }
            var distance: Float = 0; try a.computeDistance(&distance, to: b)
            result.text = "Feature-print distance: \(distance)\nSmaller means more visually similar; this is not a probability."
        case .pose3D:
            let request = VNDetectHumanBodyPose3DRequest(); try handler.perform([request])
            result.text = "3D bodies: \(request.results?.count ?? 0)\n"
            for pose in request.results ?? [] {
                for (joint, point) in try pose.recognizedPoints(.all).sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                    let p = point.position.columns.3
                    result.text += "\(joint.rawValue): (\(p.x), \(p.y), \(p.z))\n"
                }
            }
        }
        if result.text.isEmpty { result.text = "No observations found. Try another photo." }
        result.ms = Date().timeIntervalSince(start) * 1000
        return result
    }
}
