import UIKit
import Combine

struct LVPDFExporter {

    static func generate(event: Event, positionen: [LVPosition]) -> Data {
        Generator(event: event, positionen: positionen.ohneBewehrungsDuplikate()).generate()
    }

    // MARK: - Generator

    private class Generator {
        let event: Event
        let positionen: [LVPosition]

        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let mH:    CGFloat = 40
        let mV:    CGFloat = 40
        var cW:    CGFloat { pageW - 2 * mH }

        // Col widths: Pos(35) ArtNr(70) Bez(190) Menge(50) Einh(45) EP(62.5) GP(62.5) = 515
        let colW: [CGFloat] = [35, 70, 190, 50, 45, 62.5, 62.5]
        let colHdrs = ["Pos.", "Art.-Nr.", "Bezeichnung", "Menge", "Einheit", "EP (€)", "GP (€)"]

        let orange = UIColor(red: 0.91, green: 0.40, blue: 0.04, alpha: 1)
        var y: CGFloat = 40
        var ctx: UIGraphicsPDFRendererContext!

        /// Laufende Netto-Summe ueber alle Positionen (gefuellt in drawKG).
        var gesamtNetto: Double = 0

        let eurFmt: NumberFormatter = {
            let f = NumberFormatter()
            f.numberStyle  = .currency
            f.currencyCode = "EUR"
            f.locale       = Locale(identifier: "de_DE")
            return f
        }()
        func eur(_ v: Double) -> String {
            eurFmt.string(from: NSNumber(value: v)) ?? String(format: "%.2f €", v)
        }

        init(event: Event, positionen: [LVPosition]) {
            self.event = event
            self.positionen = positionen
        }

        func generate() -> Data {
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
            )
            return renderer.pdfData { c in
                self.ctx = c
                self.y   = self.mV
                c.beginPage()
                self.drawHeader()
                self.drawPositionen()
                self.drawKostenZusammenfassung()
                self.drawFooter()
            }
        }

        // MARK: Header / Deckblatt

        func drawHeader() {
            fill(CGRect(x: mH, y: y, width: cW, height: 4), color: orange)
            y += 12

            txt("iMOPS Construction Grid", x: mH, y: y,
                font: .systemFont(ofSize: 9), color: UIColor(white: 0.5, alpha: 1))
            y += 18

            txt("Leistungsverzeichnis", x: mH, y: y,
                font: .systemFont(ofSize: 18, weight: .bold))
            y += 30

            hline(at: y); y += 14

            infoRow("Projekt:",    event.title    ?? "–")
            infoRow("Standort:",   event.location ?? "–")
            infoRow("Datum:",      DateFormatter.localizedString(from: Date(),
                                        dateStyle: .long, timeStyle: .none))
            infoRow("Positionen:", "\(positionen.count)")

            y += 12
            hline(at: y); y += 20
        }

        func infoRow(_ label: String, _ value: String) {
            txt(label, x: mH, y: y,
                font: .systemFont(ofSize: 10, weight: .semibold),
                color: UIColor(white: 0.45, alpha: 1))
            txt(value, x: mH + 110, y: y,
                font: .systemFont(ofSize: 10))
            y += 17
        }

        // MARK: Positionen

        func drawPositionen() {
            let grouped = Dictionary(grouping: positionen) { $0.kostenGruppeNummer ?? "999" }
            for kg in grouped.keys.sorted() {
                let items = (grouped[kg] ?? []).sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
                guard !items.isEmpty else { continue }
                pageBreakIfNeeded(60)
                drawKG(kg, items: items)
            }
        }

        func drawKG(_ kg: String, items: [LVPosition]) {
            // Section header
            fill(CGRect(x: mH,     y: y, width: cW, height: 22), color: orange.withAlphaComponent(0.1))
            fill(CGRect(x: mH,     y: y, width: 3,  height: 22), color: orange)
            txt("KG \(kg)  –  \(dinLabel(kg))",
                x: mH + 8, y: y + 5,
                font: .systemFont(ofSize: 9, weight: .semibold), color: orange)
            y += 26

            // Table header row
            fill(CGRect(x: mH, y: y, width: cW, height: 16),
                 color: UIColor(white: 0.88, alpha: 1))
            var xOff = mH
            for (i, h) in colHdrs.enumerated() {
                let align: NSTextAlignment = i >= 3 ? .right : .left
                txtInRect(h,
                          rect: CGRect(x: xOff+3, y: y+3, width: colW[i]-6, height: 10),
                          font: .systemFont(ofSize: 8, weight: .semibold),
                          color: .darkGray, align: align)
                xOff += colW[i]
            }
            y += 18

            // Data rows
            for (idx, pos) in items.enumerated() {
                pageBreakIfNeeded(18)
                if idx % 2 == 1 {
                    fill(CGRect(x: mH, y: y, width: cW, height: 18),
                         color: UIColor(white: 0.96, alpha: 1))
                }
                let ep = LVKalkulator.effektiverEP(for: pos)
                let gp = ep * pos.menge
                gesamtNetto += gp
                let vals: [(String, NSTextAlignment)] = [
                    (pos.posNr        ?? "",  .left),
                    (pos.artikelNummer ?? "", .left),
                    (pos.bezeichnung  ?? "",  .left),
                    (pos.menge > 0 ? String(format: "%.2f", pos.menge) : "", .right),
                    (pos.einheit      ?? "",  .left),
                    (ep > 0 ? eur(ep) : "", .right),
                    (gp > 0 ? eur(gp) : "", .right)
                ]
                xOff = mH
                for (i, (val, align)) in vals.enumerated() {
                    txtInRect(val,
                              rect: CGRect(x: xOff+3, y: y+3, width: colW[i]-6, height: 15),
                              font: .systemFont(ofSize: 9), align: align)
                    xOff += colW[i]
                }
                // Row separator
                UIColor(white: 0.88, alpha: 1).setStroke()
                let p = UIBezierPath()
                p.move(to: CGPoint(x: mH,    y: y+18))
                p.addLine(to: CGPoint(x: mH+cW, y: y+18))
                p.lineWidth = 0.25
                p.stroke()
                y += 18
            }
            y += 12
        }

        // MARK: Kostenzusammenfassung (DIN 276: Netto + MwSt + Brutto)

        func drawKostenZusammenfassung() {
            pageBreakIfNeeded(90)
            y += 8
            hline(at: y); y += 12

            let mwstSatz = FirmenSettings.mwstSatz
            let mwst     = gesamtNetto * mwstSatz / 100
            let brutto   = gesamtNetto + mwst

            summenZeile("Summe netto", gesamtNetto, bold: false)
            summenZeile("zzgl. MwSt. \(pctStr(mwstSatz)) %", mwst, bold: false)
            y += 2; hline(at: y); y += 10
            summenZeile("Summe brutto", brutto, bold: true)
        }

        /// Eine rechtsbuendige Summenzeile (Label + Betrag) am rechten Rand.
        func summenZeile(_ label: String, _ value: Double, bold: Bool) {
            let font: UIFont = .systemFont(ofSize: bold ? 11 : 10,
                                           weight: bold ? .bold : .regular)
            let labelRect = CGRect(x: mH + cW - 300, y: y, width: 185, height: 16)
            txtInRect(label, rect: labelRect, font: font,
                      color: bold ? .black : UIColor(white: 0.3, alpha: 1), align: .right)
            let valRect = CGRect(x: mH + cW - 110, y: y, width: 110, height: 16)
            txtInRect(eur(value), rect: valRect, font: font,
                      color: bold ? orange : .black, align: .right)
            y += 18
        }

        /// Prozentsatz ohne unnoetige Nachkommastelle (19,0 → "19").
        func pctStr(_ v: Double) -> String {
            v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.1f", v)
        }

        // MARK: Footer

        func drawFooter() {
            let dateStr = DateFormatter.localizedString(from: Date(),
                                                       dateStyle: .medium, timeStyle: .none)
            txt("iMOPS Construction Grid  ·  \(event.title ?? "")  ·  \(dateStr)",
                x: mH, y: pageH - 25,
                font: .systemFont(ofSize: 7.5), color: .lightGray)
        }

        // MARK: Drawing helpers

        func fill(_ rect: CGRect, color: UIColor) {
            color.setFill()
            UIRectFill(rect)
        }

        func hline(at lineY: CGFloat) {
            UIColor(white: 0.75, alpha: 1).setStroke()
            let p = UIBezierPath()
            p.move(to:    CGPoint(x: mH,    y: lineY))
            p.addLine(to: CGPoint(x: mH+cW, y: lineY))
            p.lineWidth = 0.5
            p.stroke()
        }

        func txt(_ s: String, x: CGFloat, y: CGFloat,
                 font: UIFont, color: UIColor = .black) {
            s.draw(at: CGPoint(x: x, y: y),
                   withAttributes: [.font: font, .foregroundColor: color])
        }

        func txtInRect(_ s: String, rect: CGRect,
                       font: UIFont, color: UIColor = .black,
                       align: NSTextAlignment = .left) {
            let para = NSMutableParagraphStyle()
            para.alignment     = align
            para.lineBreakMode = .byTruncatingTail
            s.draw(in: rect, withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: para
            ])
        }

        func pageBreakIfNeeded(_ needed: CGFloat) {
            guard y + needed > pageH - mV - 20 else { return }
            drawFooter()
            ctx.beginPage()
            y = mV
        }

        func dinLabel(_ kg: String) -> String {
            switch kg {
            case "100": return "Grundstück"
            case "200": return "Herrichten & Erschließen"
            case "300": return "Baukonstruktionen"
            case "310": return "Baugrube"
            case "320": return "Gründung"
            case "330": return "Außenwände"
            case "340": return "Innenwände"
            case "350": return "Decken"
            case "360": return "Dächer"
            case "370": return "Infrastruktur"
            case "380": return "Fenster & Türen"
            case "390": return "Sonstige Baukonstruktion"
            case "400": return "Technische Anlagen"
            case "410": return "Abwasser, Wasser, Gas"
            case "420": return "Wärmeversorgung"
            case "430": return "Lufttechnische Anlagen"
            case "440": return "Starkstrom"
            case "450": return "Fernmelde- & IT-Anlagen"
            case "500": return "Außenanlagen"
            case "600": return "Ausstattung"
            case "700": return "Baunebenkosten"
            default:    return "Sonstige"
            }
        }
    }
}
