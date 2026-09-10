//
//  SandsteinstufenSeederTests.swift
//  Demo 2 — zwei Stränge, und zwei Modell-Lücken, die dokumentiert bleiben sollen.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct SandsteinstufenSeederTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @MainActor
    private func baustelle() throws -> Event {
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-STUFEN-001")
        return try #require(try ctx.fetch(r).first)
    }

    @MainActor
    private func schritt(_ teil: String, _ auftraege: [Auftrag]) throws -> Auftrag {
        try #require(auftraege.first { Kausalkette.bezeichnung($0).contains(teil) })
    }

    // MARK: - Anlegen

    @Test @MainActor func sechsSchritteUndEineLVZeile() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()

        #expect((event.jobs?.count ?? 0) == 6)
        #expect((event.lvPositionen?.count ?? 0) == 1)
    }

    // MARK: - Die Kette

    /// Zwei Stränge starten unabhängig: die alten Stufen ausbauen **und** den Stein
    /// bestellen. Wer erst bestellt, wenn die Treppe schon offen ist, wartet Wochen
    /// mit einem Loch vor der Haustür.
    @Test @MainActor func zweiStraengeStartenUnabhaengig() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []

        let startklar = auftraege.filter(\.istStartbar)
        #expect(startklar.count == 2,
                "startklar: \(startklar.map(Kausalkette.bezeichnung))")
        #expect(startklar.contains { Kausalkette.bezeichnung($0).contains("ausbauen") })
        #expect(startklar.contains { Kausalkette.bezeichnung($0).contains("bestellen") })
    }

    /// Der Punkt der Demo: Versetzen braucht den vorbereiteten Unterbau **und** den
    /// vom Steinmetz angepassten Stein.
    @Test @MainActor func versetzenWartetAufBeideStraenge() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []

        let versetzen = try schritt("versetzen", auftraege)
        let namen = versetzen.vorgaenger.map(Kausalkette.bezeichnung)

        #expect(versetzen.vorgaenger.count == 2, "Vorgänger: \(namen)")
        #expect(namen.contains { $0.contains("Unterbau") })
        #expect(namen.contains { $0.contains("Steinmetz") })
    }

    @Test @MainActor func fuenfKantenKeinKreis() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        let kanten = auftraege.flatMap { $0.voraussetzungenArray.filter(\.istKante) }

        #expect(kanten.count == 5)
        #expect(auftraege.contains { $0.istStartbar })   // ein Kreis würde alles blockieren
    }

    // MARK: - Der Termin

    /// Erster Freitag des Folgemonats, 08:00 — über mehrere Monate geprüft, damit
    /// die Rechnung nicht nur zufällig für den aktuellen Monat stimmt.
    @Test @MainActor func terminIstImmerDerErsteFreitagDesFolgemonats() throws {
        var kal = Calendar(identifier: .gregorian)
        kal.timeZone = TimeZone(identifier: "Europe/Berlin")!

        for monat in 1...12 {
            let start = try #require(kal.date(from: DateComponents(year: 2026, month: monat, day: 15)))
            let termin = SandsteinstufenSeeder.ersterFreitagImFolgemonat(nach: start, kalender: kal)
            let teile = kal.dateComponents([.year, .month, .day, .hour, .weekday], from: termin)

            #expect(teile.weekday == 6, "Monat \(monat): kein Freitag")
            #expect(teile.hour == 8, "Monat \(monat): nicht 08:00")
            // Erster Freitag heißt: spätestens am 7. des Monats.
            #expect((teile.day ?? 99) <= 7, "Monat \(monat): Tag \(teile.day ?? -1) ist nicht der erste Freitag")
            #expect(termin > start, "Monat \(monat): Termin liegt nicht in der Zukunft")
        }
    }

    @Test @MainActor func derBestellschrittTraegtDenKundentermin() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let event = try baustelle()
        let auftraege = (event.jobs?.allObjects as? [Auftrag]) ?? []

        let bestellen = try schritt("bestellen", auftraege)
        let extras = AuftragExtrasPayload.from(bestellen.extras)
        #expect(extras.deadline == event.eventStartTime)
    }

    // MARK: - Die Lücken

    /// **Lücke 1, dokumentiert statt versteckt:** `LVPosition` hat genau drei
    /// Kostenarten — Material, Lohn, Gerät. Für eine **Fremdleistung** (hier: der
    /// Steinmetz, 100 € fest) gibt es keinen Topf.
    ///
    /// Die 100 € sind deshalb **nicht** in der Kalkulation. Sie als Material oder
    /// Lohnstunde zu verbuchen wäre rechnerisch richtig und inhaltlich falsch. Der
    /// Test hält beides fest: dass das Feld fehlt, und dass niemand es getarnt hat.
    @Test @MainActor func fremdleistungHatKeineKostenart() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let pos = try #require((try baustelle().lvPositionen?.allObjects as? [LVPosition])?.first)

        let kostenarten = pos.entity.relationshipsByName.keys.filter { $0.hasPrefix("kalk") }.sorted()
        #expect(kostenarten == ["kalkGeraete", "kalkLohn", "kalkMaterialien"],
                "Kostenarten haben sich geändert: \(kostenarten)")
        #expect(!kostenarten.contains { $0.lowercased().contains("fremd") })

        // Und niemand hat den Steinmetz heimlich als Material oder Lohn eingebucht.
        let materialNamen = (pos.kalkMaterialien?.allObjects as? [PositionMaterial])?
            .compactMap(\.materialName) ?? []
        let lohnNamen = (pos.kalkLohn?.allObjects as? [PositionLohn])?
            .compactMap(\.qualifikation) ?? []
        #expect(!materialNamen.contains { $0.lowercased().contains("steinmetz") })
        #expect(!lohnNamen.contains { $0.lowercased().contains("steinmetz") })

        // Stattdessen steht sie im Klartext am Arbeitsschritt.
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        let steinmetz = try schritt("Steinmetz", auftraege)
        #expect(Kausalkette.bezeichnung(steinmetz).contains("100"))
    }

    /// **Lücke 2, dokumentiert:** `Auftrag` hat **kein Core-Data-Feld** für einen
    /// Termin. Es gibt `AuftragExtrasPayload.deadline`, aber das liegt als JSON in
    /// `extras` — man kann darauf **nicht per `NSPredicate` suchen**. Die Frage
    /// „welche Bestellung wird diese Woche fällig?" ist mit dem heutigen Modell
    /// nicht stellbar.
    @Test @MainActor func terminIstNichtAbfragbar() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)

        let felder = Auftrag.entity().attributesByName.keys.sorted()
        #expect(!felder.contains { $0.lowercased().contains("deadline") },
                "Auftrag hat plötzlich ein Termin-Feld: \(felder)")

        // Gegenprobe: Der Termin IST da — nur eben in JSON, unsichtbar für die Suche.
        let auftraege = (try baustelle().jobs?.allObjects as? [Auftrag]) ?? []
        let bestellen = try schritt("bestellen", auftraege)
        #expect(AuftragExtrasPayload.from(bestellen.extras).deadline != nil)
    }

    // MARK: - Idempotenz

    @Test @MainActor func zweiterLaufLegtNichtsDoppeltAn() throws {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)

        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-STUFEN-001")
        #expect(try ctx.count(for: r) == 1)
        #expect((try baustelle().jobs?.count ?? 0) == 6)
    }
}
