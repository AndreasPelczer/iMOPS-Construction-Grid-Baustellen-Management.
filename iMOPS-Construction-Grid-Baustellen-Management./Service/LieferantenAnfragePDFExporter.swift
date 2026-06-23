import UIKit

struct LieferantenAnfragePDFExporter {
    static func generate(
        kontakt: LieferantenAnfrageKontakt,
        kontext: LieferantenAnfrageKontext,
        anfrage: UniversalAnfrage
    ) -> Data {
        Generator(kontakt: kontakt, kontext: kontext, anfrage: anfrage).generate()
    }

    private final class Generator {
        let kontakt: LieferantenAnfrageKontakt
        let kontext: LieferantenAnfrageKontext
        let anfrage: UniversalAnfrage

        let pageW: CGFloat = 595
        let pageH: CGFloat = 842
        let mH: CGFloat = 40
        let mV: CGFloat = 40
        var cW: CGFloat { pageW - 2 * mH }

        let orange = UIColor(red: 0.91, green: 0.40, blue: 0.04, alpha: 1)
        var y: CGFloat = 40
        var ctx: UIGraphicsPDFRendererContext!

        init(
            kontakt: LieferantenAnfrageKontakt,
            kontext: LieferantenAnfrageKontext,
            anfrage: UniversalAnfrage
        ) {
            self.kontakt = kontakt
            self.kontext = kontext
            self.anfrage = anfrage
        }

        func generate() -> Data {
            let renderer = UIGraphicsPDFRenderer(
                bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
            )
            return renderer.pdfData { c in
                self.ctx = c
                self.y = self.mV
                c.beginPage()
                self.drawHeader()
                self.drawEmpfaenger()
                self.drawPositionen()
                self.drawRueckmeldung()
                self.drawFooter()
            }
        }

        func drawHeader() {
            fill(CGRect(x: mH, y: y, width: cW, height: 4), color: orange)
            y += 12

            txt("iMOPS Construction Grid", x: mH, y: y,
                font: .systemFont(ofSize: 9), color: UIColor(white: 0.5, alpha: 1))
            y += 18

            txt(LieferantenAnfrageFormatter.betreff(kontakt: kontakt, kontext: kontext),
                x: mH, y: y, font: .systemFont(ofSize: 18, weight: .bold))
            y += 30

            hline(at: y)
            y += 14

            infoRow("Projekt:", kontext.baustelle)
            if let nr = kontext.baustellenNummer, !nr.isEmpty { infoRow("Baust.-Nr.:", nr) }
            if let standort = kontext.standort, !standort.isEmpty { infoRow("Standort:", standort) }
            if let bauherr = kontext.bauherr, !bauherr.isEmpty { infoRow("Bauherr:", bauherr) }
            infoRow("Datum:", dateFormatter.string(from: kontext.datum))
            infoRow("Status:", anfrage.status.rawValue)
            infoRow("Lieferfenster:", lieferfensterText())
            infoRow("Positionen:", "\(anfrage.positionen.count)")

            y += 12
            hline(at: y)
            y += 18
        }

        func drawEmpfaenger() {
            sectionTitle("Empfaenger")
            infoRow("Lieferant:", kontakt.name)
            if !kontakt.email.isEmpty { infoRow("E-Mail:", kontakt.email) }
            y += 10
        }

        func drawPositionen() {
            sectionTitle("Materialbedarf")
            tableHeader()
            for (index, position) in anfrage.positionen.enumerated() {
                drawPosition(position, index: index)
            }
            y += 10
        }

        func drawRueckmeldung() {
            pageBreakIfNeeded(110)
            sectionTitle("Rueckmeldung Lieferant")
            boxLine("Preis / Angebot:")
            boxLine("Verfuegbar ab:")
            boxLine("Liefertermin:")
            boxLine("Bemerkung:")
        }

        func drawFooter() {
            txt("Automatisch erstellt aus iMOPS · Bedarfsnachweis je Position enthalten",
                x: mH, y: pageH - 25,
                font: .systemFont(ofSize: 7.5), color: .lightGray)
        }

        func infoRow(_ label: String, _ value: String) {
            txt(label, x: mH, y: y,
                font: .systemFont(ofSize: 10, weight: .semibold),
                color: UIColor(white: 0.45, alpha: 1))
            txt(value, x: mH + 110, y: y, font: .systemFont(ofSize: 10))
            y += 17
        }

        func sectionTitle(_ title: String) {
            pageBreakIfNeeded(45)
            fill(CGRect(x: mH, y: y, width: cW, height: 22), color: orange.withAlphaComponent(0.1))
            fill(CGRect(x: mH, y: y, width: 3, height: 22), color: orange)
            txt(title, x: mH + 8, y: y + 5,
                font: .systemFont(ofSize: 9, weight: .semibold), color: orange)
            y += 30
        }

        func tableHeader() {
            fill(CGRect(x: mH, y: y, width: cW, height: 18), color: UIColor(white: 0.88, alpha: 1))
            txt("Pos.", x: mH + 4, y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Material / Nachweis", x: mH + 55, y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Menge", x: mH + cW - 105, y: y + 4, font: .systemFont(ofSize: 8, weight: .semibold))
            y += 22
        }

        func drawPosition(_ position: BedarfsPosition, index: Int) {
            let nachweis = nachweisText(position.bedarfsquelle)
            let materialHeight = height(for: position.material, width: cW - 165, font: .systemFont(ofSize: 9))
            let nachweisHeight = height(for: "Nachweis: \(nachweis)", width: cW - 165, font: .systemFont(ofSize: 7.5))
            let rowH = max(36, materialHeight + nachweisHeight + 16)
            pageBreakIfNeeded(rowH + 24)

            if index.isMultiple(of: 2) {
                fill(CGRect(x: mH, y: y, width: cW, height: rowH), color: UIColor(white: 0.97, alpha: 1))
            }

            let posNr = position.posNr.isEmpty ? "\(index + 1)" : position.posNr
            txtInRect(posNr,
                      rect: CGRect(x: mH + 4, y: y + 7, width: 45, height: rowH - 8),
                      font: .systemFont(ofSize: 8), color: UIColor(white: 0.45, alpha: 1))
            txtInRect(position.material,
                      rect: CGRect(x: mH + 55, y: y + 6, width: cW - 165, height: materialHeight + 4),
                      font: .systemFont(ofSize: 9, weight: .semibold))
            txtInRect("Nachweis: \(nachweis)",
                      rect: CGRect(x: mH + 55, y: y + 10 + materialHeight, width: cW - 165, height: nachweisHeight + 4),
                      font: .systemFont(ofSize: 7.5), color: UIColor(white: 0.45, alpha: 1))
            txtInRect("\(format(position.menge)) \(position.einheit)",
                      rect: CGRect(x: mH + cW - 110, y: y + 7, width: 105, height: rowH - 8),
                      font: .systemFont(ofSize: 9), align: .right)

            hline(at: y + rowH)
            y += rowH
        }

        func boxLine(_ label: String) {
            pageBreakIfNeeded(28)
            txt(label, x: mH, y: y,
                font: .systemFont(ofSize: 9, weight: .semibold),
                color: UIColor(white: 0.35, alpha: 1))
            hline(at: y + 18)
            y += 28
        }

        func pageBreakIfNeeded(_ needed: CGFloat) {
            if y + needed > pageH - 55 {
                drawFooter()
                ctx.beginPage()
                y = mV
            }
        }

        func fill(_ rect: CGRect, color: UIColor) {
            color.setFill()
            UIRectFill(rect)
        }

        func hline(at lineY: CGFloat) {
            UIColor(white: 0.75, alpha: 1).setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: mH, y: lineY))
            p.addLine(to: CGPoint(x: mH + cW, y: lineY))
            p.lineWidth = 0.5
            p.stroke()
        }

        func txt(_ s: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor = .black) {
            s.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
        }

        func txtInRect(
            _ s: String,
            rect: CGRect,
            font: UIFont,
            color: UIColor = .black,
            align: NSTextAlignment = .left
        ) {
            let p = NSMutableParagraphStyle()
            p.alignment = align
            p.lineBreakMode = .byWordWrapping
            s.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                   attributes: [.font: font, .foregroundColor: color, .paragraphStyle: p], context: nil)
        }

        func height(for text: String, width: CGFloat, font: UIFont) -> CGFloat {
            let rect = text.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: font],
                context: nil
            )
            return ceil(rect.height)
        }

        func format(_ value: Double) -> String {
            numberFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        }

        func nachweisText(_ quelle: BedarfsQuelle) -> String {
            var parts: [String] = [quelle.typ.rawValue.uppercased(), quelle.ref]
            if let datei = quelle.datei, !datei.isEmpty { parts.append(datei) }
            if let planblatt = quelle.planblatt, !planblatt.isEmpty { parts.append("Planblatt \(planblatt)") }
            return parts.joined(separator: " / ")
        }

        func lieferfensterText() -> String {
            let von = dateTimeFormatter.string(from: anfrage.lieferung.lieferfensterVon)
            let bis = dateTimeFormatter.string(from: anfrage.lieferung.lieferfensterBis)
            return "\(von) - \(bis)"
        }

        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateFormat = "dd.MM.yyyy"
            return formatter
        }()

        let dateTimeFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            return formatter
        }()

        let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: "de_DE")
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter
        }()
    }
}
