#if !targetEnvironment(macCatalyst)
import Foundation
import Combine
import AVFoundation
import UIKit
import os

private let logger = Logger(subsystem: "com.imops.construction", category: "Scanner")

// MARK: - ScannerViewModel
class ScannerViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var isProcessing: Bool = false

    var onImageCaptured: ((UIImage) -> Void)?

    // Hinweis: Der aktive BuildIQ-Pfad ist Foto-basiert (onImageCaptured → OCRService,
    // siehe BuildIQView). Die OCR-Texterkennung läuft dort und joint ALLE erkannten
    // Zeilen — Material UND Menge gehen so an /classify-material. Ein früher hier
    // angelegter Live-Frame-Pfad (updateRecognizedText/onTextFound) war nie verdrahtet
    // und am 18.6. entfernt.

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
