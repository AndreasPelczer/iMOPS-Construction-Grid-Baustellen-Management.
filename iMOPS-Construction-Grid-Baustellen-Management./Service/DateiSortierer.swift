import Foundation

/// Wohin eine reingeworfene Datei gehört — die drei Körbe der „einen Tür".
enum SortierZiel: String, CaseIterable {
    case statik      // Statik-/Bewehrungspläne → Mengen fürs LV (/extract-plan)
    case fakten      // Gutachten · B-Plan · Erschließung · Wohnfläche → Fakten (/extract-doc)
    case ablegen     // Angebote · Sonstiges → nur ablegen (keine Auslese)

    var titel: String {
        switch self {
        case .statik:  return "Statik → Mengen fürs LV"
        case .fakten:  return "Unterlagen → Fakten"
        case .ablegen: return "Nur ablegen"
        }
    }
    var symbol: String {
        switch self {
        case .statik:  return "ruler"
        case .fakten:  return "doc.text.magnifyingglass"
        case .ablegen: return "tray"
        }
    }
}

/// Mops als Sortier-Wächter: ordnet eine Datei anhand ihres Namens einem Korb zu.
/// Bewusst über den DATEINAMEN (schnell, offline, nachvollziehbar) — die Erkennung
/// ist ein Vorschlag, der Mensch korrigiert sie im Sortier-Sheet.
enum DateiSortierer {

    /// Schlüsselwörter, die einen Statik-/Bewehrungsplan verraten.
    private static let statikWorte = [
        "bewehr", "bopla", "ringbalken", "stütze", "stuetze", "statik",
        "stahlbeton", "matten", "sturz", "giebel", "rahmen", "decke",
    ]
    /// Schlüsselwörter für Unterlagen mit auswertbaren Fakten.
    private static let faktenWorte = [
        "gutachten", "boden", "bebauungsplan", "b-plan", "bplan",
        "erschließ", "erschliess", "wohnfläche", "wohnflaeche", "gründung", "gruendung",
    ]

    static func sortiere(_ dateiname: String) -> SortierZiel {
        let n = dateiname.lowercased()

        // Nicht-PDF / Bilder / Tabellen → ablegen (keine Text-Auslese)
        if n.hasSuffix(".jpg") || n.hasSuffix(".jpeg") || n.hasSuffix(".png")
            || n.hasSuffix(".heic") || n.hasSuffix(".xlsx") || n.hasSuffix(".xls") {
            return .ablegen
        }

        if statikWorte.contains(where: n.contains) { return .statik }
        // Plan-Code wie „B 6", „B 1.1" (typisch für Statik-Einzelpläne)
        if n.range(of: #"\bb[ _-]?\d(\.\d)?\b"#, options: .regularExpression) != nil { return .statik }

        if faktenWorte.contains(where: n.contains) { return .fakten }

        // Bekannt „nur ablegen": Angebote, Aufträge, Rechnungen, Protokolle, Listen
        let ablegenWorte = ["angebot", "auftrag", "rechnung", "protokoll", "gespraech", "gespräch", "liste"]
        if ablegenWorte.contains(where: n.contains) { return .ablegen }

        // Rest: unklar → ablegen (der Mensch schiebt es im Sheet dorthin, wo es hingehört)
        return .ablegen
    }
}
