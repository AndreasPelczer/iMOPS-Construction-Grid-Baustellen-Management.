//
//  LVPDFLangtextTests.swift
//
//  Zwei Fassungen des Angebots-PDF: kurz zum Überfliegen, lang für die Abgabe. Bei VOB
//  ist der Langtext der geschuldete Leistungsinhalt — und bei uns steht in ihm auch die
//  Herkunft von Menge und Preis. Ein Angebot ohne ihn ist nicht nachvollziehbar.
//
//  Nebenbefund, der hier mit festgehalten wird: die Bezeichnung wurde vorher in eine feste
//  18-pt-Zeile gezwängt und ABGESCHNITTEN — im echten Angebot stand „Mauerwerk Innenwand
//  tragend Ytong…". Jetzt umbricht sie und die Zeile wächst mit.
//
//  Geprüft wird nicht die Dateigröße, sondern der zurückgelesene Text: was PDFKit im
//  Dokument findet, findet auch der Leser.
//

import Testing
import Foundation
import CoreData
import PDFKit
@testable import iMOPS_Construction_Grid_Baustellen_Management_

@MainActor
struct LVPDFLangtextTests {

    private let langerText = "Menge 19.00 Stk. Herkunft der Menge: gemessen. "
                           + "Preisquelle: BKI-080000421, 452 EUR je lfm Wand."

    private func baustelle() throws -> (PersistenceController, Event, [LVPosition]) {
        let c = PersistenceController(inMemory: true)
        let ctx = c.container.viewContext
        let e = Event(context: ctx)
        e.title = "Testbaustelle"
        let p = LVPosition(context: ctx)
        p.posNr = "543.0010"
        p.bezeichnung = "Stützwinkel L 995 B 120 H 1550 liefern und versetzen"
        p.langtext = "Stützwinkel L 995 B 120 H 1550 liefern und versetzen. " + langerText
        p.menge = 19
        p.einheit = "Stk"
        p.kostenGruppeNummer = "543"
        p.event = e
        try ctx.save()
        return (c, e, [p])
    }

    private func text(_ data: Data) -> String {
        PDFDocument(data: data)?.string ?? ""
    }

    @Test func kurzfassungLaesstDenLangtextWeg() throws {
        let (c, e, pos) = try baustelle(); _ = c
        let t = text(LVPDFExporter.generate(event: e, positionen: pos, mitLangtext: false))
        #expect(t.contains("Stützwinkel"), "die Position fehlt ganz")
        #expect(!t.contains("BKI-080000421"), "der Langtext steht in der Kurzfassung")
    }

    @Test func langfassungTraegtIhn() throws {
        let (c, e, pos) = try baustelle(); _ = c
        let t = text(LVPDFExporter.generate(event: e, positionen: pos, mitLangtext: true))
        #expect(t.contains("Herkunft der Menge"), "die Mengenherkunft fehlt")
        #expect(t.contains("BKI-080000421"), "die Preisquelle fehlt")
    }

    /// Die Bezeichnung darf nicht mehr abgeschnitten werden — auch nicht in der Kurzfassung.
    ///
    /// Geprüft wird nur das LETZTE WORT, nicht die ganze Wendung: seit dem Umbruch steht
    /// im Dokument „liefern und⏎versetzen", und `contains("liefern und versetzen")` findet
    /// die zusammenhängende Kette dann nicht mehr — obwohl alles da ist. Dieser Test war
    /// aus genau dem Grund einmal fälschlich rot.
    @Test func dieBezeichnungWirdVollstaendigGesetzt() throws {
        let (c, e, pos) = try baustelle(); _ = c
        let t = text(LVPDFExporter.generate(event: e, positionen: pos, mitLangtext: false))
        let sichtbar = t.replacingOccurrences(of: "\n", with: "⏎")
        #expect(t.contains("versetzen"),
                Comment(rawValue: "Ende der Bezeichnung fehlt. Im PDF steht: >>>\(sichtbar.prefix(400))<<<"))
    }

    /// Vorgabe bleibt die Kurzfassung: wer nichts angibt, bekommt das lesbare Angebot.
    @Test func ohneAngabeIstEsDieKurzfassung() throws {
        let (c, e, pos) = try baustelle(); _ = c
        let t = text(LVPDFExporter.generate(event: e, positionen: pos))
        #expect(!t.contains("BKI-080000421"))
    }
}
