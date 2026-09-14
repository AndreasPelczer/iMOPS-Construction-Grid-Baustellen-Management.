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

enum Bauablauf {

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
