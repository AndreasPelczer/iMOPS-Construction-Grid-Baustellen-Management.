//
//  LagerStoreTests.swift
//  Nachweis fürs Lager: Bestand = Summe der Buchungen (konform), Umlagerung
//  ausgeglichen, Inventur setzt den Ist-Wert, Meldebestand, Materialstatus.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LagerStoreTests {

    /// Frischer Store auf einer eigenen Temp-Datei — kein geteilter Zustand.
    private func store() -> LagerStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lager-test-\(UUID().uuidString).json")
        return LagerStore(fileURL: url)
    }

    @Test func bestandIstDieSummeDerBuchungen() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        s.eingang(artikelCode: "SCH-032", name: "Schotter 0/32", einheit: "to", menge: 10, lagerortID: hof.id)
        s.ausgang(artikelCode: "SCH-032", name: "Schotter 0/32", einheit: "to", menge: 3, lagerortID: hof.id)
        #expect(s.bestand(artikelCode: "SCH-032", lagerortID: hof.id) == 7)
        #expect(s.gesamtbestand(artikelCode: "SCH-032") == 7)
    }

    @Test func bestandGetrenntJeLagerort() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        let halle = s.addLagerort(name: "Halle")
        s.eingang(artikelCode: "PFL-VBS", name: "Pflaster", einheit: "m²", menge: 100, lagerortID: hof.id)
        s.eingang(artikelCode: "PFL-VBS", name: "Pflaster", einheit: "m²", menge: 40, lagerortID: halle.id)
        #expect(s.bestand(artikelCode: "PFL-VBS", lagerortID: hof.id) == 100)
        #expect(s.bestand(artikelCode: "PFL-VBS", lagerortID: halle.id) == 40)
        #expect(s.gesamtbestand(artikelCode: "PFL-VBS") == 140)
        #expect(s.bestandJeOrt(artikelCode: "PFL-VBS").count == 2)
    }

    @Test func umlagerungLaesstDenGesamtbestand() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        let baustelle = s.addLagerort(name: "Depot")
        s.eingang(artikelCode: "SPL-208", name: "Splitt", einheit: "to", menge: 10, lagerortID: hof.id)
        s.umlagern(artikelCode: "SPL-208", name: "Splitt", einheit: "to", menge: 4,
                   vonOrt: hof.id, nachOrt: baustelle.id)
        #expect(s.bestand(artikelCode: "SPL-208", lagerortID: hof.id) == 6)
        #expect(s.bestand(artikelCode: "SPL-208", lagerortID: baustelle.id) == 4)
        #expect(s.gesamtbestand(artikelCode: "SPL-208") == 10)   // nichts verschwindet
    }

    @Test func inventurSetztDenGezaehltenWert() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        s.eingang(artikelCode: "FUG-02", name: "Fugensand", einheit: "to", menge: 7, lagerortID: hof.id)
        // Gezählt sind nur 5 (Schwund/Rest) → Bestand danach exakt 5.
        s.inventur(artikelCode: "FUG-02", name: "Fugensand", einheit: "to", gezaehlt: 5, lagerortID: hof.id)
        #expect(s.bestand(artikelCode: "FUG-02", lagerortID: hof.id) == 5)
    }

    @Test func meldebestandFindetWasNachbestelltWerdenMuss() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        s.eingang(artikelCode: "RND-TB", name: "Randstein", einheit: "Stk", menge: 8, lagerortID: hof.id)
        s.setMindestbestand(artikelCode: "RND-TB", schwelle: 20)
        let unter = s.unterMindestbestand()
        #expect(unter.contains { $0.code == "RND-TB" && $0.bestand == 8 && $0.schwelle == 20 })
    }

    @Test func materialstatusDreiZustaende() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        // Nichts gebucht, nicht bestellt → zu bestellen.
        #expect(Materialstatus.fuer(artikelCode: "VLI-GEO", bestellt: false, store: s) == .zuBestellen)
        // Als bestellt markiert schlägt alles.
        #expect(Materialstatus.fuer(artikelCode: "VLI-GEO", bestellt: true, store: s) == .bestellt)
        // Im Lager → auf Lager (mit Menge).
        s.eingang(artikelCode: "VLI-GEO", name: "Trennvlies", einheit: "m²", menge: 50, lagerortID: hof.id)
        #expect(Materialstatus.fuer(artikelCode: "VLI-GEO", bestellt: false, store: s) == .aufLager(menge: 50, einheit: "m²"))
    }

    @Test func lagerortLoeschenNurWennLeer() {
        let s = store()
        let hof = s.addLagerort(name: "Hof")
        s.eingang(artikelCode: "BET-C16", name: "Beton", einheit: "m³", menge: 1, lagerortID: hof.id)
        #expect(s.removeLagerort(hof.id) == false)     // Bestand da → bleibt
        s.ausgang(artikelCode: "BET-C16", name: "Beton", einheit: "m³", menge: 1, lagerortID: hof.id)
        // Jetzt Bestand 0, aber es gibt Buchungen → wir schützen trotzdem (Historie).
        #expect(s.removeLagerort(hof.id) == false)
        let leer = s.addLagerort(name: "Leer")
        #expect(s.removeLagerort(leer.id) == true)     // nie bebucht → weg
    }
}
