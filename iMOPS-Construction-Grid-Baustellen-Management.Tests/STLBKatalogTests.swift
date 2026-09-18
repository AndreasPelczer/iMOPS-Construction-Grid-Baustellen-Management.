//
//  STLBKatalogTests.swift
//  Der STLB-Baustein-Katalog als Eingangstür fürs Text→Rezept:
//  Position → Baustein (über kurztext + tags) → aufwandswert_key → deterministischer Richtwert.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct STLBKatalogTests {

    @Test func yamlLaedtBausteine() async {
        let n = STLBKatalog.shared.bausteinCount()
        #expect(n >= 90)   // 94 Bausteine Stand YAML 1.0.0
    }

    /// Jeder Baustein nennt einen aufwandswert_key, der im Aufwandswerte-Katalog existiert.
    /// (Nach Raffis Ergänzung: keine GELB-ohne-Zeit-Lücke mehr.)
    @Test func alleBausteineHabenAufloesbarenKey() async {
        let bausteine = STLBKatalog.shared.alle()
        var fehlt: [String] = []
        for b in bausteine {
            guard let key = b.aufwandswertKey else { fehlt.append("\(b.id): kein key"); continue }
            if AufwandswerteKatalog.shared.eintrag(key: key) == nil { fehlt.append("\(b.id): \(key) fehlt") }
        }
        #expect(fehlt.isEmpty, "Bausteine ohne auflösbaren Aufwandswert: \(fehlt)")
    }

    /// Der Nordstern-Fall über den vollen Weg: Rohrgraben → ERD-008 → graben_ausheben (Baggerfahrer).
    @Test func rohrgrabenUeberSTLB() async {
        let b = STLBKatalog.shared.finde(leistung: "Rohrgraben herstellen DN 400")
        #expect(b?.id == "ERD-008")
        #expect(b?.aufwandswertKey == "erdarbeiten.graben_ausheben")
        let t = AufwandswerteKatalog.shared.eintrag(key: b!.aufwandswertKey!)
        #expect(t?.mittel == 0.30)
        #expect(t?.kolonne.contains("Baggerfahrer") == true)
        // Maschinen kommen direkt aus dem Baustein
        #expect(!MaschinenKatalog.shared.maschinen(ids: b!.maschinenKeys).isEmpty)
    }

    /// Synonym über die Tags: „Steinzeugrohr" trifft den Kanalrohr-Baustein.
    @Test func steinzeugTrifftKanalbaustein() async {
        let b = STLBKatalog.shared.finde(leistung: "Steinzeugrohr DN 400 verlegen")
        #expect(b?.id == "KAN-001")
        #expect(b?.aufwandswertKey == "kanalbau.kanalrohr_verlegen")
    }

    /// Material-Brücke: der Schüttgut-Baustein trägt jetzt seinen Material-Link
    /// (Text, Handelseinheit, Praxis-Richtpreis) — so findet die Auto-Bepreisung den Schotter.
    @Test func schuettgutBausteinTraegtMaterial() async {
        let sts = STLBKatalog.shared.finde(leistung: "Schottertragschicht 0/62mm, d= 10cm")
        #expect(sts?.id == "STR-002")
        #expect(sts?.material?.text == "Schotter 0/32")
        #expect(sts?.material?.einheit == "t")
        #expect(sts?.material?.richtpreis == 20)

        let fss = STLBKatalog.shared.finde(leistung: "Frostschutzschicht einbauen")
        #expect(fss?.material?.text == "Schotter 0/45")
        #expect(fss?.material?.richtpreis == 18)

        // Ein Baustein ohne Schüttgut hat keinen Material-Link (nicht erzwungen).
        let rohr = STLBKatalog.shared.finde(leistung: "Rohrgraben herstellen DN 400")
        #expect(rohr?.material == nil)
    }

    /// Raffis Ergänzung wirkt: Verkehrssicherung findet jetzt einen Baustein MIT Zeitwert.
    @Test func verkehrssicherungHatJetztZeit() async {
        let b = STLBKatalog.shared.finde(leistung: "Verkehrssicherung")
        #expect(b?.id == "BE-002")
        let t = AufwandswerteKatalog.shared.eintrag(key: b!.aufwandswertKey!)
        #expect(t?.mittel == 8.0)
    }

    /// Deterministischer Key-Lookup: Nonsense-Key → nil.
    @Test func keyLookupNonsenseNil() async {
        #expect(AufwandswerteKatalog.shared.eintrag(key: "gibtes.nicht") == nil)
    }
}
