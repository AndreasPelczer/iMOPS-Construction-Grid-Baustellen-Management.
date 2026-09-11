//
//  Briefpapier.swift
//  Logo, Briefkopf und Fuß — für jedes Dokument, das das Haus verlässt.
//
//  ── Warum das hier steht und nicht in jedem Exporter ─────────────────────────
//
//  Bis hierher schrieben vier Exporter (`LVPDFExporter`, `BautagesberichtPDFExporter`,
//  `MangelPDFExporter`, `LieferantenAnfragePDFExporter`) hart **„iMOPS Construction
//  Grid"** in Kopf und Fuß — den Namen der *Software* auf ein Dokument, das ein
//  *Bauunternehmen* verschickt. Bei der Lieferantenanfrage ging das nach draußen.
//
//  Vier Stellen, viermal derselbe Satz: Das läuft auseinander, sobald einer davon
//  angefasst wird. Deshalb ein Briefkopf, den alle benutzen.
//
//  ── Der Grundsatz: keine Platzhalter ─────────────────────────────────────────
//
//  **Eine fehlende Angabe wird weggelassen, nie gedruckt.** Kein „[fehlt]", kein
//  „–", keine leere Zeile mit Doppelpunkt. Ein Briefkopf ohne Faxnummer sieht
//  normal aus; ein Briefkopf mit „Fax: –" sieht nach Software aus.
//
//  ⚠️ **Was dieses Modul NICHT kann:** prüfen, ob die Angaben *stimmen*. Ob die
//  USt-IdNr. die richtige ist und die IBAN dem Konto gehört, sieht man nur auf den
//  Firmenpapieren. Unter echtem Firmennamen gibt es kein „ungefähr".
//

import UIKit

enum Briefpapier {

    // MARK: - Kopf

    /// Zeichnet Logo und Absenderblock. Gibt die neue y-Position zurück.
    ///
    /// Das Logo steht rechts, die Anschrift links — das übliche Bild eines
    /// Geschäftsbriefs. Fehlt das Logo, rückt die Anschrift nicht, damit
    /// Dokumente mit und ohne Logo dieselbe Höhe haben.
    @discardableResult
    static func zeichneKopf(ab y: CGFloat, links: CGFloat, breite: CGFloat) -> CGFloat {
        var y = y
        let logoHoehe: CGFloat = 46

        if let daten = FirmenSettings.logoDaten, let bild = UIImage(data: daten) {
            // Seitenverhältnis behalten und in einen Kasten einpassen: ein
            // verzerrtes Firmenlogo ist schlimmer als gar keins.
            let breiteMax: CGFloat = 150
            let faktor = min(breiteMax / bild.size.width, logoHoehe / bild.size.height)
            let groesse = CGSize(width: bild.size.width * faktor,
                                 height: bild.size.height * faktor)
            bild.draw(in: CGRect(x: links + breite - groesse.width, y: y,
                                 width: groesse.width, height: groesse.height))
        }

        for (i, zeile) in FirmenSettings.anschrift.enumerated() {
            let fett: UIFont = i == 0 ? .systemFont(ofSize: 11, weight: .semibold)
                                      : .systemFont(ofSize: 9.5)
            zeile.draw(at: CGPoint(x: links, y: y),
                       withAttributes: [.font: fett,
                                        .foregroundColor: UIColor.black])
            y += i == 0 ? 15 : 12
        }

        return max(y, logoHoehe) + 8
    }

    /// Die Empfänger-Anschrift (Anschriftenfeld eines Geschäftsbriefs).
    @discardableResult
    static func zeichneEmpfaenger(_ zeilen: [String],
                                  ab y: CGFloat, links: CGFloat) -> CGFloat {
        var y = y
        for zeile in zeilen where !zeile.isEmpty {
            zeile.draw(at: CGPoint(x: links, y: y),
                       withAttributes: [.font: UIFont.systemFont(ofSize: 10.5),
                                        .foregroundColor: UIColor.black])
            y += 14
        }
        return y
    }

    // MARK: - Fuß

    /// Der Fußblock: Kontakt · Bank · Steuer/Register. Drei Spalten, wie üblich.
    ///
    /// Gibt die Höhe zurück, die er gebraucht hat — der Aufrufer weiß dadurch,
    /// wie viel Platz der Seiteninhalt über ihm noch hat.
    @discardableResult
    static func zeichneFuss(seitenHoehe: CGFloat, links: CGFloat,
                            breite: CGFloat) -> CGFloat {
        let spalten: [[String]] = [kontaktZeilen(), bankZeilen(), steuerZeilen()]
        let gefuellt = spalten.filter { !$0.isEmpty }
        guard !gefuellt.isEmpty || !FirmenSettings.rechtstextFuss.isEmpty else { return 0 }

        let zeilenMax = gefuellt.map(\.count).max() ?? 0
        let rechtstext = FirmenSettings.rechtstextFuss
        let hoehe = CGFloat(zeilenMax) * 10 + (rechtstext.isEmpty ? 0 : 14) + 14
        var y = seitenHoehe - hoehe

        UIColor(white: 0.75, alpha: 1).setStroke()
        let linie = UIBezierPath()
        linie.move(to: CGPoint(x: links, y: y))
        linie.addLine(to: CGPoint(x: links + breite, y: y))
        linie.lineWidth = 0.5
        linie.stroke()
        y += 6

        if !rechtstext.isEmpty {
            rechtstext.draw(at: CGPoint(x: links, y: y),
                            withAttributes: [.font: UIFont.systemFont(ofSize: 7),
                                             .foregroundColor: UIColor.gray])
            y += 12
        }

        let spaltenBreite = breite / CGFloat(max(gefuellt.count, 1))
        for (i, spalte) in gefuellt.enumerated() {
            var sy = y
            for zeile in spalte {
                zeile.draw(at: CGPoint(x: links + CGFloat(i) * spaltenBreite, y: sy),
                           withAttributes: [.font: UIFont.systemFont(ofSize: 7),
                                            .foregroundColor: UIColor.darkGray])
                sy += 10
            }
        }
        return hoehe
    }

    // MARK: - Die Zeilen, jede nur wenn sie etwas sagt

    static func kontaktZeilen() -> [String] {
        var z: [String] = []
        if !FirmenSettings.telefon.isEmpty { z.append("Tel. \(FirmenSettings.telefon)") }
        if !FirmenSettings.fax.isEmpty     { z.append("Fax \(FirmenSettings.fax)") }
        if !FirmenSettings.email.isEmpty   { z.append(FirmenSettings.email) }
        if !FirmenSettings.web.isEmpty     { z.append(FirmenSettings.web) }
        return z
    }

    static func bankZeilen() -> [String] {
        var z: [String] = []
        for (bank, iban, bic) in [(FirmenSettings.bank, FirmenSettings.iban, FirmenSettings.bic),
                                  (FirmenSettings.bank2, FirmenSettings.iban2, FirmenSettings.bic2)] {
            guard !iban.isEmpty || !bank.isEmpty else { continue }
            if !bank.isEmpty { z.append(bank) }
            if !iban.isEmpty { z.append("IBAN \(iban)") }
            if !bic.isEmpty  { z.append("BIC \(bic)") }
        }
        return z
    }

    static func steuerZeilen() -> [String] {
        var z: [String] = []
        if !FirmenSettings.ustIdNr.isEmpty {
            z.append("USt-IdNr. \(FirmenSettings.ustIdNr)")
        }
        if !FirmenSettings.steuernummer.isEmpty {
            z.append("St.-Nr. \(FirmenSettings.steuernummer)")
        }
        if !FirmenSettings.handelsregister.isEmpty {
            z.append(FirmenSettings.handelsregister)
        }
        if !FirmenSettings.geschaeftsfuehrer.isEmpty {
            z.append("GF: \(FirmenSettings.geschaeftsfuehrer)")
        }
        return z
    }
}
