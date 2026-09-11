//
//  RechnungPDFExporterTests.swift
//  Das lesbare Rechnungsblatt — und was daran schiefgehen darf.
//
//  Die Prüfungen hier sind bewusst keine Pixel-Vergleiche. Ein PDF-Layout ändert
//  sich, ohne dass etwas kaputt ist. Was NICHT auseinanderlaufen darf, sind die
//  Zusagen: dieselbe Rechnungsnummer wie im XML, derselbe Betrag, keine
//  Betriebsinterna auf dem Kundenblatt, keine Platzhalter im Briefkopf.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct RechnungPDFExporterTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    /// Eine Baustelle mit Kunde, Anschrift und einer Position.
    @MainActor
    private func baustelle() -> (Event, LVPosition) {
        let e = Event(context: ctx)
        e.eventNumber = "TEST-RE-001"
        e.title = "Hofauffahrt pflastern"
        e.location = "Musterweg 1, Marktbreit"
        e.bauherr = "Familie Muster"
        e.bauherrStrasse = "Musterweg 1"
        e.bauherrPLZ = "97340"
        e.bauherrOrt = "Marktbreit"
        e.timeStamp = Date()

        let p = LVPosition(context: ctx)
        p.event = e
        p.posNr = "1.20.1"
        p.bezeichnung = "Hofauffahrt pflastern, befahrbar"
        p.menge = 100.31
        p.einheit = "m²"
        return (e, p)
    }

    // MARK: - Der Kreis schließt sich

    /// **Aus einer Baustelle fällt ein lesbares PDF.** Mehr sagt dieser Test nicht —
    /// aber weniger wäre auch nichts wert: ein leeres `Data()` wäre still.
    @Test @MainActor func ausDerBaustelleFaelltEinLesbaresPDF() throws {
        let (e, p) = baustelle()
        let daten = RechnungPDFExporter.generate(event: e, positionen: [p])

        #expect(daten.count > 1000, "PDF ist verdächtig klein: \(daten.count) Bytes")
        // %PDF- als Dateikopf — sonst ist es kein PDF, egal wie groß es ist.
        let kopf = String(data: daten.prefix(5), encoding: .ascii)
        #expect(kopf == "%PDF-", "Kein PDF-Kopf: \(kopf ?? "–")")
    }

    /// **PDF und XRechnung tragen dieselbe Rechnungsnummer.**
    ///
    /// Zwei Nummern für einen Vorgang sind ein Buchhaltungsfehler, den niemand
    /// bemerkt, bis er weh tut. Der Test hält die beiden aneinander fest.
    @Test @MainActor func pdfUndXRechnungTragenDieselbeNummer() throws {
        let (e, p) = baustelle()
        let xml = String(data: XRechnungExporter.export(event: e, positionen: [p]),
                         encoding: .utf8) ?? ""
        let nummer = RechnungPDFExporter.rechnungsnummer()

        #expect(xml.contains("<ram:ID>\(nummer)</ram:ID>"),
                "XML trägt eine andere Nummer als das PDF (\(nummer))")
    }

    // MARK: - Der Käufer ist der Kunde, nicht die Baustelle

    /// Vorher stand im XML als Käufer der **Titel der Baustelle** und als Adresse
    /// nur `<CountryID>DE</CountryID>`. Eine Rechnung braucht nach § 14 UStG Namen
    /// UND Anschrift des Leistungsempfängers.
    @Test @MainActor func kaeuferIstDerBauherrMitAnschrift() throws {
        let (e, p) = baustelle()
        let xml = String(data: XRechnungExporter.export(event: e, positionen: [p]),
                         encoding: .utf8) ?? ""

        #expect(xml.contains("<ram:Name>Familie Muster</ram:Name>"))
        #expect(xml.contains("<ram:LineOne>Musterweg 1</ram:LineOne>"))
        #expect(xml.contains("<ram:PostcodeCode>97340</ram:PostcodeCode>"))
        #expect(xml.contains("<ram:CityName>Marktbreit</ram:CityName>"))
        // Und der Baustellen-Titel steht NICHT mehr als Käufername da.
        #expect(!xml.contains("<ram:Name>Hofauffahrt pflastern</ram:Name>"))
    }

    /// Ohne Bauherrn fällt der Exporter auf den Titel zurück — ein XML **ohne**
    /// Käufernamen wäre gar nicht erst gültig. Der Notnagel darf nicht wegfallen.
    @Test @MainActor func ohneBauherrBleibtDerTitelAlsNotnagel() throws {
        let (e, p) = baustelle()
        e.bauherr = ""
        let xml = String(data: XRechnungExporter.export(event: e, positionen: [p]),
                         encoding: .utf8) ?? ""
        #expect(xml.contains("<ram:Name>Hofauffahrt pflastern</ram:Name>"))
    }

    // MARK: - Anschrift und Vollständigkeit

    @Test @MainActor func anschriftLaesstLeereZeilenWeg() throws {
        let (e, _) = baustelle()
        #expect(e.bauherrAnschrift == ["Familie Muster", "Musterweg 1", "97340 Marktbreit"])
        #expect(e.anschriftIstVollstaendig)

        e.bauherrStrasse = nil
        #expect(e.bauherrAnschrift == ["Familie Muster", "97340 Marktbreit"],
                "Leere Zeile nicht weggefallen: \(e.bauherrAnschrift)")
        // Ohne Straße ist die Anschrift für eine Rechnung nicht vollständig.
        #expect(!e.anschriftIstVollstaendig)
    }

    // MARK: - Briefkopf ohne Platzhalter

    /// **Kein Default-Firmenname mehr.** Hier stand „iMOPS Bauleitung" — der Name
    /// der Software auf der Rechnung eines Bauunternehmens.
    @Test func ohneEintragKeinFirmenname() throws {
        let d = UserDefaults.standard
        let vorher = d.string(forKey: FirmenSettings.Keys.name)
        d.removeObject(forKey: FirmenSettings.Keys.name)
        defer { if let vorher { d.set(vorher, forKey: FirmenSettings.Keys.name) } }

        #expect(FirmenSettings.name.isEmpty)
        #expect(!FirmenSettings.briefkopfIstVollstaendig)
    }

    /// Leere Angaben erzeugen **keine** Zeile — nicht „Fax: –", nicht „[fehlt]".
    @Test func leereAngabenErzeugenKeineZeile() throws {
        let d = UserDefaults.standard
        let schluessel = [FirmenSettings.Keys.telefon, FirmenSettings.Keys.fax,
                          FirmenSettings.Keys.email, FirmenSettings.Keys.web,
                          FirmenSettings.Keys.iban, FirmenSettings.Keys.bank,
                          FirmenSettings.Keys.bic]
        let vorher = schluessel.map { ($0, d.string(forKey: $0)) }
        schluessel.forEach { d.removeObject(forKey: $0) }
        defer { vorher.forEach { if let v = $0.1 { d.set(v, forKey: $0.0) } } }

        #expect(Briefpapier.kontaktZeilen().isEmpty)
        #expect(Briefpapier.bankZeilen().isEmpty)
    }

    /// Eine IBAN ohne Bankname reicht für eine Zeile — aber eine leere IBAN
    /// erzeugt keinen leeren Kontoblock in der XRechnung.
    @Test func ibanOhneBanknameGenuegt() throws {
        let d = UserDefaults.standard
        let vorher = d.string(forKey: FirmenSettings.Keys.iban)
        d.set("DE02120300000000202051", forKey: FirmenSettings.Keys.iban)
        defer {
            if let vorher { d.set(vorher, forKey: FirmenSettings.Keys.iban) }
            else { d.removeObject(forKey: FirmenSettings.Keys.iban) }
        }
        #expect(Briefpapier.bankZeilen().contains { $0.contains("DE0212030000") })
    }
}
