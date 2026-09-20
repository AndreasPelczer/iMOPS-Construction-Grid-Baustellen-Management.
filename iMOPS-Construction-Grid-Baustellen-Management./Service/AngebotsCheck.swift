import Foundation

// MARK: - AngebotsCheck (Angebots-Wächter — Rechenkern)
//
// Geschwister vom Preis-Wächter: der prüft, ob eine Zahl FALSCH ist; dieser, ob eine
// LÜCKE bleibt, bevor das Angebot rausgeht. Positionen ohne Preis (noch nicht
// bepreist) oder ohne Menge (im Angebot stünde 0) fallen einem Menschen unter
// Zeitdruck leicht durch — eine systematische Prüfung nicht.
//
// Rein, ohne Core Data → testbar. Ein Adapter füttert echte LV-Positionen ein.
// Überschriften/Titel (keine Menge, keine Einheit, kein Preis) sind KEINE Lücke —
// sie sind Gliederung; Alternativpositionen zählen auch nicht.

struct AngebotsPosten: Sendable, Equatable {
    let id: String
    let bezeichnung: String
    let einheit: String
    let menge: Double
    let einzelpreis: Double
    let istAlternative: Bool
}

struct AngebotsLuecke: Sendable, Equatable, Identifiable {
    enum Art: Sendable, Equatable { case ohnePreis, ohneMenge }
    var id: String { "\(posID)-\(art == .ohnePreis ? "p" : "m")" }
    let posID: String
    let bezeichnung: String
    let art: Art
    let hinweis: String
}

enum AngebotsCheck {

    /// Findet Lücken, die ein fertiges Angebot nicht haben darf.
    static func pruefe(_ posten: [AngebotsPosten]) -> [AngebotsLuecke] {
        var luecken: [AngebotsLuecke] = []
        for p in posten {
            if p.istAlternative { continue }                 // Alternative = bewusst optional
            let leer = p.menge <= 0
                && p.einzelpreis <= 0
                && p.einheit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if leer { continue }                             // reine Überschrift/Titel → keine Lücke

            if p.einzelpreis <= 0 {
                luecken.append(AngebotsLuecke(posID: p.id, bezeichnung: p.bezeichnung, art: .ohnePreis,
                    hinweis: "Kein Einheitspreis — Position ist noch nicht bepreist."))
            }
            if p.menge <= 0 {
                luecken.append(AngebotsLuecke(posID: p.id, bezeichnung: p.bezeichnung, art: .ohneMenge,
                    hinweis: "Keine Menge — im Angebot stünde 0."))
            }
        }
        return luecken
    }
}
