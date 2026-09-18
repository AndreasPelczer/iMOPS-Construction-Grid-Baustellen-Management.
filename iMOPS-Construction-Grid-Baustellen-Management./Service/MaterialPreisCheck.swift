import Foundation
import CoreData

/// Der Stammdaten-Preis-Check: welche Materialien braucht der Mops (aus den Baustein-
/// Material-Links), und welche haben schon DEINEN Preis?
///
/// In der Bauwelt gibt keiner Preise raus (Bulk kommt auf Anfrage). Darum ist die einzige
/// ehrliche Quelle DEINE eigene Rechnung. Dieser Check zeigt die Lücken: wo noch ein Preis
/// fehlt, damit du beim Reinkommen einer Rechnung sofort weißt, was einzutragen ist —
/// Nachweis statt Behauptung.
enum MaterialPreisCheck {

    /// Status eines Materials im Preisgefüge.
    enum Status: Int {
        case eigen      // grün: dein Preis steht in den Stammdaten (KalkMaterial)
        case richtwert  // blau: nur ein Katalog-Richtwert (Praxis) — brauchbar, aber nicht deiner
        case offen      // rot: gar kein Preis — Rechnung her und eintragen
    }

    struct Zeile: Identifiable {
        let id = UUID()
        let name: String            // "Schotter 0/32"
        let einheit: String         // "t"
        let richtpreis: Double?     // aus dem Baustein-Material-Link (Katalog)
        let eigenerPreis: Double?   // aus KalkMaterial (deine Stammdaten)
        let lieferant: String?      // dein Lieferant, falls hinterlegt
        var status: Status {
            if eigenerPreis != nil { return .eigen }
            if richtpreis != nil { return .richtwert }
            return .offen
        }
    }

    struct Bilanz {
        let zeilen: [Zeile]
        var eigen: Int     { zeilen.filter { $0.status == .eigen }.count }
        var richtwert: Int { zeilen.filter { $0.status == .richtwert }.count }
        var offen: Int     { zeilen.filter { $0.status == .offen }.count }
        var gesamt: Int    { zeilen.count }
    }

    /// Alle Materialien, die die Bausteine per Material-Link brauchen, mit ihrem Preis-Status.
    /// (Distinct über den normalisierten Namen — dasselbe Schüttgut nur einmal.)
    static func pruefe(in ctx: NSManagedObjectContext) -> Bilanz {
        var gesehen = Set<String>()
        var zeilen: [Zeile] = []
        for b in STLBKatalog.shared.alle() {
            guard let m = b.material else { continue }
            let key = LeistungskatalogService.normalisiere(m.text)
            guard !key.isEmpty, !gesehen.contains(key) else { continue }
            gesehen.insert(key)
            let eigen = eigenerPreisUndLieferant(fuer: m.text, in: ctx)
            zeilen.append(Zeile(name: m.text, einheit: m.einheit,
                                richtpreis: m.richtpreis,
                                eigenerPreis: eigen?.preis, lieferant: eigen?.lieferant))
        }
        return Bilanz(zeilen: zeilen.sorted { $0.name.localizedCompare($1.name) == .orderedAscending })
    }

    /// Dein Preis + Lieferant aus den Stammdaten (günstigster, falls mehrere Lieferanten).
    private static func eigenerPreisUndLieferant(fuer name: String, in ctx: NSManagedObjectContext)
        -> (preis: Double, lieferant: String?)? {
        let ziel = LeistungskatalogService.normalisiere(name)
        guard !ziel.isEmpty else { return nil }
        let alle = (try? ctx.fetch(KalkMaterial.fetchRequest())) ?? []
        let treffer = alle.filter { LeistungskatalogService.normalisiere($0.name) == ziel && $0.preisProEinheit > 0 }
        guard let guenstigster = treffer.min(by: { $0.preisProEinheit < $1.preisProEinheit }) else { return nil }
        return (guenstigster.preisProEinheit, guenstigster.lieferant)
    }
}
