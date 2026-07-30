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

    /// Lohnstunden je Mengeneinheit. Nur Lohn — Geraetestunden sind eine eigene
    /// Groesse (die Maschine steht auch, wenn niemand danebensteht).
    var stundenJeEinheit: Double = 0

    // Zuschlag je Kostenart. Gefuellt, wenn `zuschlagJeKostenart` an ist;
    // dann sind zuschlagWG und zuschlagBGK 0 — und umgekehrt.
    var zuschlagLohn: Double = 0
    var zuschlagMaterial: Double = 0
    var zuschlagGeraet: Double = 0

    /// Gesamter Aufschlag je Einheit — egal nach welchem der beiden Verfahren.
    var zuschlagGesamt: Double {
        zuschlagWG + zuschlagBGK + zuschlagLohn + zuschlagMaterial + zuschlagGeraet
    }

    /// Lohnstunden der ganzen Position.
    var stundenGesamt: Double { stundenJeEinheit * menge }

    /// Rechnet diese Kalkulation je Kostenart auf?
    var istJeKostenart: Bool { zuschlagLohn + zuschlagMaterial + zuschlagGeraet > 0 }

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

        let stunden = position.lohnArray.reduce(0.0) { $0 + $1.stunden }
        let ek = material + lohn + geraete

        // Baustein unter einem Element: den Zuschlag traegt das Element, nicht der
        // Baustein — sonst wuerde doppelt aufgeschlagen. Siehe kalkuliereElement.
        let z = position.istElementBaustein
            ? Zuschlaege()
            : zuschlaege(fuer: position, material: material, lohn: lohn, geraete: geraete)
        let vk = ek + z.summe

        // effektiveMenge == menge, ausser der Baustein rechnet nach Rezept
        // (mengeJeDeckelEinheit x Bezugsmenge des Elements).
        let menge = position.effektiveMenge

        return Kalkulation(
            materialKosten: material,
            lohnKosten: lohn,
            geraeteKosten: geraete,
            einheitspreisEK: ek,
            zuschlagWG: z.wg,
            zuschlagBGK: z.bgk,
            einheitspreisVK: vk,
            gesamtpreis: vk * menge,
            menge: menge,
            stundenJeEinheit: stunden,
            zuschlagLohn: z.lohn,
            zuschlagMaterial: z.material,
            zuschlagGeraet: z.geraet
        )
    }

    // MARK: - Zuschlaege (eine Stelle fuer beide Verfahren)

    /// Aufschlag auf die Selbstkosten, aufgeschluesselt.
    struct Zuschlaege {
        var wg = 0.0
        var bgk = 0.0
        var lohn = 0.0
        var material = 0.0
        var geraet = 0.0
        var summe: Double { wg + bgk + lohn + material + geraet }
    }

    /// Entweder EIN Satz auf die Summe (bisher) oder je Kostenart ein eigener.
    ///
    /// Bewusst EINE Funktion fuer beide Verfahren: Position und Element muessen
    /// zwingend gleich aufschlagen. Als es an zwei Stellen stand, ist genau das
    /// auseinandergelaufen (siehe die vier nachgebauten Preis-Logiken vom 30.07.).
    static func zuschlaege(fuer position: LVPosition,
                           material: Double, lohn: Double, geraete: Double) -> Zuschlaege {
        // Immer die WIRKSAMEN Saetze — Firmenwert, ausser die Position weicht
        // ausdruecklich ab (zuschlagEigen). Nie die rohen Felder lesen.
        var z = Zuschlaege()
        if position.rechnetJeKostenart {
            // Lohn traegt ueblicherweise den Loewenanteil, Material und Geraet wenig.
            z.lohn     = lohn     * position.satzLohn
            z.material = material * position.satzMaterial
            z.geraet   = geraete  * position.satzGeraet
        } else {
            let ek = material + lohn + geraete
            z.wg  = ek * position.satzWagnisGewinn
            z.bgk = ek * position.satzBGK
        }
        return z
    }

    /// Kalkuliert ein B-Element: die Bausteine liefern ihre Selbstkosten, umgerechnet
    /// ueber ihr Rezept-Mass auf EINE Einheit des Elements. Der Zuschlag kommt hier
    /// oben EINMAL drauf (klassische Kalkulation: Einzelkosten der Teilleistungen,
    /// dann Zuschlag) — deshalb rechnen die Bausteine selbst zuschlagsfrei.
    ///
    /// Die Einheiten kuerzen sich dabei heraus: (EUR je m³) x (m³ je m²) = EUR je m².
    /// Ein Baustein darf also in m³, lfm oder Stunden rechnen, das Element in m².
    static func kalkuliereElement(_ element: LVPosition) -> Kalkulation {
        func jeElementEinheit(_ anteil: (LVPosition) -> Double) -> Double {
            element.unterPositionenArray.reduce(0.0) { summe, baustein in
                summe + anteil(baustein) * baustein.mengeJeDeckelEinheit
            }
        }

        let material = jeElementEinheit { $0.materialArray.reduce(0.0) { $0 + $1.kostenProEinheit } }
        let lohn     = jeElementEinheit { $0.lohnArray.reduce(0.0)     { $0 + $1.kostenProEinheit } }
        let geraete  = jeElementEinheit { $0.geraeteArray.reduce(0.0)  { $0 + $1.kostenProEinheit } }
        // Lohnstunden je Element-Einheit — dasselbe Rezept-Mass wie bei den Kosten.
        let stunden  = jeElementEinheit { $0.lohnArray.reduce(0.0)     { $0 + $1.stunden } }

        let ek = material + lohn + geraete
        let z = zuschlaege(fuer: element, material: material, lohn: lohn, geraete: geraete)
        let vk = ek + z.summe

        return Kalkulation(
            materialKosten: material,
            lohnKosten: lohn,
            geraeteKosten: geraete,
            einheitspreisEK: ek,
            zuschlagWG: z.wg,
            zuschlagBGK: z.bgk,
            einheitspreisVK: vk,
            gesamtpreis: vk * element.menge,
            menge: element.menge,
            stundenJeEinheit: stunden,
            zuschlagLohn: z.lohn,
            zuschlagMaterial: z.material,
            zuschlagGeraet: z.geraet
        )
    }

    /// Kalkuliert mehrere Positionen und summiert den Gesamtpreis.
    /// B-Elemente werden ueber ihre Bausteine gerechnet — ein Element hat selbst
    /// keine Tiefenkalkulation und faellt sonst mit 0 aus der Summe.
    static func gesamtKalkulation(positionen: [LVPosition]) -> Double {
        positionen.zaehlbarePositionen().reduce(0.0) { sum, pos in
            sum + kalkulationFuer(pos).gesamtpreis
        }
    }

    /// Lohnstunden des ganzen LV. Sagt, wie viele Mannstunden hinter einem Angebot
    /// stecken — die Groesse, an der Termine und Mannschaftsstaerke haengen.
    /// Geraetestunden zaehlen NICHT mit; sie sind eine eigene Groesse.
    static func gesamtStunden(positionen: [LVPosition]) -> Double {
        positionen.zaehlbarePositionen().reduce(0.0) { sum, pos in
            sum + kalkulationFuer(pos).stundenGesamt
        }
    }

    /// Die richtige Kalkulation fuer eine Position — Element ueber seine Bausteine,
    /// alles andere direkt. Eine Stelle, damit Summen und Stunden nicht auseinanderlaufen.
    static func kalkulationFuer(_ position: LVPosition) -> Kalkulation {
        position.istElement ? kalkuliereElement(position) : kalkuliere(position: position)
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
        // Element vor Eigenkalkulation: der Preis eines B-Elements ist die Summe
        // seiner Bausteine, nicht seine eigene (meist leere) Tiefenkalkulation.
        if position.istElement { return kalkuliereElement(position).einheitspreisVK }
        if position.hatKalkulation { return kalkuliere(position: position).einheitspreisVK }
        return 0
    }
}

// MARK: - Bewehrungs-Dedup (EINE Wahrheit für Bildschirm UND Export)

/// Regel für „doppelt importierte Bewehrung zählt einmal": Plan + Liste (oder ein
/// versehentlicher Doppel-Import) liefern dieselbe kg-Menge → nur EINE Position darf
/// in Summen/Exporte einfließen. Bewusst eng gehalten — nur Einheit „kg", gleiche
/// Bezeichnung + gleiche Menge. Alles andere bleibt unangetastet.
/// Vorher lebte diese Regel nur in `LVView` (Bildschirm); GAEB/PDF/Kostenübersicht
/// rechneten flach und zählten das Duplikat doppelt. Jetzt nutzen alle dieselbe Regel.
enum LVDedup {
    static func istBewehrung(_ p: LVPosition) -> Bool {
        (p.einheit ?? "").lowercased() == "kg"
    }

    /// „Gleiche Position": Bezeichnung (getrimmt/kleingeschrieben) + Menge (2 Nachkommastellen).
    static func dedupKey(_ p: LVPosition) -> String {
        let bez = (p.bezeichnung ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        return "\(bez)|\((p.menge * 100).rounded())"
    }
}

extension Sequence where Element == LVPosition {
    /// Fürs Summieren/Exportieren: doppelt importierte Bewehrung (gleiche Menge aus
    /// Plan/Liste) zählt EINMAL. Reihenfolge bleibt erhalten, erstes Vorkommen gewinnt.
    /// Nicht-Bewehrung (Einheit ≠ „kg") bleibt vollständig erhalten.
    func ohneBewehrungsDuplikate() -> [LVPosition] {
        var gesehen = Set<String>()
        var out: [LVPosition] = []
        for pos in self {
            if LVDedup.istBewehrung(pos) {
                let k = LVDedup.dedupKey(pos)
                if gesehen.contains(k) { continue }
                gesehen.insert(k)
            }
            out.append(pos)
        }
        return out
    }

    /// Die Positionen, die WIRKLICH in Summen/Exporte zählen — eine Wahrheit für alle:
    /// 1. Unterpunkte (Belege unter einem Deckel) fallen raus; nur der Deckel zählt (Typ B,
    ///    REB-23.003-Hilfswert — die Teile stecken IM Deckel, nicht neben ihm).
    /// 2. danach zählt doppelt importierte Bewehrung (Typ A) einmal.
    func zaehlbarePositionen() -> [LVPosition] {
        filter { !$0.istUnterpunkt }.ohneBewehrungsDuplikate()
    }
}
