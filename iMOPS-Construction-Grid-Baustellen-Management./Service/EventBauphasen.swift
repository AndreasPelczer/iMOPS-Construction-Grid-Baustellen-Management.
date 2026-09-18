//
//  EventBauphasen.swift
//  Bogen 3 (Nordstern): der echte Ablaufplan einer Baustelle. Verbindet, was schon da ist —
//  Bauablauf (Reihenfolge über Vorgänger), BrigadePlanung (Manntage → Dauer) und die Bauzeit —
//  zu einem [Bauphase], das die vorhandene Gantt-View (BauzeitenplanView) unverändert zeigt.
//
//  EHRLICH (Tao): die Reihenfolge kommt aus den echten Vorgänger-Kanten (Bauablauf.rang),
//  nicht geraten. Die Dauer kommt aus den Manntagen der zugehörigen LV-Position ÷ Kolonne;
//  Aufträge ohne hinterlegten Aufwand tragen keine Dauer und werden sichtbar als solche geführt
//  (1 Woche Platzhalter + Hinweis), statt eine Zahl zu erfinden.
//
//  Anordnung: Aufträge desselben Rangs laufen PARALLEL (gleiche Startwoche); der nächste Rang
//  beginnt, wenn der längste des vorigen fertig ist. Woche 0 = Baubeginn (eventStartTime).
//

import Foundation
import CoreData

enum EventBauphasen {

    /// Ein Vorgang für den Ablaufplan — rein wertbasiert, damit die Planung ohne Core Data testbar ist.
    struct Vorgang {
        let name: String
        let gewerk: String
        let manntage: Double
        let rang: Int
        let aufwandFehlt: Bool
    }

    /// 5 Arbeitstage je Woche.
    static let arbeitstageJeWoche = 5.0

    // MARK: - Reine Planung (ohne Core Data, voll testbar)

    /// Vorgänge → Bauphasen: nach Rang gruppiert, je Rang parallel (gleiche Startwoche),
    /// nächster Rang nach dem längsten des vorigen. Dauer = Manntage ÷ (Kolonne × 5 Tage/Woche).
    static func plane(_ vorgaenge: [Vorgang], kolonne: Int) -> [Bauphase] {
        guard !vorgaenge.isEmpty else { return [] }
        let leute = max(1, kolonne)
        func dauerWochen(_ manntage: Double) -> Int {
            manntage <= 0 ? 1 : max(1, Int(ceil(manntage / (Double(leute) * arbeitstageJeWoche))))
        }
        let raenge = Set(vorgaenge.map { $0.rang }).sorted()
        var phasen: [Bauphase] = []
        var startWoche = 0
        for rang in raenge {
            let ebene = vorgaenge.filter { $0.rang == rang }
            var maxDauer = 1
            for v in ebene {
                let d = dauerWochen(v.manntage)
                maxDauer = max(maxDauer, d)
                phasen.append(Bauphase(
                    name: v.name,
                    gewerk: v.gewerk,
                    dauerWochen: d,
                    startWoche: startWoche,
                    beschreibung: v.aufwandFehlt ? "Aufwand fehlt — Dauer geschätzt (1 Woche)" : ""))
            }
            startWoche += maxDauer
        }
        return phasen
    }

    // MARK: - Core Data: Event → Bauphasen

    /// Ablaufplan einer Baustelle: Aufträge in Bauablauf-Reihenfolge, Dauer aus den Manntagen der
    /// zugeordneten LV-Position, Gewerk aus der Kostengruppe. `kolonne` = angenommene Mannschaftsstärke.
    @MainActor
    static func fuer(event: Event, kolonne: Int) -> [Bauphase] {
        let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
        guard !jobs.isEmpty else { return [] }
        let raenge = Bauablauf.rang(jobs)
        let vorgaenge: [Vorgang] = jobs.map { job in
            let mt = manntage(fuer: job)
            return Vorgang(
                name: titel(job),
                gewerk: gewerk(fuerKG: job.kostenGruppeNummer),
                manntage: mt,
                rang: raenge[job.objectID] ?? 0,
                aufwandFehlt: mt <= 0)
        }
        return plane(vorgaenge, kolonne: kolonne)
    }

    /// Manntage eines Auftrags aus seiner LV-Position (Lohnstunden je Einheit × Menge ÷ Stunden/Tag).
    @MainActor
    private static func manntage(fuer job: Auftrag) -> Double {
        guard let pos = job.lvPosition else { return 0 }
        let stundenGesamt = pos.lohnArray.reduce(0.0) { $0 + $1.stunden } * pos.menge
        return stundenGesamt / BrigadePlanung.stundenJeTag
    }

    @MainActor
    private static func titel(_ job: Auftrag) -> String {
        if let b = job.kostenGruppeBezeichnung, !b.isEmpty { return b }
        if let n = job.kostenGruppeNummer, !n.isEmpty { return "KG \(n)" }
        return "Auftrag"
    }

    // MARK: - Kostengruppe → Gewerk (Gantt-Farben)

    /// Bildet eine DIN-276-Kostengruppe auf einen Gewerk-String ab, der zu den Farben in
    /// `BauzeitenplanView.gewerkeColors` passt. Heuristik (Folgerung), kein exakter Katalog.
    static func gewerk(fuerKG kg: String?) -> String {
        let ziffern = (kg ?? "").filter(\.isNumber)
        guard !ziffern.isEmpty else { return "Allgemein" }
        let p3 = String(ziffern.prefix(3))
        // Fenster/Türen zuerst (Sonderfälle in den 3xx).
        if p3 == "334" || p3 == "344" { return "Fenster & Tueren" }
        switch String(ziffern.prefix(2)) {
        case "31": return "Erdarbeiten"                     // Baugrube/Erdbau
        case "32", "33", "34", "35": return "Rohbau"        // Gründung/Wände/Decken
        case "36", "39": return "Dach"                      // Dächer / sonstiger Rohbau
        case "41", "45": return "Sanitaer"                  // Abwasser/Wasser/Gas, Kommunikation
        case "42": return "Heizung"                         // Wärmeversorgung
        case "44": return "Elektro"                         // Starkstrom
        default: break
        }
        switch String(ziffern.prefix(1)) {
        case "5": return "Aussenanlagen"                    // 500 Außenanlagen
        case "3", "4": return "Ausbau"                      // sonstiger Bau/technische Anlagen
        default: return "Allgemein"
        }
    }
}
