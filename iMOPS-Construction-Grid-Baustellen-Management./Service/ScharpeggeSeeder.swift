import Foundation
import CoreData

/// Liest scharpegge_katalog.csv aus dem App-Bundle und befüllt CDLexikonEntry einmalig.
struct ScharpeggeSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let key = "scharpegge_seeded_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        guard let url = Bundle.main.url(forResource: "scharpegge_katalog", withExtension: "csv"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Erste Zeile ist Header — überspringen
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
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            context.rollback()
        }
    }
}
