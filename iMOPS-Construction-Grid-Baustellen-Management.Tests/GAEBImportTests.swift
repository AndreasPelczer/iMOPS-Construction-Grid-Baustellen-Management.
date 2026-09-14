//
//  GAEBImportTests.swift
//  Beweist an einer echten GAEB-DA-XML-Probe (3.2, X83 = Angebotsaufforderung),
//  dass der Mops aus Position + Text + Menge + Einheit die richtigen Werte zieht.
//  Andreas' Prüffall: „50 t Splitt K 8/16, Menge auslesen".
//
//  Erst messen, dann behaupten: wir lassen den echten GAEBImporter die Datei lesen,
//  statt zu behaupten, er könne es.
//

import Testing
import Foundation
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct GAEBImportTests {

    /// Eine kleine, gültige GAEB-DA-XML-3.2-Angebotsaufforderung (X83) mit drei
    /// Tiefbau-Positionen. Aufbau wie in echten Ausschreibungen: Positionstext im
    /// <span>, Menge in <Qty>, Einheit in <QU>.
    private static let x83 = """
    <?xml version="1.0" encoding="UTF-8"?>
    <GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.2">
      <GAEBInfo>
        <Version>3.2</Version>
        <VersDate>2026-09-14</VersDate>
      </GAEBInfo>
      <PrjInfo>
        <NamePrj>Hofeinfahrt Musterstraße 7</NamePrj>
        <LblPrj>2026-042</LblPrj>
        <Cur>EUR</Cur>
      </PrjInfo>
      <Award>
        <DP>83</DP>
        <OWN>
          <Name>Bauherr Muster</Name>
        </OWN>
        <BoQ>
          <BoQInfo><Name>LV Hofeinfahrt</Name></BoQInfo>
          <BoQBody>
            <BoQCtgy RNoPart="01">
              <LblTx><TextComplete><Complete><span>Tiefbau Außenanlagen</span></Complete></TextComplete></LblTx>
              <BoQBody>
                <Itemlist>
                  <Item RNoPart="10" ID="01.10">
                    <Qty>50.000</Qty>
                    <QU>t</QU>
                    <Description>
                      <CompleteText>
                        <OutlineText><OutlTxt><TextOutlTxt><p><span>Splitt K 8/16 liefern und einbauen</span></p></TextOutlTxt></OutlTxt></OutlineText>
                        <DetailTxt><Text><p><span>Frostschutz-Splitt Körnung 8/16 mm, lagenweise einbauen und verdichten.</span></p></Text></DetailTxt>
                      </CompleteText>
                    </Description>
                  </Item>
                  <Item RNoPart="20" ID="01.20">
                    <Qty>120.500</Qty>
                    <QU>m2</QU>
                    <Description>
                      <CompleteText>
                        <OutlineText><OutlTxt><TextOutlTxt><p><span>Betonpflaster verlegen</span></p></TextOutlTxt></OutlTxt></OutlineText>
                      </CompleteText>
                    </Description>
                  </Item>
                  <Item RNoPart="30" ID="01.30">
                    <Qty>42.000</Qty>
                    <QU>m3</QU>
                    <Description>
                      <CompleteText>
                        <OutlineText><OutlTxt><TextOutlTxt><p><span>Oberboden abtragen und lagern</span></p></TextOutlTxt></OutlTxt></OutlineText>
                      </CompleteText>
                    </Description>
                  </Item>
                </Itemlist>
              </BoQBody>
            </BoQCtgy>
          </BoQBody>
        </BoQ>
      </Award>
    </GAEB>
    """

    private func parse(_ xml: String) throws -> GAEBImportResult {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gaeb-test-\(UUID().uuidString).x83")
        try xml.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        return try GAEBImporter.parse(url: url)
    }

    @Test("Kopfdaten: Projektname, Nummer, X83 als Angebotsaufforderung")
    func kopfdaten() throws {
        let r = try parse(Self.x83)
        #expect(r.dp == 83)                       // 83 = Angebotsaufforderung (kein Preis erwartet)
        #expect(r.projectName == "Hofeinfahrt Musterstraße 7")
        #expect(r.projectLabel == "2026-042")
        #expect(r.items.count == 3)
    }

    @Test("Andreas' Prüffall: 50 t Splitt K 8/16 — Menge + Einheit + Text korrekt gelesen")
    func splittPosition() throws {
        let r = try parse(Self.x83)
        let splitt = try #require(r.items.first { $0.kurztext.contains("Splitt") })
        #expect(splitt.posNr == "01.10")
        #expect(splitt.kurztext.contains("Splitt K 8/16"))     // Positionstext
        #expect(splitt.menge == 50.0)                          // Menge ausgelesen
        #expect(splitt.einheit == "t")                         // Einheit gemappt (tne/to/t → t)
        #expect(splitt.langtext.contains("8/16 mm"))           // Langtext mitgenommen
    }

    @Test("Einheiten-Mapping: m2 → m², m3 → m³")
    func einheitenMapping() throws {
        let r = try parse(Self.x83)
        let pflaster = try #require(r.items.first { $0.kurztext.localizedCaseInsensitiveContains("pflaster") })
        #expect(pflaster.menge == 120.5)
        #expect(pflaster.einheit == "m²")

        let oberboden = try #require(r.items.first { $0.kurztext.localizedCaseInsensitiveContains("oberboden") })
        #expect(oberboden.menge == 42.0)
        #expect(oberboden.einheit == "m³")
    }

    @Test("Leere/kaputte Datei → ehrlicher Fehler, kein stiller Leerimport")
    func leereDatei() {
        #expect(throws: GAEBImportError.self) {
            _ = try parse("<GAEB></GAEB>")
        }
    }
}
