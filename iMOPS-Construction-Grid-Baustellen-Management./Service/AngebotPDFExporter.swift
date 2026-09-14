//
//  AngebotPDFExporter.swift
//  Ein Kunden-Angebot als PDF — mit Firmenlogo/Briefkopf (Briefpapier), aus dem
//  Planer-Ergebnis (HouseProjectResult). Bewusst ein PAUSCHAL-Angebot: der
//  Leistungsumfang (die Massen) als Positionsliste, dazu ein Gesamtpreis. Echte
//  Einzelpreise je Position kommen, sobald aus dem Planer ein LV mit Preisen wird.
//
//  „Angebot" ≠ „Rechnung": freibleibend, mit Gültigkeit — kein § 14 UStG.
//

import UIKit

/// Der Kunde, an den das Angebot geht.
struct AngebotKunde {
    var name: String
    var strasse: String
    var plzOrt: String
    var email: String

    /// Anschrift-Block für den Empfänger-Kasten (leere Zeilen fallen weg).
    var anschrift: [String] { [name, strasse, plzOrt].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
}

enum AngebotPDFExporter {

    static func angebotsnummer(datum: Date = Date()) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd"
        return "AN-\(df.string(from: datum))-\(Int.random(in: 100...999))"
    }

    static func generate(result: HouseProjectResult, kunde: AngebotKunde,
                         nummer: String = angebotsnummer()) -> Data {
        let seite = CGRect(x: 0, y: 0, width: 595, height: 842)     // A4
        let mH: CGFloat = 48
        let cW = seite.width - 2 * mH
        var y: CGFloat = 40

        func eur(_ v: Double) -> String {
            v.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
        }
        func txt(_ s: String, x: CGFloat, y: CGFloat, font: UIFont, color: UIColor = .black) {
            s.draw(at: CGPoint(x: x, y: y), withAttributes: [.font: font, .foregroundColor: color])
        }
        func rechts(_ s: String, bisX: CGFloat, y: CGFloat, font: UIFont, color: UIColor = .black) {
            let breite = (s as NSString).size(withAttributes: [.font: font]).width
            txt(s, x: bisX - breite, y: y, font: font, color: color)
        }
        func linie(_ ly: CGFloat, stark: Bool = false) {
            (stark ? UIColor.black : UIColor(white: 0.75, alpha: 1)).setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: mH, y: ly)); p.addLine(to: CGPoint(x: mH + cW, y: ly))
            p.lineWidth = stark ? 1.0 : 0.5; p.stroke()
        }

        let netto  = result.gesamtkosten
        let mwst   = FirmenSettings.mwstSatz
        let steuer = netto * mwst / 100.0
        let brutto = netto + steuer

        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE"); df.dateStyle = .medium
        let gueltigBis = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        let renderer = UIGraphicsPDFRenderer(bounds: seite)
        return renderer.pdfData { c in
            c.beginPage()

            y = Briefpapier.zeichneKopf(ab: y, links: mH, breite: cW)
            y += 24
            y = Briefpapier.zeichneEmpfaenger(kunde.anschrift, ab: y, links: mH)
            y += 28

            txt("Angebot", x: mH, y: y, font: .systemFont(ofSize: 17, weight: .bold))
            y += 26

            func eckdaten(_ label: String, _ wert: String) {
                guard !wert.isEmpty else { return }
                txt(label, x: mH, y: y, font: .systemFont(ofSize: 9.5, weight: .semibold),
                    color: UIColor(white: 0.45, alpha: 1))
                txt(wert, x: mH + 120, y: y, font: .systemFont(ofSize: 9.5))
                y += 14
            }
            eckdaten("Angebots-Nr.:", nummer)
            eckdaten("Datum:", df.string(from: Date()))
            eckdaten("Bauvorhaben:", bauvorhaben(result))
            if let bis = gueltigBis { eckdaten("Gültig bis:", df.string(from: bis)) }
            y += 10

            // Anrede
            txt("Sehr geehrte Damen und Herren,", x: mH, y: y, font: .systemFont(ofSize: 10)); y += 16
            let einleitung = "gern unterbreiten wir Ihnen für das oben genannte Bauvorhaben folgendes Angebot:"
            y = zeichneAbsatz(einleitung, x: mH, y: y, breite: cW, groesse: 10); y += 12

            // Positionen (Leistungsumfang aus den Massen)
            linie(y); y += 5
            txt("Pos.",     x: mH,          y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Leistung", x: mH + 44,     y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            rechts("Menge", bisX: mH + cW - 60, y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Einheit",  x: mH + cW - 55, y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            y += 13; linie(y); y += 8

            let zahl = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
            for (i, m) in result.massen.enumerated() {
                if y > seite.height - 200 { c.beginPage(); y = 40 }
                txt("\(i + 1)", x: mH, y: y, font: .systemFont(ofSize: 9))
                let kasten = CGRect(x: mH + 44, y: y, width: cW - 150, height: 40)
                (m.bezeichnung as NSString).draw(with: kasten, options: .usesLineFragmentOrigin,
                    attributes: [.font: UIFont.systemFont(ofSize: 9)], context: nil)
                let hoehe = (m.bezeichnung as NSString).boundingRect(
                    with: CGSize(width: kasten.width, height: 200), options: .usesLineFragmentOrigin,
                    attributes: [.font: UIFont.systemFont(ofSize: 9)], context: nil).height
                rechts(m.menge.formatted(.number.precision(.fractionLength(0...2))),
                       bisX: mH + cW - 60, y: y, font: zahl)
                txt(m.einheit, x: mH + cW - 55, y: y, font: .systemFont(ofSize: 9))
                y += max(hoehe, 12) + 7; linie(y - 3)
            }

            // Summen (Pauschal)
            y += 12
            func summe(_ label: String, _ wert: String, fett: Bool = false) {
                let f: UIFont = fett ? .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
                                     : .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                rechts(label, bisX: mH + cW - 110, y: y, font: f)
                rechts(wert,  bisX: mH + cW,       y: y, font: f)
                y += fett ? 18 : 15
            }
            summe("Angebotssumme netto", eur(netto))
            summe("zzgl. \(mwst.formatted(.number.precision(.fractionLength(0...1)))) % MwSt.", eur(steuer))
            linie(y - 2); y += 4
            summe("Gesamtbetrag brutto", eur(brutto), fett: true)

            // Schlusstext
            y += 16
            let schluss = "Dieses Angebot ist freibleibend und 30 Tage gültig. Die Ausführung "
                + "erfolgt nach gesonderter Terminabsprache. Alle Preise verstehen sich zzgl. der "
                + "gesetzlichen Mehrwertsteuer. Über Ihren Auftrag freuen wir uns.\n\n"
                + "Mit freundlichen Grüßen"
            y = zeichneAbsatz(schluss, x: mH, y: y, breite: cW, groesse: 9.5, farbe: UIColor(white: 0.2, alpha: 1))
            if !FirmenSettings.name.isEmpty {
                y += 6; txt(FirmenSettings.name, x: mH, y: y, font: .systemFont(ofSize: 10, weight: .semibold))
            }

            Briefpapier.zeichneFuss(seitenHoehe: seite.height, links: mH, breite: cW)
        }
    }

    private static func bauvorhaben(_ result: HouseProjectResult) -> String {
        let name = result.project.projektName.isEmpty ? "Bauvorhaben" : result.project.projektName
        let flaeche = result.project.wohnflaeche
        return flaeche > 0 ? "\(name), \(Int(flaeche)) m²" : name
    }

    /// Zeichnet einen umbrechenden Absatz, gibt das neue y zurück.
    private static func zeichneAbsatz(_ text: String, x: CGFloat, y: CGFloat, breite: CGFloat,
                                      groesse: CGFloat, farbe: UIColor = .black) -> CGFloat {
        let font = UIFont.systemFont(ofSize: groesse)
        let kasten = CGRect(x: x, y: y, width: breite, height: 400)
        (text as NSString).draw(with: kasten, options: .usesLineFragmentOrigin,
            attributes: [.font: font, .foregroundColor: farbe], context: nil)
        let hoehe = (text as NSString).boundingRect(
            with: CGSize(width: breite, height: 1000), options: .usesLineFragmentOrigin,
            attributes: [.font: font], context: nil).height
        return y + hoehe
    }
}
