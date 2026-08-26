import Foundation
import CoreData

/// Rechnet aus LV-Positionen die Bestellzeilen für den Ytong-Bestellschein.
///
/// Läuft **komplett lokal** — kein Netz nötig. Alles, was gebraucht wird, steht
/// nach dem Import schon in der LVPosition: die Material-Nummer in `artikelNummer`,
/// die Menge in `menge`, der Lieferant in `lieferant`.
///
/// Das ist Absicht: Die Firma soll vom Faxgerät wegkommen, und eine Bestellung, die
/// nur mit gutem Empfang funktioniert, wird beim ersten Funkloch wieder zum Fax.
enum BestellscheinService {

    /// Eine Zeile auf dem Bestellschein.
    struct Zeile: Identifiable {
        let materialNr: String
        let bezeichnung: String
        let mengeLV: Double
        let zuschlagProzent: Double
        var bestellmenge: Double { (mengeLV * (1 + zuschlagProzent / 100)).gerundet(2) }
        let positionen: Int
        var id: String { materialNr }
    }

    /// Zuschlag laut Aufdruck: „Bitte 10 % Eck/Laibungssteine bei Planblöcken
    /// D > 240 mm mitliefern".
    static let zuschlagAbMM = 240.0
    static let zuschlagProzent = 10.0

    /// Bestellzeilen aus allen Positionen einer Baustelle.
    ///
    /// Gruppiert über die **Material-Nummer**, nicht über den LV-Deckel: Unter einem
    /// Deckel „Außenwand 24 cm" stecken zwei Steinsorten mit zwei Nummern. Positionen
    /// ohne Nummer bleiben außen vor — sie tauchen in `ohneNummer` auf, damit sie
    /// nicht stillschweigend verschwinden.
    static func zeilen(aus positionen: [LVPosition]) -> (zeilen: [Zeile], ohneNummer: [LVPosition]) {
        var nachNummer: [String: (menge: Double, bez: String, dicke: Double, anzahl: Int)] = [:]
        var ohne: [LVPosition] = []

        for pos in positionen {
            guard let nr = pos.artikelNummer, !nr.isEmpty else {
                // Nur Wand-Positionen melden — Stürze, Putz und Außenanlagen
                // gehören ohnehin nicht auf diesen Schein.
                if istWand(pos) { ohne.append(pos) }
                continue
            }
            let dicke = dickeMM(aus: pos.bezeichnung ?? "")
            var e = nachNummer[nr] ?? (0, kurzBezeichnung(pos.bezeichnung ?? ""), dicke, 0)
            e.menge += pos.menge
            e.anzahl += 1
            if dicke > e.dicke { e.dicke = dicke }
            nachNummer[nr] = e
        }

        let zeilen = nachNummer.map { (nr, e) in
            Zeile(materialNr: nr,
                  bezeichnung: e.bez,
                  mengeLV: e.menge.gerundet(2),
                  zuschlagProzent: e.dicke > zuschlagAbMM ? zuschlagProzent : 0,
                  positionen: e.anzahl)
        }.sorted { $0.materialNr < $1.materialNr }

        return (zeilen, ohne)
    }

    // MARK: - Hilfen

    private static func istWand(_ pos: LVPosition) -> Bool {
        let b = (pos.bezeichnung ?? "").lowercased()
        return b.contains("wand") || b.contains("_aw_") || b.contains("_iw_")
    }

    /// Wandstärke in mm aus dem Bauteilnamen („…_365mm_…" oder „… 36,5 cm").
    /// Nur für den Zuschlag gebraucht — nicht für die Menge.
    private static func dickeMM(aus name: String) -> Double {
        let n = name.lowercased()
        if let r = n.range(of: #"(\d{2,4})\s*mm"#, options: .regularExpression),
           let v = Double(n[r].filter("0123456789".contains)) { return v }
        if let r = n.range(of: #"(\d{1,3}(?:[.,]\d)?)\s*cm"#, options: .regularExpression) {
            let zahl = n[r].replacingOccurrences(of: ",", with: ".")
                .filter("0123456789.".contains)
            if let v = Double(zahl) { return v * 10 }
        }
        return 0
    }

    /// „EG_AW_Waende_240mm_PP2-0,35_KG 330.001_1" → „AW 240mm PP2-0,35"
    private static func kurzBezeichnung(_ name: String) -> String {
        let teile = name.split(separator: "_").map(String.init)
        let interessant = teile.filter {
            $0.range(of: #"^\d+mm$"#, options: .regularExpression) != nil
                || $0.uppercased().hasPrefix("PP")
                || $0.uppercased() == "AW" || $0.uppercased() == "IW"
        }
        return interessant.isEmpty ? name : interessant.joined(separator: " ")
    }
}

private extension Double {
    func gerundet(_ stellen: Int) -> Double {
        let f = pow(10.0, Double(stellen))
        return (self * f).rounded() / f
    }
}
