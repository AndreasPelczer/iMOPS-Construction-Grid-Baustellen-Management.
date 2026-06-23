import Foundation
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LieferantenAnfragePDFExporterTests {
    @Test func pdfExportLiefertValidePDFDaten() {
        let data = LieferantenAnfragePDFExporter.generate(
            kontakt: LieferantenAnfrageKontakt(
                name: "Scharpegge GmbH",
                email: "info@scharpegge-gmbh.de",
                betreffPrefix: "Preisanfrage"
            ),
            kontext: LieferantenAnfrageKontext(
                baustelle: "Einfamilienhaus - Neubau",
                baustellenNummer: "B-2026-001",
                standort: "Marktbreit",
                bauherr: "Andreas Pelczer",
                datum: Date(timeIntervalSince1970: 1_771_612_800)
            ),
            anfrage: UniversalAnfrage(
                baustelleId: "event://test",
                status: .angefragt,
                positionen: [
                    BedarfsPosition(
                        lvPositionId: "lv://1",
                        posNr: "3.30.1",
                        material: "Außenwand Porenbeton Z-17.1-543",
                        menge: 28.42,
                        einheit: "m²",
                        bedarfsquelle: BedarfsQuelle(
                            typ: .plan,
                            ref: "LV 3.30.1",
                            datei: "448-GO B 1.1.pdf",
                            planblatt: "B 1.1",
                            notiz: nil,
                            geprueftVon: "AP"
                        )
                    )
                ],
                lieferung: LieferDetails(
                    lieferfensterVon: Date(timeIntervalSince1970: 1_771_612_800),
                    lieferfensterBis: Date(timeIntervalSince1970: 1_771_612_800 + 86_400)
                )
            )
        )

        #expect(data.prefix(4) == Data("%PDF".utf8))
        #expect(data.count > 1_000)
    }
}
