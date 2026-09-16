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

    /// Auto-Match beim Import: sucht das gelernte Rezept zur Position (Bezeichnung +
    /// Einheit) und schreibt dessen Aufwand als Lohn — damit rechnet der `LVKalkulator`
    /// den Preis. Gibt zurück, ob ein Treffer gefunden wurde.
    ///
    /// KEIN Treffer = die Position bleibt OHNE Preis (keine erfundene Zahl). Das ist die
    /// ehrliche Voreinstellung: gerechnet nur, wo ein gelerntes Rezept passt; alles andere
    /// wartet sichtbar auf einen Preis (Auswahl aus dem Katalog oder Prof/KI-Schätzung).
    @discardableResult
    static func autoMatch(position pos: LVPosition, in ctx: NSManagedObjectContext) -> Bool {
        guard let leistung = pos.bezeichnung, !leistung.isEmpty else { return false }
        guard let baustein = finde(leistung: leistung, einheit: pos.einheit ?? "", in: ctx) else {
            return false
        }
        schreibeRezept(baustein, auf: pos, in: ctx)
        if let kg = baustein.kostenGruppeNummer, !kg.isEmpty,
           (pos.kostenGruppeNummer ?? "").isEmpty {
            pos.kostenGruppeNummer = kg
        }
        benutzt(baustein)
        return true
    }

    // MARK: - Volles Rezept (Lohn + Material + Gerät)

    /// Ein wiederverwendbares Rezept über die reine Arbeitszeit hinaus: Material und Gerät
    /// je Einheit. Lohn bleibt in `maurerStunden`/`helferStunden` (Rückwärtskompatibilität);
    /// hier nur die Teile, die es vorher nicht gab.
    struct Rezept: Codable {
        struct Material: Codable {
            var name: String; var mengeProEinheit: Double
            var einzelpreis: Double; var verschnittProzent: Double; var einheit: String
        }
        struct Geraet: Codable {
            var name: String; var stunden: Double; var kostenProStunde: Double
        }
        var material: [Material] = []
        var geraet: [Geraet] = []
        var istLeer: Bool { material.isEmpty && geraet.isEmpty }
    }

    /// Ernten: Material + Gerät einer fertig kalkulierten Position als Rezept am Baustein
    /// ablegen (JSON). Lohn wird separat über `merke(...)` gepflegt. Leeres Rezept → nil.
    static func lerneMaterialUndGeraet(von pos: LVPosition, auf baustein: Leistungsbaustein) {
        let rezept = Rezept(
            material: pos.materialArray.map {
                .init(name: $0.materialName ?? "", mengeProEinheit: $0.mengeProEinheit,
                      einzelpreis: $0.einzelpreis, verschnittProzent: $0.verschnittProzent,
                      einheit: $0.einheit ?? "")
            },
            geraet: pos.geraeteArray.map {
                .init(name: $0.geraetName ?? "", stunden: $0.stunden, kostenProStunde: $0.kostenProStunde)
            })
        if rezept.istLeer { baustein.rezeptJSON = nil; return }
        if let data = try? JSONEncoder().encode(rezept) {
            baustein.rezeptJSON = String(decoding: data, as: UTF8.self)
        }
    }

    /// Das gelernte Material/Gerät-Rezept eines Bausteins, oder nil.
    static func rezept(von baustein: Leistungsbaustein) -> Rezept? {
        guard let s = baustein.rezeptJSON, let data = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Rezept.self, from: data)
    }

    /// Replay: das volle Rezept auf eine Position schreiben — Lohn (Maurer/Helfer) UND,
    /// falls vorhanden, Material + Gerät. Idempotent: vorhandene Material/Gerät-Zeilen
    /// werden ersetzt, nicht gestapelt.
    static func schreibeRezept(_ baustein: Leistungsbaustein,
                               auf pos: LVPosition, in ctx: NSManagedObjectContext) {
        schreibeAufwandAlsLohn(maurer: baustein.maurerStunden,
                               helfer: baustein.helferStunden, auf: pos, in: ctx)
        guard let rezept = rezept(von: baustein) else { return }

        for pm in pos.materialArray { ctx.delete(pm) }
        for pg in pos.geraeteArray { ctx.delete(pg) }
        ctx.processPendingChanges()   // Löschungen aus der Beziehung ziehen (Idempotenz ohne save)

        for m in rezept.material {
            let pm = PositionMaterial(context: ctx)
            pm.id = UUID()
            pm.materialName = m.name
            pm.mengeProEinheit = m.mengeProEinheit
            pm.einzelpreis = m.einzelpreis
            pm.verschnittProzent = m.verschnittProzent
            pm.einheit = m.einheit
            pm.position = pos
        }
        for g in rezept.geraet {
            let pg = PositionGeraet(context: ctx)
            pg.id = UUID()
            pg.geraetName = g.name
            pg.stunden = g.stunden
            pg.kostenProStunde = g.kostenProStunde
            pg.position = pos
        }
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
        ctx.processPendingChanges()   // Löschungen aus der Beziehung ziehen (sonst gestapelt ohne save)
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
