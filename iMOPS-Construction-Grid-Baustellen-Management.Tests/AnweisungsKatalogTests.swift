//
//  AnweisungsKatalogTests.swift
//
//  „Wer eine Anweisung einmal schreibt, schreibt sie für alle."
//  Der wichtigste Test ist `ungepruefteVermehrenSichNicht` — sonst würde ein
//  KI-Vorschlag, den niemand abgenommen hat, über den Katalog auf jede weitere
//  Baustelle wandern und dort wie geprüftes Wissen aussehen.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct AnweisungsKatalogTests {

    private func frisch() -> AnweisungsKatalog {
        let k = AnweisungsKatalog.shared
        k.leerenFuerTests()
        return k
    }

    private func abgenommen(_ text: String) -> AnweisungsSchritt {
        AnweisungsSchritt(text: text, herkunft: .prof,
                          abgenommenVon: "Raphael", abgenommenAm: Date())
    }

    /// Einmal gemerkt, beim nächsten Auftrag vorgeschlagen.
    @Test func einmalGeschriebenUeberallVorgeschlagen() {
        let k = frisch()
        defer { k.leerenFuerTests() }

        k.merken([abgenommen("Kimmschicht ausrichten"),
                  abgenommen("Erste Lage im Normalmoertel setzen")],
                 fuer: "Kimmschicht Ytong 24 cm, 2 Lagen")

        // Andere Baustelle, andere Schreibweise — derselbe Eintrag.
        let gefunden = k.schritte(fuer: "KIMMSCHICHT  YTONG, 24cm — 2 LAGEN")
        #expect(gefunden?.count == 2)
        #expect(gefunden?.first?.text == "Kimmschicht ausrichten")
        #expect(gefunden?.first?.herkunft == .katalog, "kommt aus dem Katalog, nicht neu vom Prof")
    }

    /// 🔴 Ungeprüfte Vorschläge dürfen sich NICHT selbst vermehren.
    @Test func ungepruefteVermehrenSichNicht() {
        let k = frisch()
        defer { k.leerenFuerTests() }

        let roh = [AnweisungsSchritt(text: "Irgendwas verdichten", herkunft: .prof),
                   AnweisungsSchritt(text: "Auf 95 % bringen", herkunft: .prof, traegtWert: true)]
        let gemerkt = k.merken(roh, fuer: "Tragschicht herstellen")

        #expect(gemerkt == 0, "nichts abgenommen, nichts gemerkt")
        #expect(k.schritte(fuer: "Tragschicht herstellen") == nil)
    }

    /// Selbst getippte Schritte wandern mit — wer tippt, steht dafür.
    @Test func selbstGetipptesWandertMit() {
        let k = frisch()
        defer { k.leerenFuerTests() }

        let mischung = [AnweisungsSchritt(text: "Bauzaun stellen", herkunft: .selbst),
                        AnweisungsSchritt(text: "Ungeprüfter Vorschlag", herkunft: .prof)]
        #expect(k.merken(mischung, fuer: "Baustelle einrichten") == 1)
        #expect(k.schritte(fuer: "Baustelle einrichten")?.count == 1)
    }

    /// Der Schlüssel ignoriert Mengen und Sonderzeichen, aber nicht das Thema.
    @Test func derSchluesselTrifftDasselbeUndNichtMehr() {
        // Gleicher Inhalt, andere Schreibweise: Groß/klein, Leerzeichen, Komma,
        // und „24 cm" gegen „24cm" — muss denselben Schlüssel ergeben.
        let a = AnweisungsKatalog.schluessel("Kimmschicht Ytong 24 cm, 2 Lagen")
        let b = AnweisungsKatalog.schluessel("KIMMSCHICHT  YTONG, 24cm — 2 LAGEN")
        #expect(a == b, "a=\(a) b=\(b)")

        let c = AnweisungsKatalog.schluessel("Estrich abziehen")
        #expect(a != c, "verschiedene Arbeiten bleiben verschieden")
        #expect(AnweisungsKatalog.schluessel("   ").isEmpty)
    }

    /// Zählt mit, wie oft eine Anweisung gebraucht wurde — wie bei den Rezepten.
    @Test func verwendungenWerdenGezaehlt() {
        let k = frisch()
        defer { k.leerenFuerTests() }

        k.merken([abgenommen("Schritt A")], fuer: "Pflaster verlegen")
        k.merken([abgenommen("Schritt A"), abgenommen("Schritt B")], fuer: "Pflaster verlegen")

        let b = k.bestand()
        #expect(b.count == 1)
        #expect(b.first?.verwendungen == 2)
        #expect(b.first?.schritte == 2, "die neuere Fassung gilt")
    }
}
