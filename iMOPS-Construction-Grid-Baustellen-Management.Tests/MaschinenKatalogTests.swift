//
//  MaschinenKatalogTests.swift
//  Der Maschinenkatalog und seine Verzahnung mit den Aufwandswerten:
//  zur LV-Tätigkeit (z.B. Rohrgraben) kennt der Mops die passenden Bagger + Miete.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MaschinenKatalogTests {

    @Test func yamlLaedtMaschinen() async {
        let n = MaschinenKatalog.shared.maschinenCount()
        #expect(n >= 40)   // 45 Maschinen Stand YAML 1.0.0
    }

    /// Der Rohrgraben (erdarbeiten.graben_ausheben) muss Bagger vorschlagen — mit Leistung + Miete.
    @Test func rohrgrabenSchlaegtBaggerVor() async {
        let m = MaschinenKatalog.shared.fuerTaetigkeit("erdarbeiten.graben_ausheben")
        #expect(!m.isEmpty)
        // mindestens ein Minibagger dabei
        #expect(m.contains { $0.bezeichnung.lowercased().contains("bagger") })
        // erster hat eine Haupt-Stundenleistung und einen Tagesmietsatz
        let top = m.first
        #expect(top?.hauptLeistung != nil)
        #expect((top?.mieteTag ?? 0) > 0)
    }

    /// Verzahnung darf nicht ins Leere zeigen: jede einsatz_bei-Referenz existiert als Aufwandswert.
    @Test func alleVerweiseTreffen() async {
        let maschinen = MaschinenKatalog.shared.alle()
        let treffer = AufwandswerteKatalog.shared.alle()
        let awKeys = Set(treffer.map { "\($0.gewerk).\($0.key)" })
        var dangling: [String] = []
        for m in maschinen {
            for ref in m.einsatzBei where !awKeys.contains(ref) {
                dangling.append(ref)
            }
        }
        #expect(dangling.isEmpty, "Verweise ohne Aufwandswert: \(dangling)")
    }

    /// Nonsense-Tätigkeit → leere Liste (kein erfundenes Gerät).
    @Test func unbekannteTaetigkeitLeer() async {
        let m = MaschinenKatalog.shared.fuerTaetigkeit("gibtes.nicht")
        #expect(m.isEmpty)
    }

    /// Tage-Modell: Miete pro ANGEFANGENEM Tag, nicht je Stunde.
    @Test func mietkostenNachTageModell() async {
        let bagger = MaschinenKatalog.shared.maschinen(ids: ["erdbau.minibagger_3t"]).first
        #expect(bagger != nil)
        // 100 m³ ÷ 6 m³/h = 16,67 h → aufgerundet 3 angefangene Tage × Tagessatz.
        let mk = bagger?.mietkostenTageModell(menge: 100, einheit: "m3")
        #expect(mk?.tage == 3)
        #expect((mk?.gesamt ?? 0) == Double(3) * (bagger?.mieteTag ?? 0))
        #expect(abs((mk?.proEinheit ?? 0) - (mk?.gesamt ?? 0) / 100) < 0.001)
        // Ein winziger Einsatz kostet trotzdem einen ganzen Tag.
        #expect(bagger?.mietkostenTageModell(menge: 1, einheit: "m3")?.tage == 1)
        // Einheit passt nicht zur Maschinenleistung → nil (keine erfundene Zahl).
        #expect(bagger?.mietkostenTageModell(menge: 5, einheit: "St") == nil)
    }
}
