import Foundation

// MARK: - Product (Master Model)
struct Product: Identifiable {
    let id = UUID()
    let name: String
    
    var seubertData: SeubertItem?
    var clinicalAnalysis: ClinicalAnalysis?
    
    var isExternal: Bool { seubertData == nil }
    
    // --- DIE REPARATUR: Der universelle Initialisierer ---
    // Dieser erlaubt uns, ein Produkt nur mit Namen zu erstellen.
    // Die anderen Felder sind optional und standardmäßig 'nil'.
    init(name: String, seubert: SeubertItem? = nil, analysis: ClinicalAnalysis? = nil) {
        self.name = name
        self.seubertData = seubert
        self.clinicalAnalysis = analysis
    }
    
    // Wir behalten deine speziellen Initialisierer für die Abwärtskompatibilität
    init(seubert: SeubertItem) {
        self.name = seubert.name
        self.seubertData = seubert
        self.clinicalAnalysis = nil
    }
    
    init(name: String, analysis: ClinicalAnalysis) {
        self.name = name
        self.seubertData = nil
        self.clinicalAnalysis = analysis
    }
}

extension Product: Equatable {
    static func == (lhs: Product, rhs: Product) -> Bool {
        return lhs.name == rhs.name &&
               lhs.seubertData?.articleNr == rhs.seubertData?.articleNr
    }
}
