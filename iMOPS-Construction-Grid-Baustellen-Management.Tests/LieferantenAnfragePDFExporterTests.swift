import Foundation
import PDFKit
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct LieferantenAnfragePDFExporterTests {
    @Test func pdfExportLiefertValidePDFDaten() {
        let data = makePDFData()

        #expect(data.prefix(4) == Data("%PDF".utf8))
        #expect(data.count > 1_000)
    }

    @Test func pdfEnthaeltPositionNachweisUndLieferfenster() throws {
        let data = makePDFData()
        let document = try #require(PDFDocument(data: data))
        let text = document.string ?? ""

        #expect(text.contains("3.30.1"))
        #expect(text.contains("Außenwand Porenbeton Z-17.1-543"))
        #expect(text.contains("28,42 m²"))
        #expect(text.contains("PLAN / LV 3.30.1 / 448-GO B 1.1.pdf / Planblatt B 1.1"))
        #expect(text.contains("Lieferfenster:"))
        #expect(text.contains("20.02.2026"))
        #expect(text.contains("21.02.2026"))
    }

    @Test func demoPDFWirdAlsDateiGeschrieben() throws {
        let data = makePDFData()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("iMOPS-Demo-Lieferantenanfrage.pdf")
        try data.write(to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect((try Data(contentsOf: url)).prefix(4) == Data("%PDF".utf8))
    }

    private func makePDFData() -> Data {
        LieferantenAnfragePDFExporter.generate(
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
                status: .beauftragt,
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
                    beauftragtAm: Date(timeIntervalSince1970: 1_771_526_400),
                    lieferfensterVon: Date(timeIntervalSince1970: 1_771_612_800),
                    lieferfensterBis: Date(timeIntervalSince1970: 1_771_612_800 + 86_400),
                    bestaetigtAm: nil
                )
            )
        )
    }
}
