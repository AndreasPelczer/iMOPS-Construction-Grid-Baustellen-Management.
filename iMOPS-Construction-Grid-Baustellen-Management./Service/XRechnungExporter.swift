import Foundation
import CoreData

// Generates a CII-based XRechnung 2.2 XML (EN 16931).
// TypeCode 380 = Handelsrechnung; VAT 19 % (S-category, DE standard).
// Unit codes: UN/ECE Rec 20 (MTK, MTQ, MTR, C62, …)
struct XRechnungExporter {

    static func export(
        event: Event,
        positionen: [LVPosition],
        store: AngebotsStore = .shared
    ) -> Data {
        buildXML(event: event, positionen: positionen, store: store)
            .data(using: .utf8) ?? Data()
    }

    // MARK: - XML

    private static func buildXML(
        event: Event,
        positionen: [LVPosition],
        store: AngebotsStore
    ) -> String {
        let df = DateFormatter()
        df.locale     = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd"
        let dateStr = df.string(from: Date())

        let title     = event.title ?? "Baustelle"
        let invoiceNr = "RE-\(dateStr)-001"

        // Only non-alternative positions; fall back to 0 EP if no offer stored
        let items: [(pos: LVPosition, ep: Double, gp: Double)] = positionen
            .filter { !LVPositionHelper.isAlternative($0) }
            .map { pos in
                let id = pos.objectID.uriRepresentation().absoluteString
                let ep = store.guenstigster(for: id)?.einzelpreis ?? 0.0
                return (pos, ep, ep * pos.menge)
            }

        let netto  = items.reduce(0.0) { $0 + $1.gp }
        let vat    = netto * 0.19
        let brutto = netto + vat

        var out = ""
        out += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        out += "<rsm:CrossIndustryInvoice\n"
        out += "  xmlns:rsm=\"urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100\"\n"
        out += "  xmlns:ram=\"urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100\"\n"
        out += "  xmlns:udt=\"urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100\"\n"
        out += "  xmlns:qdt=\"urn:un:unece:uncefact:data:standard:QualifiedDataType:100\">\n"

        // BT-24 – Specification identifier
        out += "  <rsm:ExchangedDocumentContext>\n"
        out += "    <ram:GuidelineSpecifiedDocumentContextParameter>\n"
        out += "      <ram:ID>urn:cen.eu:en16931:2017#compliant#urn:xoev-de:kosit:standard:xrechnung_2.2</ram:ID>\n"
        out += "    </ram:GuidelineSpecifiedDocumentContextParameter>\n"
        out += "  </rsm:ExchangedDocumentContext>\n"

        // BT-1 Invoice number, BT-3 TypeCode, BT-2 Issue date
        out += "  <rsm:ExchangedDocument>\n"
        out += "    <ram:ID>\(esc(invoiceNr))</ram:ID>\n"
        out += "    <ram:TypeCode>380</ram:TypeCode>\n"
        out += "    <ram:IssueDateTime>\n"
        out += "      <udt:DateTimeString format=\"102\">\(dateStr)</udt:DateTimeString>\n"
        out += "    </ram:IssueDateTime>\n"
        out += "    <ram:IncludedNote>\n"
        out += "      <ram:Content>Baustelle: \(esc(title))</ram:Content>\n"
        out += "      <ram:SubjectCode>ADU</ram:SubjectCode>\n"
        out += "    </ram:IncludedNote>\n"
        out += "  </rsm:ExchangedDocument>\n"

        out += "  <rsm:SupplyChainTradeTransaction>\n"

        // Line items (BG-25)
        for (idx, item) in items.enumerated() {
            out += lineItem(nr: idx + 1, pos: item.pos, ep: item.ep, gp: item.gp)
        }

        // BG-4 Seller / BG-7 Buyer
        out += "    <ram:ApplicableHeaderTradeAgreement>\n"
        out += "      <ram:SellerTradeParty>\n"
        out += "        <ram:Name>iMOPS Bauleitung</ram:Name>\n"
        out += "        <ram:PostalTradeAddress><ram:CountryID>DE</ram:CountryID></ram:PostalTradeAddress>\n"
        out += "      </ram:SellerTradeParty>\n"
        out += "      <ram:BuyerTradeParty>\n"
        out += "        <ram:Name>\(esc(title))</ram:Name>\n"
        out += "        <ram:PostalTradeAddress><ram:CountryID>DE</ram:CountryID></ram:PostalTradeAddress>\n"
        out += "      </ram:BuyerTradeParty>\n"
        out += "      <ram:BuyerOrderReferencedDocument>\n"
        out += "        <ram:IssuerAssignedID>\(esc(title))</ram:IssuerAssignedID>\n"
        out += "      </ram:BuyerOrderReferencedDocument>\n"
        out += "    </ram:ApplicableHeaderTradeAgreement>\n"

        // BG-13 Delivery (mandatory stub)
        out += "    <ram:ApplicableHeaderTradeDelivery/>\n"

        // BG-22 totals + BG-23 VAT + payment terms
        out += "    <ram:ApplicableHeaderTradeSettlement>\n"
        out += "      <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>\n"
        out += "      <ram:ApplicableTradeTax>\n"
        out += "        <ram:CalculatedAmount>\(amt(vat))</ram:CalculatedAmount>\n"
        out += "        <ram:TypeCode>VAT</ram:TypeCode>\n"
        out += "        <ram:BasisAmount>\(amt(netto))</ram:BasisAmount>\n"
        out += "        <ram:CategoryCode>S</ram:CategoryCode>\n"
        out += "        <ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>\n"
        out += "      </ram:ApplicableTradeTax>\n"
        out += "      <ram:SpecifiedTradePaymentTerms>\n"
        out += "        <ram:Description>Zahlbar innerhalb von 30 Tagen ohne Abzug.</ram:Description>\n"
        out += "      </ram:SpecifiedTradePaymentTerms>\n"
        out += "      <ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n"
        out += "        <ram:LineTotalAmount>\(amt(netto))</ram:LineTotalAmount>\n"
        out += "        <ram:TaxBasisTotalAmount>\(amt(netto))</ram:TaxBasisTotalAmount>\n"
        out += "        <ram:TaxTotalAmount currencyID=\"EUR\">\(amt(vat))</ram:TaxTotalAmount>\n"
        out += "        <ram:GrandTotalAmount>\(amt(brutto))</ram:GrandTotalAmount>\n"
        out += "        <ram:DuePayableAmount>\(amt(brutto))</ram:DuePayableAmount>\n"
        out += "      </ram:SpecifiedTradeSettlementHeaderMonetarySummation>\n"
        out += "    </ram:ApplicableHeaderTradeSettlement>\n"

        out += "  </rsm:SupplyChainTradeTransaction>\n"
        out += "</rsm:CrossIndustryInvoice>\n"
        return out
    }

    private static func lineItem(nr: Int, pos: LVPosition, ep: Double, gp: Double) -> String {
        let name   = esc(pos.bezeichnung ?? "Position")
        let posNr  = esc(pos.posNr ?? "\(nr)")
        let unit   = xrUnit(pos.einheit ?? "")
        var s = ""
        s += "    <ram:IncludedSupplyChainTradeLineItem>\n"
        s += "      <ram:AssociatedDocumentLineDocument>\n"
        s += "        <ram:LineID>\(nr)</ram:LineID>\n"
        s += "        <ram:IncludedNote><ram:Content>\(posNr)</ram:Content></ram:IncludedNote>\n"
        s += "      </ram:AssociatedDocumentLineDocument>\n"
        s += "      <ram:SpecifiedTradeProduct>\n"
        s += "        <ram:Name>\(name)</ram:Name>\n"
        s += "      </ram:SpecifiedTradeProduct>\n"
        s += "      <ram:SpecifiedLineTradeAgreement>\n"
        s += "        <ram:NetPriceProductTradePrice>\n"
        s += "          <ram:ChargeAmount>\(amt(ep))</ram:ChargeAmount>\n"
        s += "        </ram:NetPriceProductTradePrice>\n"
        s += "      </ram:SpecifiedLineTradeAgreement>\n"
        s += "      <ram:SpecifiedLineTradeDelivery>\n"
        s += "        <ram:BilledQuantity unitCode=\"\(unit)\">\(qty(pos.menge))</ram:BilledQuantity>\n"
        s += "      </ram:SpecifiedLineTradeDelivery>\n"
        s += "      <ram:SpecifiedLineTradeSettlement>\n"
        s += "        <ram:ApplicableTradeTax>\n"
        s += "          <ram:TypeCode>VAT</ram:TypeCode>\n"
        s += "          <ram:CategoryCode>S</ram:CategoryCode>\n"
        s += "          <ram:RateApplicablePercent>19.00</ram:RateApplicablePercent>\n"
        s += "        </ram:ApplicableTradeTax>\n"
        s += "        <ram:SpecifiedTradeSettlementLineMonetarySummation>\n"
        s += "          <ram:LineTotalAmount>\(amt(gp))</ram:LineTotalAmount>\n"
        s += "        </ram:SpecifiedTradeSettlementLineMonetarySummation>\n"
        s += "      </ram:SpecifiedLineTradeSettlement>\n"
        s += "    </ram:IncludedSupplyChainTradeLineItem>\n"
        return s
    }

    // MARK: - Formatting helpers

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&",  with: "&amp;")
         .replacingOccurrences(of: "<",  with: "&lt;")
         .replacingOccurrences(of: ">",  with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func amt(_ v: Double) -> String { String(format: "%.2f", v) }
    private static func qty(_ v: Double) -> String { String(format: "%.3f", v) }

    // Map iMOPS units → UN/ECE Rec 20 unit codes required by XRechnung
    private static func xrUnit(_ einheit: String) -> String {
        switch einheit.lowercased() {
        case "m²", "m2":               return "MTK"  // square metre
        case "m³", "m3":               return "MTQ"  // cubic metre
        case "lfm", "lm", "m":         return "MTR"  // metre
        case "stück", "stk", "st":     return "C62"  // piece (UN/ECE)
        case "kg":                     return "KGM"  // kilogram
        case "t", "to":                return "TNE"  // metric ton
        case "psch", "pauschal":       return "LS"   // lump sum
        case "h", "std":               return "HUR"  // hour
        case "l", "ltr":               return "LTR"  // litre
        default:                       return "C62"  // fallback: piece
        }
    }
}
