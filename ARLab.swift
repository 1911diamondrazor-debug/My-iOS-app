import SwiftUI
import ARKit
import SceneKit
import AVFoundation

struct ARLab: View {
    @State private var active = false
    @State private var permissionJob: Task<Void, Never>?
    @State private var status = "Camera starts only when you tap Start."
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LabNote("ARKit • Real-time 3D body tracking with the rear camera. Ask someone to stand fully in view, with good lighting and space around them.")
            if ARBodyTrackingConfiguration.isSupported {
                if active { ARBodySurface(status: $status).clipShape(RoundedRectangle(cornerRadius: 18)) }
                else { ContentUnavailableView("Ready to track", systemImage: "figure.walk", description: Text("Tracks a body skeleton on supported hardware.")) }
                Button(active ? "Stop camera" : "Start camera") {
                    if active { active = false }
                    else {
                        permissionJob = Task {
                            let granted = await AVCaptureDevice.requestAccess(for: .video)
                            guard !Task.isCancelled else { return }
                            if granted { active = true } else { status = "Camera access denied. Enable it in Settings." }
                        }
                    }
                }.buttonStyle(.borderedProminent)
            } else { ContentUnavailableView("Unsupported device", systemImage: "camera", description: Text("ARKit body tracking requires supported physical hardware.")) }
            ResultPanel(text: status)
        }.padding().navigationTitle("AR body tracking")
            .onDisappear { permissionJob?.cancel(); active = false }
            .onChange(of: scenePhase) { _, phase in if phase != .active { permissionJob?.cancel(); active = false } }
    }
}

private struct ARBodySurface: UIViewRepresentable {
    @Binding var status: String
    func makeCoordinator() -> Coordinator { Coordinator(status: $status) }
    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(); view.session.delegate = context.coordinator
        context.coordinator.view = view
        view.session.run(ARBodyTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
        return view
    }
    func updateUIView(_ uiView: ARSCNView, context: Context) {}
    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) { uiView.session.pause(); uiView.session.delegate = nil }
    final class Coordinator: NSObject, ARSessionDelegate {
        var status: Binding<String>
        weak var view: ARSCNView?
        private var nodes: [SCNNode] = []
        init(status: Binding<String>) { self.status = status }
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { update(anchors) }
        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { update(anchors) }
        func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
            if anchors.contains(where: { $0 is ARBodyAnchor }) { clear(); status.wrappedValue = "Body left the camera view." }
        }
        func session(_ session: ARSession, didFailWithError error: Error) { status.wrappedValue = error.localizedDescription }
        func sessionWasInterrupted(_ session: ARSession) { status.wrappedValue = "Camera session interrupted. Stop and restart tracking." }
        private func clear() { nodes.forEach { $0.removeFromParentNode() }; nodes = [] }
        private func update(_ anchors: [ARAnchor]) {
            guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).first, let view else { return }
            clear()
            let skeleton = body.skeleton
            var count = 0
            for index in 0..<skeleton.jointModelTransforms.count where skeleton.isJointTracked(index) {
                let transform = body.transform * skeleton.jointModelTransforms[index]
                let sphere = SCNSphere(radius: 0.015); sphere.firstMaterial?.diffuse.contents = UIColor.cyan
                let node = SCNNode(geometry: sphere); node.simdTransform = transform
                view.scene.rootNode.addChildNode(node); nodes.append(node); count += 1
            }
            status.wrappedValue = "Body tracked: \(body.isTracked)\nTracked joints: \(count)\nEstimated scale: \(String(format: "%.2f", body.estimatedScaleFactor))"
        }
    }
}
