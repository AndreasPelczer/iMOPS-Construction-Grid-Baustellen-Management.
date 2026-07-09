import Foundation
import CoreData

/// Ein LV-Vorschlag aus einer Dokument-Auswertung (`/extract-doc` → LV).
/// Wird im „Aus Unterlagen übernehmen"-Review bestätigt, bevor er zur `LVPosition` wird.
struct VorschlagLVPosition: Identifiable {
    let id = UUID()
    var bezeichnung: String
    var menge: Double
    var einheit: String
    var kostenGruppe: String
    var quellDatei: String
    var hinweis: String?
    var istSelektiert: Bool = true
}

/// Übersetzt gespeicherte Dokument-Auswertungen in LV-Vorschläge — die „Brücke"
/// extract-doc → LV. Aktuell: **Erschließung**. Weitere Doctypes (Bodengutachten,
/// B-Plan, Wohnfläche) kommen später als je ein weiterer `case` dazu — die Übernahme
/// und der Review-Screen bleiben gleich.
enum AuswertungLVMapper {

    static func vorschlaege(aus auswertungen: [ExtractDocResult]) -> [VorschlagLVPosition] {
        auswertungen.flatMap { vorschlaege(aus: $0) }
    }

    static func vorschlaege(aus res: ExtractDocResult) -> [VorschlagLVPosition] {
        switch res.doctypeErkannt {
        case "erschliessung": return erschliessung(res)
        default:              return []   // andere Doctypes: eigene Schritte, folgen später
        }
    }

    // MARK: - Erschließung → Hausanschluss-Positionen

    private static func erschliessung(_ res: ExtractDocResult) -> [VorschlagLVPosition] {
        (res.felder["medien"]?.alleArrayElemente ?? []).map { m in
            let medium = m["medium"]?.skalarText ?? "Anschluss"
            let dim    = m["dimension"]?.skalarText
            let laenge = m["laenge_m"]?.zahl
            let bez = "Hausanschluss \(medium)" + (dim.map { " \($0)" } ?? "")

            var hinweise: [String] = []
            if let h = m["hinweis"]?.skalarText, h != "—", !h.isEmpty { hinweise.append(h) }
            if laenge == nil { hinweise.append("Länge fehlt – bitte nachtragen") }

            return VorschlagLVPosition(
                bezeichnung: bez,
                menge: laenge ?? 0,
                einheit: "m",
                kostenGruppe: "200",     // DIN 276: Erschließung — im Review änderbar
                quellDatei: res.quelle,
                hinweis: hinweise.isEmpty ? nil : hinweise.joined(separator: " · ")
            )
        }
    }

    // MARK: - Übernahme ins LV

    /// Legt aus den bestätigten Vorschlägen echte `LVPosition`en an (nur `istSelektiert`).
    /// Herkunft: geschätzt (aus Dokument gefolgert) + Quell-Dateiname am Doku-Bezug.
    @discardableResult
    static func uebernehmen(_ vorschlaege: [VorschlagLVPosition],
                            in context: NSManagedObjectContext,
                            event: Event) -> [LVPosition] {
        var neu: [LVPosition] = []
        var n = 0
        for v in vorschlaege where v.istSelektiert {
            n += 1
            let pos = LVPosition(context: context)
            pos.posNr = "E.\(n)"                 // „E" = aus Unterlage übernommen
            pos.bezeichnung = v.bezeichnung
            pos.menge = v.menge
            pos.einheit = v.einheit
            pos.kostenGruppeNummer = v.kostenGruppe
            pos.mengenQuelleRaw = "schaetzung"   // aus Dokument gefolgert → geschätzt (ehrlich)
            pos.setValue(v.quellDatei, forKey: "dokuName")
            pos.event = event
            neu.append(pos)
        }
        if !neu.isEmpty { try? context.save() }
        return neu
    }
}
