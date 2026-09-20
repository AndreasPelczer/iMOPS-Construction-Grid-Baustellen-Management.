//
//  KnotenAufwandswertTests.swift
//  Bogen 0 — Aufwandswert an den Grap8-Knoten. Der belastbare Nachweis.
//
//  Draht 2 (die Prof-Frage) ist ein Netzaufruf und wird morgen früh von Hand am
//  echten Knoten geprüft. Was hier deterministisch fällt, sind die beiden anderen:
//
//   Draht 1  Die neue Beziehung `Auftrag.lvPosition` ⇄ `LVPosition.auftrag` steht im
//            Modell und trägt in beide Richtungen. Das ist die Modell-Änderung, die
//            der Auftrag „bewusst + sauber" verlangt — hier festgenagelt.
//
//   Draht 3  Der Vorschlag `(maurer, helfer)` landet als ZAHL: zwei `PositionLohn`
//            mit `stunden` (h/Einheit) × `stundenBruttoEK` (Lohnsatz aus Stammdaten).
//            Der Test rechnet Maurer-h × Menge × Lohnsatz + Helfer-h × Menge × Lohnsatz
//            nach — genau das, was `KnotenKalkulationView` schreibt.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct KnotenAufwandswertTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Fixture: die zwei Lohnsätze, die früher der (entfernte) StammdatenSeeder anlegte.
    @MainActor
    private func seedMaurerHelfer(_ ctx: NSManagedObjectContext) {
        for (q, l, f) in [("Maurer", 28.50, 1.65), ("Helfer", 18.50, 1.55)] {
            let ls = Lohnsatz(context: ctx)
            ls.id = UUID(); ls.qualifikation = q; ls.stundenlohn = l; ls.zuschlagFaktor = f
        }
        try? ctx.save()
    }

    // MARK: - Draht 1: der Knoten trägt seine eigene Position

    @Test @MainActor func knotenBekommtEigenePositionUndFindetSieZurueck() throws {
        let event = Event(context: ctx)
        event.name = "Testbaustelle"

        let auftrag = neuerAuftrag(event, text: "Baustelle absichern")

        let pos = LVPosition(context: ctx)
        pos.bezeichnung = Kausalkette.bezeichnung(auftrag)
        pos.menge = 1
        pos.einheit = "psch"
        pos.event = event
        auftrag.lvPosition = pos

        try ctx.save()

        // Hin: vom Knoten zur Position.
        #expect(auftrag.lvPosition?.bezeichnung == "Baustelle absichern")
        // Zurück: die Position kennt ihren Knoten (Inverse).
        #expect(pos.auftrag === auftrag)
        // Und sie hängt weiterhin ganz normal an der Baustelle.
        #expect(pos.event === event)
    }

    // MARK: - Draht 3: die Stunden werden zur kalkulierten Lohnsumme

    @Test @MainActor func aufwandswertLandetAlsLohnMalMengeMalSatz() throws {
        seedMaurerHelfer(ctx)

        // Die Stammdaten-Vorlagen, aus denen der Brutto-EK-Satz kommt.
        let maurerSatz = try #require(lohnsatz("Maurer"))
        let helferSatz = try #require(lohnsatz("Helfer"))

        let event = Event(context: ctx)
        let auftrag = neuerAuftrag(event, text: "Baustelle absichern")

        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Baustelle absichern"
        pos.menge = 4          // 4 Einheiten, von Hand
        pos.einheit = "psch"
        pos.event = event
        auftrag.lvPosition = pos

        // Der Prof-Vorschlag (hier fest gesetzt statt gefragt).
        let vorschlag = (maurer: 0.5, helfer: 1.5)   // h je Einheit

        for (quali, stunden, satz) in [("Maurer", vorschlag.maurer, maurerSatz),
                                       ("Helfer", vorschlag.helfer, helferSatz)] {
            let pl = PositionLohn(context: ctx)
            pl.id = UUID()
            pl.qualifikation = quali
            pl.stunden = stunden
            pl.stundenBruttoEK = satz.berechnungBruttoEK
            pl.position = pos
        }
        try ctx.save()

        // Es sind Zahlen, kein Text: zwei Lohnzeilen hängen an der Position.
        #expect(pos.lohnArray.count == 2)

        // Nachgerechnet: (h/E × Satz) je Zeile, dann × Menge.
        let erwartetJeEinheit = vorschlag.maurer * maurerSatz.berechnungBruttoEK
                              + vorschlag.helfer * helferSatz.berechnungBruttoEK
        let istJeEinheit = pos.lohnArray.reduce(0) { $0 + $1.kostenProEinheit }
        #expect(abs(istJeEinheit - erwartetJeEinheit) < 0.001)

        let lohnGesamt = istJeEinheit * pos.effektiveMenge
        #expect(abs(lohnGesamt - erwartetJeEinheit * 4) < 0.001)
        // Ein echter Betrag, nicht 0 — die Kette Menge → Satz → Summe trägt.
        #expect(lohnGesamt > 0)
    }

    /// Ein gültiger Auftrag wie ihn die App anlegt. `statusRawValue` und `storageNote`
    /// sind im Modell Pflicht (kein Default) — ohne sie scheitert `save()` an der
    /// Validierung. Das Feature legt selbst NIE einen Auftrag an (es hängt eine
    /// Position an einen bestehenden), darum ist das reine Test-Vorbereitung.
    @MainActor
    private func neuerAuftrag(_ event: Event, text: String) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.processingDetails = text
        a.status = .pending          // setzt statusRawValue
        a.storageNote = ""
        a.event = event
        return a
    }

    @MainActor
    private func lohnsatz(_ quali: String) -> Lohnsatz? {
        let r: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        r.predicate = NSPredicate(format: "qualifikation ==[c] %@", quali)
        r.fetchLimit = 1
        return (try? ctx.fetch(r))?.first
    }
}
