import Foundation
import CoreData

// MARK: - Kalkulations-Ergebnis

/// Aufschluesselung einer LV-Position in Material, Lohn, Geraete + Zuschlaege.
/// Alle Werte beziehen sich auf EINE Mengeneinheit der Position.
struct Kalkulation {
    let materialKosten: Double
    let lohnKosten: Double
    let geraeteKosten: Double
    let einheitspreisEK: Double
    let zuschlagWG: Double
    let zuschlagBGK: Double
    let einheitspreisVK: Double
    let gesamtpreis: Double
    let menge: Double

    // Prozentuale Aufteilung fuer Visualisierung
    var materialAnteil: Double {
        guard einheitspreisEK > 0 else { return 0 }
        return materialKosten / einheitspreisEK
    }

    var lohnAnteil: Double {
        guard einheitspreisEK > 0 else { return 0 }
        return lohnKosten / einheitspreisEK
    }

    var geraeteAnteil: Double {
        guard einheitspreisEK > 0 else { return 0 }
        return geraeteKosten / einheitspreisEK
    }
}

// MARK: - LVKalkulator

/// Pure Berechnungs-Engine fuer LV-Tiefenkalkulation.
/// Keine externen Abhaengigkeiten, keine Seiteneffekte — voll testbar.
enum LVKalkulator {

    /// Kalkuliert eine LV-Position komplett durch.
    /// Alle Berechnungen offline, keine Netzwerk-Abhaengigkeit.
    static func kalkuliere(position: LVPosition) -> Kalkulation {
        let material = position.materialArray.reduce(0.0) { sum, pm in
            sum + pm.kostenProEinheit
        }

        let lohn = position.lohnArray.reduce(0.0) { sum, pl in
            sum + pl.kostenProEinheit
        }

        let geraete = position.geraeteArray.reduce(0.0) { sum, pg in
            sum + pg.kostenProEinheit
        }

        let ek = material + lohn + geraete
        let wg = ek * position.wagnisGewinnProzent
        let bgk = ek * position.bgkProzent
        let vk = ek + wg + bgk
        let gesamt = vk * position.menge

        return Kalkulation(
            materialKosten: material,
            lohnKosten: lohn,
            geraeteKosten: geraete,
            einheitspreisEK: ek,
            zuschlagWG: wg,
            zuschlagBGK: bgk,
            einheitspreisVK: vk,
            gesamtpreis: gesamt,
            menge: position.menge
        )
    }

    /// Kalkuliert mehrere Positionen und summiert den Gesamtpreis.
    static func gesamtKalkulation(positionen: [LVPosition]) -> Double {
        positionen.reduce(0.0) { sum, pos in
            sum + kalkuliere(position: pos).gesamtpreis
        }
    }

    // MARK: - Effektiver Einzelpreis (eine Wahrheit fuer alle Konsumenten)

    /// Liefert den effektiven Einzelpreis (VK, netto) einer Position.
    /// Reihenfolge EXAKT wie im GAEB-X84-Export:
    ///   1. guenstigstes erfasstes Angebot (AngebotsStore)
    ///   2. sonst kalkulierter VK-Preis (Tiefenkalkulation / Pauschal-Traeger)
    ///   3. sonst 0
    /// Damit rechnen Kostenzusammenfassung, PDF-Export, XRechnung und GAEB identisch.
    static func effektiverEP(for position: LVPosition,
                             store: AngebotsStore = .shared) -> Double {
        let id = position.objectID.uriRepresentation().absoluteString
        let angebotsEP = store.guenstigster(for: id)?.einzelpreis ?? 0
        if angebotsEP > 0 { return angebotsEP }
        if position.hatKalkulation { return kalkuliere(position: position).einheitspreisVK }
        return 0
    }
}
