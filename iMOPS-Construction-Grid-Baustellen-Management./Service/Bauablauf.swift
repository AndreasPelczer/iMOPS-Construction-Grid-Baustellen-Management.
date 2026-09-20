//
//  Bauablauf.swift
//  Die Reihenfolge, in der gebaut wird — als eine Wahrheit für Liste UND Spiel.
//
//  Der Rang eines Auftrags = längster Weg über die Kausalkette (vorgaenger) bis zu
//  ihm. Damit lässt sich die Auftragsliste top-to-bottom abarbeiten; und dasselbe
//  Maß ist der Antwortschlüssel fürs Sortier-Spiel des Lehrlings (er ordnet die
//  gemischten Aufgaben, der Mops weiß die richtige Reihenfolge schon).
//
//  „Eine Übergabe ist ein Zustandswechsel" (Tao Kap 5): Schritt N darf erst nach
//  N-1. Das Spiel lehrt die Reihenfolge, die die Baustelle danach verlangt.
//

import Foundation
import CoreData

// MARK: - Zeit im Canvas (Netzplan-Vorwärtsrechnung)
//
// `rang(...)` unten kennt die REIHENFOLGE. Hier kommt die ZEIT dazu: früheste
// Start-/Endzeitpunkte (CPM, Ende→Anfang mit Übergangszeit/lag). Die Wartezeit —
// Zement härten, Estrich trocknen — sitzt auf der KANTE, nicht als Arbeit im Knoten.
// Reine Structs (kein Core Data) → testbar; ein Adapter füttert später Aufträge
// (dauerTage) + Voraussetzungen (wartezeitTage) ein. Tage sind relativ zum
// Baustellenstart (Tag 0); Kalenderdaten macht der Adapter aus einem Startdatum.

struct AblaufKnoten: Sendable, Equatable {
    let id: String
    let name: String
    let dauerTage: Double   // Arbeitsdauer (0 erlaubt = Meilenstein)
}

struct AblaufKante: Sendable, Equatable {
    let von: String          // Vorgänger (blockiert den Nachfolger)
    let zu: String           // Nachfolger (wartet auf den Vorgänger)
    let wartezeitTage: Double // Übergangszeit/lag: 0 = direkt, >0 = Liegezeit
}

struct AblaufTermin: Sendable, Equatable, Identifiable {
    var id: String { knotenID }
    let knotenID: String
    let name: String
    let fruehesterStartTag: Double
    let fruehestesEndeTag: Double
}

struct AblaufErgebnis: Sendable, Equatable {
    let termine: [AblaufTermin]
    let gesamtdauerTage: Double
    let zyklus: [String]      // nicht leer = Ringabhängigkeit erkannt (dann keine Termine)
}

enum Bauablauf {

    /// Früheste Start-/Endzeitpunkte aus dem Abhängigkeitsgraph. Zyklus wird erkannt
    /// und ehrlich gemeldet, statt still falsch zu rechnen.
    static func vorwaertsrechnung(knoten: [AblaufKnoten], kanten: [AblaufKante]) -> AblaufErgebnis {
        let dauer = Dictionary(knoten.map { ($0.id, $0.dauerTage) }, uniquingKeysWith: { a, _ in a })
        var indeg: [String: Int] = Dictionary(knoten.map { ($0.id, 0) }, uniquingKeysWith: { a, _ in a })
        var ausgehend: [String: [AblaufKante]] = [:]
        var eingehend: [String: [AblaufKante]] = [:]
        for e in kanten where dauer[e.von] != nil && dauer[e.zu] != nil && e.von != e.zu {
            indeg[e.zu, default: 0] += 1
            ausgehend[e.von, default: []].append(e)
            eingehend[e.zu, default: []].append(e)
        }
        // Kahn: v wird erst berechnet, wenn ALLE Vorgänger fertig sind (deren EF steht).
        var queue = knoten.map { $0.id }.filter { indeg[$0] == 0 }
        var es: [String: Double] = [:]
        var ef: [String: Double] = [:]
        var reihenfolge: [String] = []
        var i = 0
        while i < queue.count {
            let v = queue[i]; i += 1
            reihenfolge.append(v)
            let start = (eingehend[v] ?? []).map { (ef[$0.von] ?? 0) + $0.wartezeitTage }.max() ?? 0
            es[v] = start
            ef[v] = start + (dauer[v] ?? 0)
            for out in ausgehend[v] ?? [] {
                indeg[out.zu, default: 0] -= 1
                if indeg[out.zu] == 0 { queue.append(out.zu) }
            }
        }
        if reihenfolge.count < knoten.count {
            let fertig = Set(reihenfolge)
            return AblaufErgebnis(termine: [], gesamtdauerTage: 0,
                                  zyklus: knoten.map { $0.id }.filter { !fertig.contains($0) })
        }
        let termine = knoten.map {
            AblaufTermin(knotenID: $0.id, name: $0.name,
                         fruehesterStartTag: es[$0.id] ?? 0, fruehestesEndeTag: ef[$0.id] ?? 0)
        }
        return AblaufErgebnis(termine: termine, gesamtdauerTage: ef.values.max() ?? 0, zyklus: [])
    }

    /// Rang je Auftrag = längster Vorgänger-Pfad + 1 (Wurzeln = 0). Zyklus-fest.
    /// Unabhängig von der Reihenfolge der übergebenen Liste — er kommt aus dem Graph.
    static func rang(_ jobs: [Auftrag]) -> [NSManagedObjectID: Int] {
        var rang: [NSManagedObjectID: Int] = [:]
        var laeuft: Set<NSManagedObjectID> = []          // Zyklus-Schutz
        func r(_ a: Auftrag) -> Int {
            if let v = rang[a.objectID] { return v }
            if laeuft.contains(a.objectID) { return 0 }
            laeuft.insert(a.objectID)
            let vor = a.vorgaenger
            let val = vor.isEmpty ? 0 : (vor.map { r($0) }.max() ?? 0) + 1
            laeuft.remove(a.objectID)
            rang[a.objectID] = val
            return val
        }
        jobs.forEach { _ = r($0) }
        return rang
    }

    /// Eine Reihenfolge ist gültig, wenn die Ränge NICHT fallen — kein späterer
    /// Bauschritt steht vor einem früheren. Parallele Schritte (gleicher Rang) dürfen
    /// in beliebiger Reihenfolge stehen (es gibt mehrere richtige Lösungen).
    static func istGueltigeReihenfolge(_ reihenfolge: [Auftrag]) -> Bool {
        let rang = rang(reihenfolge)
        var letzter = Int.min
        for a in reihenfolge {
            let r = rang[a.objectID] ?? 0
            if r < letzter { return false }
            letzter = r
        }
        return true
    }

    /// Die erste Stelle, an der die Reihenfolge kippt (ein Auftrag, der zu früh steht),
    /// oder nil, wenn alles gültig ist. Für einen sanften Hinweis im Spiel.
    static func ersterFehler(_ reihenfolge: [Auftrag]) -> Auftrag? {
        let rang = rang(reihenfolge)
        var letzter = Int.min
        for a in reihenfolge {
            let r = rang[a.objectID] ?? 0
            if r < letzter { return a }
            letzter = r
        }
        return nil
    }
}
