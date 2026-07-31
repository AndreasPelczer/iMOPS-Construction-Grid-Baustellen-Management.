import Foundation
import CoreData

// MARK: - BeispielKalkulationSeeder
//
// Rechnet die 15 Eigenleistungs-Positionen der Beispiel-Baustelle Marktbreit durch
// (KG 320 Gruendung bis KG 440 Elektro) und legt zwei Beispiel-Mitarbeiter an. Damit hat
// das Beispiel erstmals ein VOLLSTAENDIG kalkuliertes LV: jede Position, die die eigene
// Kolonne baut, hat Material, Lohn und teils Geraet. Die neun NU-Pauschalen bleiben
// bewusst unaufgerechnet — fremde Leistung kalkuliert man nicht nach.
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
        seedPlanerSchaetzung(context: context)
        seedMitarbeiter(context: context)
    }

    // MARK: - Grobkostenschaetzung fuers Beispiel

    /// Legt die Planer-Konfiguration an, damit der Kennwert-Vergleich am Beispiel
    /// etwas zu zeigen hat. Werte aus den Event-Notizen (T&C Aura 125, UG+EG+DG,
    /// Satteldach 20°/20°) — nicht erfunden, sondern aus der Statik uebernommen.
    ///
    /// Ueberschreibt NICHTS: wer im Planer schon etwas konfiguriert hat, behaelt es.
    private static func seedPlanerSchaetzung(context: NSManagedObjectContext) {
        let req: NSFetchRequest<Event> = Event.fetchRequest()
        req.predicate = NSPredicate(format: "eventNumber == %@", eventNummer)
        req.fetchLimit = 1
        guard let event = try? context.fetch(req).first else { return }

        var extras = EventExtrasPayload.laden(aus: event)
        guard extras.houseProject == nil else { return }

        var projekt = HouseProject()
        projekt.projektName = "EFH T&C Aura 125"
        projekt.haustyp = .einfamilienhaus
        projekt.wohnflaeche = 125          // Typenhaus Aura 125
        projekt.geschosse = 2              // EG + DG (Keller separat)
        projekt.kellerGeplant = true       // Statik weist Keller-Aussenwaende aus
        projekt.dachform = .satteldach
        projekt.ausstattung = .mittel
        projekt.garage = false             // Carport, siehe Stuetzmauer-Position

        extras.houseProject = projekt
        extras.speichern(in: event)
        try? context.save()
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

    /// Alle 15 Eigenleistungs-Positionen der Beispiel-Baustelle. Die restlichen 9 sind
    /// Nachunternehmer-Pauschalen (KG 390/5xx) — die haben einen Endpreis und werden
    /// bewusst NICHT aufgerechnet: fremde Leistung kalkuliert man nicht nach.
    private static let rezepte: [Rezept] = [

        // --- KG 320 Gruendung ---

        // Streifenfundament Aussenwand b=37 d=16 -> rund 0,06 m3 je lfm, zweiseitig geschalt.
        Rezept(posNr: "3.20.1",
               material: [Mat(name: "Beton C25/30",       jeEinheit: 0.060, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl",    jeEinheit: 8.0,   verschnitt: 0.08),
                          Mat(name: "Schalungsplatte",    jeEinheit: 0.35,  verschnitt: 0.15)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 0.45),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 0.40)],
               geraete:  [Ger(name: "Rüttler / Verdichter", stundenJeEinheit: 0.10)]),

        Rezept(posNr: "3.20.2",
               material: [Mat(name: "Beton C25/30",       jeEinheit: 0.050, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl",    jeEinheit: 6.0,   verschnitt: 0.08),
                          Mat(name: "Schalungsplatte",    jeEinheit: 0.35,  verschnitt: 0.15)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 0.45),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 0.40)],
               geraete:  [Ger(name: "Rüttler / Verdichter", stundenJeEinheit: 0.10)]),

        // Sohlplatte: grosse zusammenhaengende Flaeche -> deutlich weniger Stunden je m2
        // als ein Fundamentgraben. Bewehrung als Matten, keine Seitenschalung gerechnet.
        Rezept(posNr: "3.20.3",
               material: [Mat(name: "Beton C25/30",       jeEinheit: 0.165, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl",    jeEinheit: 9.0,   verschnitt: 0.08)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 0.25),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 0.22)],
               geraete:  [Ger(name: "Rüttler / Verdichter", stundenJeEinheit: 0.05)]),

        // --- KG 330 Aussenwaende ---

        // Porenbeton-Planstein, Duennbettmoertel. ~6,7 Steine je m2 (Format 599x249).
        Rezept(posNr: "3.30.1",
               material: [Mat(name: "Porenbeton PP2 24cm", jeEinheit: 6.7, verschnitt: 0.05),
                          Mat(name: "Dünnbettmörtel",      jeEinheit: 3.5, verschnitt: 0.08)],
               lohn:     [Loh(qualifikation: "Maurer",  stundenJeEinheit: 0.55),
                          Loh(qualifikation: "Helfer",  stundenJeEinheit: 0.35)],
               geraete:  [Ger(name: "Mörtelschlitten", stundenJeEinheit: 0.10)]),

        Rezept(posNr: "3.30.2",
               material: [Mat(name: "Porenbeton PP4 24cm", jeEinheit: 6.7, verschnitt: 0.05),
                          Mat(name: "Dünnbettmörtel",      jeEinheit: 3.5, verschnitt: 0.08)],
               lohn:     [Loh(qualifikation: "Maurer",  stundenJeEinheit: 0.55),
                          Loh(qualifikation: "Helfer",  stundenJeEinheit: 0.35)],
               geraete:  [Ger(name: "Mörtelschlitten", stundenJeEinheit: 0.10)]),

        // d=36,5 cm: schwerere Steine, mehr Moertel, hoeherer Aufwandswert als die 24er.
        // Genau der Unterschied, den die Statik-Notiz als Stolperstein markiert
        // ("Zwei Keller-AW-Staerken!") — im Preis muss er sich auch zeigen.
        Rezept(posNr: "3.30.2b",
               material: [Mat(name: "Porenbeton PP4 36,5cm", jeEinheit: 6.7, verschnitt: 0.05),
                          Mat(name: "Dünnbettmörtel",        jeEinheit: 5.0, verschnitt: 0.08)],
               lohn:     [Loh(qualifikation: "Maurer",  stundenJeEinheit: 0.70),
                          Loh(qualifikation: "Helfer",  stundenJeEinheit: 0.45)],
               geraete:  [Ger(name: "Mörtelschlitten", stundenJeEinheit: 0.12)]),

        // Einzelstuetze: fast alles Ruestzeit, deshalb Stunden je STUECK und nicht je m2.
        Rezept(posNr: "3.30.3",
               material: [Mat(name: "Beton C25/30",    jeEinheit: 0.12, verschnitt: 0.05),
                          Mat(name: "Bewehrungsstahl", jeEinheit: 25.0, verschnitt: 0.08),
                          Mat(name: "Schalungsplatte", jeEinheit: 3.0,  verschnitt: 0.15)],
               lohn:     [Loh(qualifikation: "Betonbauer", stundenJeEinheit: 3.50),
                          Loh(qualifikation: "Helfer",     stundenJeEinheit: 2.00)],
               geraete:  []),

        // --- KG 340 Innenwaende ---

        Rezept(posNr: "3.40.1",
               material: [Mat(name: "Porenbeton PP4 17,5cm", jeEinheit: 6.7, verschnitt: 0.05),
                          Mat(name: "Dünnbettmörtel",        jeEinheit: 2.8, verschnitt: 0.08)],
               lohn:     [Loh(qualifikation: "Maurer",  stundenJeEinheit: 0.45),
                          Loh(qualifikation: "Helfer",  stundenJeEinheit: 0.28)],
               geraete:  [Ger(name: "Mörtelschlitten", stundenJeEinheit: 0.08)]),

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
            ("Porenbeton PP2 24cm",        "Stk",   3.60, 0.05),
            ("Porenbeton PP4 24cm",        "Stk",   4.20, 0.05),
            ("Porenbeton PP4 36,5cm",      "Stk",   6.40, 0.05),
            ("Porenbeton PP4 17,5cm",      "Stk",   2.90, 0.05),
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
