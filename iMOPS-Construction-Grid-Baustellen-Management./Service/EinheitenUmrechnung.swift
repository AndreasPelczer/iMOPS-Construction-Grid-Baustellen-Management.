import Foundation

/// Rechnet einen „pro Einheit"-Wert von einer Einheit in eine andere um — genau dann,
/// wenn beide zur selben Größenart gehören (Masse, Volumen, Länge, Fläche).
///
/// Warum: Ein Aufwandswert steht im Katalog z. B. als „15 h **pro Tonne**", die
/// LV-Position rechnet aber in **kg**. Ohne Umrechnung würden 15 h pro kg angesetzt —
/// Faktor 1000 daneben (der Bewehrungs-Ausreißer). Passt die Größenart gar nicht
/// zusammen (t gegen m²), gibt es KEINEN Faktor → der Aufrufer flaggt lieber, als
/// eine grob falsche Zahl zu setzen.
enum EinheitenUmrechnung {

    // Größe einer Einheit in ihrer jeweiligen Basis (kg · l · m · m²).
    private static let masse:   [String: Double] = ["kg": 1, "g": 0.001, "mg": 0.000001,
                                                    "t": 1000, "to": 1000, "mg.": 0.000001]
    private static let volumen: [String: Double] = ["l": 1, "ml": 0.001, "m3": 1000,
                                                    "dm3": 1, "cbm": 1000, "fm": 1000, "hl": 100]
    private static let laenge:  [String: Double] = ["m": 1, "lfm": 1, "lm": 1, "rm": 1,
                                                    "cm": 0.01, "mm": 0.001, "dm": 0.1, "km": 1000]
    private static let flaeche: [String: Double] = ["m2": 1, "qm": 1, "ar": 100, "ha": 10000]

    private static let tabellen = [masse, volumen, laenge, flaeche]

    /// Einheit vereinheitlichen: klein, ohne Leerzeichen/Punkte, ² → 2, ³ → 3.
    static func normalisiere(_ e: String) -> String {
        e.lowercased()
            .replacingOccurrences(of: "²", with: "2")
            .replacingOccurrences(of: "³", with: "3")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Faktor, um einen „pro `von`"-Wert in einen „pro `nach`"-Wert umzurechnen.
    ///
    /// `wert_pro_nach = wert_pro_von × faktor`. Beispiel t → kg: 15 h/t × 0,001 = 0,015 h/kg.
    /// Gleiche Einheit → 1. Unterschiedliche Größenart (nicht umrechenbar) → nil.
    static func proFaktor(von: String, nach: String) -> Double? {
        let v = normalisiere(von)
        let n = normalisiere(nach)
        if v == n { return 1 }
        for tabelle in tabellen {
            if let basisVon = tabelle[v], let basisNach = tabelle[n] {
                // pro-nach = pro-von × (Basisgröße nach / Basisgröße von)
                return basisNach / basisVon
            }
        }
        return nil
    }

    // Volumen-Einheiten → Größe in m³; Masse-Einheiten → Größe in t.
    private static let volumen_m3: [String: Double] = ["m3": 1, "cbm": 1, "fm": 1, "l": 0.001, "dm3": 0.001, "hl": 0.1]
    private static let masse_t:    [String: Double] = ["t": 1, "to": 1, "kg": 0.001, "g": 0.000001]

    /// Faktor „pro `von`" → „pro `nach`", wenn eine Größenart Volumen und die andere Masse ist —
    /// überbrückt mit der **Dichte** (`dichteTproM3`, t/m³). Nur so kommt ein h/m³-Aufwandswert
    /// an eine t-Position. Keine reine Umrechnung (siehe `proFaktor`) → der Aufrufer markiert
    /// das Ergebnis als Richtwert. nil, wenn nicht Volumen↔Masse.
    static func proFaktorMitDichte(von: String, nach: String, dichteTproM3: Double) -> Double? {
        guard dichteTproM3 > 0 else { return nil }
        let v = normalisiere(von)
        let n = normalisiere(nach)
        // pro-Volumen → pro-Masse: 1 Masse-Einheit (mN t) = mN/dichte m³ = (mN/dichte)/vV Volumen-Einheiten.
        if let vV = volumen_m3[v], let mN = masse_t[n] {
            return (mN / dichteTproM3) / vV
        }
        // pro-Masse → pro-Volumen: 1 Volumen-Einheit (vN m³) = vN·dichte t = (vN·dichte)/mV Masse-Einheiten.
        if let mV = masse_t[v], let vN = volumen_m3[n] {
            return (vN * dichteTproM3) / mV
        }
        return nil
    }

    /// Eine ABSOLUTE Menge von `von` in `nach` umrechnen (kein „pro"-Wert): 70 t → kg = 70000.
    ///
    /// Anders als `proFaktor` (das einen je-Einheit-Wert umrechnet und sich dabei umgekehrt
    /// verhält) — hier geht es um die Menge selbst. Beispiel Maschinen-Brücke: die Position
    /// hat 70 t Schotter, der Bagger schafft m³/h → wie viele m³ sind das? Gleiche Größenart
    /// direkt, Volumen↔Masse über die Dichte. nil, wenn nicht umrechenbar.
    ///
    /// Zusammenhang: absolute Menge A_nach = A_von × (Basisgröße von / Basisgröße nach)
    /// = A_von × proFaktor(nach, von) — daher sind die Argumente hier vertauscht.
    static func mengeUmrechnen(_ menge: Double, von: String, nach: String, dichteTproM3: Double? = nil) -> Double? {
        if let f = proFaktor(von: nach, nach: von) { return menge * f }
        if let d = dichteTproM3, let f = proFaktorMitDichte(von: nach, nach: von, dichteTproM3: d) {
            return menge * f
        }
        return nil
    }
}
