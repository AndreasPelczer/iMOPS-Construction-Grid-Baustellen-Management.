//
//  ProjektTyp.swift
//  Vom Haus-Generator zum Projekt-Generator (firm-fitting).
//
//  Der Konfigurator dachte bisher nur in `Haustyp` (Einfamilienhaus … Reihenhaus).
//  `ProjektTyp` verallgemeinert das eine Stück nach oben: ein Projekt ist ENTWEDER
//  ein Haus (dann trägt es einen `Haustyp` und läuft unverändert über den bestehenden
//  `HouseProjectGenerator`) ODER eine kleine, firm-typische Baustelle (erste: die
//  Hofeinfahrt). Der Haus-Generator wird NICHT umgebaut — er ist einfach ein Typ unter
//  mehreren. Neue Typen kommen daneben, Zimmer für Zimmer.
//
//  Die Liste ist bewusst KEINE Taxonomie über alles Baubare, sondern das, was die
//  Firma (Goldschmitt: Town-&-Country-Häuser + Tiefbau/Außenanlagen) wirklich macht.
//  Sie soll später aus echten Baustellen wachsen — nicht aus einer erfundenen Norm.

enum ProjektTyp: String, CaseIterable, Identifiable {
    // Häuser — laufen 1:1 über den bestehenden Haus-Generator.
    case einfamilienhaus
    case zweifamilienhaus
    case doppelhaushaelfte
    case reihenhaus
    // Kleine firm-typische Baustellen (erste Vorlage).
    case hofeinfahrt

    var id: String { rawValue }

    /// Ist das ein Haus (→ HouseProjectGenerator) oder eine kleine Vorlage?
    var istHaus: Bool { hausTyp != nil }

    /// Der zugehörige `Haustyp`, falls es ein Haus ist — sonst nil.
    var hausTyp: Haustyp? {
        switch self {
        case .einfamilienhaus:   return .einfamilienhaus
        case .zweifamilienhaus:  return .zweifamilienhaus
        case .doppelhaushaelfte: return .doppelhaushaelfte
        case .reihenhaus:        return .reihenhaus
        case .hofeinfahrt:       return nil
        }
    }

    var anzeige: String {
        switch self {
        case .einfamilienhaus:   return "Einfamilienhaus"
        case .zweifamilienhaus:  return "Zweifamilienhaus"
        case .doppelhaushaelfte: return "Doppelhaushälfte"
        case .reihenhaus:        return "Reihenhaus"
        case .hofeinfahrt:       return "Hofeinfahrt pflastern"
        }
    }
}
