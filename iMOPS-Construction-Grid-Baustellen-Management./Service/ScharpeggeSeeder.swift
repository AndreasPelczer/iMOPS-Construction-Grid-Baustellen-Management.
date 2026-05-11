import Foundation
import CoreData

/// Liest scharpegge_katalog.csv aus dem App-Bundle und befüllt CDLexikonEntry einmalig.
struct ScharpeggeSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let key = "scharpegge_seeded_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        print("🐟 Scharpegge Seeder startet")

        guard let url = Bundle.main.url(forResource: "scharpegge_katalog", withExtension: "csv") else {
            print("🐟 CSV nicht gefunden")
            return
        }
        print("🐟 CSV gefunden: \(url)")

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("🐟 CSV konnte nicht gelesen werden")
            return
        }

        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        print("🐟 CSV Zeilen (inkl. Header): \(lines.count)")

        // Erste Zeile ist Header — überspringen
        var count = 0
        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ";")
            guard cols.count >= 5 else { continue }

            let artikelnummer = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let name         = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let kategorie    = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let beschreibung = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let gebinde      = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !artikelnummer.isEmpty, !name.isEmpty else { continue }

            let entry = CDLexikonEntry(context: context)
            entry.code        = artikelnummer
            entry.name        = name
            entry.kategorie   = "Scharpegge – \(kategorie)"
            entry.beschreibung = beschreibung
            entry.details     = gebinde
            count += 1
        }

        print("🐟 Einträge erstellt: \(count)")

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print("🐟 Seeder erfolgreich abgeschlossen")
        } catch {
            print("🐟 Seeder Fehler beim Speichern: \(error)")
            context.rollback()
        }
    }
}
