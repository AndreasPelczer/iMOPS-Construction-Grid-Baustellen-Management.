import Foundation
import CoreData

// MARK: - Export Format

enum GAEBExportFormat {
    case x83_v33   // Angebotsaufforderung (ohne Preise)
    case x84_v33   // Angebot (mit Preisen aus AngebotsStore)

    var dp: Int { self == .x83_v33 ? 83 : 84 }
    var includePrices: Bool { self == .x84_v33 }
    var filenameSuffix: String { self == .x83_v33 ? "X83" : "X84" }
}

// MARK: - Exporter

struct GAEBExporter {

    static func export(
        event: Event,
        positionen: [LVPosition],
        format: GAEBExportFormat,
        store: AngebotsStore = .shared
    ) -> Data {
        let xml = buildXML(event: event, positionen: positionen.zaehlbarePositionen(), format: format, store: store)
        return xml.data(using: .utf8) ?? Data()
    }

    // MARK: - XML Builder

    private static func buildXML(
        event: Event,
        positionen: [LVPosition],
        format: GAEBExportFormat,
        store: AngebotsStore
    ) -> String {
        let now         = Date()
        let dateStr     = isoDate(now)
        let timeStr     = isoTime(now)
        let projectName = event.title ?? "Bauprojekt"
        let projectLabel = event.eventNumber ?? "001"

        // Group by KG, sorted
        let grouped = Dictionary(grouping: positionen, by: { $0.kostenGruppeNummer ?? "300" })
            .sorted { $0.key < $1.key }

        // Grand total for X84
        var grandTotal = 0.0

        // BoQCtgy blocks
        var boqCtgyBlocks = ""
        for (kg, items) in grouped {
            let groupTitle = kgFullName(kg)
            var itemsXML = ""
            for pos in items {
                let (xml, lineTotal) = itemXML(pos, format: format, store: store)
                itemsXML += xml
                grandTotal += lineTotal
            }
            boqCtgyBlocks += """
      <BoQCtgy>
        <LblTx>
          <TextOutlTxt>
            <OutlineText>
              <OutlTxt>
                <TextComplete>\(e(groupTitle))</TextComplete>
              </OutlTxt>
            </OutlineText>
          </TextOutlTxt>
        </LblTx>
        <Itemlist>
\(itemsXML)        </Itemlist>
      </BoQCtgy>
"""
        }

        let ownerBlock = event.bauherr.map { bauherr in
            """
    <OWN>
      <Name>\(e(bauherr))</Name>
    </OWN>
""" } ?? ""

        let offerSummary = format.includePrices ? """
      <OfrSummary>
        <GrandTotal>\(fmt(grandTotal))</GrandTotal>
      </OfrSummary>
""" : ""

        let locationBlock = event.location.map { loc in
            "    <LblPrj>\(e(loc))</LblPrj>\n" } ?? ""

        return """
<?xml version="1.0" encoding="UTF-8"?>
<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/200407"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <GAEBInfo>
    <Version>3.3</Version>
    <VersDate>2018-04-13</VersDate>
    <Date>\(dateStr)</Date>
    <Time>\(timeStr)</Time>
    <Name>iMOPS Construction Grid</Name>
    <ProgSystem>iMOPS</ProgSystem>
  </GAEBInfo>
  <PrjInfo>
    <NamePrj>\(e(projectName))</NamePrj>
    <LblPrj>\(e(projectLabel))</LblPrj>
\(locationBlock)    <Cur>EUR</Cur>
  </PrjInfo>
  <Award>
    <DP>\(format.dp)</DP>
\(ownerBlock)    <BoQ>
      <BoQInfo>
        <Name>\(e(projectName)) – Leistungsverzeichnis</Name>
        <LblBoQ>HV</LblBoQ>
      </BoQInfo>
      <BoQBody>
\(boqCtgyBlocks)      </BoQBody>
\(offerSummary)    </BoQ>
  </Award>
</GAEB>
"""
    }

    // MARK: - Single Item

    /// Returns the item XML and the line total (EP × Menge)
    private static func itemXML(
        _ pos: LVPosition,
        format: GAEBExportFormat,
        store: AngebotsStore
    ) -> (xml: String, total: Double) {
        let posID    = pos.posNr ?? "000"
        let rNoPart  = posID.components(separatedBy: ".").last.map { String($0) } ?? posID
        let unit     = gaebUnit(for: pos.einheit ?? "m²")
        let qty      = String(format: "%.3f", pos.menge)
        let bez      = pos.bezeichnung ?? ""

        // Prices: only for X84
        var priceLines = ""
        var lineTotal  = 0.0
        if format.includePrices {
            let storeID = pos.objectID.uriRepresentation().absoluteString
            var ep = store.guenstigster(for: storeID)?.einzelpreis ?? 0
            // Fallback: kalkulierter VK-Preis wenn vorhanden
            if ep == 0 && pos.istElement {
                // B-Element: der Preis entsteht aus den Bausteinen, nicht aus einer
                // eigenen Kalkulation. Ohne diesen Zweig ginge das Element OHNE
                // Einheitspreis in die GAEB-Datei.
                ep = LVKalkulator.kalkuliereElement(pos).einheitspreisVK
            } else if ep == 0 && pos.hatKalkulation {
                ep = LVKalkulator.kalkuliere(position: pos).einheitspreisVK
            }
            lineTotal = ep * pos.menge
            if ep > 0 {
                priceLines = """
            <UP>\(fmt(ep))</UP>
            <IT>\(fmt(lineTotal))</IT>
"""
            }
        }

        // Alternative marker
        let altLine = LVPositionHelper.isAlternative(pos) ? "            <Alt/>\n" : ""

        let xml = """
          <Item ID="\(e(posID))" RNoPart="\(e(rNoPart))">
\(altLine)            <Qty>\(qty)</Qty>
            <QU>\(unit)</QU>
            <Description>
              <CompleteText>
                <DetailTxt>
                  <Text>
                    <p>
                      <span>\(e(bez))</span>
                    </p>
                  </Text>
                </DetailTxt>
                <OutlineText>
                  <OutlTxt>
                    <TextComplete>\(e(bez))</TextComplete>
                  </OutlTxt>
                </OutlineText>
              </CompleteText>
            </Description>\(priceLines.isEmpty ? "" : "\n" + priceLines)
          </Item>
"""
        return (xml, lineTotal)
    }

    // MARK: - Helpers

    private static func e(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func fmt(_ d: Double) -> String { String(format: "%.2f", d) }

    private static func isoDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private static func isoTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    // iMOPS display → GAEB QU code
    static func gaebUnit(for einheit: String) -> String {
        switch einheit.lowercased().trimmingCharacters(in: .whitespaces) {
        case "m²", "m2", "qm":            return "m2"
        case "m³", "m3", "cbm":           return "m3"
        case "lfm", "lm", "lfdm":         return "lfdm"
        case "m":                          return "m"
        case "stück", "stk", "st":         return "Stk"
        case "kg":                         return "kg"
        case "t", "to":                    return "t"
        case "psch", "pauschal", "psch.": return "psch"
        case "h", "std":                   return "h"
        case "l", "lt", "ltr":            return "l"
        default: return einheit
        }
    }

    private static func kgFullName(_ kg: String) -> String {
        switch kg {
        case "100": return "Grundstück"
        case "200": return "Herrichten und Erschließen"
        case "300": return "Bauwerk - Baukonstruktionen"
        case "310": return "Baugrube"
        case "320": return "Gründung"
        case "330": return "Außenwände"
        case "340": return "Innenwände"
        case "350": return "Decken"
        case "360": return "Dächer"
        case "370": return "Infrastruktur"
        case "380": return "Fenster und Türen"
        case "390": return "Sonstige Baukonstruktion"
        case "400": return "Bauwerk - Technische Anlagen"
        case "410": return "Abwasser, Wasser, Gas"
        case "420": return "Wärmeversorgung"
        case "430": return "Lufttechnische Anlagen"
        case "440": return "Starkstrom"
        case "450": return "Fernmelde- und IT-Anlagen"
        case "500": return "Außenanlagen"
        case "600": return "Ausstattung und Kunstwerke"
        case "700": return "Baunebenkosten"
        default:    return "Sonstige"
        }
    }
}
