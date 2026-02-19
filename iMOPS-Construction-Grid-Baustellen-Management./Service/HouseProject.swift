//
//  HouseProject.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Datenmodell fuer die Hauskonfiguration.
//

import Foundation

// MARK: - Haustyp

enum Haustyp: String, Codable, CaseIterable, Identifiable {
    case einfamilienhaus = "Einfamilienhaus"
    case zweifamilienhaus = "Zweifamilienhaus"
    case doppelhaushaelfte = "Doppelhaushaelfte"
    case reihenhaus = "Reihenhaus"

    var id: String { rawValue }
}

// MARK: - Dachform

enum Dachform: String, Codable, CaseIterable, Identifiable {
    case satteldach = "Satteldach"
    case walmdach = "Walmdach"
    case flachdach = "Flachdach"
    case pultdach = "Pultdach"

    var id: String { rawValue }
}

// MARK: - Ausstattungsniveau

enum Ausstattungsniveau: String, Codable, CaseIterable, Identifiable {
    case einfach = "Einfach"
    case mittel = "Mittel"
    case gehoben = "Gehoben"

    var id: String { rawValue }

    /// Baukosten pro m² Wohnflaeche (netto, ohne Grundstueck)
    var kostenProQm: Double {
        switch self {
        case .einfach: return 2000
        case .mittel:  return 2500
        case .gehoben: return 3200
        }
    }
}

// MARK: - Haus-Konfiguration (Eingabe)

struct HouseProject: Codable, Identifiable {
    var id: String = UUID().uuidString

    // Grunddaten
    var projektName: String = ""
    var haustyp: Haustyp = .einfamilienhaus
    var wohnflaeche: Double = 140          // m²
    var geschosse: Int = 2
    var kellerGeplant: Bool = true
    var dachform: Dachform = .satteldach

    // Raeume
    var anzahlBaeder: Int = 2
    var anzahlGaesteWC: Int = 1
    var anzahlZimmer: Int = 5
    var kueche: Bool = true
    var garage: Bool = false

    // Technik & Ausstattung
    var fussbodenheizung: Bool = true
    var solaranlage: Bool = false
    var waermepumpe: Bool = false
    var smartHome: Bool = false
    var ausstattung: Ausstattungsniveau = .mittel

    // Berechnet: Grundflaeche pro Geschoss
    var grundflaecheProGeschoss: Double {
        guard geschosse > 0 else { return wohnflaeche }
        return wohnflaeche / Double(geschosse)
    }

    // Berechnet: Gesamt-Bruttoflaeche (inkl. Keller wenn vorhanden)
    var gesamtBruttoflaeche: Double {
        var total = wohnflaeche
        if kellerGeplant { total += grundflaecheProGeschoss }
        if garage { total += 30 } // Standardgarage ~30m²
        return total
    }
}

// MARK: - Generiertes Ergebnis

struct HouseProjectResult: Identifiable {
    let id = UUID().uuidString
    let project: HouseProject

    // Massenermittlung
    var massen: [MassenPosition]

    // Materialien (gruppiert nach Gewerk)
    var materialien: [MaterialPosition]

    // Kosten
    var baukosten: Kostenaufstellung
    var baunebenkosten: [Nebenkostenposition]

    // Bauzeitenplan
    var phasen: [Bauphase]

    // Einkaufsliste (abgeleitet aus Materialien)
    var einkaufsliste: [EinkaufsPosition] {
        materialien.map { mat in
            EinkaufsPosition(
                titel: mat.titel,
                menge: mat.menge,
                einheit: mat.einheit,
                gewerk: mat.gewerk,
                geschaetzterPreis: mat.einzelpreis * mat.menge
            )
        }
    }

    var gesamtkosten: Double {
        baukosten.gesamtBaukosten + baunebenkosten.reduce(0) { $0 + $1.betrag }
    }
}

// MARK: - Massenermittlung

struct MassenPosition: Identifiable {
    let id = UUID().uuidString
    var bezeichnung: String    // z.B. "Aussenwaende EG"
    var menge: Double
    var einheit: String        // m², m³, Stk, lfm
    var gewerk: String         // Rohbau, Elektro, etc.
    var details: String = ""
}

// MARK: - Materialpositionen

struct MaterialPosition: Identifiable {
    let id = UUID().uuidString
    var titel: String          // z.B. "Transportbeton C25/30"
    var menge: Double
    var einheit: String        // m³, m², Stk, lfm
    var einzelpreis: Double    // EUR pro Einheit
    var gewerk: String
    var notiz: String = ""
}

// MARK: - Kosten

struct Kostenaufstellung {
    var rohbau: Double = 0
    var dach: Double = 0
    var fensterTueren: Double = 0
    var elektro: Double = 0
    var sanitaer: Double = 0
    var heizung: Double = 0
    var trockenbau: Double = 0
    var estrich: Double = 0
    var maler: Double = 0
    var aussenanlagen: Double = 0

    var gesamtBaukosten: Double {
        rohbau + dach + fensterTueren + elektro + sanitaer +
        heizung + trockenbau + estrich + maler + aussenanlagen
    }

    var positionen: [(String, Double)] {
        [
            ("Rohbau", rohbau),
            ("Dach", dach),
            ("Fenster & Tueren", fensterTueren),
            ("Elektro", elektro),
            ("Sanitaer", sanitaer),
            ("Heizung", heizung),
            ("Trockenbau", trockenbau),
            ("Estrich & Boden", estrich),
            ("Malerarbeiten", maler),
            ("Aussenanlagen", aussenanlagen)
        ].filter { $0.1 > 0 }
    }
}

struct Nebenkostenposition: Identifiable {
    let id = UUID().uuidString
    var bezeichnung: String
    var betrag: Double
    var details: String = ""
}

// MARK: - Bauzeitenplan

struct Bauphase: Identifiable {
    let id = UUID().uuidString
    var name: String
    var gewerk: String
    var dauerWochen: Int
    var startWoche: Int          // Woche ab Baubeginn
    var beschreibung: String = ""

    var endeWoche: Int { startWoche + dauerWochen }
}

// MARK: - Einkaufsliste

struct EinkaufsPosition: Identifiable {
    let id = UUID().uuidString
    var titel: String
    var menge: Double
    var einheit: String
    var gewerk: String
    var geschaetzterPreis: Double
}
