//
//  HofauffahrtSeederTests.swift
//  Demo 3 — das Mengengerüst, ein Abzweig, eine Zusammenführung, drei Lücken.
//
//  Der neue Prüfpunkt dieser Runde ist `mengengeruestTraegtBisZurSumme`: die
//  Vorgänger-Demos tragen „1 Psch" als Deckel, hier steht `menge = 100 qm` mit
//  Tonnen und laufenden Metern darunter. Der Test hält fest, dass die Kette
//  Menge → Preis → Summe wirklich durchrechnet.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct HofauffahrtSeederTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func baustelle() throws -> Event {
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-AUFFAHRT-001")
        return try #require(try ctx.fetch(r).first)
    }

    @MainActor
    private func schritt(_ teil: String, _ auftraege: [Auftrag]) throws -> Auftrag {
        try #require(auftraege.first { Kausalkette.bezeichnung($0).contains(teil) })
    }

    @MainActor
    private func position() throws -> LVPosition {
        try #require((try baustelle().lvPositionen?.allObjects as? [LVPosition])?.first)
    }

    // MARK: - Anlegen

    @Test @MainActor func zehnSchritteUndEineLVZeile() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()

        #expect((event.jobs?.count ?? 0) == 10)
        #expect((event.lvPositionen?.count ?? 0) == 1)
    }

    /// Ohne Aufmaß kein Termin. Ein Datum hier wäre eine Zusage, die niemand
    /// gegeben hat — anders als bei den Sandsteinstufen, wo der Kunde einen
    /// Wunschtermin genannt hatte.
    @Test @MainActor func keinTerminOhneAufmass() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()

        #expect(event.eventStartTime == nil)
        #expect(event.notes?.contains("verbindlich nach Aufmaß") == true)
    }

    // MARK: - Die Kette

    /// Zwei Stränge starten unabhängig: einrichten **und** Material bestellen.
    /// Wer 57 Tonnen Schotter erst ordert, wenn die Grube offen ist, steht daneben
    /// und wartet.
    @Test @MainActor func einrichtenUndBestellenStartenUnabhaengig() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []

        let startklar = auftraege.filter(\.istStartbar)
        #expect(startklar.count == 2,
                "startklar: \(startklar.map(Kausalkette.bezeichnung))")
        #expect(startklar.contains { Kausalkette.bezeichnung($0).contains("einrichten") })
        #expect(startklar.contains { Kausalkette.bezeichnung($0).contains("bestellen") })

        // Der Rest wartet — acht von zehn.
        #expect(auftraege.filter { !$0.istStartbar }.count == 8)
    }

    /// Der Punkt dieser Demo: Die Tragschicht wartet auf **zwei** Stränge — das
    /// Trennvlies muss liegen *und* das Material muss geliefert sein.
    @Test @MainActor func tragschichtWartetAufVliesUndMaterial() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []

        let tragschicht = try schritt("Tragschicht", auftraege)
        let namen = tragschicht.vorgaenger.map(Kausalkette.bezeichnung)

        #expect(tragschicht.vorgaenger.count == 2, "Vorgänger: \(namen)")
        #expect(namen.contains { $0.contains("Trennvlies") })
        #expect(namen.contains { $0.contains("bestellen") })
    }

    @Test @MainActor func neunKantenKeinKreis() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        let kanten = auftraege.flatMap { $0.voraussetzungenArray.filter(\.istKante) }

        #expect(kanten.count == 9)
        #expect(auftraege.contains { $0.istStartbar })   // ein Kreis würde alles blockieren
    }

    // MARK: - Die Kostengruppen

    /// **Am Katalog gemessen, nicht geraten.** Der Auftrag nannte 520 „Befestigte
    /// Flächen" — im `DIN276BaumKatalog` heißt 520 aber „Gründung / Unterbau".
    /// Die befestigten Flächen liegen in der 530er-Gruppe, für vier Stellplätze
    /// ist es 534.
    @Test @MainActor func kostengruppenStehenSoImKatalog() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)

        #expect(DIN276BaumKatalog.knoten(mitNummer: "520")?.bezeichnung == "Gründung / Unterbau")
        #expect(DIN276BaumKatalog.knoten(mitNummer: "534")?.bezeichnung == "Stellplätze")

        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        #expect(try schritt("Tragschicht", auftraege).kostenGruppeNummer == "520")
        #expect(try schritt("Pflaster verlegen", auftraege).kostenGruppeNummer == "534")
        #expect(try position().kostenGruppeNummer == "534")

        // Tätigkeiten tragen keine Nummer — eine wäre erfunden.
        #expect(try schritt("einrichten", auftraege).kostenGruppeNummer == nil)
        #expect(try schritt("Reinigen", auftraege).kostenGruppeNummer == nil)
    }

    // MARK: - Das Mengengerüst (der neue Prüfpunkt)

    /// **Die Falle, die diese Runde aufgedeckt hat.** `mengeProEinheit` ist die
    /// Menge **je Positionseinheit**, nicht die Gesamtmenge — nachgemessen in
    /// `PositionMaterial.kostenProEinheit` und `LVKalkulator.kalkuliere`.
    ///
    /// Gebraucht werden 57 t Mineralgemisch; im Modell steht 0,57 (t je qm).
    /// Dieser Test rechnet zurück: Menge je Einheit × Positionsmenge muss die
    /// Gesamtmenge aus dem Aufmaß ergeben. Trüge jemand versehentlich 57 ein,
    /// schlüge er hier fehl — und die Kalkulation wäre um das Hundertfache daneben.
    @Test @MainActor func mengenSindJeEinheitNichtGesamt() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let pos = try position()

        #expect(pos.menge == 100)
        #expect(pos.einheit == "qm")

        let material = (pos.kalkMaterialien?.allObjects as? [PositionMaterial]) ?? []
        #expect(material.count == 7)

        // Toleranz statt Gleichheit: 0,57 × 100 ergibt in Double 56,99999999999999,
        // nicht 57. Ein `==` hier wäre ein Test, der aus Rundung fehlschlägt.
        func gesamtmenge(_ teil: String) throws -> Double {
            let m = try #require(material.first { ($0.materialName ?? "").contains(teil) })
            return m.mengeProEinheit * pos.menge
        }
        func pruefe(_ teil: String, _ erwartet: Double) throws {
            let ist = try gesamtmenge(teil)
            #expect(abs(ist - erwartet) < 0.0001, "\(teil): \(ist) statt \(erwartet)")
        }

        try pruefe("Mineralgemisch", 57.0)    // t
        try pruefe("Splitt",          6.5)    // t
        try pruefe("Betonpflaster", 100.0)    // qm
        try pruefe("Tiefbordstein",  30.0)    // lfm
        try pruefe("Fugensand",       2.0)    // t
        try pruefe("Trennvlies",    110.0)    // qm, mit Überlappung an den Stößen

        // Lohn und Gerät rechnen genauso je Einheit.
        let lohn = try #require((pos.kalkLohn?.allObjects as? [PositionLohn])?.first)
        #expect(abs(lohn.stunden * pos.menge - 70.0) < 0.0001)
    }

    /// **Das Mengengerüst trägt bis zur Summe.** Die Kette Menge → Einzelpreis →
    /// Einheitspreis → Gesamtpreis rechnet durch, und zwar mit den echten Mengen.
    ///
    /// Geprüft wird gegen von Hand nachgerechnete Werte, nicht gegen das, was das
    /// Programm gerade ausspuckt — sonst prüft der Test sich selbst.
    @Test @MainActor func mengengeruestTraegtBisZurSumme() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let pos = try position()
        let k = LVKalkulator.kalkuliere(position: pos)

        // Material je qm, von Hand: 0,57×7,90 + 0,065×8,50 + 1,0×40×1,05
        //                         + 0,30×8,00 + 0,02×3,00 + 1,10×1,50 + 0,01×110
        //                         = 4,503 + 0,5525 + 42,00 + 2,40 + 0,06 + 1,65 + 1,10
        #expect(abs(k.materialKosten - 52.2655) < 0.01,
                "Material je qm: \(k.materialKosten)")

        // Lohn je qm: 0,7 h × 74 €
        #expect(abs(k.lohnKosten - 51.80) < 0.01, "Lohn je qm: \(k.lohnKosten)")

        // Gerät je qm: 0,08×65 + 0,10×12 + 0,06×120 = 5,20 + 1,20 + 7,20
        #expect(abs(k.geraeteKosten - 13.60) < 0.01, "Gerät je qm: \(k.geraeteKosten)")

        // Der Einheitspreis ist die Summe der drei Töpfe.
        #expect(abs(k.einheitspreisEK - (52.2655 + 51.80 + 13.60)) < 0.01)

        // Und der Gesamtpreis skaliert mit der Menge — das ist der Punkt.
        #expect(k.menge == 100)
        #expect(abs(k.gesamtpreis - k.einheitspreisVK * 100) < 0.01)

        // Größenordnung: eine 100-qm-Auffahrt liegt im niedrigen fünfstelligen
        // Bereich. Diese Schranke fängt einen Faktor-100-Fehler, ohne den Preis
        // festzunageln.
        #expect(k.gesamtpreis > 8_000 && k.gesamtpreis < 30_000,
                "Gesamtpreis: \(k.gesamtpreis)")
    }

    /// Verschnitt ist ein **Faktor** (0.05 = 5 %), kein Prozentwert. Gemessen an
    /// der UI (`MaterialHinzufuegenView`: Eingabe ÷ 100) und am `StammdatenSeeder`.
    ///
    /// ⚠️ `BauerHorstSeeder` trägt `5` und `10` ein — das ergibt 500 % und 1000 %
    /// Aufschlag. Dieser Test hält die richtige Konvention für diese Demo fest.
    @Test @MainActor func verschnittIstEinFaktorKeinProzent() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let material = (try position().kalkMaterialien?.allObjects as? [PositionMaterial]) ?? []

        for m in material {
            #expect(m.verschnittProzent < 1.0,
                    "\(m.materialName ?? "?") hat \(m.verschnittProzent) — das wären \(Int(m.verschnittProzent * 100)) %")
        }

        let pflaster = try #require(material.first {
            ($0.materialName ?? "").contains("Betonpflaster")
        })
        #expect(abs(pflaster.verschnittProzent - 0.05) < 0.0001)
        // 1,0 qm × 40 € × 1,05 = 42,00 — nicht 240 € wie bei verschnitt = 5.
        #expect(abs(pflaster.kostenProEinheit - 42.00) < 0.01)
    }

    // MARK: - Die Lücken

    /// **Lücke 1, bestätigt:** Die Entsorgung des Aushubs ist eine Fremdleistung
    /// (Deponie/Recyclinghof) — weder Material noch Lohn noch Gerät. `LVPosition`
    /// kennt nur drei Töpfe. Sie steht deshalb im Klartext am Arbeitsschritt und
    /// **nicht** getarnt in der Kalkulation. Die Summe dieser Position ist damit
    /// unvollständig, und das soll man sehen.
    @Test @MainActor func entsorgungHatKeineKostenart() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let pos = try position()

        let kostenarten = pos.entity.relationshipsByName.keys.filter { $0.hasPrefix("kalk") }.sorted()
        #expect(kostenarten == ["kalkGeraete", "kalkLohn", "kalkMaterialien"],
                "Kostenarten haben sich geändert: \(kostenarten)")
        #expect(!kostenarten.contains { $0.lowercased().contains("fremd") })
        #expect(!kostenarten.contains { $0.lowercased().contains("entsorg") })

        // Niemand hat die Entsorgung heimlich als Material oder Lohn eingebucht.
        let materialNamen = (pos.kalkMaterialien?.allObjects as? [PositionMaterial])?
            .compactMap(\.materialName) ?? []
        let lohnNamen = (pos.kalkLohn?.allObjects as? [PositionLohn])?
            .compactMap(\.qualifikation) ?? []
        #expect(!materialNamen.contains { $0.lowercased().contains("entsorg") })
        #expect(!lohnNamen.contains { $0.lowercased().contains("entsorg") })

        // Stattdessen steht sie im Klartext am Arbeitsschritt — mitsamt dem
        // Hinweis, dass die Kosten von der Bodenklasse abhängen (Lücke 2).
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        let entsorgen = try schritt("entsorgen", auftraege)
        let text = Kausalkette.bezeichnung(entsorgen)
        #expect(text.contains("Fremdleistung"))
        #expect(text.contains("keine Kostenart"))
        #expect(text.lowercased().contains("bodenklasse"))
    }

    /// **Lücke 3, bestätigt:** Die Fuhren fallen pro Fahrt an, `PositionGeraet`
    /// rechnet aber `stunden × kostenProStunde`. Der Test hält fest, dass es im
    /// Modell kein Feld für Stückzahl oder Pauschale gibt — die 720 € stehen als
    /// „0,06 Stunden × 120 €" da, rechnerisch richtig, begrifflich schief.
    @Test @MainActor func fuhrenRechnenImZeitModell() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)

        let felder = PositionGeraet.entity().attributesByName.keys.sorted()
        #expect(!felder.contains { $0.lowercased().contains("pauschal") },
                "PositionGeraet hat plötzlich ein Pauschalfeld: \(felder)")
        #expect(!felder.contains { $0.lowercased().contains("stueck") })

        let geraete = (try position().kalkGeraete?.allObjects as? [PositionGeraet]) ?? []
        let fuhren = try #require(geraete.first { ($0.geraetName ?? "").contains("Fuhren") })

        // Sechs Fahrten à 120 € = 720 € gesamt, hier als 0,06 „Stunden" je qm.
        #expect(abs(fuhren.stunden * 100 - 6.0) < 0.0001)
        #expect(abs(fuhren.kostenProEinheit * 100 - 720.00) < 0.01)
    }

    // MARK: - Idempotenz

    @Test @MainActor func zweiterLaufLegtNichtsDoppeltAn() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        HofauffahrtSeeder.seedIfNeeded(context: ctx)

        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-AUFFAHRT-001")
        #expect(try ctx.count(for: r) == 1)
        #expect((try baustelle().jobs?.count ?? 0) == 10)
        #expect((try position().kalkMaterialien?.count ?? 0) == 7)
    }
}
