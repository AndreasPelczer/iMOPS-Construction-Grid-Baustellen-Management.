import UIKit
import Combine

struct LVPDFExporter {

    static func generate(event: Event, positionen: [LVPosition]) -> Data {
        Generator(event: event, positionen: positionen.zaehlbarePositionen()).generate()
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

        /// Laufende Netto-Summe ueber alle Positionen (gefuellt in drawTitel).
        var gesamtNetto: Double = 0
        /// Je Titel: Nummer, Name, Summe — für die Titelzusammenstellung (Raphis Form).
        var titelSummen: [(nr: String, name: String, summe: Double)] = []

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
                self.drawTitelzusammenstellung()
                self.drawKostenZusammenfassung()
                self.drawFooter()
            }
        }

        // MARK: Header / Deckblatt

        func drawHeader() {
            // Firmenkopf (Logo + Anschrift) aus dem Briefpapier — Raphis Kopf.
            y = Briefpapier.zeichneKopf(ab: y, links: mH, breite: cW)
            y += 8

            // Empfänger (Bauherr) als Anschriftenfeld.
            let plzOrt = [event.bauherrPLZ, event.bauherrOrt].compactMap { $0 }
                .filter { !$0.isEmpty }.joined(separator: " ")
            let empf = [event.bauherr, event.bauherrStrasse, plzOrt]
                .compactMap { $0 }.filter { !$0.isEmpty }
            if !empf.isEmpty {
                y = Briefpapier.zeichneEmpfaenger(empf, ab: y, links: mH) + 16
            } else {
                y += 8
            }

            // Angebot-Titel links, Kopfdaten rechts.
            let datum = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
            txt("Angebot", x: mH, y: y, font: .systemFont(ofSize: 16, weight: .bold), color: orange)
            txtInRect("Angebots-Nr.: \(event.eventNumber ?? "–")",
                      rect: CGRect(x: mH + cW - 240, y: y + 1, width: 240, height: 12),
                      font: .systemFont(ofSize: 9.5), align: .right)
            txtInRect("Datum: \(datum)",
                      rect: CGRect(x: mH + cW - 240, y: y + 14, width: 240, height: 12),
                      font: .systemFont(ofSize: 9.5), align: .right)
            y += 24
            txt("Objekt: \(event.title ?? "–")", x: mH, y: y,
                font: .systemFont(ofSize: 10, weight: .semibold)); y += 15
            if let ort = event.location, !ort.isEmpty {
                txt(ort, x: mH, y: y, font: .systemFont(ofSize: 9.5),
                    color: UIColor(white: 0.35, alpha: 1)); y += 14
            }
            y += 4; hline(at: y); y += 12

            // Anschreiben.
            txt("Sehr geehrte Damen und Herren,", x: mH, y: y, font: .systemFont(ofSize: 10)); y += 15
            txtInRect("beiliegend erhalten Sie unser Angebot. Es ist ein Einheitspreis-Angebot; die Abrechnung erfolgt nach tatsächlich geleisteten Mengen. Wir sichern Ihnen eine fachgerechte und termingerechte Ausführung der Arbeiten nach VOB zu.",
                      rect: CGRect(x: mH, y: y, width: cW, height: 42),
                      font: .systemFont(ofSize: 9.5), color: UIColor(white: 0.2, alpha: 1))
            y += 46; hline(at: y); y += 14
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
            var titelNr = 0
            for kg in grouped.keys.sorted() {
                let items = (grouped[kg] ?? []).sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
                guard !items.isEmpty else { continue }
                titelNr += 1
                let nr = String(format: "%02d", titelNr)
                let name = dinLabel(kg)
                pageBreakIfNeeded(70)
                let summe = drawTitel(nr, name: name, items: items)
                titelSummen.append((nr: nr, name: name, summe: summe))
            }
        }

        /// Ein Titel-Block (Kopf → Positionen → Titelsumme). Gibt die Titelsumme zurück.
        func drawTitel(_ nr: String, name: String, items: [LVPosition]) -> Double {
            // Titel-Kopf
            fill(CGRect(x: mH, y: y, width: cW, height: 22), color: orange.withAlphaComponent(0.1))
            fill(CGRect(x: mH, y: y, width: 3,  height: 22), color: orange)
            txt("\(nr).   \(name.uppercased())", x: mH + 8, y: y + 5,
                font: .systemFont(ofSize: 10, weight: .bold), color: orange)
            y += 26

            // Table header
            fill(CGRect(x: mH, y: y, width: cW, height: 16), color: UIColor(white: 0.88, alpha: 1))
            var xOff = mH
            for (i, h) in colHdrs.enumerated() {
                let align: NSTextAlignment = i >= 3 ? .right : .left
                txtInRect(h, rect: CGRect(x: xOff+3, y: y+3, width: colW[i]-6, height: 10),
                          font: .systemFont(ofSize: 8, weight: .semibold), color: .darkGray, align: align)
                xOff += colW[i]
            }
            y += 18

            // Data rows
            var titelSumme: Double = 0
            for (idx, pos) in items.enumerated() {
                pageBreakIfNeeded(18)
                if idx % 2 == 1 {
                    fill(CGRect(x: mH, y: y, width: cW, height: 18), color: UIColor(white: 0.96, alpha: 1))
                }
                let ep = LVKalkulator.effektiverEP(for: pos)
                let gp = ep * pos.menge
                gesamtNetto += gp
                titelSumme += gp
                let vals: [(String, NSTextAlignment)] = [
                    (pos.posNr ?? "", .left),
                    (pos.artikelNummer ?? "", .left),
                    (pos.bezeichnung ?? "", .left),
                    (pos.menge > 0 ? String(format: "%.2f", pos.menge) : "", .right),
                    (pos.einheit ?? "", .left),
                    (ep > 0 ? eur(ep) : "", .right),
                    (gp > 0 ? eur(gp) : "", .right)
                ]
                xOff = mH
                for (i, (val, align)) in vals.enumerated() {
                    txtInRect(val, rect: CGRect(x: xOff+3, y: y+3, width: colW[i]-6, height: 15),
                              font: .systemFont(ofSize: 9), align: align)
                    xOff += colW[i]
                }
                UIColor(white: 0.88, alpha: 1).setStroke()
                let p = UIBezierPath()
                p.move(to: CGPoint(x: mH, y: y+18)); p.addLine(to: CGPoint(x: mH+cW, y: y+18))
                p.lineWidth = 0.25; p.stroke()
                y += 18
            }

            // Titelsumme
            pageBreakIfNeeded(24)
            y += 3
            txtInRect("Titelsumme \(nr)  \(name)",
                      rect: CGRect(x: mH + cW - 340, y: y, width: 220, height: 14),
                      font: .systemFont(ofSize: 9.5, weight: .semibold), align: .right)
            txtInRect(eur(titelSumme),
                      rect: CGRect(x: mH + cW - 120, y: y, width: 120, height: 14),
                      font: .systemFont(ofSize: 9.5, weight: .bold), color: orange, align: .right)
            y += 22
            return titelSumme
        }

        // MARK: Titelzusammenstellung

        func drawTitelzusammenstellung() {
            guard titelSummen.count > 1 else { return }
            pageBreakIfNeeded(40 + CGFloat(titelSummen.count) * 16)
            y += 6
            txt("Titelzusammenstellung", x: mH, y: y,
                font: .systemFont(ofSize: 12, weight: .bold)); y += 20
            for t in titelSummen {
                txtInRect("\(t.nr)   \(t.name)",
                          rect: CGRect(x: mH, y: y, width: cW - 130, height: 14),
                          font: .systemFont(ofSize: 9.5))
                txtInRect(eur(t.summe),
                          rect: CGRect(x: mH + cW - 130, y: y, width: 130, height: 14),
                          font: .systemFont(ofSize: 9.5), align: .right)
                y += 16
            }
            y += 2; hline(at: y); y += 8
        }

        // MARK: Kostenzusammenfassung (DIN 276: Netto + MwSt + Brutto)

        func drawKostenZusammenfassung() {
            pageBreakIfNeeded(90)
            y += 8
            hline(at: y); y += 12

            let mwstSatz = FirmenSettings.mwstSatz
            let mwst     = gesamtNetto * mwstSatz / 100
            let brutto   = gesamtNetto + mwst

            summenZeile("LV-Gesamtsumme (netto)", gesamtNetto, bold: true)
            summenZeile("zzgl. MwSt. \(pctStr(mwstSatz)) %", mwst, bold: false)
            y += 2; hline(at: y); y += 10
            summenZeile("Angebotsendsumme", brutto, bold: true)
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
            // Firmen-Fuß (Kontakt/Bank/Steuer + kurzer Rechtstext) aus dem Briefpapier.
            _ = Briefpapier.zeichneFuss(seitenHoehe: pageH, links: mH, breite: cW)
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

        /// DIN-276-Bezeichnung zu einer KG-Nummer.
        /// Kommt aus DIN276KostenGruppe (abgeleitet aus dem Baum-Katalog) — vorher stand
        /// hier eine eigene switch-Kopie, die nur Hunderter/Zehner kannte.
        private func dinLabel(_ kg: String) -> String {
            DIN276KostenGruppe.bezeichnung(fuer: kg)
        }
    }
}
