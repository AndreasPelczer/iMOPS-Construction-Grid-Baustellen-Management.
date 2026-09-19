//
//  ZeitformatTests.swift
//  Beweis: Dezimalstunden werden menschlich (Stunden + Minuten) — für den Bau-Mann,
//  der „1,8 Stunden" nicht als Zeit erfassen kann.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct ZeitformatTests {
    @Test func stundenUndMinuten() { #expect(Zeitformat.menschlich(1.8) == "1 Std 48 Min") }
    @Test func volleStunde()       { #expect(Zeitformat.menschlich(2.0) == "2 Std") }
    @Test func nurMinuten()        { #expect(Zeitformat.menschlich(0.5) == "30 Min") }
    @Test func kleineMenge()       { #expect(Zeitformat.menschlich(0.03) == "2 Min") }
    @Test func grosseMenge()       { #expect(Zeitformat.menschlich(15.6) == "15 Std 36 Min") }
    @Test func null()              { #expect(Zeitformat.menschlich(0) == "0 Min") }
}
