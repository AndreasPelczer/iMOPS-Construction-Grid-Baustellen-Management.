//
//  UebergabeNachweisTests.swift
//  Übergabe sichern: der Beleg (wer/wann) am Arbeitsschritt.
//
//  Prüft die persistierbare Wahrheit: alte Checklisten (ohne die neuen Felder)
//  bleiben lesbar, und ein Übergabe-Beleg übersteht Speichern → Laden.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct UebergabeNachweisTests {

    @Test func altesJSONOhneUebergabeBleibtLesbar() {
        // Rückwärtskompatibel: ein Schritt aus der Zeit vor dem Nachweis decodiert sauber.
        let alt = #"{"id":"x","title":"Schotter einbauen","isDone":true}"#.data(using: .utf8)!
        let item = try! JSONDecoder().decode(AuftragChecklistItem.self, from: alt)
        #expect(item.title == "Schotter einbauen")
        #expect(item.isDone)
        #expect(item.uebernommenVon == nil)
        #expect(item.uebernommenAm == nil)
    }

    @Test func belegUeberstehtSpeichernUndLaden() {
        var item = AuftragChecklistItem(title: "Tragschicht verdichten")
        item.isDone = true
        item.uebernommenVon = "Leitung"
        item.uebernommenAm = Date(timeIntervalSince1970: 1_700_000_000)

        let data = try! JSONEncoder().encode(item)
        let zurueck = try! JSONDecoder().decode(AuftragChecklistItem.self, from: data)

        #expect(zurueck.uebernommenVon == "Leitung")
        #expect(zurueck.uebernommenAm == item.uebernommenAm)
    }

    @Test func ganzeCheckliste_imPayload_traegtDenBeleg() {
        var payload = AuftragExtrasPayload()
        var s = AuftragChecklistItem(title: "Randeinfassung setzen")
        s.isDone = true
        s.uebernommenVon = "Mitarbeiter"
        s.uebernommenAm = Date()
        payload.checklist = [s]

        let json = try! JSONEncoder().encode(payload)
        let back = try! JSONDecoder().decode(AuftragExtrasPayload.self, from: json)
        #expect(back.checklist.first?.uebernommenVon == "Mitarbeiter")
    }
}
