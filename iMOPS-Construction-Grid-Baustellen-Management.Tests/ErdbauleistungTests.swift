//
//  ErdbauleistungTests.swift
//  Bagger-Stunden = Aushubmenge ÷ Leistung — nachvollziehbar statt geraten.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ErdbauleistungTests {

    @Test func stundenIstMengeDurchLeistung() {
        #expect(abs(Erdbauleistung.stunden(menge: 35.11, leistung: 4.4) - 7.979545) < 0.0001)
        #expect(Erdbauleistung.stunden(menge: 12, leistung: 12) == 1)
    }

    @Test func nullLeistungGibtNull() {
        #expect(Erdbauleistung.stunden(menge: 10, leistung: 0) == 0)
    }

    /// Andreas' vorsichtiger Praxiswert: bei 1 m³/h werden aus 35 m³ Aushub 35
    /// Stunden Bagger. Der Test hält die Größenordnung fest — falls jemand den
    /// Richtwert dorthin setzt, weiß er, was das bedeutet.
    @Test func einKubikProStundeMacht35Stunden() {
        #expect(Erdbauleistung.stunden(menge: 35.11, leistung: 1.0) == 35.11)
    }
}
