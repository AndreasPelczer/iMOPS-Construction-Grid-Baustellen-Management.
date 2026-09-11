//
//  RechnungPDFExporter.swift
//  Das lesbare Blatt — was der Kunde bekommt.
//
//  ── Warum es das braucht ─────────────────────────────────────────────────────
//
//  Bis hierher endete der Weg bei der **XRechnung**: gültiges XML, für Menschen
//  unlesbar. Ein Privatkunde, der eine Hofauffahrt bezahlen soll, bekommt keine
//  CII-Datei. Damit schließt dieser Exporter den Kreis:
//
//      Gespräch → Angebot → Baustelle → Kalkulation → **Rechnung**
//
//  ── Kundensicht heißt: weniger zeigen ────────────────────────────────────────
//
//  Auf dieses Blatt gehört, was der Kunde bestellt hat — Position, Menge, Einheit,
//  Einheitspreis, Gesamt. **Nicht** die Arbeitsschritte, **nicht** die Aufteilung
//  in Lohn/Material/Gerät. Das ist die Kalkulation, und die ist Betriebsinterna:
//  Wer seinem Kunden zeigt, dass 51,80 € von 117,42 € Lohn sind, verhandelt ab
//  morgen über seinen Stundensatz statt über die Leistung.
//
//  `LVPositionHelper.isAlternative` fliegt raus — ein Alternativangebot ist nicht
//  beauftragt und wird nicht berechnet. Dieselbe Regel wie im `XRechnungExporter`,
//  damit PDF und XML **denselben Betrag** ergeben. Liefen sie auseinander, hätte
//  der Kunde zwei Rechnungen über verschiedene Summen — der schlimmste Fall.
//
//  ⚠️ **Vor dem ersten echten Versand:** Briefkopf-Angaben gegen die Firmenpapiere
//  prüfen (USt-IdNr., IBAN, HRB) und die Empfänger-Anschrift ausfüllen. Ohne
//  vollständige Anschrift des Leistungsempfängers ist eine Rechnung nach § 14 UStG
//  nicht ordnungsgemäß — der Kunde kann keine Vorsteuer ziehen.
//

import UIKit
import CoreData

enum RechnungPDFExporter {

    /// Rechnungsnummer nach dem Muster des `XRechnungExporter`, damit PDF und XML
    /// **dieselbe Nummer** tragen. Zwei Nummern für einen Vorgang wären ein
    /// Buchhaltungsfehler, den niemand bemerkt, bis er weh tut.
    static func rechnungsnummer(am datum: Date = Date()) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd"
        return "RE-\(df.string(from: datum))-001"
    }

    static func generate(event: Event, positionen: [LVPosition],
                         store: AngebotsStore = .shared) -> Data {

        let seite = CGRect(x: 0, y: 0, width: 595, height: 842)   // A4 @72dpi
        let mH: CGFloat = 48
        let cW = seite.width - 2 * mH
        var y: CGFloat = 40

        // Nur beauftragte Positionen, Preis über denselben Resolver wie die XRechnung.
        let zeilen: [(pos: LVPosition, ep: Double, gp: Double)] = positionen
            .filter { !LVPositionHelper.isAlternative($0) }
            .map { pos in
                let ep = LVKalkulator.effektiverEP(for: pos, store: store)
                return (pos, ep, ep * pos.menge)
            }

        let netto  = zeilen.reduce(0.0) { $0 + $1.gp }
        let mwst   = FirmenSettings.mwstSatz
        let steuer = netto * mwst / 100.0
        let brutto = netto + steuer

        func eur(_ v: Double) -> String {
            v.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
        }
        func txt(_ s: String, x: CGFloat, y: CGFloat, font: UIFont,
                 color: UIColor = .black) {
            s.draw(at: CGPoint(x: x, y: y),
                   withAttributes: [.font: font, .foregroundColor: color])
        }
        func rechts(_ s: String, bisX: CGFloat, y: CGFloat, font: UIFont,
                    color: UIColor = .black) {
            let breite = (s as NSString).size(withAttributes: [.font: font]).width
            txt(s, x: bisX - breite, y: y, font: font, color: color)
        }
        func linie(_ ly: CGFloat, stark: Bool = false) {
            (stark ? UIColor.black : UIColor(white: 0.75, alpha: 1)).setStroke()
            let p = UIBezierPath()
            p.move(to: CGPoint(x: mH, y: ly))
            p.addLine(to: CGPoint(x: mH + cW, y: ly))
            p.lineWidth = stark ? 1.0 : 0.5
            p.stroke()
        }

        let fussHoehe = geschaetzteFussHoehe()

        let renderer = UIGraphicsPDFRenderer(bounds: seite)
        return renderer.pdfData { c in
            c.beginPage()

            // ── Briefkopf ───────────────────────────────────────────────────
            y = Briefpapier.zeichneKopf(ab: y, links: mH, breite: cW)
            y += 24

            // ── Empfänger ───────────────────────────────────────────────────
            y = Briefpapier.zeichneEmpfaenger(event.bauherrAnschrift, ab: y, links: mH)
            y += 28

            // ── Titel und Eckdaten ──────────────────────────────────────────
            txt("Rechnung", x: mH, y: y, font: .systemFont(ofSize: 17, weight: .bold))
            y += 26

            let df = DateFormatter()
            df.locale = Locale(identifier: "de_DE")
            df.dateStyle = .medium
            df.timeStyle = .none

            func eckdaten(_ label: String, _ wert: String) {
                guard !wert.isEmpty else { return }
                txt(label, x: mH, y: y, font: .systemFont(ofSize: 9.5, weight: .semibold),
                    color: UIColor(white: 0.45, alpha: 1))
                txt(wert, x: mH + 120, y: y, font: .systemFont(ofSize: 9.5))
                y += 14
            }
            eckdaten("Rechnungs-Nr.:", rechnungsnummer())
            eckdaten("Rechnungsdatum:", df.string(from: Date()))
            eckdaten("Bauvorhaben:", event.title ?? "")
            eckdaten("Baustelle:", event.location ?? "")
            if let start = event.eventStartTime {
                let bis = event.eventEndTime.map { " – " + df.string(from: $0) } ?? ""
                eckdaten("Leistungszeitraum:", df.string(from: start) + bis)
            }
            y += 12

            // ── Positionen ──────────────────────────────────────────────────
            linie(y); y += 5
            txt("Pos.",    x: mH,           y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Leistung", x: mH + 52,     y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            rechts("Menge", bisX: mH + cW - 175, y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            txt("Einheit", x: mH + cW - 170, y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            rechts("Einheitspreis", bisX: mH + cW - 78, y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            rechts("Gesamt", bisX: mH + cW,  y: y, font: .systemFont(ofSize: 8, weight: .semibold))
            y += 13
            linie(y); y += 8

            for (i, zeile) in zeilen.enumerated() {
                // Seitenumbruch, bevor der Text in den Fuß läuft.
                if y > seite.height - fussHoehe - 60 {
                    c.beginPage(); y = 40
                }
                let pos = zeile.pos
                txt(pos.posNr ?? "\(i + 1)", x: mH, y: y, font: .systemFont(ofSize: 9))

                let name = pos.bezeichnung ?? "–"
                let kasten = CGRect(x: mH + 52, y: y, width: cW - 240, height: 40)
                (name as NSString).draw(
                    with: kasten, options: .usesLineFragmentOrigin,
                    attributes: [.font: UIFont.systemFont(ofSize: 9)], context: nil)
                let hoehe = (name as NSString).boundingRect(
                    with: CGSize(width: kasten.width, height: 200),
                    options: .usesLineFragmentOrigin,
                    attributes: [.font: UIFont.systemFont(ofSize: 9)], context: nil).height

                let zahl = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
                rechts(pos.menge.formatted(.number.precision(.fractionLength(0...2))),
                       bisX: mH + cW - 175, y: y, font: zahl)
                txt(pos.einheit ?? "", x: mH + cW - 170, y: y, font: .systemFont(ofSize: 9))
                rechts(eur(zeile.ep), bisX: mH + cW - 78, y: y, font: zahl)
                rechts(eur(zeile.gp), bisX: mH + cW, y: y, font: zahl)

                y += max(hoehe, 12) + 7
                linie(y - 3)
            }

            // ── Summen ──────────────────────────────────────────────────────
            y += 10
            func summe(_ label: String, _ wert: String, fett: Bool = false) {
                let f: UIFont = fett ? .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
                                     : .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
                rechts(label, bisX: mH + cW - 110, y: y, font: f)
                rechts(wert,  bisX: mH + cW,       y: y, font: f)
                y += fett ? 18 : 15
            }
            summe("Nettobetrag", eur(netto))
            summe("zzgl. \(mwst.formatted(.number.precision(.fractionLength(0...1)))) % USt.",
                  eur(steuer))
            linie(y - 2)
            y += 4
            summe("Rechnungsbetrag", eur(brutto), fett: true)

            // ── Zahlungsziel ────────────────────────────────────────────────
            let tage = FirmenSettings.zahlungszielTage
            if tage > 0 {
                y += 12
                let faellig = Calendar.current.date(byAdding: .day, value: tage, to: Date())
                let text = faellig.map {
                    "Zahlbar ohne Abzug bis \(df.string(from: $0)) (\(tage) Tage)."
                } ?? "Zahlbar ohne Abzug innerhalb von \(tage) Tagen."
                txt(text, x: mH, y: y, font: .systemFont(ofSize: 9))
            }

            // ── Fuß ─────────────────────────────────────────────────────────
            Briefpapier.zeichneFuss(seitenHoehe: seite.height, links: mH, breite: cW)
        }
    }

    /// Grobe Höhe des Fußes, um den Seitenumbruch davor zu setzen.
    private static func geschaetzteFussHoehe() -> CGFloat {
        let zeilen = [Briefpapier.kontaktZeilen(), Briefpapier.bankZeilen(),
                      Briefpapier.steuerZeilen()].map(\.count).max() ?? 0
        guard zeilen > 0 || !FirmenSettings.rechtstextFuss.isEmpty else { return 20 }
        return CGFloat(zeilen) * 10 + (FirmenSettings.rechtstextFuss.isEmpty ? 0 : 14) + 14
    }
}
