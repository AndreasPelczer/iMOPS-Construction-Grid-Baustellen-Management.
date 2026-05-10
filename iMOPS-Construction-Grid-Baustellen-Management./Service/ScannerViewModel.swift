#if !targetEnvironment(macCatalyst)
import Foundation
import Vision
import AVFoundation
import UIKit
import os

private let logger = Logger(subsystem: "com.imops.construction", category: "Scanner")

// MARK: - ScannerViewModel
class ScannerViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var recognizedText: String = ""
    @Published var isScanning: Bool = true
    @Published var isProcessing: Bool = false

    var onTextFound: ((String) -> Void)?
    var onImageCaptured: ((UIImage) -> Void)?

    func updateRecognizedText(_ results: [VNRecognizedTextObservation]) {
        let detectedStrings = results.compactMap { $0.topCandidates(1).first?.string }
        if let firstMatch = detectedStrings.first(where: { $0.count > 3 }) {
            DispatchQueue.main.async {
                self.recognizedText = firstMatch
                self.isScanning = false
                self.onTextFound?(firstMatch)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        DispatchQueue.main.async { self.isProcessing = false }

        if let error = error {
            logger.error("Fehler beim Foto-Empfang: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            logger.error("Bilddaten konnten nicht extrahiert werden.")
            return
        }

        guard let image = UIImage(data: imageData) else {
            logger.error("UIImage konnte nicht erstellt werden.")
            return
        }

        DispatchQueue.main.async {
            self.onImageCaptured?(image)
            logger.info("Foto erfolgreich verarbeitet")
        }
    }
}
#endif
