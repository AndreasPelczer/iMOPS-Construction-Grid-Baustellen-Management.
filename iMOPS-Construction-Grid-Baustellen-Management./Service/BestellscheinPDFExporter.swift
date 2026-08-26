import UIKit

/// Setzt den Bestellvorschlag als PDF — offline, ohne Server.
///
/// Bewusst **kein Nachbau des T&C-Formulars**: Ein Blatt, das aussieht wie das
/// Original, wird unterschrieben statt gelesen. Stattdessen ein sichtbarer
/// ENTWURF-Vermerk, die offenen Stellen gleichberechtigt neben den fertigen und
/// ein Feld „Geprüft".
///
/// Die Firma faxt bisher eine Kopie des Scheins. Das hier ersetzt das Fax, nicht
/// die Prüfung durch einen Menschen.
enum BestellscheinPDFExporter {

    struct Kontext {
        let baustelle: String
        let bauvorhaben: String?
        let datum: Date
        let bearbeiter: String?
    }

    static func generate(zeilen: [BestellscheinService.Zeile],
                         ohneNummer: [LVPosition],
                         kontext: Kontext) -> Data {

        let pageW: CGFloat = 595.2, pageH: CGFloat = 841.8   // A4
        let m: CGFloat = 46
        let cW = pageW - 2 * m
        let orange = UIColor(red: 0.88, green: 0.35, blue: 0.13, alpha: 1)
        let grau = UIColor(white: 0.42, alpha: 1)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        return renderer.pdfData { c in
            c.beginPage()
            var y: CGFloat = m

            func text(_ s: String, _ size: CGFloat, _ weight: UIFont.Weight = .regular,
                      _ color: UIColor = .black, x: CGFloat = m, w: CGFloat? = nil,
                      align: NSTextAlignment = .left) -> CGFloat {
                let p = NSMutableParagraphStyle(); p.alignment = align
                let attr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size, weight: weight),
                    .foregroundColor: color, .paragraphStyle: p,
                ]
                let breite = w ?? (cW - (x - m))
                let h = (s as NSString).boundingRect(
                    with: CGSize(width: breite, height: 400),
                    options: .usesLineFragmentOrigin, attributes: attr, context: nil).height
                (s as NSString).draw(in: CGRect(x: x, y: y, width: breite, height: h + 2), withAttributes: attr)
                return h
            }

            // ENTWURF quer über die Seite — damit niemand das Blatt für geprüft hält
            c.cgContext.saveGState()
            c.cgContext.translateBy(x: pageW / 2, y: pageH * 0.42)
            c.cgContext.rotate(by: -.pi / 7.5)
            let stempel = "ENTWURF"
            let sAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 86, weight: .heavy),
                .foregroundColor: orange.withAlphaComponent(0.10),
            ]
            let sSize = (stempel as NSString).size(withAttributes: sAttr)
            (stempel as NSString).draw(at: CGPoint(x: -sSize.width / 2, y: -sSize.height / 2),
                                       withAttributes: sAttr)
            c.cgContext.restoreGState()

            // Kopf
            y += text("BESTELLVORSCHLAG · YTONG-WANDBAUSTOFFE", 8.5, .semibold, orange) + 6
            y += text(kontext.baustelle, 20, .bold) + 4
            if let bv = kontext.bauvorhaben, !bv.isEmpty { y += text(bv, 11, .regular, grau) + 2 }
            let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy"
            y += text("Gerechnet am \(df.string(from: kontext.datum))"
                      + (kontext.bearbeiter.map { " · \($0)" } ?? ""), 9.5, .regular, grau) + 10
            orange.setFill()
            c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 1.6)); y += 18

            y += text("Bestelleinheit ist m³ — wie auf dem T&C-Schein vermerkt.", 9.5, .regular, grau) + 16

            // Tabellenkopf
            let sp: [CGFloat] = [m, m + 82, m + 300, m + 372, m + 448]
            _ = text("MATERIAL-NR", 8, .semibold, grau, x: sp[0], w: 80)
            _ = text("POSITION", 8, .semibold, grau, x: sp[1], w: 210)
            _ = text("LV", 8, .semibold, grau, x: sp[2], w: 62, align: .right)
            _ = text("ZUSCHLAG", 8, .semibold, grau, x: sp[3], w: 68, align: .right)
            y += text("BESTELLEN", 8, .semibold, grau, x: sp[4], w: 55, align: .right) + 6
            UIColor(white: 0.75, alpha: 1).setFill()
            c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.7)); y += 8

            let nf = NumberFormatter()
            nf.minimumFractionDigits = 2; nf.maximumFractionDigits = 2
            nf.decimalSeparator = ","
            func z(_ d: Double) -> String { nf.string(from: NSNumber(value: d)) ?? "\(d)" }

            var summe = 0.0
            for zeile in zeilen {
                _ = text(zeile.materialNr, 9.5, .medium, .black, x: sp[0], w: 80)
                _ = text(zeile.mengeLV.formatiert, 9.5, .regular, .black, x: sp[2], w: 62, align: .right)
                _ = text(zeile.zuschlagProzent > 0 ? "+\(Int(zeile.zuschlagProzent)) %" : "—",
                         9.5, .regular, grau, x: sp[3], w: 68, align: .right)
                _ = text(z(zeile.bestellmenge), 9.5, .bold, .black, x: sp[4], w: 55, align: .right)
                let h = text(zeile.bezeichnung, 9.5, .regular, .black, x: sp[1], w: 210)
                y += h + 3
                y += text("\(zeile.positionen) LV-Position\(zeile.positionen == 1 ? "" : "en")",
                          8, .regular, UIColor(white: 0.55, alpha: 1), x: sp[1], w: 210) + 7
                UIColor(white: 0.88, alpha: 1).setFill()
                c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.5)); y += 8
                summe += zeile.bestellmenge
            }

            y += 4
            UIColor.black.setFill(); c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 1)); y += 8
            _ = text("Summe", 10.5, .bold, .black, x: sp[1], w: 210)
            y += text("\(z(summe)) m³", 10.5, .bold, .black, x: sp[4], w: 55, align: .right) + 20

            // Offene Stellen
            if !ohneNummer.isEmpty {
                y += text("NICHT ZUGEORDNET — BRAUCHT EINE ENTSCHEIDUNG", 8.5, .semibold, grau) + 8
                y += text("Diese Positionen stehen im LV, tragen aber keine Material-Nummer. "
                          + "Sie sind NICHT in der Summe enthalten.", 9.5, .regular, grau) + 10
                for pos in ohneNummer.prefix(10) {
                    orange.setFill(); c.cgContext.fill(CGRect(x: m, y: y, width: 2, height: 26))
                    _ = text("\(z(pos.menge)) \(pos.einheit ?? "")", 9.5, .medium, .black,
                             x: sp[4] - 40, w: 95, align: .right)
                    y += text(pos.bezeichnung ?? "—", 9.5, .regular, .black, x: m + 9, w: 330) + 12
                }
                if ohneNummer.count > 10 {
                    y += text("… und \(ohneNummer.count - 10) weitere", 9, .regular, grau, x: m + 9) + 10
                }
                y += 8
            }

            // Fuß
            UIColor(white: 0.75, alpha: 1).setFill()
            c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.7)); y += 10
            y += text("Vorschlag, keine Bestellung. Mengen und Material-Nummern vor dem "
                      + "Absenden prüfen — die Nummern stammen aus einem abfotografierten "
                      + "Schein und sind ungeprüft.", 8.5, .regular, grau) + 26

            UIColor.black.setFill()
            c.cgContext.fill(CGRect(x: m, y: y, width: 200, height: 0.7))
            c.cgContext.fill(CGRect(x: m + 240, y: y, width: 200, height: 0.7))
            y += 5
            _ = text("Geprüft — Datum, Unterschrift", 8.5, .regular, grau, x: m, w: 200)
            _ = text("Freigegeben zur Bestellung", 8.5, .regular, grau, x: m + 240, w: 200)
        }
    }
}

private extension Double {
    var formatiert: String {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 2; nf.maximumFractionDigits = 2; nf.decimalSeparator = ","
        return nf.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
