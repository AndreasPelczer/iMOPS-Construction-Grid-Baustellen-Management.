import Foundation

struct DIN276KostenGruppe: Identifiable, Hashable {
    let nummer: String
    let bezeichnung: String

    var id: String { nummer }

    var anzeige: String { "\(nummer) \(bezeichnung)" }
}

extension DIN276KostenGruppe {

    /// Flache Sicht auf `DIN276BaumKatalog` — **eine** Quelle der Wahrheit.
    ///
    /// Bis 29.07.2026 war das hier eine zweite, von Hand gepflegte Liste. Die beiden
    /// Kataloge sind auseinandergelaufen: 37 Nummern trugen unterschiedliche
    /// Bezeichnungen, rund 20 davon mit echter Bedeutungsverschiebung — dieselbe
    /// Nummer meinte in beiden Katalogen etwas anderes:
    ///
    ///   325  „Bodenbeläge"   ↔ „Abdichtungen und Bekleidungen"
    ///   326  „Bauwerksabdichtungen" ↔ „Dränagen"
    ///   352  „Deckenbeläge"  ↔ „Deckenöffnungen"
    ///   533  „Stellplätze"   ↔ „Plätze, Höfe, Terrassen"
    ///
    /// Der Baum ist die maßgebliche Fassung (er deckt sich mit dem Kostengruppen-
    /// Blatt, auf dem 200 „Vorbereitende Maßnahmen" und 214 „Herrichten der
    /// Geländeoberflächen" stehen). Ableiten statt doppelt pflegen macht diese
    /// Drift strukturell unmöglich — es gibt nur noch einen Ort zum Ändern.
    ///
    /// Zusätzlich kennt die abgeleitete Liste jetzt alle 3 Ebenen (334 statt 114
    /// Einträge), also auch Nummern wie 532, die vorher nur in einem der beiden
    /// Kataloge standen.
    static let alle: [DIN276KostenGruppe] = {
        func flach(_ knoten: [DIN276BaumKnoten]) -> [DIN276KostenGruppe] {
            knoten.flatMap { knoten in
                [DIN276KostenGruppe(nummer: knoten.nummer, bezeichnung: knoten.bezeichnung)]
                    + flach(knoten.kinder)
            }
        }
        return flach(DIN276BaumKatalog.hauptgruppen).sorted { $0.nummer < $1.nummer }
    }()

    /// Nur die Zehner-Ebene (z. B. 310, 320, 330) — die Hunderter sind ebenfalls
    /// enthalten, weil sie auf „0" enden.
    static let hauptgruppen: [DIN276KostenGruppe] = alle.filter {
        $0.nummer.count == 3 && $0.nummer.hasSuffix("0")
    }

    /// Bezeichnung zu einer KG-Nummer — **die** Stelle, die den Namen kennt.
    ///
    /// Vorher hatten LVView, Kostenübersicht, GAEB-Import, PDF-Export und
    /// GAEB-Export je eine eigene, handgepflegte `switch`-Kopie. Alle fünf kannten
    /// nur Hunderter und Zehner (dreistellige KGs fielen in „Sonstige"), und sie
    /// trugen teils veraltete oder schlicht falsche Namen: 200 hieß dort
    /// „Herrichten & Erschließen" (alte Fassung, heute „Vorbereitende Maßnahmen"),
    /// 380 stand als „Fenster & Türen" statt „Baukonstruktive Einbauten".
    ///
    /// Der Fallback bleibt bewusst „Sonstige": hauseigene Gliederungsnummern, die
    /// der Katalog nicht kennt, sollen nicht wie ein Fehler aussehen.
    static func bezeichnung(fuer nummer: String) -> String {
        alle.first { $0.nummer == nummer }?.bezeichnung ?? "Sonstige"
    }
}
