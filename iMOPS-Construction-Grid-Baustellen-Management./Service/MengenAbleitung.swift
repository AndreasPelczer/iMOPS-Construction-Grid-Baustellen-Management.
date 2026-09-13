import Foundation

// MARK: - MengenAbleitung
//
// Bogen 2 / Leitstand-Schritt 2: die Menge einer LV-Zeile aus der BAUSTELLENGRÖSSE
// ableiten. Der Katalog liefert den Aufwandswert (h/Einheit), was fehlte, war die Menge.
// Sie steckt jetzt am `Event` (grundflaeche/umfang, seit „Größe ans Event").
//
// Die Zuordnung läuft über die EINHEIT der Position, nicht über den Leistungsnamen:
//   m² / qm  → Grundfläche der Baustelle
//   m / lfm  → Umfang (laufende Meter, z.B. Absperrung, Randeinfassung)
// Alles andere (Pauschal, m³, Stück, kg …) ist NICHT ableitbar → bleibt Handeingabe.
//
// **Ehrlich:** eine so abgeleitete Menge ist eine SCHÄTZUNG aus der groben Baustellen-
// größe, kein Aufmaß. Der Aufrufer markiert sie als `.schaetzung` (→ `istGeschaetzt`,
// in der App andersfarbig), damit sie nie wie ein gemessener Wert aussieht.
enum MengenAbleitung {

    struct Vorschlag {
        let menge: Double
        let quelle: String   // menschenlesbar für den Hinweis: „Umfang" / „Grundfläche"
    }

    /// Schlägt eine Menge vor, wenn Einheit + vorhandene Baustellengröße zusammenpassen.
    /// Gibt nil, wenn die Einheit nicht ableitbar ist oder die Größe fehlt (=0).
    static func ausGroesse(einheit: String?, event: Event?) -> Vorschlag? {
        guard let event else { return nil }
        let e = (einheit ?? "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespaces)

        switch e {
        case "m²", "m2", "qm", "quadratmeter":
            return event.grundflaeche > 0 ? Vorschlag(menge: event.grundflaeche, quelle: "Grundfläche") : nil
        case "m", "lfm", "lfdm", "laufm", "laufmeter":
            return event.umfang > 0 ? Vorschlag(menge: event.umfang, quelle: "Umfang") : nil
        default:
            return nil
        }
    }
}
