//
//  BaunormenTests.swift
//  Nachweis für die Normen-Spur: welche DIN eine Leistung berührt.
//

import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct BaunormenTests {

    private func ids(_ texte: [String], hatLV: Bool = true) -> [String] {
        Baunormen.berührt(vonLeistungen: texte, hatLV: hatLV).map(\.id)
    }

    @Test func pflasterBeruehrtVerlegeUndProduktnorm() {
        let n = ids(["Betonpflaster verlegen, abrütteln"])
        #expect(n.contains("DIN 18318"))   // Verlegen (VOB/C)
        #expect(n.contains("DIN EN 1338")) // Produktnorm Pflasterstein
    }

    @Test func schotterBeruehrtOberbauUndKoernung() {
        let n = ids(["Schottertragschicht 0/32, 10 cm"])
        #expect(n.contains("DIN 18315"))    // Oberbau ohne Bindemittel
        #expect(n.contains("DIN EN 13242")) // Gesteinskörnungen
    }

    @Test func einrichtungUndErdarbeit() {
        #expect(ids(["Baustelleneinrichtung"]).contains("DIN 18299"))
        #expect(ids(["Mutterboden abtragen & lagern"]).contains("DIN 18300"))
        #expect(ids(["Aushub Planum herstellen"]).contains("DIN 18300"))
    }

    @Test func randeinfassungBeruehrtBordProduktnorm() {
        let n = ids(["Randeinfassung Tiefbord in Beton"])
        #expect(n.contains("DIN EN 1340"))  // Bordsteine aus Beton
        #expect(n.contains("DIN 18318"))    // Einfassungen (VOB/C)
    }

    @Test func din276GiltNurWennEsEinLVGibt() {
        // Kein Stichwort, aber ein LV vorhanden → DIN 276 (Kostengliederung).
        #expect(ids(["irgendeine freie Leistung"], hatLV: true).contains("DIN 276"))
        // Kein LV → keine DIN 276.
        #expect(!ids(["irgendeine freie Leistung"], hatLV: false).contains("DIN 276"))
    }

    @Test func jedeNormNurEinmalUndInKatalogReihenfolge() {
        // Zwei Pflaster-Positionen → DIN 18318 trotzdem nur einmal.
        let n = ids(["Betonpflaster verlegen", "Pflaster Halbsteine einpassen"])
        #expect(n.filter { $0 == "DIN 18318" }.count == 1)
        // Reihenfolge folgt dem Katalog (Bauablauf), nicht der Eingabe.
        let voll = ids(["Betonpflaster verlegen", "Schottertragschicht", "Baustelleneinrichtung"])
        let katalog = Baunormen.alle.map(\.id)
        #expect(voll == katalog.filter { voll.contains($0) })
    }

    @Test func nichtsBeruehrtNichts() {
        #expect(ids(["Kaffee kochen"], hatLV: false).isEmpty)
    }
}
