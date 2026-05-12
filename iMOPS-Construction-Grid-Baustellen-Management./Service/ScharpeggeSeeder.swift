import Foundation
import CoreData

/// Liest scharpegge_katalog.csv aus dem App-Bundle und befüllt CDLexikonEntry einmalig.
struct ScharpeggeSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        print("🐟 Scharpegge Seeder startet")

        // Alle bestehenden Einträge löschen damit kein alter Datenmüll bleibt
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CDLexikonEntry")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: deleteRequest)
        batchDelete.resultType = .resultTypeCount
        do {
            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            print("🐟 Alte Einträge gelöscht: \(result?.result ?? 0)")
            context.reset()
        } catch {
            print("🐟 Fehler beim Löschen: \(error)")
        }

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

        var count = 0
        for line in lines.dropFirst() {
            // maxSplits:4 → genau 5 Felder; Semikolons in Beschreibung/Gebinde bleiben erhalten
            let cols = line.split(separator: ";", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 5 else { continue }

            let artikelnummer = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let name         = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let kategorie    = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let beschreibung = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let gebinde      = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !artikelnummer.isEmpty, !name.isEmpty else { continue }

            let entry = CDLexikonEntry(context: context)
            entry.code         = artikelnummer
            entry.name         = name
            entry.kategorie    = "Scharpegge: \(kategorie)"
            entry.beschreibung = beschreibung
            entry.details      = gebinde
            count += 1
        }

        print("🐟 Einträge erstellt: \(count)")

        do {
            try context.save()
            print("🐟 Seeder erfolgreich abgeschlossen")
        } catch {
            print("🐟 Seeder Fehler beim Speichern: \(error)")
            context.rollback()
        }
    }
}
