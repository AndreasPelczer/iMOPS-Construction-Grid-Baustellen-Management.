import Foundation

struct SeubertItem: Codable, Identifiable {
    // Die Artikelnummer dient als eindeutige ID
    var id: String { articleNr }
    
    let articleNr: String         // Spalte 0
    let name: String              // Spalte 1
    let category: String          // Spalte 2
    let allergenCodes: String     // Spalte 3 (z.B. "A,G,L")
    let additiveCodes: String     // Spalte 4 (z.B. "2,3")
    let supplier: String          // Spalte 5
    let cookingInstruction: String // Spalte 6
}
