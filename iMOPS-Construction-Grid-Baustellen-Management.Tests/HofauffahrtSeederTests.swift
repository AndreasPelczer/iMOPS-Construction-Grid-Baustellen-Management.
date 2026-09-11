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
    /// **Dieser Test hiess bis zur DXF-Runde `keinTerminOhneAufmass`.**
    ///
    /// Der alte Name traf eine Begruendung, die nicht mehr gilt: Es stand kein
    /// Termin, *weil das Aufmass fehlte*. Das Aufmass fehlt jetzt nicht mehr —
    /// 1294 Steine sind gezaehlt, die Flaeche ist deren Summe. Trotzdem steht
    /// weiter kein Termin, und zwar aus einem anderen Grund: **es wurde keiner
    /// zugesagt.** Ein Datum im Kalender waere eine Zusage, die niemand gegeben
    /// hat — unabhaengig davon, wie genau die Mengen sind.
    ///
    /// Was jetzt noch fehlt, ist nicht das Mass, sondern der **Preis**: die
    /// Steinpreise sind aus einem Quadratmeter-Anker umgerechnet, nicht bei
    /// Pasand angefragt.
    @Test @MainActor func keinTerminZugesagt() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()

        #expect(event.eventStartTime == nil)
        let notes = event.notes ?? ""
        // Die Notiz sagt jetzt, was wirklich aussteht.
        #expect(notes.contains("Lieferantenpreis"), "Notiz: \(notes)")
        #expect(notes.contains("Aufmaß liegt bereits vor"))
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

        #expect(abs(pos.menge - 100.31) < 0.0001)
        // `m²`, nicht `qm` — sonst wird daraus in der XRechnung C62 (Stück).
        #expect(pos.einheit == "m²")

        let material = (pos.kalkMaterialien?.allObjects as? [PositionMaterial]) ?? []
        #expect(material.count == 8)

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

        // Die gezählten Stückzahlen müssen exakt zurückkommen — das ist der Kern
        // dieser Runde. Wer `mengeProEinheit` mit der Gesamtmenge verwechselt,
        // fällt hier auf: 1294 statt 12,9 ergäbe 129.794 Steine.
        try pruefe("Vollstein",    1294.0)    // Stk, Layer „Pflaster"
        try pruefe("Halbstein",      50.0)    // Stk, Layer „Pflaster"
        try pruefe("Leistensteine",  40.0)    // Stk à 1,00 m = 40 lfm

        try pruefe("Schotter 0/32",  57.1767) // t  — 100,31 × 0,30 m × 1,9 t/m³
        try pruefe("Splitt 8/16",     6.5202) // t  — 100,31 × 0,04 m × 1,625 t/m³
        try pruefe("Fugensand",       2.0062) // t
        try pruefe("Trennvlies",    110.3410) // m², 10 % Überlappung an den Stößen

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

        // Material je m², von Hand gegen 100,31 gerechnet:
        //   Vollstein  1294/100,31 = 12,90001 × 3,04 = 39,21603
        //   Halbstein    50/100,31 =  0,49845 × 1,52 =  0,75765
        //   Leisten      40/100,31 =  0,39876 × 8,00 =  3,19011
        //   Schotter               =  0,57000 ×10,00 =  5,70000
        //   Splitt                 =  0,06500 × 8,50 =  0,55250
        //   Fugensand              =  0,02000 × 3,00 =  0,06000
        //   Trennvlies             =  1,10000 × 1,50 =  1,65000
        //   Beton         1/100,31 =  0,00997 ×110,00=  1,09660
        //                                            ──────────
        //                                              52,22289
        #expect(abs(k.materialKosten - 52.22289) < 0.01,
                "Material je m²: \(k.materialKosten)")

        // Lohn je m²: 70 h / 100,31 × 74 €
        #expect(abs(k.lohnKosten - 51.63996) < 0.01, "Lohn je m²: \(k.lohnKosten)")

        // Gerät je m²: (8×65 + 10×12 + 6×120) / 100,31 = 1360 / 100,31
        #expect(abs(k.geraeteKosten - 13.55797) < 0.01, "Gerät je m²: \(k.geraeteKosten)")

        // Der Einheitspreis ist die Summe der drei Töpfe.
        #expect(abs(k.einheitspreisEK - (52.22289 + 51.63996 + 13.55797)) < 0.01)

        // Und der Gesamtpreis skaliert mit der Menge — das ist der Punkt.
        #expect(abs(k.menge - 100.31) < 0.0001)
        #expect(abs(k.gesamtpreis - k.einheitspreisVK * 100.31) < 0.01)

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

        // **Gezählte Steine tragen 0 % Verschnitt.** Solange 100 qm Pflaster als
        // Fläche dastanden, waren 5 % richtig — eine Fläche muss man zuschneiden.
        // Der Zuschnitt am Rand ist im DXF aber bereits als 50 Halbsteine
        // ausgewiesen; wer jetzt noch aufschlägt, zählt den Rand zweimal.
        let vollstein = try #require(material.first {
            ($0.materialName ?? "").contains("Vollstein")
        })
        #expect(vollstein.verschnittProzent == 0)
        // 12,90001 Stk × 3,04 € × 1,0 = 39,216 je m² — ohne stillen Aufschlag.
        #expect(abs(vollstein.kostenProEinheit - 39.21603) < 0.01)
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

        // Sechs Fahrten à 120 € = 720 € gesamt, hier als „Stunden" je m².
        // Gegen `pos.menge` gerechnet, nicht gegen eine hart notierte 100 —
        // sonst bricht der Test bei jeder Mengenkorrektur, ohne dass an den
        // Fuhren etwas falsch waere. (Genau das ist in der DXF-Runde passiert.)
        let menge = try position().menge
        #expect(abs(fuhren.stunden * menge - 6.0) < 0.0001)
        #expect(abs(fuhren.kostenProEinheit * menge - 720.00) < 0.01)
    }

    // MARK: - Idempotenz

    // MARK: - Die gezählten Mengen

    /// **Die Fläche ist keine eigene Angabe, sondern die Summe der Steine.**
    ///
    /// 1294 × (0,39 × 0,195) + 50 × (0,195 × 0,195) = 98,4087 + 1,9013 = 100,31 m².
    ///
    /// Der Test hält die drei Zahlen aneinander fest. Ändert jemand eine
    /// Stückzahl und vergisst die Fläche, fällt es hier auf — und nicht erst in
    /// einem Angebot, das über eine Fläche lautet, die es nicht gibt.
    @Test @MainActor func flaecheIstDieSummeDerSteine() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let pos = try position()

        let ausSteinen = 1294.0 * (0.39 * 0.195) + 50.0 * (0.195 * 0.195)
        #expect(abs(ausSteinen - 100.31) < 0.001,
                "Steine ergeben \(ausSteinen) m², die Position trägt \(pos.menge)")
        #expect(abs(pos.menge - ausSteinen) < 0.001)
    }

    /// **Gezählt, nicht geschätzt — 1344 Pflastersteine und 40 Leistensteine.**
    ///
    /// Die Summenprobe über beide Pflaster-Zeilen ist der eigentliche Nachweis
    /// dieser Runde: Voll- und Halbsteine sind zwei Artikel, aber eine Zählung.
    @Test @MainActor func gezaehlteSteineStehenAlsStueckzahl() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let pos = try position()
        let material = (pos.kalkMaterialien?.allObjects as? [PositionMaterial]) ?? []

        func stueck(_ teil: String) throws -> Double {
            let m = try #require(material.first { ($0.materialName ?? "").contains(teil) })
            #expect(m.einheit == "Stk", "\(teil) ist in \(m.einheit ?? "?") statt Stk")
            return m.mengeProEinheit * pos.menge
        }

        let voll  = try stueck("Vollstein")
        let halb  = try stueck("Halbstein")
        let leist = try stueck("Leistensteine")

        #expect(abs(voll  - 1294) < 0.0001)
        #expect(abs(halb  -   50) < 0.0001)
        #expect(abs(leist -   40) < 0.0001)
        // Die Summenprobe: 1294 + 50 = 1344 Pflastersteine.
        #expect(abs((voll + halb) - 1344) < 0.0001,
                "Pflastersteine gesamt: \(voll + halb)")

        // Der Herkunftsstempel sagt, woher die Zahlen kommen. `mengenQuelle`
        // kann es nicht sagen — sie kennt keinen Fall „gezählt".
        let stempel = pos.deckelNotiz ?? ""
        #expect(stempel.contains("dxf-gezählt"), "Stempel: \(stempel)")
        #expect(stempel.contains("Testhofeinfahrt.dxf"))
        #expect(pos.mengenQuelle == .schaetzung)   // Befund, siehe Seeder-Kopf
    }

    // MARK: - Der geschlossene Kreis

    /// **Gespräch → Angebot → Baustelle → Kalkulation → Rechnung.**
    ///
    /// Das ist der Punkt, an dem sich zeigt, ob die Kette trägt: Aus derselben
    /// Baustelle, die der Seeder anlegt, fällt am Ende eine XRechnung — über den
    /// **bestehenden** `XRechnungExporter`, genau wie bei Bauer Horst. Kein neues
    /// Feature, nur das Ende eines Weges, der vorne mit einer Zeichnung anfängt.
    ///
    /// Geprüft wird die Stelle, an der die gezählte Menge im Rechnungsformat
    /// ankommt: `<ram:BilledQuantity unitCode="MTK">100.310</ram:BilledQuantity>`.
    /// **MTK ist der UN/ECE-Code für Quadratmeter.** Stünde in der Position „qm"
    /// statt „m²", fiele der Exporter auf **C62 (Stück)** zurück — die Rechnung
    /// läse sich als „100,31 Stück Hofauffahrt", und niemand sähe es dem XML an.
    @Test @MainActor func ausDerBaustelleFaelltEineXRechnung() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()
        let pos   = try position()

        let daten = XRechnungExporter.export(event: event, positionen: [pos])
        let xml = try #require(String(data: daten, encoding: .utf8))

        // Es ist überhaupt eine XRechnung.
        #expect(xml.contains("<rsm:CrossIndustryInvoice"))
        #expect(xml.contains("xrechnung_2.2"))
        #expect(xml.contains("<ram:TypeCode>380</ram:TypeCode>"))   // Handelsrechnung

        // Die gezählte Menge kommt als Quadratmeter an, nicht als Stück.
        #expect(xml.contains("unitCode=\"MTK\""),
                "Einheit kam nicht als MTK an — Position trägt \(pos.einheit ?? "?")")
        #expect(xml.contains(">100.310<"), "Menge fehlt im XML")
        #expect(!xml.contains("unitCode=\"C62\""),
                "Fallback C62 aufgetaucht — die Einheit wurde nicht erkannt")

        // Die Position steht mit Nummer und Bezeichnung drin.
        #expect(xml.contains("1.20.1"))
        #expect(xml.contains("Hofauffahrt pflastern"))

        // Und sie trägt einen Betrag, der zur Kalkulation passt.
        let k = LVKalkulator.kalkuliere(position: pos)
        #expect(k.gesamtpreis > 8_000 && k.gesamtpreis < 30_000,
                "Rechnungsbetrag: \(k.gesamtpreis)")
        #expect(xml.contains("<ram:LineTotalAmount>"))
    }

    @Test @MainActor func zweiterLaufLegtNichtsDoppeltAn() throws {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        HofauffahrtSeeder.seedIfNeeded(context: ctx)

        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-AUFFAHRT-001")
        #expect(try ctx.count(for: r) == 1)
        #expect((try baustelle().jobs?.count ?? 0) == 10)
        // Acht seit der DXF-Runde: Voll- und Halbstein sind zwei Artikel,
        // wo vorher eine Pflaster-Flaeche stand.
        #expect((try position().kalkMaterialien?.count ?? 0) == 8)
    }
}
