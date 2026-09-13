//
//  MaterialCheckTests.swift
//  Polier-Check „ist das Material da?" — Zustand (da/fehlt/ungeprüft) + Nachweis.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MaterialCheckTests {

    @Test func frischIstUngeprueft() {
        let item = AuftragLineItem(title: "Schotter 0/32")
        #expect(item.vorhanden == nil)
        #expect(item.geprueftVon == nil)
    }

    @Test func altesJSONOhneCheckBleibtLesbar() {
        // Rückwärtskompatibel: ein Material aus der Zeit vor dem Check.
        let alt = #"{"id":"m1","title":"Randsteine","amount":"40","unit":"Stk","note":"","kostenGruppeNummer":""}"#
            .data(using: .utf8)!
        let item = try! JSONDecoder().decode(AuftragLineItem.self, from: alt)
        #expect(item.title == "Randsteine")
        #expect(item.vorhanden == nil)
    }

    @Test func daUndFehltMitNachweisUeberstehenSpeichern() {
        var da = AuftragLineItem(title: "Pflaster")
        da.vorhanden = true
        da.geprueftVon = "Polier"
        da.geprueftAm = Date(timeIntervalSince1970: 1_700_000_000)

        var fehlt = AuftragLineItem(title: "Splitt")
        fehlt.vorhanden = false
        fehlt.geprueftVon = "Mitarbeiter"

        var e = AuftragExtrasPayload()
        e.lineItems = [da, fehlt]
        let back = AuftragExtrasPayload.from(e.toJSONString())

        #expect(back.lineItems[0].vorhanden == true)
        #expect(back.lineItems[0].geprueftVon == "Polier")
        #expect(back.lineItems[1].vorhanden == false)
    }
}
