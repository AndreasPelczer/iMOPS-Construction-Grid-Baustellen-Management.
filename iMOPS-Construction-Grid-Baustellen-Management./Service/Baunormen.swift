//
//  Baunormen.swift
//  Die „Normen-Spur": welche DIN eine Leistung BERÜHRT — ambient, als Nachweis,
//  dass nach Norm gearbeitet wird.
//
//  WICHTIG — die ehrliche Grenze: „berührt" heißt NICHT „erfüllt". Die Spur zeigt,
//  welche Norm für eine Leistung einschlägig ist, damit der Nutzer sieht, ob er
//  daran gedacht hat. Ob die Ausführung die Norm einhält, kann nur der Mensch auf
//  dem Bau beurteilen. Keine Rechtsberatung.
//
//  Die Norm-Fakten (Kurzbeschreibung, Quelle) liegen ausführlich in
//  Resources/Knowledge/din_normen.yaml (Exact-Match-Wissen, kein Norm-Volltext —
//  Beuth-lizenziert). Hier steht nur, was die Spur zum Anzeigen und Zuordnen braucht.
//

import Foundation

/// Eine Bau-Norm, wie die Spur sie zeigt.
struct Baunorm: Identifiable, Hashable {
    let id: String          // Anzeigename = YAML-Alias, z. B. "DIN 18318"
    let was: String         // Kurz: was sie regelt
    let quelleKurz: String  // Fundstelle (ohne Volltext)
    /// Stichwörter, bei denen diese Norm eine Leistung berührt (lowercase, Teilstring).
    let keywords: [String]
    /// Gilt immer, sobald ein LV existiert (z. B. DIN 276 für die Kostengliederung).
    var immerBeiLV: Bool = false
}

enum Baunormen {

    /// Der Katalog. Reihenfolge = Anzeige-Reihenfolge (Bauablauf: Kosten → Einrichtung
    /// → Erd → Unterbau → Pflaster). Generisch; die echten Fassungen prüft der Betrieb.
    static let alle: [Baunorm] = [
        Baunorm(id: "DIN 276", was: "Kosten im Bauwesen — Kostengruppen fürs LV",
                quelleKurz: "DIN 276:2018-12",
                keywords: ["kostengruppe", "kalkulation"], immerBeiLV: true),

        Baunorm(id: "DIN 18299", was: "Allgemeine Regelungen für Bauarbeiten (VOB/C)",
                quelleKurz: "DIN 18299 (VOB/C, ATV)",
                keywords: ["baustelleneinrichtung", "einricht", "absperr", "verkehrssicher", "absteck"]),

        Baunorm(id: "DIN 18300", was: "Erdarbeiten (VOB/C) — Aushub, Mutterboden, Planum",
                quelleKurz: "DIN 18300 (VOB/C, ATV)",
                keywords: ["erdarbeit", "aushub", "mutterboden", "abtragen", "erdaushub", "bodenaushub", "planum"]),

        Baunorm(id: "DIN 18315", was: "Oberbauschichten ohne Bindemittel (VOB/C)",
                quelleKurz: "DIN 18315 (VOB/C, ATV)",
                keywords: ["tragschicht", "schotter", "mineralgemisch", "frostschutz", "schottertragschicht"]),

        Baunorm(id: "DIN EN 13242", was: "Gesteinskörnungen für ungebundene Gemische",
                quelleKurz: "DIN EN 13242",
                keywords: ["schotter", "splitt", "gesteinskörnung", "gesteinskoernung", "körnung", "koernung", "mineralgemisch"]),

        Baunorm(id: "RStO 12", was: "Standardisierung des Oberbaus — Schichtdicken & Aufbau",
                quelleKurz: "RStO 12 (FGSV)",
                keywords: ["oberbau", "schichtdicke", "belastungsklasse", "rsto"]),

        Baunorm(id: "DIN 18318", was: "Pflasterdecken, Plattenbeläge & Einfassungen (VOB/C)",
                quelleKurz: "DIN 18318 (VOB/C, ATV)",
                keywords: ["pflaster", "bettung", "splittbett", "fuge", "randeinfassung", "einfassung", "bord", "tiefbord", "leistenstein", "plattenbelag"]),

        Baunorm(id: "DIN EN 1338", was: "Pflastersteine aus Beton — Maße & Anforderungen",
                quelleKurz: "DIN EN 1338",
                keywords: ["pflasterstein", "betonpflaster", "pflaster", "verbundstein"]),

        Baunorm(id: "DIN EN 1340", was: "Bordsteine aus Beton — Randeinfassung",
                quelleKurz: "DIN EN 1340",
                keywords: ["bordstein", "tiefbord", "randstein", "kantenstein", "leistenstein"]),
    ]

    /// Alle Normen, die von einer Menge Leistungstexte berührt werden.
    /// Dedupliziert (jede Norm höchstens einmal), in Katalog-Reihenfolge.
    /// - Parameter hatLV: true, wenn es überhaupt ein LV / Positionen gibt (für DIN 276).
    static func berührt(vonLeistungen texte: [String], hatLV: Bool) -> [Baunorm] {
        let heu = texte.map { $0.lowercased() }
        return alle.filter { norm in
            if norm.immerBeiLV && hatLV { return true }
            return heu.contains { text in
                norm.keywords.contains { text.contains($0) }
            }
        }
    }
}
