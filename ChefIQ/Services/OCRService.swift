//
//  OCRService.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import Vision
import UIKit

// MARK: - OCRService
/// Der "Sensor-Droide", der Text in Bildern erkennt.
class OCRService {
    func performOCR(on image: UIImage, completion: @escaping ([VNRecognizedTextObservation]) -> Void) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            completion(observations)
        }
        
        request.recognitionLevel = .accurate // Maximale Präzision
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}