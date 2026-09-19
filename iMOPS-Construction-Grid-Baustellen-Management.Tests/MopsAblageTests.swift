//
//  MopsAblageTests.swift
//  Beweis: Baustellen-Namen werden zu sicheren Ordnernamen (Schrägstrich würde sonst
//  einen Unterordner erzeugen), leere Namen fallen sauber raus.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MopsAblageTests {

    @Test func normalerNameBleibt() {
        #expect(MopsAblage.sichererOrdnername("Setiadji-Baustelle") == "Setiadji-Baustelle")
    }

    @Test func schraegstrichWirdBindestrich() {
        // Sonst würde "Haus 2" ein Unterordner von "BV Müller" — nicht gewollt.
        #expect(MopsAblage.sichererOrdnername("BV Müller / Haus 2") == "BV Müller - Haus 2")
    }

    @Test func doppelpunktWirdBindestrich() {
        #expect(MopsAblage.sichererOrdnername("A:B") == "A-B")
    }

    @Test func leererNameGibtNil() {
        #expect(MopsAblage.sichererOrdnername("   ") == nil)
        #expect(MopsAblage.sichererOrdnername("") == nil)
    }

    @Test func sechsDokumentFaecher() {
        #expect(MopsAblage.baustellenFaecher.count == 6)
        #expect(MopsAblage.baustellenFaecher.contains("Statik"))
        #expect(MopsAblage.baustellenFaecher.contains("Genehmigung"))
    }
}
