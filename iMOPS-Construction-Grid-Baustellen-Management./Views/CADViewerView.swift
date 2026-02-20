import SwiftUI
import SceneKit
import ModelIO
import SceneKit.ModelIO

/// 3D-Viewer fuer USDZ/OBJ/DAE/STL Dateien via SceneKit.
/// Unterstuetzt Drehen, Zoomen und Pan per Gesten.
/// STL-Dateien werden via ModelIO geladen.
struct CADViewerView: View {
    let fileURL: URL
    let fileName: String

    @State private var loadError: String?

    var body: some View {
        Group {
            if let error = loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Datei konnte nicht geladen werden")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                SceneKitView(fileURL: fileURL, onError: { error in
                    loadError = error
                })
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - SceneKit UIViewRepresentable

struct SceneKitView: UIViewRepresentable {
    let fileURL: URL
    let onError: (String) -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true // Drehen, Zoomen, Pan
        scnView.backgroundColor = UIColor.systemBackground

        do {
            let ext = fileURL.pathExtension.lowercased()
            let scene: SCNScene

            // STL/PLY: ModelIO verwenden (SCNScene kann diese nicht direkt laden)
            if ext == "stl" || ext == "ply" {
                let asset = MDLAsset(url: fileURL)
                scene = SCNScene(mdlAsset: asset)
            } else {
                scene = try SCNScene(url: fileURL, options: [
                    .checkConsistency: true
                ])
            }
            scnView.scene = scene

            // Kamera auf Modell ausrichten
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.automaticallyAdjustsZRange = true

            // Bounding-Box berechnen fuer optimale Kameraposition
            let (minBound, maxBound) = scene.rootNode.boundingBox
            let center = SCNVector3(
                (minBound.x + maxBound.x) / 2,
                (minBound.y + maxBound.y) / 2,
                (minBound.z + maxBound.z) / 2
            )
            let size = SCNVector3(
                maxBound.x - minBound.x,
                maxBound.y - minBound.y,
                maxBound.z - minBound.z
            )
            let maxDimension = max(size.x, max(size.y, size.z))
            let distance = maxDimension * 2.0

            cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
            cameraNode.look(at: center)
            scene.rootNode.addChildNode(cameraNode)

            scnView.pointOfView = cameraNode
        } catch {
            DispatchQueue.main.async {
                onError(error.localizedDescription)
            }
        }

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
