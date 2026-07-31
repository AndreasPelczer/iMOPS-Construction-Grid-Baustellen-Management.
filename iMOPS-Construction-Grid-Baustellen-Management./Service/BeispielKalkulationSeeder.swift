import Foundation
import CoreData

// MARK: - BeispielKalkulationSeeder
//
// Rechnet die Dach- und Decken-Positionen der Beispiel-Baustelle Marktbreit durch
// (KG 350, 360, 440) und legt zwei Beispiel-Mitarbeiter an. Damit hat das Beispiel
// erstmals durchkalkulierte Positionen mit Material, Lohn UND Geraet — vorher gab es
// nur Pauschalen aus NU-Angeboten und Positionen ganz ohne Preis.
//
// ⚠️ ZU DEN ZAHLEN: Die Aufwandswerte (h je Einheit) sind recherchierte
// REFA-Richtwerte, KEINE gemessenen Werte von einer echten Baustelle. Sie sind gut
// genug, um die Kalkulation auszuprobieren, und ausdruecklich nicht gut genug fuer
// ein Angebot. Bevor daraus je Geld wird, muss jemand drueberschauen, der so ein Dach
// gebaut hat. Buch Kap 6: geschaetzt ist ein anderer Zustand als gemessen — nicht
// schlechter, aber ein anderer.
//
// Bewusst NICHT ueber den Mops erzeugt: Beispieldaten muessen reproduzierbar, offline
// und testbar sein. Fragt der Seeder den Mops, sieht das Beispiel bei jedem Aufsetzen
// anders aus und Tests wackeln. Der Mops-Weg ist der Knopf in der Tiefenkalkulation
// (MopsVorschlagSheet -> aufwandswertVorschlag) — das ist das Feature, nicht die Fixture.
//
// Preise kommen, wo vorhanden, aus den Stammdaten (KalkMaterial/Lohnsatz/Geraet) statt
// hier ein zweites Mal zu stehen. Fehlende Stammdaten werden ergaenzt, nicht dupliziert.
enum BeispielKalkulationSeeder {

    private static let eventNummer = "I-25_448-GO"

    static func seedIfNeeded(context: NSManagedObjectContext) {
        ergaenzeStammdaten(context: context)
        kalkuliereBeispielPositionen(context: context)
        seedMitarbeiter(context: context)
    }

    // MARK: - Rezepte je Position

    /// Ein Materialposten im Rezept: Menge JE Positions-Einheit (nicht gesamt).
    private struct Mat {
        let name: String
        let jeEinheit: Double
        let verschnitt: Double
    }

    /// Ein Lohnposten: Stunden JE Positions-Einheit.
    private struct Loh {
        let qualifikation: String
        let stundenJeEinheit: Double
    }

    /// Ein Geraeteposten: Stunden JE Positions-Einheit.
    private struct Ger {
        let name: String
        let stundenJeEinheit: Double
    }

    private struct Rezept {
        let posNr: String
        let material: [Mat]
        let lohn: [Loh]
        let geraete: [Ger]
    }

    /// Die sieben bisher preislosen Positionen. Einheiten stehen im MarktbreitSeeder:
    /// 3.50.1 m² · 3.50.2 m · 3.50.3 m · 3.60.1 Stk · 3.60.2 m² · 3.60.3 m² · 4.40.1 psch
    private static let rezepte: [Rezept] = [

        // --- KG 350 Decken ---

        // Filigrandecke d=20 cm = 5 cm Elementplatte + 15 cm Ortbetonergaenzung.
        Rezept(posNr: "3.50.1",
               material: [Mat(name: "Filigranplatte 5 cm", jeEinheit: 1.0,   verschnitt: 0.03),
                          Mat(name: "Beton C25/30",        jeEinheit: 0.155, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl",     jeEinheit: 8.5,   verschnitt: 0.08)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 0.42),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 0.33)],
               geraete:  [Ger(name: "Kran (Tagesmiete)",   stundenJeEinheit: 0.10)]),

        // Ringbalken 17 cm hoch, zweiseitig geschalt mit XPS (bleibt als Daemmung drin).
        Rezept(posNr: "3.50.2",
               material: [Mat(name: "Beton C25/30",        jeEinheit: 0.035, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl",     jeEinheit: 6.0,   verschnitt: 0.08),
                          Mat(name: "XPS-Schalung 7 cm",   jeEinheit: 0.40,  verschnitt: 0.10)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 0.55),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 0.45)],
               geraete:  []),

        // Fenstersturz: kurze Stuecke, viel Ruesten je Meter -> hoher Aufwandswert.
        Rezept(posNr: "3.50.3",
               material: [Mat(name: "Beton C25/30",        jeEinheit: 0.055, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl",     jeEinheit: 14.0,  verschnitt: 0.08),
                          Mat(name: "Schalungsplatte",     jeEinheit: 1.30,  verschnitt: 0.15)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 1.10),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 0.70)],
               geraete:  []),

        // --- KG 360 Daecher ---

        // Nagelplattenbinder: Material je Stueck, Montage im Takt, Kran haengt am Binder.
        Rezept(posNr: "3.60.1",
               material: [Mat(name: "Nagelplattenbinder 20°/20°", jeEinheit: 1.0, verschnitt: 0.0)],
               lohn:     [Loh(qualifikation: "Zimmerer", stundenJeEinheit: 0.85),
                          Loh(qualifikation: "Helfer",   stundenJeEinheit: 0.85)],
               geraete:  [Ger(name: "Kran (Tagesmiete)", stundenJeEinheit: 0.35)]),

        Rezept(posNr: "3.60.2",
               material: [Mat(name: "Dachziegel Braas",  jeEinheit: 12.0, verschnitt: 0.05),
                          Mat(name: "Dachlatte 30×50",   jeEinheit: 3.30, verschnitt: 0.10),
                          Mat(name: "Unterspannbahn",    jeEinheit: 1.05, verschnitt: 0.10)],
               lohn:     [Loh(qualifikation: "Zimmerer", stundenJeEinheit: 0.55),
                          Loh(qualifikation: "Helfer",   stundenJeEinheit: 0.30)],
               geraete:  []),

        Rezept(posNr: "3.60.3",
               material: [Mat(name: "OSB 18mm",              jeEinheit: 1.0, verschnitt: 0.10),
                          Mat(name: "Mineralwolle 160mm",    jeEinheit: 1.0, verschnitt: 0.05),
                          Mat(name: "Dampfsperre",           jeEinheit: 1.1, verschnitt: 0.15)],
               lohn:     [Loh(qualifikation: "Zimmerer", stundenJeEinheit: 0.45),
                          Loh(qualifikation: "Helfer",   stundenJeEinheit: 0.25)],
               geraete:  []),

        // --- KG 440 Elektro ---

        // Vorruestung, keine Anlage: Leerrohr, Durchfuehrung, Kabel. Pauschal.
        Rezept(posNr: "4.40.1",
               material: [Mat(name: "PV-Vorruestung Set", jeEinheit: 1.0, verschnitt: 0.0)],
               lohn:     [Loh(qualifikation: "Elektriker", stundenJeEinheit: 6.0)],
               geraete:  [])
    ]

    // MARK: - Kalkulation schreiben

    private static func kalkuliereBeispielPositionen(context: NSManagedObjectContext) {
        let req: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        req.predicate = NSPredicate(format: "event.eventNumber == %@", eventNummer)
        guard let positionen = try? context.fetch(req), !positionen.isEmpty else { return }

        var etwasGeschrieben = false

        for rezept in rezepte {
            guard let pos = positionen.first(where: { $0.posNr == rezept.posNr }) else { continue }
            // Idempotent UND respektvoll: wer selbst kalkuliert hat, wird nicht ueberschrieben.
            guard !pos.hatKalkulation else { continue }

            for m in rezept.material {
                guard let stamm = materialStammdaten(name: m.name, context: context) else { continue }
                let pm = PositionMaterial(context: context)
                pm.id = UUID()
                pm.materialName = m.name
                pm.mengeProEinheit = m.jeEinheit
                pm.einzelpreis = stamm.preisProEinheit
                pm.verschnittProzent = m.verschnitt
                pm.einheit = stamm.einheit
                pm.position = pos
            }

            for l in rezept.lohn {
                guard let satz = lohnsatzStammdaten(qualifikation: l.qualifikation, context: context) else { continue }
                let pl = PositionLohn(context: context)
                pl.id = UUID()
                pl.qualifikation = l.qualifikation
                pl.stunden = l.stundenJeEinheit
                // Brutto-EK = Tariflohn x Zuschlagsfaktor (Lohnnebenkosten). Kommt aus den
                // Stammdaten, damit der Satz nicht an zwei Stellen gepflegt werden muss.
                pl.stundenBruttoEK = satz.stundenlohn * satz.zuschlagFaktor
                pl.position = pos
            }

            for g in rezept.geraete {
                guard let geraet = geraetStammdaten(name: g.name, context: context),
                      geraet.nutzungsdauerStunden > 0 else { continue }
                let pg = PositionGeraet(context: context)
                pg.id = UUID()
                pg.geraetName = g.name
                pg.stunden = g.stundenJeEinheit
                pg.kostenProStunde = geraet.anschaffungsKosten / Double(geraet.nutzungsdauerStunden)
                pg.position = pos
            }

            // Die Werte sind geschaetzt, nicht gemessen — das muss die Position wissen,
            // damit die Voraussetzungs-Ampel (Welle 9) sie andersfarbig zeigen kann.
            pos.mengenQuelle = .schaetzung
            etwasGeschrieben = true
        }

        if etwasGeschrieben { try? context.save() }
    }

    // MARK: - Fehlende Stammdaten ergaenzen

    /// Ergaenzt nur, was fehlt. `StammdatenSeeder` legt seinen Satz nur an, solange die
    /// Tabelle KOMPLETT leer ist — auf einer bestehenden Datenbank kaeme also nichts mehr
    /// dazu. Darum hier je Eintrag einzeln pruefen.
    private static func ergaenzeStammdaten(context: NSManagedObjectContext) {
        var neu = false

        let materialien: [(String, String, Double, Double)] = [
            // (Name, Einheit, Preis je Einheit, Verschnitt-Vorgabe)
            ("Filigranplatte 5 cm",        "m²",   46.00, 0.03),
            ("XPS-Schalung 7 cm",          "m²",   14.50, 0.10),
            ("Unterspannbahn",             "m²",    2.80, 0.10),
            ("Nagelplattenbinder 20°/20°", "Stk", 185.00, 0.00),
            ("PV-Vorruestung Set",         "psch", 385.00, 0.00)
        ]
        for (name, einheit, preis, verschnitt) in materialien
        where materialStammdaten(name: name, context: context) == nil {
            let m = KalkMaterial(context: context)
            m.id = UUID()
            m.name = name
            m.einheit = einheit
            m.preisProEinheit = preis
            m.verbrauchProM2 = 0
            m.verschnittProzent = verschnitt
            m.letzteAktualisierung = Date()
            m.quelleRaw = MaterialQuelle.manuell.rawValue
            neu = true
        }

        // Elektro fehlt in den Standard-Lohnsaetzen; die PV-Vorruestung braucht ihn.
        if lohnsatzStammdaten(qualifikation: "Elektriker", context: context) == nil {
            let ls = Lohnsatz(context: context)
            ls.id = UUID()
            ls.qualifikation = "Elektriker"
            ls.stundenlohn = 34.00
            ls.zuschlagFaktor = 1.68
            neu = true
        }

        if neu { try? context.save() }
    }

    // MARK: - Beispiel-Mitarbeiter

    /// Zwei Mitarbeiter zum Ausprobieren der Crew-Planung. Rollen aus der dortigen
    /// Vorschlagsliste, damit sie im Picker wiederzufinden sind.
    private static func seedMitarbeiter(context: NSManagedObjectContext) {
        let req: NSFetchRequest<Employee> = Employee.fetchRequest()
        let vorhanden = (try? context.count(for: req)) ?? 0
        guard vorhanden == 0 else { return }

        let daten: [(String, String, String)] = [
            ("Bernd Krammer",  "Polier",   "Beispiel-Mitarbeiter. Faehrt den Pass auf der Baustelle."),
            ("Ali Yildirim",   "Maurer",   "Beispiel-Mitarbeiter.")
        ]

        for (name, rolle, notiz) in daten {
            let e = Employee(context: context)
            e.id = UUID()
            e.name = name
            e.rolle = rolle
            e.notiz = notiz
            e.isActive = true
        }

        try? context.save()
    }

    // MARK: - Stammdaten-Zugriff

    private static func materialStammdaten(name: String, context: NSManagedObjectContext) -> KalkMaterial? {
        let req: NSFetchRequest<KalkMaterial> = KalkMaterial.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    private static func lohnsatzStammdaten(qualifikation: String, context: NSManagedObjectContext) -> Lohnsatz? {
        let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        req.predicate = NSPredicate(format: "qualifikation == %@", qualifikation)
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    private static func geraetStammdaten(name: String, context: NSManagedObjectContext) -> Geraet? {
        let req: NSFetchRequest<Geraet> = Geraet.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }
}
