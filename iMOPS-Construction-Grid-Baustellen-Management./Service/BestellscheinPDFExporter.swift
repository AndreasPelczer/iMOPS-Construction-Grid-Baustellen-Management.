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
        let bvhNr: String?
        let bauherr: String?
        let strasse: String?
        let plzOrt: String?
        let objektNr: String?
        let baustoffhandel: String?
        let angaben: BestellscheinAngaben
        let datum: Date
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
            let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy"
            y += text("Gerechnet am \(df.string(from: kontext.datum))", 9.5, .regular, grau) + 10
            orange.setFill()
            c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 1.6)); y += 16

            // Zwei Spalten: links die Baustelle, rechts die Lieferung.
            // Entspricht dem Aufbau des Originalscheins, ohne ihn nachzuahmen.
            let spaltenBreite = (cW - 24) / 2
            let rechts = m + spaltenBreite + 24
            let yStart = y

            func feld(_ titel: String, _ wert: String?, x: CGFloat) {
                guard let w = wert, !w.isEmpty else { return }
                _ = text(titel, 7.5, .semibold, grau, x: x, w: spaltenBreite)
                y += 9
                y += text(w, 10, .regular, .black, x: x, w: spaltenBreite) + 7
            }

            _ = text("BAUSTELLE", 8, .bold, orange, x: m, w: spaltenBreite); y += 13
            feld("Bauvorhaben", kontext.baustelle, x: m)
            feld("BVH-Nr.", kontext.bvhNr, x: m)
            feld("Bauherr", kontext.bauherr, x: m)
            feld("Straße", kontext.strasse, x: m)
            feld("PLZ / Ort", kontext.plzOrt, x: m)
            feld("Objekt-Nr. (Xella)", kontext.objektNr, x: m)
            feld("Baustoffhandel", kontext.baustoffhandel, x: m)
            let yLinks = y

            y = yStart
            _ = text("LIEFERUNG", 8, .bold, orange, x: rechts, w: spaltenBreite); y += 13
            let a = kontext.angaben
            feld("Art", a.lieferart.rawValue + (a.mitKran ? ", mit Kran" : ", ohne Kran"), x: rechts)
            feld("Zeitfenster", a.zeitfenster.rawValue, x: rechts)
            feld("Wunschtermin", df.string(from: a.wunschtermin)
                 + (a.vorlaufKnapp ? "  ⚠ unter 3 Werktagen" : ""), x: rechts)
            feld("Bemerkung", a.bemerkung, x: rechts)

            y = max(yLinks, y) + 8
            UIColor(white: 0.85, alpha: 1).setFill()
            c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.7)); y += 14

            y += text("Bestelleinheit ist m³ — wie auf dem T&C-Schein vermerkt.", 9.5, .regular, grau) + 16

            // Spalten wie auf dem Papierschein, damit sich beides nebeneinanderlegen
            // laesst: Material-Nr · Stk/Pal · m³ · Guete · Profil · Abmessung
            let sp: [CGFloat] = [m, m + 66, m + 108, m + 168, m + 268, m + 320]
            func kopfzeile() {
                _ = text("MATERIAL-NR", 7, .semibold, grau, x: sp[0], w: 64)
                _ = text("STK", 7, .semibold, grau, x: sp[1], w: 38, align: .right)
                _ = text("m³", 7, .semibold, grau, x: sp[2], w: 54, align: .right)
                _ = text("GÜTE", 7, .semibold, grau, x: sp[3], w: 96)
                _ = text("PROFIL", 7, .semibold, grau, x: sp[4], w: 48)
                y += text("ABMESSUNG", 7, .semibold, grau, x: sp[5], w: 100) + 5
                UIColor(white: 0.7, alpha: 1).setFill()
                c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.7)); y += 6
            }

            let nf = NumberFormatter()
            nf.minimumFractionDigits = 2; nf.maximumFractionDigits = 2
            nf.decimalSeparator = ","
            func z(_ d: Double) -> String { nf.string(from: NSNumber(value: d)) ?? "\(d)" }

            // Nach den Gruppen des Scheins durchgehen. Zeilen ohne Bestellmenge
            // bleiben stehen -- so liegt das Blatt neben dem Papier und man findet
            // jede Nummer an derselben Stelle. Nur die bestellten sind hervorgehoben.
            var summe = 0.0
            let bestellt = Dictionary(uniqueKeysWithValues: zeilen.map { ($0.materialNr, $0) })

            for gruppe in Bestellscheinvorlage.gruppen {
                y += 6
                _ = text(gruppe.titel, 9, .bold, .black, x: m, w: cW); y += 13
                kopfzeile()

                for e in gruppe.eintraege {
                    let z1 = bestellt[e.materialNr]
                    let aktiv = z1 != nil
                    if aktiv {
                        orange.withAlphaComponent(0.07).setFill()
                        c.cgContext.fill(CGRect(x: m - 3, y: y - 2, width: cW + 6, height: 15))
                    }
                    let farbe: UIColor = aktiv ? .black : UIColor(white: 0.62, alpha: 1)
                    _ = text(e.materialNr, 8.5, aktiv ? .semibold : .regular, farbe, x: sp[0], w: 64)
                    _ = text("\(e.stueckJePalette)", 8.5, .regular, farbe, x: sp[1], w: 38, align: .right)
                    _ = text(z1.map { z($0.bestellmenge) } ?? "", 9, .bold,
                             aktiv ? UIColor(red: 0.75, green: 0.28, blue: 0.08, alpha: 1) : farbe,
                             x: sp[2], w: 54, align: .right)
                    _ = text(e.guete, 8.5, .regular, farbe, x: sp[3], w: 96)
                    _ = text(e.profil, 8.5, .regular, farbe, x: sp[4], w: 48)
                    y += text(e.abmessung, 8.5, .regular, farbe, x: sp[5], w: 100) + 5
                    if let z1 = z1 {
                        summe += z1.bestellmenge
                        if z1.zuschlagProzent > 0 {
                            y += text("davon \(Int(z1.zuschlagProzent)) % Eck-/Laibungssteine "
                                      + "(LV \(z1.mengeLV.formatiert) m³, \(z1.positionen) Positionen)",
                                      7.5, .regular, grau, x: sp[3], w: 240) + 3
                        } else {
                            y += text("\(z1.positionen) LV-Position\(z1.positionen == 1 ? "" : "en")",
                                      7.5, .regular, grau, x: sp[3], w: 240) + 3
                        }
                    }
                    UIColor(white: 0.9, alpha: 1).setFill()
                    c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.4)); y += 3.5
                }
                y += 6
            }

            y += 4
            UIColor.black.setFill(); c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 1)); y += 8
            _ = text("Bestellmenge gesamt", 10.5, .bold, .black, x: sp[3], w: 200)
            y += text("\(z(summe)) m³", 10.5, .bold, .black, x: sp[2], w: 54, align: .right) + 20

            // Offene Stellen
            if !ohneNummer.isEmpty {
                y += text("NICHT ÜBER DIESEN SCHEIN BESTELLBAR", 8.5, .semibold, grau) + 8
                y += text("Diese Positionen stehen im LV, gehören aber nicht ins Ytong-Sortiment "
                          + "oder tragen keine Material-Nummer — etwa Kalksandstein oder Beton. "
                          + "Sie sind NICHT in der Summe enthalten und müssen getrennt bestellt werden.",
                          9, .regular, grau) + 10
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
