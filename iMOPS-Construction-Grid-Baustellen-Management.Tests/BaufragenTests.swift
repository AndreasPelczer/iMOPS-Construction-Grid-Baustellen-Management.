//
//  BaufragenTests.swift
//  Hält den Baufragen-Seed sauber: jede Frage 4 Antworten, gültiger Lösungsindex,
//  eindeutige IDs, nichts leer. Eine kaputte Frage soll hier auffallen, nicht im Spiel.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BaufragenTests {

    @Test func jedeFrageIstWohlgeformt() {
        for f in Baufragen.alle {
            #expect(f.antworten.count == 4, "Frage \(f.id) braucht genau 4 Antworten")
            #expect(f.richtige >= 0 && f.richtige < f.antworten.count, "Frage \(f.id): Lösungsindex ungültig")
            #expect(!f.frage.trimmingCharacters(in: .whitespaces).isEmpty)
            #expect(!f.erklaerung.trimmingCharacters(in: .whitespaces).isEmpty)
            #expect(f.antworten.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        }
    }

    @Test func idsSindEindeutig() {
        let ids = Baufragen.alle.map(\.id)
        #expect(Set(ids).count == ids.count, "Doppelte Frage-IDs")
    }

    @Test func rundeLiefertGemischteTeilmenge() {
        let r = Baufragen.runde(anzahl: 5)
        #expect(r.count == 5)
        #expect(Set(r.map(\.id)).count == 5)          // keine Dopplung in einer Runde
        // mehr angefordert als vorhanden → gekappt, kein Absturz
        #expect(Baufragen.runde(anzahl: 999).count == Baufragen.alle.count)
    }
}
