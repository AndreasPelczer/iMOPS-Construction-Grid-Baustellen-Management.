//
//  AnweisungsKatalog.swift
//
//  „Wer eine Anweisung einmal schreibt, schreibt sie für alle."
//
//  Das Prinzip steht im Mops schon für Rezepte — `Leistungsbaustein` trägt den Satz
//  „einmal fragen → für immer im Katalog" und hat 1.153 Einträge. Hier dasselbe für
//  die Arbeitsschritte: sie hängen am LEISTUNGSTEXT, nicht am einzelnen Auftrag.
//
//  Paolo schreibt die Schritte für „Kimmschicht Ytong 24 cm" einmal — mit seinem Namen
//  dran. Beim nächsten Haus, in drei Jahren, auf einer anderen Baustelle: der Mops
//  schlägt sie vor. Geprüft, von einem Menschen, der es kann.
//
//  Andreas' Rechnung dazu: „Nach zwanzig Baustellen hast du die achtzig Prozent, die
//  wirklich vorkommen. Nicht tausende erfundene, sondern zweihundert echte."
//
//  Absichtlich KEIN Core Data: eine JSON-Datei neben `AngebotsStore` und `LagerStore`.
//  Kein Modell-Umbau, keine Migration — und der Katalog lässt sich später als eine
//  Datei an Raphi geben.
//

import Foundation
import os

final class AnweisungsKatalog {

    static let shared = AnweisungsKatalog()
    private let logger = Logger(subsystem: "io.imops", category: "Anweisungen")

    private struct Eintrag: Codable {
        var schritte: [AnweisungsSchritt]
        var zuletzt: Date
        var verwendungen: Int
    }

    private var eintraege: [String: Eintrag] = [:]
    private let datei: URL

    private init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        datei = ordner.appendingPathComponent("anweisungen.json")
        laden()
    }

    // MARK: - Schlüssel

    /// Der Leistungstext, auf das Wesentliche gebracht: klein, ohne Mengen und
    /// Sonderzeichen. „Kimmschicht Ytong 24 cm, 2 Lagen" und „KIMMSCHICHT YTONG 24CM"
    /// sollen denselben Eintrag finden.
    static func schluessel(_ leistung: String) -> String {
        // 🔴 Erster Versuch war inkonsequent: „24 cm" fiel ganz weg (Zahl + zu kurzes
        //    Wort), „24cm" blieb als „24cm" stehen — derselbe Text, zwei Schlüssel.
        //    Jetzt werden Ziffern ZUERST aus jedem Wort gezogen, dann gefiltert.
        let ohneSonderzeichen = leistung.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N} ]"#, with: " ", options: .regularExpression)
        let worte = ohneSonderzeichen.split(separator: " ")
            .map { $0.filter { !$0.isNumber } }      // „24cm" -> „cm", „24" -> „"
            .filter { $0.count > 2 }                  // Einheiten und Füllsel raus
            .prefix(5)
        return worte.joined(separator: " ")
    }

    // MARK: - Lesen und Schreiben

    /// Gibt es zu dieser Leistung schon eine Anweisung?
    func schritte(fuer leistung: String) -> [AnweisungsSchritt]? {
        let k = Self.schluessel(leistung)
        guard !k.isEmpty, let e = eintraege[k], !e.schritte.isEmpty else { return nil }
        return e.schritte.map { s in
            var kopie = s
            kopie.id = UUID().uuidString     // eigene Kennung je Auftrag
            kopie.herkunft = .katalog
            return kopie
        }
    }

    /// Merkt sich die Anweisung. Nur ABGENOMMENE Schritte wandern in den Katalog —
    /// ein ungeprüfter Vorschlag soll sich nicht selbst vermehren.
    @discardableResult
    func merken(_ schritte: [AnweisungsSchritt], fuer leistung: String) -> Int {
        let k = Self.schluessel(leistung)
        guard !k.isEmpty else { return 0 }
        let abgenommen = schritte.filter { !$0.herkunft.brauchtAbnahme || $0.istAbgenommen }
        guard !abgenommen.isEmpty else { return 0 }

        let bisher = eintraege[k]?.verwendungen ?? 0
        eintraege[k] = Eintrag(schritte: abgenommen, zuletzt: Date(), verwendungen: bisher + 1)
        sichern()
        logger.info("Anweisung gemerkt: \(k, privacy: .public) — \(abgenommen.count) Schritte")
        return abgenommen.count
    }

    func vergessen(_ leistung: String) {
        eintraege.removeValue(forKey: Self.schluessel(leistung))
        sichern()
    }

    var anzahl: Int { eintraege.count }

    /// Für den Ankunfts-Nachweis: was steht wirklich drin?
    func bestand() -> [(leistung: String, schritte: Int, verwendungen: Int)] {
        eintraege.map { ($0.key, $0.value.schritte.count, $0.value.verwendungen) }
            .sorted { $0.verwendungen > $1.verwendungen }
    }

    // MARK: - Platte

    private func laden() {
        guard let daten = try? Data(contentsOf: datei) else { return }
        eintraege = (try? JSONDecoder().decode([String: Eintrag].self, from: daten)) ?? [:]
    }

    private func sichern() {
        guard let daten = try? JSONEncoder().encode(eintraege) else { return }
        try? daten.write(to: datei, options: .atomic)
    }

    /// Nur für Tests: Katalog leeren, ohne die Datei zu behalten.
    func leerenFuerTests() {
        eintraege = [:]
        sichern()
    }
}
