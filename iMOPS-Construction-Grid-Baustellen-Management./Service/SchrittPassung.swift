//
//  SchrittPassung.swift
//
//  „Ich brauche keinen Bauzaun und Dixiklo für einen Pfosten, den ich setze."
//  (Andreas, 21.09.2026)
//
//  Vorgeschlagene Arbeitsschritte sind für die grosse Baustelle geschrieben. Auf der
//  kleinen sind die halben davon Unsinn — nicht falsch, nur nicht gekauft. Bisher
//  gingen sie trotzdem alle in den Auftrag, und jemand musste sie einzeln wieder
//  löschen.
//
//  Der Mops kann das selbst sehen: was auf dieser Baustelle zu tun ist, steht im LV.
//  Nennt ein Schritt eine Sache, die eine eigene Position wäre — Bauzaun, Gerüst,
//  Toilette — und die im ganzen LV nicht vorkommt, dann wurde sie nicht verkauft.
//
//  🔴 Das ist eine TATSACHE, kein Urteil: „kommt im LV nicht vor" heisst nicht
//  „falsch". Es kann gut sein, dass der Bauzaun über einen Pauschalposten läuft oder
//  vom Bauherrn gestellt wird. Deshalb wird der Schritt nur ABGEWÄHLT vorgeschlagen,
//  nicht entfernt — ein Griff, und er ist wieder drin.
//

import Foundation
import CoreData

enum SchrittPassung {

    /// Dinge, die auf einer Baustelle eine eigene Position hätten — und die man auf
    /// einer kleinen schlicht nicht braucht. Jeweils: Anzeigename → Wortstämme.
    ///
    /// Bewusst kurz gehalten. Jeder Eintrag hier kann einen Schritt abwählen, also
    /// gehört nur herein, was WIRKLICH immer eine eigene Position ist. Im Zweifel
    /// lieber nicht aufnehmen — ein übersehener Bauzaun kostet einen Klick, ein
    /// falsch abgewählter Arbeitsschritt kostet Vertrauen.
    static let eigenePosition: [(name: String, stamm: [String])] = [
        ("Bauzaun",            ["bauzaun", "bauzäun"]),
        ("Baustellentoilette", ["dixi", "toilette", "wc-", "baustellen-wc"]),
        ("Gerüst",             ["gerüst", "geruest"]),
        ("Baustrom",           ["baustrom", "stromanschluss", "baustellenstrom"]),
        ("Bauwasser",          ["bauwasser", "wasseranschluss"]),
        ("Container",          ["container", "mulde"]),
        ("Kran",               ["kran"]),
        ("Bauschild",          ["bauschild", "bautafel"]),
        ("Schnurgerüst",       ["schnurgerüst", "schnurgeruest"]),
        ("Bauwagen",           ["bauwagen", "baubüro", "buero-container"]),
        ("Absperrung",         ["absperr", "verkehrssicherung", "beschilderung"]),
    ]

    /// Alle Wörter, die im LV dieser Baustelle vorkommen — einmal gesammelt,
    /// damit nicht je Schritt neu gesucht wird.
    @MainActor
    static func lvWortschatz(_ event: Event?) -> String {
        guard let event, let positionen = event.lvPositionen as? Set<LVPosition> else { return "" }
        return positionen
            .map { [$0.bezeichnung, $0.langtext, $0.posNr].compactMap { $0 }.joined(separator: " ") }
            .joined(separator: " ")
            .lowercased()
    }

    /// Nennt dieser Schritt etwas, das im LV nicht vorkommt? Dann den Namen zurück.
    ///
    /// Beide Seiten werden geprüft: das Wort muss im SCHRITT stehen und darf im LV
    /// nicht stehen. Steht es in keinem von beiden, ist nichts zu melden.
    static func fehltImLV(_ schritt: String, lvWortschatz: String) -> String? {
        guard !lvWortschatz.isEmpty else { return nil }   // ohne LV kein Urteil
        let text = schritt.lowercased()
        for eintrag in eigenePosition {
            let imSchritt = eintrag.stamm.contains { text.contains($0) }
            guard imSchritt else { continue }
            let imLV = eintrag.stamm.contains { lvWortschatz.contains($0) }
            if !imLV { return eintrag.name }
        }
        return nil
    }

    /// Bequem für die Ansicht: prüft eine ganze Liste auf einmal.
    @MainActor
    static func fehlende(in schritte: [AnweisungsSchritt], auftrag: Auftrag) -> [String: String] {
        let wortschatz = lvWortschatz(auftrag.event)
        var treffer: [String: String] = [:]
        for s in schritte {
            if let name = fehltImLV(s.text, lvWortschatz: wortschatz) {
                treffer[s.id] = name
            }
        }
        return treffer
    }
}
