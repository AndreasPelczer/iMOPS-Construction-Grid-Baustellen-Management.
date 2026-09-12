//
//  KatalogSichtenUndMasseTests.swift
//  13.09. — Katalog-Sichten zusammenführen + Größe ans Event.
//
//  Deterministischer Nachweis (kein Netz, keine UI):
//   Teil A  Der gemeinsame Lohn-Schreiber `schreibeAufwandAlsLohn` — den nutzen der
//           Grap8-Knoten UND der Picker „Aus deinen Baustellen". Schreibt Maurer/Helfer
//           mit Stammdaten-Satz, idempotent (zweiter Aufruf ersetzt statt zu stapeln).
//   Teil B  Das Event speichert die Maße (Grundfläche/Umfang/Geschosse) über einen
//           Speicher-/Ladezyklus.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct KatalogSichtenUndMasseTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    // MARK: - Teil A: gemeinsamer Lohn-Schreiber

    @Test @MainActor func aufwandAlsLohnSchreibtMitStammdatenSatzUndIstIdempotent() throws {
        StammdatenSeeder.seedIfNeeded(context: ctx)
        let maurerBrutto = 28.50 * 1.65
        let helferBrutto = 18.50 * 1.55

        let event = Event(context: ctx)
        let pos = LVPosition(context: ctx)
        pos.bezeichnung = "Baustelle absichern"
        pos.menge = 4
        pos.einheit = "psch"
        pos.event = event

        LeistungskatalogService.schreibeAufwandAlsLohn(maurer: 0.5, helfer: 1.5, auf: pos, in: ctx)
        try ctx.save()

        #expect(pos.lohnArray.count == 2)
        let maurer = try #require(pos.lohnArray.first { $0.qualifikation == "Maurer" })
        let helfer = try #require(pos.lohnArray.first { $0.qualifikation == "Helfer" })
        #expect(maurer.stunden == 0.5)
        #expect(helfer.stunden == 1.5)
        #expect(abs(maurer.stundenBruttoEK - maurerBrutto) < 0.001)
        #expect(abs(helfer.stundenBruttoEK - helferBrutto) < 0.001)

        // Zweiter Aufruf ersetzt (idempotent) — keine vier Zeilen.
        LeistungskatalogService.schreibeAufwandAlsLohn(maurer: 1.0, helfer: 2.0, auf: pos, in: ctx)
        try ctx.save()
        #expect(pos.lohnArray.count == 2, "Die Lohnzeilen wurden gestapelt statt ersetzt.")
        #expect(pos.lohnArray.first { $0.qualifikation == "Maurer" }?.stunden == 1.0)

        // Und die Kette Stunden × Menge × Satz trägt eine echte Summe.
        let lohnGesamt = pos.lohnArray.reduce(0) { $0 + $1.kostenProEinheit } * pos.effektiveMenge
        #expect(lohnGesamt > 0)
    }

    // MARK: - Teil B: Event speichert die Maße

    @Test @MainActor func eventSpeichertMasse() throws {
        let event = Event(context: ctx)
        event.name = "Testbaustelle"
        event.grundflaeche = 120.5
        event.umfang = 44.0
        event.geschosse = 2
        try ctx.save()

        // Frisch aus dem Store holen (round-trip).
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "name == %@", "Testbaustelle")
        let geladen = try #require(try ctx.fetch(r).first)
        #expect(geladen.grundflaeche == 120.5)
        #expect(geladen.umfang == 44.0)
        #expect(geladen.geschosse == 2)
    }

    // Default 0 = „nicht gesetzt" — ein frisches Event trägt keine erfundene Größe.
    @Test @MainActor func neuesEventHatKeineMasse() throws {
        let event = Event(context: ctx)
        event.name = "Ohne Maße"
        try ctx.save()
        #expect(event.grundflaeche == 0)
        #expect(event.umfang == 0)
        #expect(event.geschosse == 0)
    }
}
