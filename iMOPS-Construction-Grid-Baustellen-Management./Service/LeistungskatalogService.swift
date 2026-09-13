import Foundation
import CoreData

// MARK: - LeistungskatalogService
//
// Der wachsende Aufwandswert-Katalog (Bogen 1). Zwei Bewegungen:
//   ERNTEN  `merke(...)` legt eine Leistung als Baustein ab bzw. aktualisiert sie —
//           aufgerufen, wenn am Knoten ein Prof-Aufwandswert übernommen wird.
//   PICKEN  `finde(...)` / `alle(...)` holen einen Baustein zurück, damit der nächste
//           gleichnamige Knoten den Wert übernehmen kann, OHNE den Prof erneut zu fragen.
//
// Dedup-Schlüssel = normalisierte Leistung + normalisierte Einheit. So wird aus „Baustelle
// absichern" nicht bei jedem Tippfehler ein neuer Baustein, und derselbe Knoten aktualisiert
// seinen Baustein statt ihn zu verdoppeln.
enum LeistungskatalogService {

    /// Vergleichsform: klein, ohne Diakritika, getrimmt. Dieselbe Regel für Leistung und Einheit.
    static func normalisiere(_ text: String?) -> String {
        (text ?? "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Findet den Baustein zu einer Leistung + Einheit, oder nil.
    static func finde(leistung: String, einheit: String,
                      in ctx: NSManagedObjectContext) -> Leistungsbaustein? {
        let zielL = normalisiere(leistung)
        let zielE = normalisiere(einheit)
        guard !zielL.isEmpty else { return nil }
        // Case/Diakritik-Vergleich macht Core Data nicht verlässlich über SQLite — darum
        // grob per Fetch vorfiltern und in Swift genau vergleichen (der Katalog ist klein).
        let req: NSFetchRequest<Leistungsbaustein> = Leistungsbaustein.fetchRequest()
        let alle = (try? ctx.fetch(req)) ?? []
        return alle.first { normalisiere($0.leistung) == zielL && normalisiere($0.einheit) == zielE }
    }

    /// Ernten: Baustein anlegen oder (bei Treffer) die Stunden aktualisieren.
    /// Gibt den Baustein zurück. `verwendungen` bleibt beim Aktualisieren erhalten.
    @discardableResult
    static func merke(leistung: String, einheit: String,
                      maurer: Double, helfer: Double,
                      kostenGruppeNummer: String? = nil,
                      quelle: String = "prof",
                      in ctx: NSManagedObjectContext) -> Leistungsbaustein {
        let baustein = finde(leistung: leistung, einheit: einheit, in: ctx)
            ?? {
                let neu = Leistungsbaustein(context: ctx)
                neu.id = UUID()
                neu.erstelltAm = Date()
                neu.verwendungen = 0
                return neu
            }()
        baustein.leistung = leistung.trimmingCharacters(in: .whitespacesAndNewlines)
        baustein.einheit = einheit.trimmingCharacters(in: .whitespacesAndNewlines)
        baustein.maurerStunden = maurer
        baustein.helferStunden = helfer
        if let kg = kostenGruppeNummer, !kg.isEmpty { baustein.kostenGruppeNummer = kg }
        baustein.quelle = quelle
        return baustein
    }

    /// Picken quittieren: Zähler hoch, damit häufig genutzte Bausteine oben stehen.
    static func benutzt(_ baustein: Leistungsbaustein) {
        baustein.verwendungen += 1
    }

    // MARK: - Aufwandswert als Lohn schreiben (gemeinsam für Knoten & Picker)

    /// Schreibt den Aufwandswert (Maurer/Helfer h je Einheit) als zwei Lohnzeilen auf eine
    /// Position. Idempotent: vorhandene Maurer/Helfer-Zeilen werden ersetzt, nicht gestapelt.
    /// Lohnsatz kommt aus den Stammdaten (`Lohnsatz`), mit Rückfall auf die Seeder-Werte —
    /// so trägt die Kalkulation immer eine Zahl, nie 0. Genutzt von `KnotenKalkulationView`
    /// (Prof/Katalog) UND `LVBausteinAuswahlView` (Auswahl aus dem gelernten Katalog).
    static func schreibeAufwandAlsLohn(maurer: Double, helfer: Double,
                                       auf pos: LVPosition, in ctx: NSManagedObjectContext) {
        for pl in pos.lohnArray where pl.qualifikation == "Maurer" || pl.qualifikation == "Helfer" {
            ctx.delete(pl)
        }
        lohnEintrag("Maurer", maurer, pos, ctx)
        lohnEintrag("Helfer", helfer, pos, ctx)
    }

    private static func lohnEintrag(_ qualifikation: String, _ stunden: Double,
                                    _ pos: LVPosition, _ ctx: NSManagedObjectContext) {
        let pl = PositionLohn(context: ctx)
        pl.id = UUID()
        pl.qualifikation = qualifikation
        pl.stunden = stunden
        pl.stundenBruttoEK = bruttoEK(fuer: qualifikation, in: ctx)
        pl.position = pos
    }

    /// Brutto-EK-Stundensatz aus den Stammdaten (`Lohnsatz`), Rückfall = Seeder-Werte.
    static func bruttoEK(fuer qualifikation: String, in ctx: NSManagedObjectContext) -> Double {
        let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        req.predicate = NSPredicate(format: "qualifikation ==[c] %@", qualifikation)
        req.fetchLimit = 1
        if let satz = (try? ctx.fetch(req))?.first { return satz.berechnungBruttoEK }
        switch qualifikation {
        case "Maurer": return 28.50 * 1.65
        case "Helfer": return 18.50 * 1.55
        default:       return 0
        }
    }

    /// Vorschlagsliste zu einem Knoten-/Leistungstext: Bausteine, die zum Text passen
    /// (Leistung enthält ihn oder umgekehrt), zuerst — dann die häufigsten. Gekappt.
    /// Ohne Text: schlicht die häufigsten. So sieht Andreas beim Öffnen gleich die Auswahl.
    static func vorschlaege(fuer leistung: String, limit: Int = 12,
                            in ctx: NSManagedObjectContext) -> [Leistungsbaustein] {
        let sortiert = alle(in: ctx)
        let q = normalisiere(leistung)
        guard !q.isEmpty else { return Array(sortiert.prefix(limit)) }
        let treffer = sortiert.filter { baustein in
            let l = normalisiere(baustein.leistung)
            return !l.isEmpty && (l.contains(q) || q.contains(l))
        }
        let trefferIDs = Set(treffer.map { $0.objectID })
        let rest = sortiert.filter { !trefferIDs.contains($0.objectID) }
        return Array((treffer + rest).prefix(limit))
    }

    /// Alle Bausteine, häufigste zuerst, dann alphabetisch.
    static func alle(in ctx: NSManagedObjectContext) -> [Leistungsbaustein] {
        let req: NSFetchRequest<Leistungsbaustein> = Leistungsbaustein.fetchRequest()
        req.sortDescriptors = [
            NSSortDescriptor(keyPath: \Leistungsbaustein.verwendungen, ascending: false),
            NSSortDescriptor(keyPath: \Leistungsbaustein.leistung, ascending: true),
        ]
        return (try? ctx.fetch(req)) ?? []
    }
}
