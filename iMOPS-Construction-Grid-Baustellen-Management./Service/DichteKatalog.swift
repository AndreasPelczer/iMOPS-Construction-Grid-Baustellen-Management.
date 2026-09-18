import Foundation

/// Dichte-Richtwerte für Schüttgüter (t/m³) — die Brücke zwischen **m³** (so führt der
/// Katalog Schotter, Frostschutz …) und **t** (so misst die Stadt-Ausschreibung oft).
///
/// EHRLICH: Dichte ist material-/körnungs-/verdichtungsabhängig — das sind **Richtwerte**,
/// keine gemessenen Werte (lose vs. eingebaut schwankt). Darum wird eine so überbrückte
/// Zahl als Richtwert markiert, nicht als Firmenwert. Wer's genau weiß: von Hand setzen.
///
/// Später besser in eine `dichten.yaml` (wie die anderen Kataloge), damit Raphi sie pflegen
/// kann; für den ersten Wurf hier als Tabelle.
enum DichteKatalog {

    /// (Stichwort, Dichte t/m³) — spezifischere Begriffe zuerst, „enthält"-Treffer gewinnt.
    /// BEWUSST nur klare Schüttgüter: KEIN bloßes „beton" (träfe Betonstahl/Betonpflaster)
    /// und KEIN bloßes „boden" (träfe Bodenplatte) — die gäben falsche Dichten. Lieber eng
    /// und ehrlich flaggen als breit und falsch.
    private static let tabelle: [(stichwort: String, dichte: Double)] = [
        ("schottertragschicht", 1.9),
        ("frostschutzschicht", 1.9),
        ("frostschutz", 1.9),
        ("tragschicht", 1.9),
        ("mineralgemisch", 1.9),
        ("mineralbeton", 2.0),
        ("recyclingschotter", 1.7),
        ("recycling", 1.7),
        ("schotter", 1.9),
        ("splitt", 1.5),
        ("kies", 1.8),
        ("brechsand", 1.6),
        ("mutterboden", 1.5),
        ("oberboden", 1.6),
        ("humus", 1.5),
        ("aushub", 1.8),
    ]

    /// Dichte (t/m³) für einen Leistungs-/Positionstext — oder nil, wenn kein Schüttgut erkannt.
    static func dichte(fuer text: String?) -> Double? {
        let t = (text ?? "").lowercased()
        guard !t.isEmpty else { return nil }
        return tabelle.first { t.contains($0.stichwort) }?.dichte
    }
}
