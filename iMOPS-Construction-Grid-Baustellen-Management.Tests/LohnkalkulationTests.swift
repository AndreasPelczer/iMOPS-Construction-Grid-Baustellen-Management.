//
//  LohnkalkulationTests.swift
//  Ehrliche Kalkulation: Kostenseite (Vollkosten, Mittellohn) + Aufschlags-Kette.
//
//  Nachweis gegen die Orakel: Vollkosten = Brutto × 1,85, Mittellohn 37,81 €/h,
//  und das 74-ORAKEL — die 74 ist der Verrechnungssatz (Ergebnis der Kette), kein Lohn.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LohnkalkulationTests {

    private func lg(_ kuerzel: String) -> Lohngruppe {
        LohnkalkulationDefaults.lohngruppen.first { $0.kuerzel == kuerzel }!
    }

    @Test func vollkostenOrakel() {
        let f = 1.85
        #expect(abs(lg("LG1").vollkosten(nebenkostenFaktor: f) - 31.45) < 0.01)   // 17 × 1,85
        #expect(abs(lg("LG4").vollkosten(nebenkostenFaktor: f) - 38.85) < 0.01)   // 21 × 1,85
        #expect(abs(lg("LG6").vollkosten(nebenkostenFaktor: f) - 52.725) < 0.01)  // 28,5 × 1,85
    }

    @Test func mittellohnOrakel_37_81() {
        // Beispiel-Kolonne: 1 Polier + 4 Spezialfacharbeiter + 3 Hilfsarbeiter.
        let kolonne = [
            KolonnenPosten(lohngruppe: lg("LG6"), anzahl: 1),
            KolonnenPosten(lohngruppe: lg("LG4"), anzahl: 4),
            KolonnenPosten(lohngruppe: lg("LG1"), anzahl: 3),
        ]
        let m = Mittellohn.berechne(kolonne: kolonne, nebenkostenFaktor: 1.85)
        #expect(abs(m - 37.81) < 0.01)
    }

    @Test func ketteNettoUndBrutto() {
        let k = Aufschlagskette(bgk: 0.10, agk: 0.10, wagnisGewinn: 0.08,
                                skonto: 0.025, mwstSatz: 0.19)
        #expect(abs(k.firmenzuschlag - 0.33947) < 0.001)     // 1,10·1,10·1,08·1,025 − 1
        let netto = k.nettoAngebot(selbstkosten: 10_000)
        #expect(abs(netto - 13_394.7) < 1.0)
        #expect(abs(k.bruttoAngebot(selbstkosten: 10_000) - netto * 1.19) < 0.5)
    }

    @Test func orakel74_istErgebnisNichtInput() {
        // Die bekannte Wahrheit: Verrechnungssatz Facharbeiter = 74 €/h.
        let vollkosten = 38.85                                  // LG4, die KOSTEN
        // Der EINE (vertrauliche) Firmenzuschlag, der 74 reproduziert:
        let zuschlag = Aufschlagskette.firmenzuschlag(ausVollkosten: vollkosten, verrechnungssatz: 74.0)
        #expect(abs(vollkosten * (1 + zuschlag) - 74.0) < 0.01) // ← die Kette TRIFFT die 74

        // Und der generische Default trifft die 74 NICHT — die Differenz ist Firmensache
        // (Geschäftsgeheimnis), nicht im Code.
        let generisch = vollkosten * (1 + LohnkalkulationDefaults.kette.firmenzuschlag)
        #expect(generisch < 74.0)                              // ~52 €/h, nicht 74
        #expect(zuschlag > LohnkalkulationDefaults.kette.firmenzuschlag)
    }
}
