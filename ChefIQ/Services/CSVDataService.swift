import Foundation

class CSVDataService {
    private var inventory: [SeubertItem] = []

    init() { loadLocalDatabase() }

    private func loadLocalDatabase() {
        guard let path = Bundle.main.path(forResource: "Produkte", ofType: "csv") else {
            print("❌ R2-ALARM: Datei 'Produkte.csv' fehlt!")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let rows = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            for row in rows.dropFirst() { // Kopfzeile überspringen
                let columns = row.components(separatedBy: ";")
                
                // Wir prüfen auf genau 7 Spalten gemäß deiner id;name;category... Vorlage
                if columns.count >= 7 {
                    let item = SeubertItem(
                        articleNr: columns[0].trimmingCharacters(in: .whitespacesAndNewlines),
                        name: columns[1].trimmingCharacters(in: .whitespacesAndNewlines),
                        category: columns[2].trimmingCharacters(in: .whitespacesAndNewlines),
                        allergenCodes: columns[3].trimmingCharacters(in: .whitespacesAndNewlines),
                        additiveCodes: columns[4].trimmingCharacters(in: .whitespacesAndNewlines),
                        supplier: columns[5].trimmingCharacters(in: .whitespacesAndNewlines),
                        cookingInstruction: columns[6].trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    inventory.append(item)
                }
            }
            print("📦 R2: \(inventory.count) Produkte mit Allergen-Codes geladen.")
        } catch {
            print("❌ CSV Fehler: \(error)")
        }
    }
    
    // ... restliche Funktionen (filterInventory, findProduct) bleiben gleich
    func filterInventory(query: String) -> [SeubertItem] {
        let lower = query.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.isEmpty { return [] }
        return inventory.filter { $0.name.lowercased().contains(lower) || $0.articleNr.contains(lower) }.prefix(10).map { $0 }
    }

    func findProduct(query: String) -> SeubertItem? {
        let lowerQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        return inventory.first { $0.name.lowercased().contains(lowerQuery) || $0.articleNr.contains(lowerQuery) }
    }
}
