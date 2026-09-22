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

// MARK: - 🔴 Die Gegenrichtung: was im LV steht, wofür es keinen Schritt gibt

extension SchrittPassung {

    /// Andreas, 22.09.2026, vor „411 Abwasser-, Wasser-, Gasanlagen":
    /// „Sind im oberen Bereich die ganzen Anforderungen mit den Arbeitsschritten
    ///  passend? Passt oben und unten zusammen?"
    ///
    /// Sie passten nicht. Oben standen ein Schmutzwasser-Hausanschluss in 2,60 m
    /// Tiefe, 30 m Grundleitungen und vier Kontrollschächte; unten acht Schritte aus
    /// der Vorlage „Sanitär & Heizung" — Wandschlitze, Dämmung, Sanitärobjekte
    /// montieren. Reine Innenmontage. Für den Graben stand kein Wort da.
    ///
    /// Die bisherige Prüfung schaute nur in eine Richtung (nennt ein Schritt etwas,
    /// das im LV fehlt — Bauzaun). Diese hier schaut zurück: **steht im LV etwas,
    /// wofür niemand einen Handgriff aufgeschrieben hat?**
    ///
    /// 🔴 Absichtlich zurückhaltend: gemeldet wird nur, wenn KEIN Schritt auch nur
    /// den Kernbegriff der Position trägt. Lieber ein übersehener Hinweis als eine
    /// Liste, die bei jeder Position meckert — ein Zustand, der immer rot ist, ist
    /// Rauschen.
    struct OhneSchritt: Identifiable, Equatable {
        var id: String { posNr }
        let posNr: String
        let bezeichnung: String
        let menge: String
        /// Das Wort, an dem es hängt — damit man sieht, wonach gesucht wurde.
        let kern: String
    }

    /// Wörter, die überall vorkommen und deshalb nichts beweisen.
    private static let fuellwoerter: Set<String> = [
        "und", "oder", "mit", "ohne", "für", "fuer", "von", "bis", "der", "die", "das",
        "den", "dem", "des", "aus", "auf", "nach", "vor", "bei", "inkl", "incl", "je",
        "einschl", "gemäß", "gemaess", "laut", "ca", "rd", "pro", "als", "zur", "zum",
        "liefern", "herstellen", "einbauen", "stellen", "setzen", "arbeiten",
    ]

    /// Die tragenden Wörter einer Positionsbezeichnung — lang genug, um etwas zu
    /// bedeuten, und keine Füllsel. Zusammensetzungen werden aufgetrennt:
    /// „Schmutzwasser-Hausanschluss" gibt „schmutzwasser" UND „hausanschluss".
    /// 🔴 ä und ae sind dasselbe Wort. „Sanitärinstallation" im LV gegen
    /// „Sanitaerobjekte montieren" im Schritt — ohne das hier hätte der Mops zwei
    /// Positionen gemeldet, die längst abgedeckt sind. Derselbe Fehler wie gestern
    /// in der Anleitungs-Suche.
    static func flach(_ text: String) -> String {
        var t = text.lowercased()
        for (a, b) in [("ä","a"), ("ö","o"), ("ü","u"), ("ß","ss"),
                       ("ae","a"), ("oe","o"), ("ue","u")] {
            t = t.replacingOccurrences(of: a, with: b)
        }
        return t
    }

    static func kernbegriffe(_ text: String) -> [String] {
        flach(text)
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 5 && !fuellwoerter.contains($0) && !$0.allSatisfy(\.isNumber) }
    }

    /// Deckt irgendein Schritt diese Position ab?
    ///
    /// Ein Treffer reicht, und er zählt auch bei Wortstamm-Nähe: „Grundleitungen"
    /// gilt als abgedeckt, wenn ein Schritt „Leitungen verlegen" heisst. Das ist
    /// bewusst grosszügig — im Zweifel schweigt der Mops.
    static func abgedeckt(_ position: LVPosition, von schritten: [String]) -> Bool {
        let kerne = kernbegriffe(position.bezeichnung ?? "")
        guard !kerne.isEmpty else { return true }        // ohne Text kein Urteil
        let schritttext = flach(schritten.joined(separator: " "))
        guard !schritttext.isEmpty else { return false }

        return kerne.contains { kern in
            if schritttext.contains(kern) { return true }
            // Wortstamm: die ersten sechs Zeichen reichen für „leitung(en)",
            // „montage/montieren", „prüfung/prüfen".
            let stamm = String(kern.prefix(6))
            return stamm.count >= 5 && schritttext.contains(stamm)
        }
    }

    /// Alle Positionen eines Auftrags, für die kein Schritt existiert.
    @MainActor
    static func ohneSchritt(auftrag: Auftrag, schritte: [String]) -> [OhneSchritt] {
        Arbeitspakete.positionen(fuer: auftrag)
            .filter { !abgedeckt($0, von: schritte) }
            .map { p in
                let menge = p.menge == p.menge.rounded()
                    ? String(format: "%.0f", p.menge)
                    : String(format: "%.2f", p.menge)
                return OhneSchritt(
                    posNr: p.posNr ?? "—",
                    bezeichnung: p.bezeichnung ?? "ohne Text",
                    menge: "\(menge) \(p.einheit ?? "")".trimmingCharacters(in: .whitespaces),
                    kern: kernbegriffe(p.bezeichnung ?? "").first ?? "")
            }
    }
}
