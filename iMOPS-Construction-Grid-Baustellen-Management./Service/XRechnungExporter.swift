import Foundation
import CoreData

// Generates a CII-based XRechnung 2.2 XML (EN 16931).
// TypeCode 380 = Handelsrechnung.
// Seller info + MwSt-Satz come from FirmenSettings (configured in Settings tab).
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

        // Firm settings
        let sellerName = FirmenSettings.name
        let mwst       = FirmenSettings.mwstSatz
        let vatCat     = FirmenSettings.vatCategory
        let ustId      = FirmenSettings.ustIdNr

        // Only non-alternative positions. Preis ueber den zentralen Resolver:
        // guenstigstes Angebot → kalkulierter VK (z.B. Pauschal-Traeger) → 0.
        let items: [(pos: LVPosition, ep: Double, gp: Double)] = positionen
            .filter { !LVPositionHelper.isAlternative($0) }
            .map { pos in
                let ep = LVKalkulator.effektiverEP(for: pos, store: store)
                return (pos, ep, ep * pos.menge)
            }

        let netto  = items.reduce(0.0) { $0 + $1.gp }
        let vat    = netto * mwst / 100.0
        let brutto = netto + vat

        var out = ""
        out += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        out += "<rsm:CrossIndustryInvoice\n"
        out += "  xmlns:rsm=\"urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100\"\n"
        out += "  xmlns:ram=\"urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100\"\n"
        out += "  xmlns:udt=\"urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100\"\n"
        out += "  xmlns:qdt=\"urn:un:unece:uncefact:data:standard:QualifiedDataType:100\">\n"

        // BT-24 Specification identifier
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
            out += lineItem(nr: idx + 1, pos: item.pos, ep: item.ep, gp: item.gp,
                            mwst: mwst, vatCat: vatCat)
        }

        // BG-4 Seller
        out += "    <ram:ApplicableHeaderTradeAgreement>\n"
        out += "      <ram:SellerTradeParty>\n"
        out += "        <ram:Name>\(esc(sellerName))</ram:Name>\n"
        // USt-IdNr if configured
        if !ustId.isEmpty {
            out += "        <ram:SpecifiedTaxRegistration>\n"
            out += "          <ram:ID schemeID=\"VA\">\(esc(ustId))</ram:ID>\n"
            out += "        </ram:SpecifiedTaxRegistration>\n"
        }
        out += "        <ram:PostalTradeAddress>\n"
        if !FirmenSettings.strasse.isEmpty {
            out += "          <ram:LineOne>\(esc(FirmenSettings.strasse))</ram:LineOne>\n"
        }
        if !FirmenSettings.plz.isEmpty {
            out += "          <ram:PostcodeCode>\(esc(FirmenSettings.plz))</ram:PostcodeCode>\n"
        }
        if !FirmenSettings.ort.isEmpty {
            out += "          <ram:CityName>\(esc(FirmenSettings.ort))</ram:CityName>\n"
        }
        out += "          <ram:CountryID>DE</ram:CountryID>\n"
        out += "        </ram:PostalTradeAddress>\n"
        out += "      </ram:SellerTradeParty>\n"
        // BG-7 Buyer
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
        out += "        <ram:CategoryCode>\(vatCat)</ram:CategoryCode>\n"
        out += "        <ram:RateApplicablePercent>\(amt(mwst))</ram:RateApplicablePercent>\n"
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

    private static func lineItem(nr: Int, pos: LVPosition, ep: Double, gp: Double,
                                  mwst: Double, vatCat: String) -> String {
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
        s += "          <ram:CategoryCode>\(vatCat)</ram:CategoryCode>\n"
        s += "          <ram:RateApplicablePercent>\(amt(mwst))</ram:RateApplicablePercent>\n"
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
