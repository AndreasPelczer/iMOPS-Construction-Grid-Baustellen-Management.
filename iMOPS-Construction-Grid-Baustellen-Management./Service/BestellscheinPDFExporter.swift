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
///
/// **Mehrseitig.** Der Vordruck hat allein 22 Zeilen; mit Kopf, Summe und
/// Unterschriftsfeld ist das Blatt rund 1400 pt hoch, eine A4-Seite fasst 842.
/// Wer hier nur `beginPage()` einmal aufruft, zeichnet den Rest ins Nichts —
/// und merkt es nicht, weil das PDF gültig bleibt und die erste Seite stimmt.
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

    // MARK: - Maße

    private static let pageW: CGFloat = 595.2, pageH: CGFloat = 841.8   // A4
    private static let m: CGFloat = 46
    private static var cW: CGFloat { pageW - 2 * m }
    /// Platz am Fuß jeder Seite für die Seitenzahl — hier wird nicht gesetzt.
    private static let fussRaum: CGFloat = 38

    private static let orange = UIColor(red: 0.88, green: 0.35, blue: 0.13, alpha: 1)
    private static let grau = UIColor(white: 0.42, alpha: 1)

    // MARK: - Einstieg

    static func generate(zeilen: [BestellscheinService.Zeile],
                         ohneNummer: [LVPosition],
                         kontext: Kontext) -> Data {

        let bounds = CGRect(x: 0, y: 0, width: pageW, height: pageH)

        // Zwei Durchgänge. Der erste zählt nur die Seiten — anders kann auf
        // Seite 1 nicht „von 3" stehen, und genau daran erkennt der Lieferant,
        // ob das Fax vollständig bei ihm angekommen ist.
        //
        // Je Durchgang ein EIGENER Renderer: `pdfData` zweimal auf derselben
        // Instanz liefert beim zweiten Mal 0 Bytes. Das PDF ist dann leer, nicht
        // kaputt — es fällt also erst auf, wenn jemand die Mail öffnet.
        var gesamt = 1
        _ = UIGraphicsPDFRenderer(bounds: bounds).pdfData { c in
            gesamt = zeichne(c, zeilen: zeilen, ohneNummer: ohneNummer,
                             kontext: kontext, gesamtSeiten: nil)
        }
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { c in
            _ = zeichne(c, zeilen: zeilen, ohneNummer: ohneNummer,
                        kontext: kontext, gesamtSeiten: gesamt)
        }
    }

    // MARK: - Satz

    /// Zeichnet das Blatt und gibt die Zahl der gesetzten Seiten zurück.
    /// `gesamtSeiten == nil` heißt: Zähl-Durchgang, die Fußzeile bleibt leer.
    private static func zeichne(_ c: UIGraphicsPDFRendererContext,
                                zeilen: [BestellscheinService.Zeile],
                                ohneNummer: [LVPosition],
                                kontext: Kontext,
                                gesamtSeiten: Int?) -> Int {

        var y: CGFloat = m
        var seite = 0

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

        /// Höhe eines Textes, ohne ihn zu setzen — für die Platzfrage vor dem Umbruch.
        func hoehe(_ s: String, _ size: CGFloat, _ weight: UIFont.Weight = .regular,
                   w: CGFloat? = nil) -> CGFloat {
            let attr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
            ]
            return (s as NSString).boundingRect(
                with: CGSize(width: w ?? cW, height: 400),
                options: .usesLineFragmentOrigin, attributes: attr, context: nil).height
        }

        func stempel() {
            // ENTWURF quer über jede Seite — damit kein Blatt für geprüft gehalten
            // wird, auch nicht das dritte, das einzeln aus dem Drucker fällt.
            c.cgContext.saveGState()
            c.cgContext.translateBy(x: pageW / 2, y: pageH * 0.42)
            c.cgContext.rotate(by: -.pi / 7.5)
            let s = "ENTWURF"
            let a: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 86, weight: .heavy),
                .foregroundColor: orange.withAlphaComponent(0.10),
            ]
            let size = (s as NSString).size(withAttributes: a)
            (s as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: a)
            c.cgContext.restoreGState()
        }

        func fusszeile() {
            guard let gesamt = gesamtSeiten else { return }
            let merk = y
            y = pageH - fussRaum + 12
            UIColor(white: 0.85, alpha: 1).setFill()
            c.cgContext.fill(CGRect(x: m, y: y - 8, width: cW, height: 0.5))
            _ = text(kontext.baustelle, 7.5, .regular, grau, x: m, w: cW - 120)
            _ = text("Seite \(seite) von \(gesamt)", 7.5, .regular, grau,
                     x: m + cW - 120, w: 120, align: .right)
            y = merk
        }

        func neueSeite() {
            if seite > 0 { fusszeile() }
            c.beginPage()
            seite += 1
            stempel()
            y = m
        }

        /// Bricht um, wenn `bedarf` nicht mehr auf die Seite passt.
        /// Gibt zurück, ob umgebrochen wurde — der Aufrufer wiederholt dann
        /// Tabellenkopf o. ä.
        @discardableResult
        func platz(_ bedarf: CGFloat) -> Bool {
            guard y + bedarf > pageH - fussRaum else { return false }
            neueSeite()
            return true
        }

        neueSeite()

        // MARK: Kopf

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

        // MARK: Tabelle

        // Spalten wie auf dem Papierschein, damit sich beides nebeneinanderlegen
        // laesst: Material-Nr · Stk/Pal · m³ · Guete · Profil · Abmessung
        let sp: [CGFloat] = [m, m + 66, m + 108, m + 168, m + 268, m + 320]
        /// Höhe des Tabellenkopfs — muss zur Platzfrage passen, sonst bricht es
        /// direkt nach dem Kopf um und die erste Zeile steht allein auf der Seite.
        let kopfHoehe: CGFloat = 22

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

        let vordruck = zeilen.filter { !$0.istFreieZeile }
        let freie = zeilen.filter { $0.istFreieZeile }

        // Nach den Gruppen des Scheins durchgehen. Zeilen ohne Bestellmenge
        // bleiben stehen -- so liegt das Blatt neben dem Papier und man findet
        // jede Nummer an derselben Stelle. Nur die bestellten sind hervorgehoben.
        var summe = 0.0
        let bestellt = Dictionary(uniqueKeysWithValues: vordruck.map { ($0.materialNr, $0) })

        for gruppe in Bestellscheinvorlage.gruppen {
            // Gruppentitel + Kopf + mindestens eine Zeile gehören zusammen —
            // ein Titel als letzte Zeile einer Seite hilft niemandem.
            platz(6 + 13 + kopfHoehe + 20)
            y += 6
            _ = text(gruppe.titel, 9, .bold, .black, x: m, w: cW); y += 13
            kopfzeile()

            for e in gruppe.eintraege {
                let z1 = bestellt[e.materialNr]
                let aktiv = z1 != nil
                // Zeile plus ihre Unterzeile am Stück umbrechen.
                if platz(aktiv ? 33 : 20) {
                    _ = text(gruppe.titel + " (Fortsetzung)", 9, .bold, .black, x: m, w: cW); y += 13
                    kopfzeile()
                }
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
                    if z1.vonHand {
                        y += text("von Hand gesetzt — Vorschlag war "
                                  + (z1.mengeLV * (1 + z1.zuschlagProzent / 100)).formatiert
                                  + " m³", 7.5, .regular,
                                  UIColor(red: 0.75, green: 0.45, blue: 0.10, alpha: 1),
                                  x: sp[3], w: 240) + 3
                    } else if z1.zuschlagProzent > 0 {
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

        // MARK: Weitere Positionen

        // „Weitere Positionen" — auf dem Papier die freien Zeilen unter der Tabelle
        if !freie.isEmpty {
            platz(4 + 13 + 32)
            y += 4
            _ = text("WEITERE POSITIONEN — nicht auf dem Vordruck", 8, .bold, orange, x: m, w: cW)
            y += 13
            for f in freie {
                if platz(32) {
                    _ = text("WEITERE POSITIONEN (Fortsetzung)", 8, .bold, orange, x: m, w: cW)
                    y += 13
                }
                orange.withAlphaComponent(0.05).setFill()
                c.cgContext.fill(CGRect(x: m - 3, y: y - 2, width: cW + 6, height: 15))
                // Keine Material-Nummer — der Strich sagt das, statt die Spalte
                // leer zu lassen und wie ein Versehen auszusehen.
                _ = text("—", 8.5, .regular, UIColor(white: 0.62, alpha: 1), x: sp[0], w: 64)
                _ = text(z(f.bestellmenge), 9, .bold,
                         UIColor(red: 0.75, green: 0.28, blue: 0.08, alpha: 1),
                         x: sp[2], w: 54, align: .right)
                // Der Freitext steht rechts der m³-Spalte, nicht links davon:
                // „Kalksandstein KS-RP 24 cm, KS-RP 20-2,2" ist länger als die
                // Material-Nummern und lief sonst mitten durch die Menge.
                y += text(f.freitext ?? f.bezeichnung, 8.5, .regular, .black,
                          x: sp[3], w: cW - (sp[3] - m)) + 4
                y += text("\(f.positionen) LV-Position\(f.positionen == 1 ? "" : "en")",
                          7.5, .regular, grau, x: sp[3], w: 240) + 3
                UIColor(white: 0.9, alpha: 1).setFill()
                c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.4)); y += 4
                summe += f.bestellmenge
            }
            y += 6
        }

        // MARK: Summe

        // Der Strich, die Summe und ihre Beschriftung dürfen nie getrennt werden —
        // eine Gesamtmenge ohne Bezug ist schlimmer als keine.
        platz(4 + 1 + 8 + 14 + 20)
        y += 4
        UIColor.black.setFill(); c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 1)); y += 8
        // Beschriftung links, Summe in der m³-Spalte — sie steht damit unter den
        // Zahlen, die sie zusammenzählt. Andersherum las es sich als „78,33 m³
        // Bestellmenge gesamt".
        //
        // Kurz halten: links der m³-Spalte sind nur 100 pt Platz. „Bestellmenge
        // gesamt" bricht dort um und steht als „Bestellmenge / gesamt" da —
        // in der Textebene des PDFs sogar mit Zeilenumbruch mittendrin.
        _ = text("BESTELLMENGE", 8.5, .semibold, .black, x: m, w: sp[2] - m - 8, align: .right)
        _ = text("\(z(summe))", 11, .bold, .black, x: sp[2], w: 54, align: .right)
        y += text("m³ gesamt", 9.5, .semibold, .black, x: sp[3], w: 160) + 20

        // MARK: Offene Stellen

        if !ohneNummer.isEmpty {
            let einleitung = "Diese Positionen stehen im LV, gehören aber nicht ins Ytong-Sortiment "
                + "oder tragen keine Material-Nummer — etwa Kalksandstein oder Beton. "
                + "Sie sind NICHT in der Summe enthalten und müssen getrennt bestellt werden."
            // Überschrift, Einleitung und die erste Position am Stück.
            platz(11 + 8 + hoehe(einleitung, 9) + 10 + 26)
            y += text("NICHT ÜBER DIESEN SCHEIN BESTELLBAR", 8.5, .semibold, grau) + 8
            y += text(einleitung, 9, .regular, grau) + 10
            for pos in ohneNummer.prefix(10) {
                if platz(26) {
                    y += text("NICHT ÜBER DIESEN SCHEIN BESTELLBAR (Fortsetzung)",
                              8.5, .semibold, grau) + 8
                }
                orange.setFill(); c.cgContext.fill(CGRect(x: m, y: y, width: 2, height: 26))
                _ = text("\(z(pos.menge)) \(pos.einheit ?? "")", 9.5, .medium, .black,
                         x: sp[4] - 40, w: 95, align: .right)
                y += text(pos.bezeichnung ?? "—", 9.5, .regular, .black, x: m + 9, w: 330) + 12
            }
            if ohneNummer.count > 10 {
                platz(20)
                y += text("… und \(ohneNummer.count - 10) weitere", 9, .regular, grau, x: m + 9) + 10
            }
            y += 8
        }

        // MARK: Fuß

        let schluss = "Vorschlag, keine Bestellung. Mengen und Material-Nummern vor dem "
            + "Absenden prüfen — die Nummern des Planblock-W-Teils sind gegen ein Foto "
            + "des Originalscheins geprüft, Flachsturz und Mörtel nicht."
        // Hinweis und Unterschriftsfeld gehören zusammen aufs selbe Blatt.
        platz(10 + hoehe(schluss, 8.5) + 26 + 20)
        UIColor(white: 0.75, alpha: 1).setFill()
        c.cgContext.fill(CGRect(x: m, y: y, width: cW, height: 0.7)); y += 10
        y += text(schluss, 8.5, .regular, grau) + 26

        UIColor.black.setFill()
        c.cgContext.fill(CGRect(x: m, y: y, width: 200, height: 0.7))
        c.cgContext.fill(CGRect(x: m + 240, y: y, width: 200, height: 0.7))
        y += 5
        _ = text("Geprüft — Datum, Unterschrift", 8.5, .regular, grau, x: m, w: 200)
        _ = text("Freigegeben zur Bestellung", 8.5, .regular, grau, x: m + 240, w: 200)

        fusszeile()
        return seite
    }
}

private extension Double {
    var formatiert: String {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 2; nf.maximumFractionDigits = 2; nf.decimalSeparator = ","
        return nf.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
