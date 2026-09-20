//
//  AngebotSchlaegtKalkulationTests.swift
//  Ein importierter Angebotspreis muss die Eigenkalkulation schlagen — überall gleich.
//
//  Der Fall aus der Praxis (20.09.2026): ein GAEB-X84 wurde importiert, jede Position
//  bekam ihren Einheitspreis als Angebot. Danach lief „Mops fass" und schrieb Lohn-
//  Kalkulationen dazu. Die Kostenübersicht (rechnet über `effektiverEP`) zeigte weiter
//  die richtige Summe, der Summenbalken im LV dagegen nur noch die Lohnanteile —
//  15.255 € statt 256.742 €, weil dort die Kalkulation VOR dem Angebot abgefragt wurde.
//
//  Diese Tests halten die Rangfolge fest: Angebot → Element → Eigenkalkulation.
//

import Testing
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AngebotSchlaegtKalkulationTests {

    /// Der Store ist ein Singleton (private init) — also den gemeinsamen nehmen und
    /// hinterher aufräumen. Die objectIDs sind je In-Memory-Container eindeutig,
    /// die Tests sehen sich dadurch nicht.
    private let s = AngebotsStore.shared

    private func aufraeumen(_ ids: [String], lieferanten: [String]) {
        for id in ids { for l in lieferanten { s.remove(lieferant: l, for: id) } }
    }

    /// Eine Lohnzeile — so schreibt „Mops fass" die Kalkulation in die Position.
    private func lohn(_ pos: LVPosition, in ctx: NSManagedObjectContext,
                      satz: Double = 42.0, stunden: Double) {
        let l = PositionLohn(context: ctx)
        l.id = UUID()
        l.qualifikation = "Facharbeiter"
        l.stundenBruttoEK = satz
        l.stunden = stunden
        l.position = pos
    }

    private func position(in ctx: NSManagedObjectContext,
                          menge: Double, einheit: String = "m³") -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = "01.01"
        p.bezeichnung = "Beton Bodenplatte C25/30"
        p.einheit = einheit
        p.menge = menge
        return p
    }

    @Test func angebotSchlaegtEigenkalkulation() throws {
        let pc = PersistenceController(inMemory: true)     // festhalten! (struct)
        let ctx = pc.container.viewContext
        let pos = position(in: ctx, menge: 12.16)

        // Eigenkalkulation: nur Lohn, wie „Mops fass" sie schreibt.
        lohn(pos, in: ctx, stunden: 2.0)
        #expect(pos.hatKalkulation)
        let nurKalk = LVKalkulator.kalkuliere(position: pos).einheitspreisVK
        #expect(nurKalk > 0)

        // Importierter Angebotspreis aus dem X84.
        try? ctx.obtainPermanentIDs(for: [pos])
        let id = pos.objectID.uriRepresentation().absoluteString
        s.upsert(Angebot(lieferant: "GAEB-Import", einzelpreis: 174.00), for: id)

        // Der Angebotspreis gewinnt — nicht die Kalkulation.
        #expect(LVKalkulator.effektiverEP(for: pos, store: s) == 174.00)
        #expect(LVKalkulator.effektiverEP(for: pos, store: s) != nurKalk)
        aufraeumen([id], lieferanten: ["GAEB-Import"])
    }

    @Test func ohneAngebotZaehltDieKalkulation() throws {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext
        let pos = position(in: ctx, menge: 10)
        lohn(pos, in: ctx, stunden: 1.5)
        let erwartet = LVKalkulator.kalkuliere(position: pos).einheitspreisVK
        #expect(erwartet > 0)
        #expect(LVKalkulator.effektiverEP(for: pos, store: s) == erwartet)
    }

    @Test func guenstigstesAngebotGewinnt() throws {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext
        let pos = position(in: ctx, menge: 1)
        try? ctx.obtainPermanentIDs(for: [pos])
        let id = pos.objectID.uriRepresentation().absoluteString
        s.upsert(Angebot(lieferant: "Lieferant A", einzelpreis: 210.00), for: id)
        s.upsert(Angebot(lieferant: "Lieferant B", einzelpreis: 189.50), for: id)
        #expect(LVKalkulator.effektiverEP(for: pos, store: s) == 189.50)
        aufraeumen([id], lieferanten: ["Lieferant A", "Lieferant B"])
    }

    /// Der Kern des Praxisfalls: 109 Positionen mit Angebot, danach kommt eine
    /// Kalkulation dazu — die Gesamtsumme darf NICHT einbrechen.
    @Test func summeBleibtStehenWennSpaeterKalkuliertWird() throws {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext

        var positionen: [LVPosition] = []
        for i in 0..<5 {
            let p = position(in: ctx, menge: 10)
            p.posNr = "01.0\(i)"
            positionen.append(p)
        }
        try? ctx.obtainPermanentIDs(for: positionen)
        for p in positionen {
            s.upsert(Angebot(lieferant: "GAEB-Import", einzelpreis: 100.00),
                     for: p.objectID.uriRepresentation().absoluteString)
        }
        func summe() -> Double {
            positionen.reduce(0) { $0 + $1.menge * LVKalkulator.effektiverEP(for: $1, store: s) }
        }
        #expect(summe() == 5000.0)          // 5 × 10 × 100

        // Jetzt läuft „Mops fass" und schreibt Lohnstunden dazu.
        for p in positionen { lohn(p, in: ctx, stunden: 0.5) }
        let alleKalkuliert = positionen.allSatisfy { $0.hatKalkulation }
        #expect(alleKalkuliert)
        #expect(summe() == 5000.0)          // Summe bleibt: das Angebot gewinnt
        aufraeumen(positionen.map { $0.objectID.uriRepresentation().absoluteString },
                   lieferanten: ["GAEB-Import"])
    }
}

// MARK: - Die Ampel muss hinterlegte Preise sehen

struct AmpelSiehtAngebotTests {

    private let s = AngebotsStore.shared

    @Test func positionMitAngebotIstGruen() throws {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext
        let pos = LVPosition(context: ctx)
        pos.posNr = "01.01"
        // Bewusst eine Leistung, für die es KEIN Rezept und KEINEN Richtwert gibt —
        // ohne Angebot wäre sie ROT.
        pos.bezeichnung = "Stützwinkel L 995 B 120 H 1550 liefern und versetzen"
        pos.einheit = "Stück"
        pos.menge = 19

        let ohne = AutoKalkulationsService.bewerte(pos, in: ctx, store: s)
        #expect(ohne.status != .gruen)

        try? ctx.obtainPermanentIDs(for: [pos])
        let id = pos.objectID.uriRepresentation().absoluteString
        s.upsert(Angebot(lieferant: "GAEB-Import", einzelpreis: 210.00), for: id)

        let mit = AutoKalkulationsService.bewerte(pos, in: ctx, store: s)
        #expect(mit.status == .gruen)
        #expect(mit.einheitspreisVK == 210.00)
        #expect(mit.meldungen.first?.contains("GAEB-Import") == true)
        #expect(mit.meldungen.first?.contains("210,00") == true)
        #expect(mit.enthaeltKI == false)
        s.remove(lieferant: "GAEB-Import", for: id)
    }

    @Test func ampelBleibtRotOhnePreisUndOhneRezept() throws {
        let pc = PersistenceController(inMemory: true)
        let ctx = pc.container.viewContext
        let pos = LVPosition(context: ctx)
        pos.posNr = "01.02"
        pos.bezeichnung = "Zyxwvu Fantasieleistung ohne Katalogeintrag"
        pos.einheit = "Stück"
        pos.menge = 1
        #expect(AutoKalkulationsService.bewerte(pos, in: ctx, store: s).status == .rot)
    }
}
