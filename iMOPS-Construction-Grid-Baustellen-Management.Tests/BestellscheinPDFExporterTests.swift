import Foundation
import PDFKit
import Testing
@testable import iMOPS_Construction_Grid_Baustellen_Management_

/// Das Blatt war einseitig und abgeschnitten: Der Vordruck hat allein 22 Zeilen,
/// mit Kopf, Summe und Unterschriftsfeld ist der Satz rund 1400 pt hoch — eine
/// A4-Seite fasst 842. Ein einziges `beginPage()` zeichnet den Rest ins Nichts,
/// und das PDF bleibt dabei gültig. Genau deshalb prüfen diese Tests nicht, ob
/// Daten herauskommen, sondern ob das Ende drin steht.
struct BestellscheinPDFExporterTests {

    @Test func blattGehtUeberMehrereSeiten() throws {
        let doc = try #require(PDFDocument(data: makePDFData()))
        #expect(doc.pageCount > 1)
    }

    @Test func dieLetztenZeilenSindNichtAbgeschnitten() throws {
        let doc = try #require(PDFDocument(data: makePDFData()))
        let text = doc.string ?? ""

        // Das Ende des Blattes — bei einer einzelnen Seite fehlt genau das hier.
        #expect(text.contains("BESTELLMENGE"))
        #expect(text.contains("m³ gesamt"))
        #expect(text.contains("Geprüft"))
        #expect(text.contains("Freigegeben zur Bestellung"))
    }

    @Test func jedeSeiteTraegtDieSeitenzahl() throws {
        let doc = try #require(PDFDocument(data: makePDFData()))
        let gesamt = doc.pageCount

        for i in 0..<gesamt {
            let seite = try #require(doc.page(at: i))
            // „Seite 2 von 3" — daran sieht der Lieferant, ob das Fax vollständig
            // angekommen ist. Ohne Gesamtzahl merkt niemand ein fehlendes Blatt.
            #expect((seite.string ?? "").contains("Seite \(i + 1) von \(gesamt)"))
        }
    }

    @Test func letzteVordruckZeileStehtDrin() throws {
        let doc = try #require(PDFDocument(data: makePDFData()))
        let text = doc.string ?? ""

        // 10005485 ist die unterste Zeile des Vordrucks (425 mm). Sie lag vorher
        // weit unter dem Seitenrand.
        #expect(text.contains("10005485"))
        #expect(text.contains("499 x 425 x 249"))
    }

    @Test func entwurfStempelStehtAufJederSeite() throws {
        let doc = try #require(PDFDocument(data: makePDFData()))
        for i in 0..<doc.pageCount {
            let seite = try #require(doc.page(at: i))
            #expect((seite.string ?? "").contains("ENTWURF"))
        }
    }

    @Test func demoPDFWirdAlsDateiGeschrieben() throws {
        let data = makePDFData()
        // Ablage im Dokumente-Ordner statt im Temp: das Temp-Verzeichnis des
        // Simulators ist nach dem Lauf weg, und dann kann sich das Blatt niemand
        // mehr ansehen. `IMOPS_PDF_OUT` lenkt es beim Sichtprüfen woandershin.
        let ziel = ProcessInfo.processInfo.environment["IMOPS_PDF_OUT"].map(URL.init(fileURLWithPath:))
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("iMOPS-Demo-Bestellschein.pdf")
        try data.write(to: ziel)

        #expect(FileManager.default.fileExists(atPath: ziel.path))
        #expect((try Data(contentsOf: ziel)).prefix(4) == Data("%PDF".utf8))
    }

    // MARK: - Hilfe

    /// Mengen aus dem echten Römisch-Durchlauf, damit die Zeilenhöhen stimmen:
    /// vier Zeilen vom Vordruck, drei freie darunter.
    private func makePDFData() -> Data {
        var angaben = BestellscheinAngaben()
        angaben.objektNr = "T&C-2026-0042"
        angaben.strasse = "Musterweg 1"
        angaben.plzOrt = "97199 Musterdorf"
        angaben.baustoffhandel = "Baustoff Muster GmbH"
        angaben.bemerkung = "Zufahrt über die Feldseite, Wendeplatz vorhanden."

        let zeilen: [BestellscheinService.Zeile] = [
            .init(materialNr: "10005024", bezeichnung: "Außenwand 36,5 cm · PPW 4-0,50",
                  mengeLV: 16.48, zuschlagProzent: 10, positionen: 3),
            .init(materialNr: "10005028", bezeichnung: "Außenwand 24 cm · PPW 2-0,35",
                  mengeLV: 33.22, zuschlagProzent: 0, positionen: 15),
            .init(materialNr: "10005022", bezeichnung: "Außenwand 24 cm · PPW 4-0,50",
                  mengeLV: 2.30, zuschlagProzent: 0, positionen: 2),
            .init(materialNr: "10005006", bezeichnung: "Innenwand 11,5 cm · PPW 4-0,55",
                  mengeLV: 6.92, zuschlagProzent: 0, positionen: 8),
            .init(materialNr: "", bezeichnung: "Kalksandstein 24 cm",
                  mengeLV: 8.33, zuschlagProzent: 0, positionen: 4,
                  freitext: "Kalksandstein KS-RP 24 cm, KS-RP 20-2,2"),
            .init(materialNr: "", bezeichnung: "Mauerwerk 22 cm",
                  mengeLV: 4.57, zuschlagProzent: 0, positionen: 2,
                  freitext: "Mauerwerk 22 cm (Sorte bitte ergänzen)"),
            .init(materialNr: "", bezeichnung: "Ytong Planblock 17,5 cm",
                  mengeLV: 4.86, zuschlagProzent: 0, positionen: 5,
                  freitext: "Ytong Planblock 17,5 cm, PPW 4-0,50"),
        ]

        return BestellscheinPDFExporter.generate(
            zeilen: zeilen,
            ohneNummer: [],
            kontext: .init(baustelle: "Musterhaus Feldstraße",
                           bvhNr: "BVH-2026-17",
                           bauherr: "Familie Muster",
                           strasse: angaben.strasse,
                           plzOrt: angaben.plzOrt,
                           objektNr: angaben.objektNr,
                           baustoffhandel: angaben.baustoffhandel,
                           angaben: angaben,
                           datum: Date(timeIntervalSince1970: 1_772_000_000)))
    }
}
