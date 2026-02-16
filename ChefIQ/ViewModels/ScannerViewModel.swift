//
//  ScannerViewModel.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//

import Foundation
import Vision
import AVFoundation
import UIKit

// MARK: - ScannerViewModel
/// Verantwortlich für die Steuerung der Kamera, die Texterkennung via Vision und das Verarbeiten von Foto-Captures.
class ScannerViewModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    @Published var recognizedText: String = ""
    @Published var isScanning: Bool = true
    @Published var isProcessing: Bool = false
    
    // Die Verbindung zur Zentrale (IntelligenceHub)
    var onTextFound: ((String) -> Void)?
    var onImageCaptured: ((UIImage) -> Void)?
    
    // MARK: - Live OCR Logik
    // Diese Funktion wird vom OCRService aufgerufen, wenn Text erkannt wurde
    func updateRecognizedText(_ results: [VNRecognizedTextObservation]) {
        // Wir nehmen die besten Treffer der Texterkennung
        let detectedStrings = results.compactMap { $0.topCandidates(1).first?.string }
        
        // Wir suchen nach dem ersten relevanten Begriff (z.B. Produktname oder Nummer)
        if let firstMatch = detectedStrings.first(where: { $0.count > 3 }) {
            DispatchQueue.main.async {
                self.recognizedText = firstMatch
                self.isScanning = false // Stoppe Scan, wenn etwas gefunden wurde
                self.onTextFound?(firstMatch)
            }
        }
    }
    
  
    // MARK: - Photo Capture Delegate
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            
            if let error = error {
                print("❌ R2-Fehler beim Foto-Empfang: \(error.localizedDescription)")
                return
            }
            
            // --- HIER FEHLTE DIE VARIABLE 'imageData' ---
            // Wir holen die Rohdaten aus dem 'photo' Objekt
            guard let imageData = photo.fileDataRepresentation() else {
                print("❌ Fehler: Bilddaten konnten nicht extrahiert werden.")
                return
            }
            
            // Jetzt machen wir aus den Rohdaten ein UIImage
            guard let image = UIImage(data: imageData) else {
                print("❌ Fehler: UIImage konnte nicht erstellt werden.")
                return
            }
            
            // Melde das fertige Bild an die Zentrale (IntelligenceHub) zurück
            DispatchQueue.main.async {
                self.onImageCaptured?(image)
                print("✅ Foto erfolgreich an Hub gesendet")
            }
        }
    }

