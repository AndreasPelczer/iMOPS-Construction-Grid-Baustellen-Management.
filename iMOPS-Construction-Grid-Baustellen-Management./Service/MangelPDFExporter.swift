import UIKit
import Combine

struct MangelPDFExporter {

    static func generate(event: Event, maengel: [Mangel]) -> Data {
        Generator(event: event, maengel: maengel).generate()
    }

    private class Generator {
        let event:  Event
        let maengel: [Mangel]

        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let mH:    CGFloat = 40
        let mV:    CGFloat = 40
        var cW:    CGFloat { pageW - 2 * mH }
        let red    = UIColor(red: 0.85, green: 0.12, blue: 0.08, alpha: 1)
        let orange = UIColor(red: 0.91, green: 0.40, blue: 0.04, alpha: 1)
        var y: CGFloat = 40
        var ctx: UIGraphicsPDFRendererContext!

        init(event: Event, maengel: [Mangel]) {
            self.event   = event
            self.maengel = maengel
        }

        func generate() -> Data {
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
            return renderer.pdfData { c in
                self.ctx = c; self.y = self.mV
                c.beginPage()
                self.drawHeader()
                self.drawSummary()
                self.drawMangelListe()
                self.drawFooter()
            }
        }

        // MARK: - Header

        func drawHeader() {
            fill(CGRect(x: mH, y: y, width: cW, height: 4), color: red); y += 12
            txt("iMOPS Construction Grid", x: mH, y: y,
                font: .systemFont(ofSize: 9), color: UIColor(white: 0.5, alpha: 1)); y += 18
            txt("Mängelprotokoll", x: mH, y: y,
                font: .systemFont(ofSize: 18, weight: .bold)); y += 30
            hline(at: y); y += 14

            let dateFmt = DateFormatter()
            dateFmt.dateStyle = .full
            dateFmt.locale = Locale(identifier: "de_DE")

            infoRow("Projekt:",   event.title    ?? "–")
            infoRow("Standort:",  event.location ?? "–")
            if let nr = event.eventNumber, !nr.isEmpty { infoRow("Baust.-Nr.:", nr) }
            if let b  = event.bauherr, !b.isEmpty      { infoRow("Bauherr:",   b) }
            infoRow("Erstellt:",  DateFormatter.localizedString(
                from: Date(), dateStyle: .medium, timeStyle: .short))
            y += 12; hline(at: y); y += 16
        }

        // MARK: - Summary Chips

        func drawSummary() {
            let offen    = maengel.filter { $0.status == .offen }.count
            let inArbeit = maengel.filter { $0.status == .inArbeit }.count
            let erledigt = maengel.filter { $0.status == .erledigt }.count
            let ueberfaellig = maengel.filter { $0.istUeberfaellig }.count

            let chipH: CGFloat = 34
            let chipW = (cW - 12) / 4

            func chip(_ label: String, _ count: Int, _ color: UIColor, xOff: CGFloat) {
                let x = mH + xOff
                fill(CGRect(x: x, y: y, width: chipW - 4, height: chipH),
                     color: color.withAlphaComponent(0.12))
                fill(CGRect(x: x, y: y, width: 3, height: chipH), color: color)
                txt("\(count)", x: x + 10, y: y + 4,
                    font: .systemFont(ofSize: 14, weight: .bold), color: color)
                txt(label, x: x + 10, y: y + 20,
                    font: .systemFont(ofSize: 7.5), color: UIColor(white: 0.4, alpha: 1))
            }

            chip("Offen",       offen,       .systemOrange, xOff: 0)
            chip("In Arbeit",   inArbeit,    .systemBlue,   xOff: chipW)
            chip("Erledigt",    erledigt,    .systemGreen,  xOff: chipW * 2)
            chip("Überfällig",  ueberfaellig, .systemRed,   xOff: chipW * 3)

            y += chipH + 16
        }

        // MARK: - Mängel Liste

        func drawMangelListe() {
            // Header row
            fill(CGRect(x: mH, y: y, width: cW, height: 18),
                 color: UIColor(white: 0.88, alpha: 1))
            txt("#",        x: mH + 4,   y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Status",   x: mH + 24,  y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Schwere",  x: mH + 90,  y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Titel / Ort / Gewerk",
                            x: mH + 150, y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Frist",    x: mH + 390, y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            y += 22

            let sorted = maengel.sorted {
                let o: [MangelStatus] = [.offen, .inArbeit, .erledigt, .abgelehnt]
                let a = o.firstIndex(of: $0.status) ?? 99
                let b = o.firstIndex(of: $1.status) ?? 99
                return a < b
            }

            for (idx, mangel) in sorted.enumerated() {
                drawMangelRow(idx + 1, mangel: mangel)
            }
        }

        func drawMangelRow(_ nr: Int, mangel: Mangel) {
            // Estimate height needed
            let beschr = mangel.beschreibung ?? ""
            let descHeight: CGFloat = beschr.isEmpty ? 0 : 24
            let rowH: CGFloat = 38 + descHeight
            pageBreakIfNeeded(rowH + 4)

            let bg = nr.isMultiple(of: 2)
                ? UIColor(white: 0.97, alpha: 1)
                : UIColor.white
            fill(CGRect(x: mH, y: y, width: cW, height: rowH), color: bg)

            // Left border = status colour
            fill(CGRect(x: mH, y: y, width: 3, height: rowH), color: mangel.status.uiColor)

            // Nr
            txt("\(nr)", x: mH + 6, y: y + 12,
                font: .systemFont(ofSize: 8), color: UIColor(white: 0.55, alpha: 1))

            // Status pill
            let sLabel = mangel.status.displayName
            let sRect  = CGRect(x: mH + 20, y: y + 8, width: 64, height: 16)
            fill(sRect.insetBy(dx: 0, dy: 0),
                 color: mangel.status.uiColor.withAlphaComponent(0.18))
            txt(sLabel, x: sRect.minX + 4, y: sRect.minY + 3,
                font: .systemFont(ofSize: 7.5, weight: .semibold),
                color: mangel.status.uiColor)

            // Schwere pill
            let schwLabel = mangel.mangelSchwere.displayName
            let schwRect  = CGRect(x: mH + 88, y: y + 8, width: 54, height: 16)
            fill(schwRect, color: mangel.mangelSchwere.uiColor.withAlphaComponent(0.18))
            txt(schwLabel, x: schwRect.minX + 4, y: schwRect.minY + 3,
                font: .systemFont(ofSize: 7.5, weight: .semibold),
                color: mangel.mangelSchwere.uiColor)

            // Titel
            txt(mangel.titel ?? "–", x: mH + 148, y: y + 6,
                font: .systemFont(ofSize: 9, weight: .semibold))

            // Ort · Gewerk
            var meta: [String] = []
            if let ort = mangel.ort, !ort.isEmpty       { meta.append(ort) }
            if let gew = mangel.gewerk, !gew.isEmpty     { meta.append(gew) }
            if !meta.isEmpty {
                txt(meta.joined(separator: " · "), x: mH + 148, y: y + 19,
                    font: .systemFont(ofSize: 7.5), color: UIColor(white: 0.5, alpha: 1))
            }

            // Frist
            if let frist = mangel.frist {
                let fStr = frist.formatted(date: .abbreviated, time: .omitted)
                txt(fStr, x: mH + 388, y: y + 6,
                    font: .systemFont(ofSize: 8),
                    color: mangel.istUeberfaellig ? .systemRed : UIColor(white: 0.35, alpha: 1))
                if mangel.istUeberfaellig {
                    txt("!", x: mH + 388, y: y + 18,
                        font: .systemFont(ofSize: 8, weight: .bold), color: .systemRed)
                }
            }

            // Beschreibung
            if !beschr.isEmpty {
                txtInRect(beschr,
                          rect: CGRect(x: mH + 148, y: y + 30, width: cW - 160, height: 22),
                          font: .systemFont(ofSize: 7.5),
                          color: UIColor(white: 0.35, alpha: 1))
            }

            y += rowH + 2
        }

        // MARK: - Footer

        func drawFooter() {
            txt("iMOPS Construction Grid  ·  Mängelprotokoll  ·  \(event.title ?? "")  ·  " +
                DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none),
                x: mH, y: pageH - 25,
                font: .systemFont(ofSize: 7.5), color: .lightGray)
        }

        // MARK: - Helpers

        func fill(_ rect: CGRect, color: UIColor) { color.setFill(); UIRectFill(rect) }

        func hline(at lineY: CGFloat) {
            UIColor(white: 0.75, alpha: 1).setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: mH, y: lineY))
            p.addLine(to: CGPoint(x: mH + cW, y: lineY))
            p.lineWidth = 0.5; p.stroke()
        }

        func txt(_ s: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor = .black) {
            s.draw(at: CGPoint(x: x, y: y),
                   withAttributes: [.font: font, .foregroundColor: color])
        }

        func txtInRect(_ s: String, rect: CGRect, font: UIFont, color: UIColor = .black) {
            let para = NSMutableParagraphStyle()
            para.lineBreakMode = .byTruncatingTail
            s.draw(in: rect, withAttributes: [
                .font: font, .foregroundColor: color, .paragraphStyle: para
            ])
        }

        func infoRow(_ label: String, _ value: String) {
            txt(label, x: mH, y: y,
                font: .systemFont(ofSize: 10, weight: .semibold),
                color: UIColor(white: 0.45, alpha: 1))
            txt(value, x: mH + 110, y: y, font: .systemFont(ofSize: 10))
            y += 17
        }

        func pageBreakIfNeeded(_ needed: CGFloat) {
            guard y + needed > pageH - mV - 20 else { return }
            drawFooter(); ctx.beginPage(); y = mV
        }
    }
}

// MARK: - UIColor extensions for MangelStatus / MangelSchwere

private extension MangelStatus {
    var uiColor: UIColor {
        switch self {
        case .offen:      return .systemOrange
        case .inArbeit:   return .systemBlue
        case .behoben:    return .systemGreen
        case .erledigt:   return .systemGreen
        case .abgenommen: return .systemGreen
        case .abgelehnt:  return .systemGray
        }
    }
}

private extension MangelSchwere {
    var uiColor: UIColor {
        switch self {
        case .gering:        return .systemGreen
        case .mittel:        return .systemOrange
        case .kritisch:      return .systemRed
        case .schwerwiegend: return .systemRed
        }
    }
}
