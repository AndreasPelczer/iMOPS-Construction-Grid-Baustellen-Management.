//
//  AuftragTemplateMatchTests.swift
//  Auto-Vorausfuellen: die passende Vorlage aus der Aufgaben-Beschreibung erkennen.
//
//  Prueft AuftragTemplate.passend(zu:) — Stichwort-Treffer je Gewerk, und dass ohne
//  Treffer ehrlich nil zurueckkommt (dann keine Checkliste, kein Raten).
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct AuftragTemplateMatchTests {

    @Test func erkenntTragschichtAusAufgabe() {
        #expect(AuftragTemplate.passend(zu: "Tragschicht Mineralgemisch 0/32 einbauen + verdichten") == .tragschicht)
    }

    @Test func gewerkUnterbauZaehltAlsTragschicht() {
        #expect(AuftragTemplate.passend(zu: "Unterbau herstellen") == .tragschicht)
    }

    @Test func erkenntPflasterUndRandeinfassung() {
        #expect(AuftragTemplate.passend(zu: "Pflasterbelag verlegen") == .pflasterverlegen)
        #expect(AuftragTemplate.passend(zu: "Randeinfassung Leistensteine setzen") == .randeinfassung)
    }

    @Test func erkenntTrennvlies() {
        #expect(AuftragTemplate.passend(zu: "Trennvlies verlegen") == .trennvlies)
        #expect(AuftragTemplate.passend(zu: "Geotextil auslegen") == .trennvlies)
    }

    @Test func ohneTrefferNil() {
        #expect(AuftragTemplate.passend(zu: "Kaffee kochen") == nil)
        #expect(AuftragTemplate.passend(zu: "") == nil)
    }

    @Test func trennvliesHatEigeneSchritte() {
        // "Keine gesetzliche Vorlage" -> selbst beschrieben, aber vollstaendig.
        #expect(AuftragTemplate.trennvlies.steps.count >= 6)
        #expect(AuftragTemplate.trennvlies.steps.contains { $0.contains("ueberlappen") })
    }
}
