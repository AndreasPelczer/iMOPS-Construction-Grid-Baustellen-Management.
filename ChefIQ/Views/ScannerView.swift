import SwiftUI
import AVFoundation

struct ScannerView: View {
    @Environment(\.dismiss) var dismiss
    var hub: IntelligenceHub
    @StateObject private var scannerVM = ScannerViewModel()
    
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    @State private var shutterEffect = false

    var body: some View {
        ZStack {
            ScannerDevicePreview(session: session)
                .ignoresSafeArea()
            
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.blue, lineWidth: 4)
                .frame(width: 280, height: 200)
            
            if shutterEffect {
                Color.white.opacity(0.8).ignoresSafeArea()
            }
            
            VStack {
                HStack {
                    Button("Abbrechen") { dismiss() }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    Spacer()
                }
                .padding()
                Spacer()
                captureButton
            }
            .padding(.bottom, 40)
        }
        .onAppear {
                    // 1. Kamera starten
                    setupCamera()
                    
                    // 2. Verbindung zum Hub herstellen
                    // Sobald der Scanner ein Bild fertig verarbeitet hat, wird dieser Block gefeuert
                    scannerVM.onImageCaptured = { uiImage in
                        Task { @MainActor in
                            // Das Bild in den Snapshot-Cache des Hubs legen und analysieren
                            await hub.processImage(uiImage)
                            
                            // Den Scanner automatisch schließen, wenn das Bild "im Kasten" ist
                            dismiss()
                        }
                    }
                }
                .onDisappear {
                    // Wichtig: Kamera stoppen, um Akku zu sparen
                    session.stopRunning()
                }
    }

    // ... Rest der Hilfsfunktionen bleibt gleich ...
    
    private func setupCamera() {
        // Check: Sind wir auf einem echten Gerät?
        #if targetEnvironment(simulator)
        print("🤖 Simulator-Modus: Kamera-Hardware wird übersprungen.")
        return
        #else
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            session.commitConfiguration()
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        } catch {
            print("❌ Kamera Setup Fehler: \(error)")
        }
        #endif
    }
    
    private var captureButton: some View {
        Button(action: { takePhoto() }) {
            ZStack {
                Circle().fill(Color.white).frame(width: 70, height: 70)
                Circle().stroke(Color.blue, lineWidth: 4).frame(width: 80, height: 80)
                Image(systemName: "camera.fill").foregroundColor(.blue).font(.system(size: 30))
            }
            .shadow(radius: 10)
        }
    }
    
    private func takePhoto() {
        withAnimation(.easeInOut(duration: 0.1)) { shutterEffect = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shutterEffect = false }

        #if targetEnvironment(simulator)
        // SIMULATOR LOGIK: Wir nehmen ein statisches Bild
        // Tipp: Füge ein Bild namens "TestProdukt" zu deinen Assets hinzu
        let testImage = UIImage(systemName: "fork.knife") ?? UIImage()
        
        Task { @MainActor in
            // Wir füttern den Hub direkt mit dem Testbild
            await hub.processImage(testImage)
            dismiss()
        }
        #else
        // ECHTES GERÄT: Normaler Foto-Prozess
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: scannerVM)
        #endif
    }
}

// MARK: - Vorschau (Bleibt identisch)
struct ScannerDevicePreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
