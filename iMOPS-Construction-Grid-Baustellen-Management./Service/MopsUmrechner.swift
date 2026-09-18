import Foundation

/// Der EINE Umrechner. Alle Bau-Einheiten hängen an EINER Leiter, jede Sprosse ist ein
/// geometrisches/physikalisches Maß:
///
///     Länge ──(× Höhe/Breite)──► Fläche ──(× Dicke)──► Volumen ──(× Dichte)──► Masse
///       m                          m²                    m³                      t
///
/// Jede Umrechnung über Größenarten hinweg ist ein GANG über die Sprossen: Länge↔Volumen
/// (Graben) = 2 Sprossen, Länge↔Masse (Bewehrung, der alte kg-Ausreißer) = 3 Sprossen,
/// Fläche↔Masse = 3. Es gibt also NICHT dutzende Sonderfälle, sondern genau drei Brückenmaße:
/// **Höhe/Breite, Dicke, Dichte**. Fehlt eine nötige Sprosse (z. B. keine Höhe bekannt),
/// gibt es keinen Faktor → der Aufrufer flaggt ehrlich, statt grob falsch zu rechnen.
///
/// Innerhalb einer Größenart (cm↔m, kg↔t) rechnet `EinheitenUmrechnung` — hier kommt nur
/// der Gang ÜBER die Größenarten dazu. So bleibt eine Wahrheit: ein Ort, der weiß, wie man
/// von Einheit A nach B kommt, gegeben was man messen kann.
enum MopsUmrechner {

    /// Die Brückenmaße zwischen den Größenarten. Alles optional — was fehlt, sperrt die
    /// zugehörige Sprosse (dann nur Umrechnungen, die sie nicht brauchen).
    struct Bruecke: Equatable {
        var hoeheOderBreite: Double? = nil  // Länge ↔ Fläche (m) — z. B. Fundament-/Wandhöhe
        var dicke: Double? = nil            // Fläche ↔ Volumen (m) — z. B. Schichtdicke
        var dichteTproM3: Double? = nil     // Volumen ↔ Masse (t/m³) — Schüttgut-Dichte

        static let keine = Bruecke()
    }

    /// Die vier Größenarten auf der Leiter, von unten (Länge) nach oben (Masse).
    enum Groesse: Int, CaseIterable {
        case laenge = 0, flaeche = 1, volumen = 2, masse = 3
        var basisEinheit: String {
            switch self {
            case .laenge:  return "m"
            case .flaeche: return "m2"
            case .volumen: return "m3"
            case .masse:   return "t"
            }
        }
    }

    /// Ergebnis einer Umrechnung: der „pro"-Faktor (je-Einheit-Werte, z. B. Aufwandswert),
    /// der Mengen-Faktor (absolute Mengen) und ein Klartext-Hinweis auf die benutzten Brücken.
    struct Umrechnung {
        let proFaktor: Double     // wert_pro_nach = wert_pro_von × proFaktor
        let mengeFaktor: Double   // menge_nach   = menge_von   × mengeFaktor
        let hinweis: String       // "" bei gleicher Größenart, sonst "über Dichte 1,9 t/m³ · Höhe 0,5 m"
    }

    /// Die Größenart einer Einheit — ermittelt über `EinheitenUmrechnung` (kein zweites
    /// Einheiten-Register): passt die Einheit auf die Basis einer Größenart, gehört sie dazu.
    static func groesse(_ einheit: String) -> Groesse? {
        for g in Groesse.allCases where EinheitenUmrechnung.proFaktor(von: einheit, nach: g.basisEinheit) != nil {
            return g
        }
        return nil
    }

    /// Der Mengen-Faktor von `von` nach `nach` über die Leiter, oder nil (Sprosse fehlt / keine
    /// Größenart, z. B. Stück). `menge_nach = menge_von × mengeFaktor`.
    static func mengeFaktor(von: String, nach: String, bruecke: Bruecke = .keine) -> Double? {
        umrechnung(von: von, nach: nach, bruecke: bruecke)?.mengeFaktor
    }

    /// Der „pro"-Faktor (je-Einheit-Werte) von `von` nach `nach`, oder nil.
    /// `wert_pro_nach = wert_pro_von × proFaktor`.
    static func proFaktor(von: String, nach: String, bruecke: Bruecke = .keine) -> Double? {
        umrechnung(von: von, nach: nach, bruecke: bruecke)?.proFaktor
    }

    /// Eine absolute Menge umrechnen (nicht „pro"). 70 t Schotter → m³ (über Dichte),
    /// 115 m Fundament → m² Schalfläche (über Höhe). nil, wenn eine Sprosse fehlt.
    static func mengeUmrechnen(_ menge: Double, von: String, nach: String, bruecke: Bruecke = .keine) -> Double? {
        guard let f = mengeFaktor(von: von, nach: nach, bruecke: bruecke) else { return nil }
        return menge * f
    }

    /// Der volle Gang über die Leiter: normalisieren auf die Basis der Von-Größenart, Sprosse
    /// für Sprosse zur Ziel-Größenart (hoch = mal Brückenmaß, runter = geteilt), dann auf die
    /// Ziel-Einheit. Sammelt unterwegs den Klartext-Hinweis.
    static func umrechnung(von: String, nach: String, bruecke: Bruecke = .keine) -> Umrechnung? {
        guard let gv = groesse(von), let gn = groesse(nach) else { return nil }

        // 1) Menge (=1) auf die Basis-Einheit der Von-Größenart bringen.
        guard var menge = EinheitenUmrechnung.mengeUmrechnen(1, von: von, nach: gv.basisEinheit) else { return nil }

        // 2) Sprosse für Sprosse zur Ziel-Größenart.
        var teile: [String] = []
        var stufe = gv.rawValue
        while stufe < gn.rawValue {
            guard let (mass, text) = sprosse(stufe, bruecke: bruecke) else { return nil }
            menge *= mass; teile.append(text); stufe += 1
        }
        while stufe > gn.rawValue {
            guard let (mass, text) = sprosse(stufe - 1, bruecke: bruecke) else { return nil }
            menge /= mass; teile.append(text); stufe -= 1
        }

        // 3) Von der Basis-Einheit der Ziel-Größenart auf die gewünschte Einheit.
        guard let mengeFaktor = EinheitenUmrechnung.mengeUmrechnen(menge, von: gn.basisEinheit, nach: nach),
              mengeFaktor != 0 else { return nil }

        let hinweis = teile.isEmpty ? "" : "über \(teile.joined(separator: " · "))"
        return Umrechnung(proFaktor: 1 / mengeFaktor, mengeFaktor: mengeFaktor, hinweis: hinweis)
    }

    /// Das Brückenmaß der Sprosse von Stufe `i` nach `i+1` (Länge→Fläche→Volumen→Masse) plus
    /// sein Klartext. nil, wenn das nötige Maß fehlt.
    private static func sprosse(_ i: Int, bruecke: Bruecke) -> (mass: Double, text: String)? {
        switch i {
        case 0:
            guard let h = bruecke.hoeheOderBreite, h > 0 else { return nil }
            return (h, "Höhe/Breite \(zahl(h)) m")
        case 1:
            guard let d = bruecke.dicke, d > 0 else { return nil }
            return (d, "Dicke \(zahl(d)) m")
        case 2:
            guard let d = bruecke.dichteTproM3, d > 0 else { return nil }
            return (d, "Dichte \(zahl(d)) t/m³")
        default:
            return nil
        }
    }

    private static func zahl(_ d: Double) -> String { String(format: "%g", d) }
}
