import CoreData
import Foundation

// MARK: - ExtractPlanMapper
// Scheibe 2 der App-Brücke (Welle 4): das JSON von POST /extract-plan
// (ExtractPlanResult) wird auf die CoreData-Entität LVPosition abgebildet.
//
// Reine Abbildung: legt LVPosition-Objekte im übergebenen Context an, speichert
// NICHT selbst (der Aufrufer entscheidet über save()). Bestellzeilen werden über
// ihr `bezug_posNr` der passenden LV-Position zugeordnet und füllen artikelNummer
// + lieferant (die Mat-Nr stammt aus dem abZ-Resolver der Box).

enum ExtractPlanMapper {

    /// Erzeugt LVPosition-Objekte aus dem Extraktions-Ergebnis.
    /// - Parameters:
    ///   - result: dekodierte Antwort von /extract-plan
    ///   - context: Ziel-Context (Objekte werden hier angelegt, nicht gespeichert)
    ///   - event: optionales Projekt, dem die Positionen zugeordnet werden
    /// - Returns: die angelegten LVPosition-Objekte in Plan-Reihenfolge
    @discardableResult
    static func mapPositions(_ result: ExtractPlanResult,
                             into context: NSManagedObjectContext,
                             event: Event? = nil) -> [LVPosition] {
        // Bestellzeile je LV-Position (erste Zeile je bezug_posNr gewinnt)
        var bestellByPos: [String: ExtractBestellzeile] = [:]
        for zeile in result.bestellliste {
            guard let ref = zeile.bezugPosNr, bestellByPos[ref] == nil else { continue }
            bestellByPos[ref] = zeile
        }

        return result.lvPositionen.map { p in
            let pos = LVPosition(context: context)
            pos.posNr = p.posNr
            pos.bezeichnung = p.bezeichnung
            pos.menge = p.menge ?? 0               // "manuell"-Positionen: menge=null
            pos.einheit = p.einheit
            pos.kostenGruppeNummer = p.kg          // DIN 276
            pos.event = event
            if let zeile = bestellByPos[p.posNr] {
                pos.artikelNummer = zeile.matnr     // Xella-Mat-Nr (abZ-Resolver)
                pos.lieferant = zeile.lieferant
            }
            return pos
        }
    }

    /// Wandelt das Extraktions-Ergebnis in die Vorschau-Struktur des LV-Imports
    /// (ParsedLVPosition) — für den „prüfen/abwählen/importieren"-Screen.
    /// confidence: harte Statik-Positionen 0,95 · Schätzungen 0,6.
    static func toParsed(_ result: ExtractPlanResult) -> [ParsedLVPosition] {
        var bestellByPos: [String: ExtractBestellzeile] = [:]
        for zeile in result.bestellliste {
            guard let ref = zeile.bezugPosNr, bestellByPos[ref] == nil else { continue }
            bestellByPos[ref] = zeile
        }
        return result.lvPositionen.map { p in
            let zeile = bestellByPos[p.posNr]
            return ParsedLVPosition(
                posNr: p.posNr,
                bezeichnung: p.bezeichnung,
                menge: p.menge ?? 0,
                einheit: p.einheit ?? "",
                confidence: p.quelle == "schaetzung" ? 0.6 : 0.95,
                kostenGruppe: p.kg,
                artikelNummer: zeile?.matnr,
                lieferant: zeile?.lieferant
            )
        }
    }
}
