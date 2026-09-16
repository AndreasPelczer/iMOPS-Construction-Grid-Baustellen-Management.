//
//  Lohnkalkulation.swift
//  Ehrliche Kalkulation: die KOSTENSEITE (Lohngruppen → Mittellohn) und die
//  Aufschlags-Kette (Selbstkosten → Angebot) — als generische Struktur.
//
//  WICHTIG (Repo ist öffentlich): hier stehen NUR Formeln + generische öffentliche
//  Richtwerte (ZDB-Tarif West, übliche Zuschlag-Spannen). Die echten Firmenzahlen
//  trägt der Nutzer in FirmenSettings ein — nie in den Code.
//
//  Zwei Sätze NICHT verwechseln (der alte „74"-Fehler):
//   • Vollkosten-Lohn  = Brutto-Tarif × Nebenkosten-Faktor   (was die Stunde KOSTET)
//   • Verrechnungssatz = Vollkosten × (1 + Firmenzuschlag)    (was der Betrieb VERLANGT)
//  74 €/h ist der Verrechnungssatz, NICHT der Lohn. Er ist ein ERGEBNIS der Kette.
//

import Foundation

// MARK: - Lohngruppe (Kostenseite)

struct Lohngruppe: Identifiable, Equatable {
    var id: String { kuerzel }
    let kuerzel: String          // "LG1" … "LG6", "AT", "Azubi"
    let bezeichnung: String      // "Werker/Hilfsarbeiter", "Facharbeiter", "Polier" …
    let bruttoStundenlohn: Double // Tariflohn €/h (öffentlich, ZDB)

    /// Vollkosten je Stunde = Brutto × Nebenkosten-Faktor (Sozialabgaben, Lohnneben-
    /// kosten). Das ist, was die Mannstunde den Betrieb KOSTET.
    func vollkosten(nebenkostenFaktor: Double) -> Double {
        bruttoStundenlohn * nebenkostenFaktor
    }
}

// MARK: - Mittellohn aus einer Kolonne

/// Ein Kolonnen-Mitglied: eine Lohngruppe, `anzahl`-fach besetzt.
struct KolonnenPosten: Equatable {
    let lohngruppe: Lohngruppe
    let anzahl: Int
}

enum Mittellohn {
    /// Gewichteter Vollkosten-Schnitt über die Kolonne — der „Lohnkosten pro Mannstunde",
    /// der in die LV-Positionen geht (STATT eines Verrechnungssatzes wie 74).
    static func berechne(kolonne: [KolonnenPosten], nebenkostenFaktor: Double) -> Double {
        let summe = kolonne.reduce(0.0) {
            $0 + $1.lohngruppe.vollkosten(nebenkostenFaktor: nebenkostenFaktor) * Double($1.anzahl)
        }
        let koepfe = kolonne.reduce(0) { $0 + $1.anzahl }
        return koepfe > 0 ? summe / Double(koepfe) : 0
    }
}

// MARK: - Aufschlags-Kette (Selbstkosten → Angebot)

/// Die Kette von den Selbstkosten zum Angebot. Der Betrieb kann sie INNEN einzeln
/// sehen (BGK, AGK, Wagnis&Gewinn, Skonto), sie AUSSEN aber als EINEN vertraulichen
/// „Firmenzuschlag" ausweisen — die Aufteilung ist Geschäftsgeheimnis.
struct Aufschlagskette {
    var bgk: Double            // Baustellengemeinkosten
    var agk: Double            // Allgemeine Geschäftskosten
    var wagnisGewinn: Double   // Wagnis & Gewinn
    var skonto: Double         // Skonto/Nachlass-Puffer
    var mwstSatz: Double

    /// Der aggregierte, vertrauliche Aufschlag von Selbstkosten auf Netto-Angebot.
    /// (= das „Firmengeheimnis" — deckt BGK + AGK + W&G + Skonto ab, ohne den Split zu zeigen.)
    var firmenzuschlag: Double {
        (1 + bgk) * (1 + agk) * (1 + wagnisGewinn) * (1 + skonto) - 1
    }

    func nettoAngebot(selbstkosten: Double) -> Double {
        selbstkosten * (1 + firmenzuschlag)
    }

    func bruttoAngebot(selbstkosten: Double) -> Double {
        nettoAngebot(selbstkosten: selbstkosten) * (1 + mwstSatz)
    }

    /// Rückwärts: welcher EINE Firmenzuschlag reproduziert einen bekannten Verrechnungs-
    /// satz aus gegebenen Vollkosten? (Für das 74-Orakel und die vertrauliche Config.)
    static func firmenzuschlag(ausVollkosten vollkosten: Double, verrechnungssatz: Double) -> Double {
        vollkosten > 0 ? verrechnungssatz / vollkosten - 1 : 0
    }
}

// MARK: - Generische öffentliche Defaults (NIE firmenspezifisch)

enum LohnkalkulationDefaults {
    /// Nebenkosten-Faktor (Brutto → Vollkosten). Generischer Mittelwert; die Firma
    /// trägt ihren echten Wert in FirmenSettings ein.
    static let nebenkostenFaktor = 1.85

    /// Generische Lohngruppen (ZDB-Tarif West, Richtwerte). Platzhalter — die Firma
    /// pflegt ihre echten Tariflöhne. KEINE firmenspezifischen Zahlen.
    static let lohngruppen: [Lohngruppe] = [
        Lohngruppe(kuerzel: "LG1", bezeichnung: "Werker / Hilfsarbeiter", bruttoStundenlohn: 17.00),
        Lohngruppe(kuerzel: "LG2", bezeichnung: "Fachwerker",             bruttoStundenlohn: 18.50),
        Lohngruppe(kuerzel: "LG3", bezeichnung: "Facharbeiter",           bruttoStundenlohn: 19.80),
        Lohngruppe(kuerzel: "LG4", bezeichnung: "Spezialfacharbeiter",    bruttoStundenlohn: 21.00),
        Lohngruppe(kuerzel: "LG5", bezeichnung: "Vorarbeiter",            bruttoStundenlohn: 24.00),
        Lohngruppe(kuerzel: "LG6", bezeichnung: "Werkpolier / Polier",    bruttoStundenlohn: 28.50),
    ]

    /// Übliche Zuschlag-Spannen (Defaults). Generisch — jede Firma sieht das.
    static let kette = Aufschlagskette(bgk: 0.10, agk: 0.10, wagnisGewinn: 0.08,
                                       skonto: 0.025, mwstSatz: 0.19)
}
