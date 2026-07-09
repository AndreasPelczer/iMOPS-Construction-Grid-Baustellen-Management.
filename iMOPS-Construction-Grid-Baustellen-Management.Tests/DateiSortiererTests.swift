//
//  DateiSortiererTests.swift
//  Der Sortier-Wächter der „einen Tür": Dateiname → richtiger Korb.
//  Getestet an echten Schwarz-Marktbreit-Dateinamen.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct DateiSortiererTests {

    @Test func statikPlaeneLandenBeiStatik() {
        let namen = [
            "448-GO B 6 Ringbalken.pdf",
            "448-GO B 1.1 BoPla untere Lage.pdf",
            "448-GO B 2 Stb.- Stützen.pdf",
            "448-GO B 4 Decke obere Lage.pdf",
            "448-GO B 7 GiebelMW.pdf",
        ]
        for n in namen {
            #expect(DateiSortierer.sortiere(n) == .statik, "\(n) sollte Statik sein")
        }
    }

    @Test func faktenUnterlagenLandenBeiFakten() {
        #expect(DateiSortierer.sortiere("Bodengutachten Schwarz.pdf") == .fakten)
        #expect(DateiSortierer.sortiere("Erschließungsplan Marktbreit.pdf") == .fakten)
        #expect(DateiSortierer.sortiere("Bebauungsplan_WA3.pdf") == .fakten)
    }

    @Test func angeboteUndSonstigesLandenBeiAblegen() {
        #expect(DateiSortierer.sortiere("Angebot 67774 BV Schwarz Marktbreit.pdf") == .ablegen)
        #expect(DateiSortierer.sortiere("gespraech_vorarbeiter.pdf") == .ablegen)
        #expect(DateiSortierer.sortiere("Bestellliste_BV_Schwarz.xlsx") == .ablegen)
        #expect(DateiSortierer.sortiere("Foto_Baustelle.jpg") == .ablegen)
        // kryptischer Name ohne Signal → ablegen (Mensch korrigiert im Sheet)
        #expect(DateiSortierer.sortiere("260402_1545_Schwarz_WP_kk.PDF") == .ablegen)
    }
}
