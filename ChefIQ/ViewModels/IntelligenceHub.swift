import Foundation
import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
class IntelligenceHub {
    // MARK: - Parkplätze (Bestand)
    var allProducts: [OmniProduct] = []
    var activeProduct: OmniProduct?
    var lastCapturedImage: UIImage? = nil
    var activeLexikon: LexikonEintrag?
    var activeSeubert: SeubertItem?
    var isLoading: Bool = false
    var nutritionNews: String = "Lade operative Fakten..."

    // NAVIGATION
    var showAIDetail: Bool = false
    var showSeubertDetail: Bool = false

    // MARK: - GASTRO-GRID OMNI ADD-ONS
    var detectedSizeMM: Double = 0.0
    var cookingInstruction: String = ""

    private let aiService = GeminiClinicalService()
    private let csvService = CSVDataService()
    private let ocrService = OCRService()

    init() {
        fetchDailyNutritionNews()
        loadOmniData()
    }

    // MARK: - DIE HANNES-LOGIK
    /// Verarbeitet Geometrie-Daten vom Scanner
    func processGeometry(objectPixels: Double, referencePixels: Double) {
        let idCardWidth: Double = 85.6 // mm
        let size = (objectPixels / referencePixels) * idCardWidth
        self.detectedSizeMM = size

        if size > 0 && size < 200 {
            if size < 8.0 {
                self.cookingInstruction = "MAILLARD-PEAK: 220°C | 8 Min. (Scharf anbraten!)"
            } else {
                self.cookingInstruction = "CORE-FOCUS: 165°C | 25 Min. (Sanft garen.)"
            }
        } else {
            self.cookingInstruction = "REFERENZ-FEHLER: Bitte Dienstausweis flach auflegen."
        }
    }

    func triggerMumpsAnalysis(for product: OmniProduct) {
        let temp = product.baseTemperature
        let time = product.baseTime

        if temp > 100 {
            self.cookingInstruction = "MAILLARD-PROZESS: Bei \(temp)°C für \(time) Min. garen. (Ziel: Kruste & Aroma)"
        } else if temp > 0 {
            self.cookingInstruction = "SANFT-GAREN: Bei \(temp)°C für \(time) Min. (Ziel: Saftigkeit/Struktur)"
        } else {
            self.cookingInstruction = "KÜHLKETTE: Produkt bei 2-4°C halten. Keine thermische Bearbeitung."
        }

        self.activeProduct = product
        self.showAIDetail = true
    }

    // MARK: - BESTANDS-PFADE (Optimiert)
    func runLexikonSuche(begriff: String) async {
        self.isLoading = true

        if let match = allProducts.first(where: { $0.name.lowercased().contains(begriff.lowercased()) }) {
            self.activeProduct = match
            self.cookingInstruction = "Fokus: \(match.baseTemperature)°C | \(match.baseTime) Min."
        }

        self.activeLexikon = LexikonEintrag(name: begriff)
        self.showAIDetail = true
        fetchDailyNutritionNews(for: begriff)
        await fetchFullAnalysis(for: begriff)
        self.isLoading = false
    }

    func loadOmniData() {
        guard let url = Bundle.main.url(forResource: "Produkt", withExtension: "json") else {
            print("iMOPS-CHEFIQ: Produkt.json fehlt im Bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let geladene = try JSONDecoder().decode([OmniProduct].self, from: data)
            self.allProducts = geladene
            print("iMOPS-CHEFIQ: \(geladene.count) OmniProdukte geladen.")
        } catch {
            print("iMOPS-CHEFIQ Decoder-Fehler: \(error)")
        }
    }

    private func fetchFullAnalysis(for name: String) async {
        do {
            let result = try await aiService.fetchAnalysis(for: name)
            var neueQuellen: [QuellenInfo] = []

            if let aiSources = result.sources {
                neueQuellen = aiSources.map { QuellenInfo(quelle: $0.q, aussage: $0.a) }
            }

            if var current = self.activeLexikon {
                current.analysis = result
                current.quellenFakten = neueQuellen
                self.activeLexikon = current
            }
        } catch {
            print("iMOPS-CHEFIQ Analyse-Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - SCANNER INTEGRATION
    func processImage(_ image: UIImage) async {
        self.isLoading = true
        self.lastCapturedImage = image
        ocrService.performOCR(on: image) { [weak self] observations in
            let detectedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            Task { @MainActor in
                if !detectedText.isEmpty { await self?.runLexikonSuche(begriff: detectedText) }
                else { self?.isLoading = false }
            }
        }
    }

    func fetchDailyNutritionNews(for query: String? = nil) {
        Task {
            let topic = query ?? "Gastro-Physik"
            let response = (try? await aiService.fetchRawText(prompt: "Nenne einen Fakt über Maillard-Reaktion oder Garphysik bei \(topic) (max 2 Sätze).")) ?? "Bereit am Pass."
            self.nutritionNews = response
        }
    }

    // MARK: - CSV/Seubert Inventar
    func searchSeubert(query: String) -> [SeubertItem] {
        return csvService.filterInventory(query: query)
    }

    func findSeubertProduct(query: String) -> SeubertItem? {
        return csvService.findProduct(query: query)
    }
}
