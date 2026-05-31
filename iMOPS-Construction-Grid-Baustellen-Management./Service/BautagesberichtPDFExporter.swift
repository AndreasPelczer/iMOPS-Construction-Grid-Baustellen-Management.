import UIKit

// MARK: - Config

struct BautagesberichtConfig {
    var datum:               Date
    var witterung:           String
    var witterungSymbol:     String
    var temperatur:          String
    var personalAnzahl:      Int
    var geraete:             String
    var ausgefuehrteArbeiten: String
    var behinderungen:       String
    var notizen:             String
}

// MARK: - Exporter

struct BautagesberichtPDFExporter {

    static func generate(event: Event, config: BautagesberichtConfig) -> Data {
        Generator(event: event, config: config).generate()
    }

    private class Generator {
        let event:  Event
        let config: BautagesberichtConfig

        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let mH:    CGFloat = 40
        let mV:    CGFloat = 40
        var cW:    CGFloat { pageW - 2 * mH }
        let orange = UIColor(red: 0.91, green: 0.40, blue: 0.04, alpha: 1)
        var y: CGFloat = 40
        var ctx: UIGraphicsPDFRendererContext!

        init(event: Event, config: BautagesberichtConfig) {
            self.event  = event
            self.config = config
        }

        func generate() -> Data {
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
            return renderer.pdfData { c in
                self.ctx = c; self.y = self.mV
                c.beginPage()
                self.drawHeader()
                self.drawWitterungPersonal()
                self.drawTextBlock("Maschinen & Geräte", config.geraete)
                self.drawTextBlock("Ausgeführte Arbeiten", config.ausgefuehrteArbeiten)
                self.drawTextBlock("Behinderungen / Besonderheiten", config.behinderungen)
                self.drawAuftraege()
                self.drawLV()
                self.drawMaengel()
                self.drawTextBlock("Notizen", config.notizen)
                self.drawFooter()
            }
        }

        // MARK: Header

        func drawHeader() {
            fill(CGRect(x: mH, y: y, width: cW, height: 4), color: orange); y += 12
            txt("iMOPS Construction Grid", x: mH, y: y,
                font: .systemFont(ofSize: 9), color: UIColor(white: 0.5, alpha: 1)); y += 18
            txt("Bautagesbericht", x: mH, y: y,
                font: .systemFont(ofSize: 18, weight: .bold)); y += 30
            hline(at: y); y += 14

            let dateFmt = DateFormatter()
            dateFmt.dateStyle = .full
            dateFmt.locale = Locale(identifier: "de_DE")

            infoRow("Projekt:",    event.title    ?? "–")
            infoRow("Standort:",   event.location ?? "–")
            if let nr = event.eventNumber, !nr.isEmpty { infoRow("Baust.-Nr.:", nr) }
            if let b  = event.bauherr, !b.isEmpty      { infoRow("Bauherr:",   b) }
            infoRow("Datum:",      dateFmt.string(from: config.datum))
            infoRow("Erstellt:",   DateFormatter.localizedString(
                from: Date(), dateStyle: .medium, timeStyle: .short))
            y += 12; hline(at: y); y += 20
        }

        // MARK: Witterung & Personal

        func drawWitterungPersonal() {
            sectionHeader("Witterung & Personal")

            let boxH: CGFloat = 38
            let halfW = (cW - 8) / 2

            // Witterung box
            fill(CGRect(x: mH, y: y, width: halfW, height: boxH),
                 color: UIColor(white: 0.96, alpha: 1))
            txt(config.witterung, x: mH + 12, y: y + 6,
                font: .systemFont(ofSize: 11, weight: .semibold))
            if !config.temperatur.isEmpty {
                txt(config.temperatur, x: mH + 12, y: y + 22,
                    font: .systemFont(ofSize: 9),
                    color: UIColor(white: 0.45, alpha: 1))
            }

            // Personal box
            let px = mH + halfW + 8
            fill(CGRect(x: px, y: y, width: halfW, height: boxH),
                 color: UIColor(white: 0.96, alpha: 1))
            txt("\(config.personalAnzahl) Arbeiter", x: px + 12, y: y + 6,
                font: .systemFont(ofSize: 11, weight: .semibold))
            txt("Personal auf der Baustelle", x: px + 12, y: y + 22,
                font: .systemFont(ofSize: 9),
                color: UIColor(white: 0.45, alpha: 1))

            y += boxH + 14
        }

        // MARK: Generic Text Block

        func drawTextBlock(_ title: String, _ text: String) {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            pageBreakIfNeeded(60)
            sectionHeader(title)
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9)]
            let textH = (text as NSString).boundingRect(
                with: CGSize(width: cW - 16, height: 1000),
                options: .usesLineFragmentOrigin,
                attributes: attrs, context: nil).height + 8
                fill(CGRect(x: mH, y: y, width: cW, height: textH + 8),
                 color: UIColor(white: 0.97, alpha: 1))
            txtInRect(text,
                      rect: CGRect(x: mH + 8, y: y + 4, width: cW - 16, height: textH),
                      font: .systemFont(ofSize: 9))
            y += textH + 16
        }

        // MARK: Aufträge

        func drawAuftraege() {
            let all = (event.jobs?.allObjects as? [Auftrag]) ?? []
            guard !all.isEmpty else { return }
            let offen    = all.filter { !$0.isCompleted }
            let erledigt = all.filter {  $0.isCompleted }

            pageBreakIfNeeded(60)
            sectionHeader("Aufträge (\(all.count))")
            fill(CGRect(x: mH, y: y, width: cW, height: 28),
                 color: UIColor(white: 0.96, alpha: 1))
            txt("Offen: \(offen.count)", x: mH + 12, y: y + 8,
                font: .systemFont(ofSize: 10, weight: .semibold),
                color: offen.isEmpty ? UIColor.systemGreen : UIColor.systemOrange)
            txt("Erledigt: \(erledigt.count)", x: mH + 130, y: y + 8,
                font: .systemFont(ofSize: 10, weight: .semibold), color: .systemGreen)
            y += 32

            for job in offen.prefix(15) {
                pageBreakIfNeeded(18)
                fill(CGRect(x: mH, y: y, width: 3, height: 16), color: .systemOrange)
                txt("▸  \(job.employeeName ?? "–")", x: mH + 8, y: y + 2,
                    font: .systemFont(ofSize: 9))
                y += 18
            }
            y += 8
        }

        // MARK: LV

        func drawLV() {
            let pos = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
            guard !pos.isEmpty else { return }
            pageBreakIfNeeded(60)
            sectionHeader("Leistungsverzeichnis (\(pos.count) Positionen)")
            let grouped = Dictionary(grouping: pos) { $0.kostenGruppeNummer ?? "–" }
            for kg in grouped.keys.sorted() {
                let items = grouped[kg] ?? []
                pageBreakIfNeeded(18)
                txt("KG \(kg) – \(dinLabel(kg)):  \(items.count) Position\(items.count == 1 ? "" : "en")",
                    x: mH + 8, y: y, font: .systemFont(ofSize: 9))
                y += 16
            }
            y += 8
        }

        // MARK: Mängel

        func drawMaengel() {
            let all = (event.maengel?.allObjects as? [Mangel]) ?? []
            guard !all.isEmpty else { return }
            pageBreakIfNeeded(50)
            let offen    = all.filter { $0.status == .offen || $0.status == .inArbeit }
            let erledigt = all.count - offen.count
            sectionHeader("Mängel (\(all.count) gesamt)")
            fill(CGRect(x: mH, y: y, width: cW, height: 28),
                 color: UIColor(white: 0.96, alpha: 1))
            txt("Offen/In Arbeit: \(offen.count)", x: mH + 12, y: y + 8,
                font: .systemFont(ofSize: 10, weight: .semibold),
                color: offen.isEmpty ? UIColor.darkGray : UIColor.systemOrange)
            txt("Erledigt: \(erledigt)", x: mH + 180, y: y + 8,
                font: .systemFont(ofSize: 10, weight: .semibold), color: .systemGreen)
            y += 32 + 8
        }

        // MARK: Footer

        func drawFooter() {
            txt("iMOPS Construction Grid  ·  \(event.title ?? "")  ·  " +
                DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none),
                x: mH, y: pageH - 25,
                font: .systemFont(ofSize: 7.5), color: .lightGray)
        }

        // MARK: Helpers

        func sectionHeader(_ title: String) {
            fill(CGRect(x: mH, y: y, width: cW, height: 24),
                 color: orange.withAlphaComponent(0.1))
            fill(CGRect(x: mH, y: y, width: 3,  height: 24), color: orange)
            txt(title, x: mH + 10, y: y + 6,
                font: .systemFont(ofSize: 10, weight: .semibold), color: orange)
            y += 28
        }

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
            para.lineBreakMode = .byWordWrapping
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

        func dinLabel(_ kg: String) -> String {
            switch kg {
            case "300": return "Baukonstruktionen"
            case "310": return "Baugrube"
            case "320": return "Gründung"
            case "330": return "Außenwände"
            case "340": return "Innenwände"
            case "350": return "Decken"
            case "360": return "Dächer"
            case "400": return "Technische Anlagen"
            case "500": return "Außenanlagen"
            default:    return "Sonstige"
            }
        }
    }
}
