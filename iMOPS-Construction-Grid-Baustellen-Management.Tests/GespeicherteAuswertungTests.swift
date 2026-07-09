//
//  GespeicherteAuswertungTests.swift
//  Persistenz der Dokument-Auswertungen (/extract-doc) in EventExtrasPayload.auswertungen.
//  Kritische Punkte:
//   - neues Feld ist OPTIONAL → alte Blobs ohne 'auswertungen' bleiben dekodierbar
//   - Round-Trip: felder (JSONValue) muss verlustfrei durch JSON
//   - Dedup über 'quelle': dasselbe PDF erneut → EIN Eintrag (der neuere)
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct GespeicherteAuswertungTests {

    private func mk(_ quelle: String, wf: Double = 112.8, conf: Double = 0.9) -> ExtractDocResult {
        ExtractDocResult(
            status: "success",
            quelle: quelle,
            doctypeErkannt: "wohnflaeche",
            confidence: conf,
            felder: .object(["wohnflaeche_gesamt_m2": .number(wf)]),
            model: "gpt-4.1",
            meldung: "Entwurf, prüfen."
        )
    }

    @Test func roundTripMitAuswertungen() throws {
        var p = EventExtrasPayload()
        p.mergeAuswertungen([mk("b.pdf"), mk("a.pdf")], am: Date(timeIntervalSince1970: 1000))

        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(EventExtrasPayload.self, from: data)

        #expect(back.auswertungen?.count == 2)
        // nach quelle sortiert → a.pdf zuerst
        #expect(back.auswertungen?.first?.ergebnis.quelle == "a.pdf")
        #expect(back.auswertungen?.first?.ergebnis.felder
                == JSONValue.object(["wohnflaeche_gesamt_m2": .number(112.8)]))
        #expect(back.auswertungen?.first?.gespeichertAm == Date(timeIntervalSince1970: 1000))
    }

    @Test func dedupUeberQuelleBehaeltNeueren() throws {
        var p = EventExtrasPayload()
        p.mergeAuswertungen([mk("a.pdf", wf: 100, conf: 0.5)], am: Date(timeIntervalSince1970: 1000))
        p.mergeAuswertungen([mk("a.pdf", wf: 200, conf: 0.9)], am: Date(timeIntervalSince1970: 2000))

        #expect(p.auswertungen?.count == 1)                 // ein Eintrag, nicht zwei
        let e = p.auswertungen?.first
        #expect(e?.ergebnis.confidence == 0.9)              // der neuere Wert
        #expect(e?.gespeichertAm == Date(timeIntervalSince1970: 2000))
    }

    @Test func altesExtrasOhneAuswertungenBleibtDekodierbar() throws {
        let alt = """
        {"checklist": [], "pinnedProductIDs": [], "pinnedLexikonCodes": []}
        """
        let p = try JSONDecoder().decode(EventExtrasPayload.self, from: Data(alt.utf8))
        #expect(p.auswertungen == nil)   // fehlender Schlüssel → nil, kein Fehler
    }

    @Test func loeschenEntferntNurDenRichtigen() throws {
        // Falsche Auswertung geladen → gezielt löschen, Rest bleibt, überlebt Neustart.
        var p = EventExtrasPayload()
        p.mergeAuswertungen([mk("a.pdf"), mk("b.pdf"), mk("c.pdf")], am: Date(timeIntervalSince1970: 1))

        p.removeAuswertung(quelle: "b.pdf")
        #expect((p.auswertungen ?? []).map(\.ergebnis.quelle) == ["a.pdf", "c.pdf"])

        // überlebt Round-Trip (persistent gelöscht)
        let back = try JSONDecoder().decode(EventExtrasPayload.self, from: JSONEncoder().encode(p))
        #expect((back.auswertungen ?? []).map(\.ergebnis.quelle) == ["a.pdf", "c.pdf"])

        // unbekannte quelle löscht nichts (kein Crash)
        p.removeAuswertung(quelle: "gibtsnicht.pdf")
        #expect(p.auswertungen?.count == 2)
    }

    @Test func setDoctypeKorrigiertNurEtikett() throws {
        // Fehl-Erkennung aufräumen: Typ ändern, Felder bleiben, überlebt Neustart.
        var p = EventExtrasPayload()
        p.mergeAuswertungen([mk("a.pdf")], am: Date(timeIntervalSince1970: 1))   // mk → "wohnflaeche"
        p.setDoctype(quelle: "a.pdf", doctype: "auto")

        let e = try #require(p.auswertungen?.first)
        #expect(e.ergebnis.doctypeErkannt == "auto")   // Etikett korrigiert
        #expect(e.ergebnis.felder == .object(["wohnflaeche_gesamt_m2": .number(112.8)]))  // Felder unverändert

        let back = try JSONDecoder().decode(EventExtrasPayload.self, from: JSONEncoder().encode(p))
        #expect(back.auswertungen?.first?.ergebnis.doctypeErkannt == "auto")   // persistent

        p.setDoctype(quelle: "gibtsnicht.pdf", doctype: "bebauungsplan")        // unbekannt → no-op
        #expect(p.auswertungen?.first?.ergebnis.doctypeErkannt == "auto")
    }
}
