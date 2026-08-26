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
        /// Von Hand gesetzte Menge. Ist sie belegt, gilt sie statt der gerechneten —
        /// jemand hat sich das angesehen und entschieden, etwa wegen Restbestand.
        var bestellmengeManuell: Double? = nil
        let positionen: Int

        var bestellmenge: Double {
            bestellmengeManuell ?? (mengeLV * (1 + zuschlagProzent / 100)).gerundet(2)
        }
        /// Wurde die gerechnete Menge überschrieben? Wird im PDF gekennzeichnet.
        var vonHand: Bool { bestellmengeManuell != nil }
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
            // Deckel überspringen: Sie tragen die Summe ihrer Belege, und die Belege
            // sind unten einzeln erfasst. Sonst stünde dieselbe Menge zweimal da —
            // einmal gezählt und einmal als „nicht zugeordnet".
            if (pos.unterPositionen?.count ?? 0) > 0 { continue }

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


// MARK: - Der Bestellschein als Vorlage

/// Die Zeilen des T&C-Bestellscheins SÜD 2022 in **seiner** Reihenfolge.
///
/// Damit lässt sich das PDF Zeile für Zeile gegen das Papier abgleichen — der
/// Grund, warum diese Tabelle hier steht und nicht nur im Backend. Wer den Schein
/// in der Hand hält, findet jede Nummer an derselben Stelle.
///
/// ⚠️ Aus einem Foto des Scheins abgetippt. Vor dem Bestellen gegen das Original
/// prüfen: Ein Zahlendreher in einer Material-Nr lässt den falschen Stein kommen.
enum Bestellscheinvorlage {

    struct Eintrag {
        let materialNr: String
        let stueckJePalette: Int
        let guete: String
        let profil: String
        let abmessung: String
    }

    struct Gruppe {
        let titel: String
        let eintraege: [Eintrag]
    }

    static let gruppen: [Gruppe] = [
        Gruppe(titel: "YTONG Planbauplatte", eintraege: [
            .init(materialNr: "10005034", stueckJePalette: 162, guete: "PPpl-0,50", profil: "glatt", abmessung: "599 x 50 x 249"),
            .init(materialNr: "10005036", stueckJePalette: 120, guete: "PPpl-0,50", profil: "glatt", abmessung: "599 x 75 x 249"),
            .init(materialNr: "10005000", stueckJePalette: 90,  guete: "PPpl-0,50", profil: "glatt", abmessung: "599 x 100 x 249"),
        ]),
        Gruppe(titel: "YTONG Planblock W", eintraege: [
            .init(materialNr: "10005006", stueckJePalette: 78, guete: "PPW 4-0,55", profil: "glatt", abmessung: "599 x 115 x 249"),
            .init(materialNr: "10005008", stueckJePalette: 60, guete: "PPW 4-0,55", profil: "NF",    abmessung: "599 x 150 x 249"),
            .init(materialNr: "10005026", stueckJePalette: 48, guete: "PPW 4-0,60", profil: "NF-GT", abmessung: "599 x 175 x 249"),
            .init(materialNr: "10005003", stueckJePalette: 48, guete: "PPW 6-0,65", profil: "NF-GT", abmessung: "599 x 175 x 249"),
            .init(materialNr: "10005129", stueckJePalette: 42, guete: "PPW 4-0,55", profil: "NF-GT", abmessung: "599 x 200 x 249"),
            .init(materialNr: "10005028", stueckJePalette: 36, guete: "PPW 2-0,35 (0,09)", profil: "NF-GT", abmessung: "599 x 240 x 249"),
            .init(materialNr: "10005013", stueckJePalette: 36, guete: "PPW 2-0,40", profil: "NF-GT", abmessung: "599 x 240 x 249"),
            .init(materialNr: "10005022", stueckJePalette: 36, guete: "PPW 4-0,50", profil: "NF-GT", abmessung: "599 x 240 x 249"),
            .init(materialNr: "10005045", stueckJePalette: 36, guete: "PPW 6-0,65", profil: "NF-GT", abmessung: "499 x 240 x 249"),
            .init(materialNr: "10005030", stueckJePalette: 30, guete: "PPW 2-0,35 (0,09)", profil: "NF-GT", abmessung: "599 x 300 x 249"),
            .init(materialNr: "10005015", stueckJePalette: 30, guete: "PPW 2-0,40", profil: "NF-GT", abmessung: "599 x 300 x 249"),
            .init(materialNr: "10005042", stueckJePalette: 30, guete: "PPW 4-0,50", profil: "NF-GT", abmessung: "499 x 300 x 249"),
            .init(materialNr: "10005056", stueckJePalette: 30, guete: "PPW 6-0,65", profil: "NF-GT", abmessung: "499 x 300 x 249"),
            .init(materialNr: "10005032", stueckJePalette: 24, guete: "PPW 2-0,35 (0,09)", profil: "NF-GT", abmessung: "599 x 365 x 249"),
            .init(materialNr: "10005213", stueckJePalette: 24, guete: "PPW 2-0,35 (0,09)", profil: "NF-GT", abmessung: "499 x 365 x 249"),
            .init(materialNr: "10005017", stueckJePalette: 24, guete: "PPW 2-0,40", profil: "NF-GT", abmessung: "499 x 365 x 249"),
            .init(materialNr: "10005024", stueckJePalette: 24, guete: "PPW 4-0,50", profil: "NF-GT", abmessung: "499 x 365 x 249"),
            .init(materialNr: "10005058", stueckJePalette: 24, guete: "PPW 6-0,65", profil: "NF-GT", abmessung: "499 x 365 x 249"),
            .init(materialNr: "10005485", stueckJePalette: 18, guete: "PPW 2-0,35 (0,09)", profil: "NF-GT", abmessung: "499 x 425 x 249"),
        ]),
    ]

    /// Alle Einträge flach — zum Nachschlagen einer Nummer.
    static func eintrag(zu materialNr: String) -> Eintrag? {
        gruppen.flatMap(\.eintraege).first { $0.materialNr == materialNr }
    }
}
