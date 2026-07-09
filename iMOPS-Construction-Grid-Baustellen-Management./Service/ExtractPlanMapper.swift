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

    /// Effektive DIN-276-Kostengruppe: die gelieferte KG, sonst heuristisch aus der
    /// Bezeichnung (`KGZuordnungsService`, Keyword→KG), sonst Sammel-„300".
    /// Greift NUR, wenn keine KG geliefert wird — echte KGs (Mops/Statik) bleiben unberührt.
    /// Ohne diesen Schritt landen extern per Vision/JSON erzeugte LVs (kg=null) alle in „300".
    static func effektiveKG(kg: String?, bezeichnung: String) -> String {
        if let kg, !kg.trimmingCharacters(in: .whitespaces).isEmpty { return kg }
        return KGZuordnungsService.shared.ordneZu(materialName: bezeichnung) ?? "300"
    }

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
            pos.kostenGruppeNummer = effektiveKG(kg: p.kg, bezeichnung: p.bezeichnung)  // DIN 276 (kg==nil → heuristisch)
            pos.mengenQuelleRaw = p.quelle ?? "manuell"   // gemessen/geschätzt (Welle-9-Fundament)
            pos.seite = p.seite.map(NSNumber.init(value:))   // Weg B: Seite im Quell-PDF (nil bleibt nil)
            pos.event = event
            if let zeile = bestellByPos[p.posNr] {
                pos.artikelNummer = zeile.matnr     // Xella-Mat-Nr (abZ-Resolver)
                pos.lieferant = zeile.lieferant
            }
            legeTeilgewichteAn(unter: pos, teilgewichte: p.teilgewichte, in: context)  // Schritt 4
            return pos
        }
    }

    /// Schritt 4: Legt für die Einzelgewichte einer Plan-Summe je einen Unterpunkt (Beleg)
    /// unter die Position — so wird sichtbar, WOHER die Summe kommt. Nur ab 2 Teilen; die
    /// Unterpunkte zählen dank Deckel-Regel (`zaehlbarePositionen`) nicht doppelt.
    static func legeTeilgewichteAn(unter deckel: LVPosition, teilgewichte: [Double]?,
                                   in context: NSManagedObjectContext) {
        guard let teile = teilgewichte, teile.count >= 2 else { return }
        for (i, g) in teile.enumerated() {
            let kind = LVPosition(context: context)
            kind.bezeichnung = "Teilgewicht \(i + 1)"
            kind.menge = g
            kind.einheit = "kg"
            kind.kostenGruppeNummer = deckel.kostenGruppeNummer
            kind.mengenQuelleRaw = deckel.mengenQuelleRaw
            kind.seite = deckel.seite
            kind.event = deckel.event
            // Datei-Bezug erben, damit auch die Belege ins Quell-PDF springen können.
            if let dn = deckel.value(forKey: "dokuName") { kind.setValue(dn, forKey: "dokuName") }
            if let dp = deckel.value(forKey: "dokuPath") { kind.setValue(dp, forKey: "dokuPath") }
            kind.deckel = deckel        // wird Unterpunkt → automatischer Deckel
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
                kostenGruppe: effektiveKG(kg: p.kg, bezeichnung: p.bezeichnung),
                artikelNummer: zeile?.matnr,
                lieferant: zeile?.lieferant,
                seite: p.seite,          // Weg B: Seite im Quell-PDF
                quelle: p.quelle,        // rohe Herkunft für mengenQuelleRaw
                teilgewichte: p.teilgewichte  // Schritt 4: Summe aufgliedern
            )
        }
    }
}
