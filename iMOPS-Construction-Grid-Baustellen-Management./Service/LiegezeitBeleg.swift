//
//  LiegezeitBeleg.swift
//
//  Woher kommt die Zahl?
//
//  Andreas, 21.09.2026 spät: „das ist eine Stelle, wo wir aufpassen müssen. Wenn auf
//  dem Zement steht, er braucht 2 Tage, dann braucht er 2 Tage. Wenn der Chef anders
//  entscheidet, dann muss das doch dokumentiert werden. Der Mops schreibt ja nicht
//  umsonst 2 Tage."
//
//  🔴 Damit dreht sich die Richtung. Der erste Entwurf hielt den Mops-Katalog für
//  das Maß und die eingetragene Zahl für den Verdachtsfall. Falsch herum: steht auf
//  dem Sack 2 Tage, dann sind 2 Tage richtig — und der Katalogwert ist bloss ein
//  Richtwert für den Fall, dass niemand nachgesehen hat.
//
//  Was fehlte, ist nicht eine bessere Zahl, sondern **die Herkunft der Zahl**.
//  Gemessen: `Voraussetzung` trägt `wartezeitTage` nackt — kein Feld sagt, ob die
//  2 Tage vom Datenblatt kommen, vom Statiker, aus dem Katalog oder aus dem Bauch.
//
//  Die Regel, die daraus folgt:
//  · Gibt es einen BELEG (Datenblatt, Statiker), gilt er. Der Katalog schweigt.
//  · Geht jemand UNTER einen Beleg, ist das eine Entscheidung — mit Namen, Grund
//    und Datum. Das ist der Fall, den Andreas meint.
//  · Ohne Beleg bleibt der Katalog ein Vorschlag, mehr nicht.
//
//  Wie AnweisungsKatalog und SonderfallBuch: JSON in Documents, kein Core Data,
//  keine Migration — gekeyt auf die Kennung der Kante.
//

import Foundation
import os

// MARK: - Woher die Zahl kommt

enum LiegezeitHerkunft: String, Codable, CaseIterable, Sendable {
    case datenblatt   // steht auf dem Sack / im technischen Merkblatt
    case statiker     // vom Statiker vorgegeben
    case erfahrung    // jemand weiss es aus der Praxis, mit Namen
    case katalog      // Richtwert des Mops — ein Vorschlag
    case entschieden  // 🔴 jemand ist UNTER einen Beleg gegangen

    var kurz: String {
        switch self {
        case .datenblatt:  return "laut Datenblatt"
        case .statiker:    return "vom Statiker"
        case .erfahrung:   return "aus Erfahrung"
        case .katalog:     return "Richtwert des Mops"
        case .entschieden: return "so entschieden"
        }
    }

    /// Belegt heisst: da hat jemand nachgesehen, nicht geschätzt.
    /// Ein Beleg schlägt jeden Richtwert — auch den aus dem eigenen Katalog.
    var istBelegt: Bool { self == .datenblatt || self == .statiker }

    /// Braucht es einen Namen dazu? Bei allem, was nicht einfach abgelesen ist.
    var brauchtNamen: Bool { self != .katalog }
}

struct LiegezeitBeleg: Codable, Identifiable, Equatable, Sendable {
    var id: String              // die Kennung der Voraussetzungs-Kante
    var tage: Double
    var herkunft: LiegezeitHerkunft
    /// Der Beleg selbst — „CEM I 42,5 R, Merkblatt S. 2" oder „Statik Pos. 4.3".
    var quelle: String = ""
    var von: String = ""
    var am: Date = Date()

    /// 🔴 Nur gesetzt, wenn jemand unter einen Beleg gegangen ist: was galt vorher.
    var stattBelegTage: Double?
    var begruendung: String = ""

    var istUnterschreitung: Bool { stattBelegTage != nil }
}

// MARK: - Das Buch

final class LiegezeitBuch {

    static let shared = LiegezeitBuch()
    private let logger = Logger(subsystem: "io.imops", category: "Liegezeit")

    private var belege: [String: LiegezeitBeleg] = [:]
    private let datei: URL

    private init() {
        let ordner = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        datei = ordner.appendingPathComponent("liegezeiten.json")
        laden()
    }

    func beleg(fuer kanteID: String) -> LiegezeitBeleg? { belege[kanteID] }

    func merken(_ b: LiegezeitBeleg) {
        belege[b.id] = b
        sichern()
        if b.istUnterschreitung {
            logger.info("Liegezeit unterschritten: \(b.tage) statt \(b.stattBelegTage ?? 0) Tage, \(b.von, privacy: .public)")
        }
    }

    func vergessen(_ kanteID: String) {
        belege.removeValue(forKey: kanteID)
        sichern()
    }

    /// Alle Unterschreitungen — das ist die Liste, die man im Streitfall braucht.
    var unterschreitungen: [LiegezeitBeleg] {
        belege.values.filter(\.istUnterschreitung).sorted { $0.am > $1.am }
    }

    var alle: [LiegezeitBeleg] { belege.values.sorted { $0.am > $1.am } }

    // MARK: Datei

    private func laden() {
        guard let data = try? Data(contentsOf: datei) else { return }
        let liste = (try? JSONDecoder().decode([LiegezeitBeleg].self, from: data)) ?? []
        belege = Dictionary(liste.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    private func sichern() {
        do {
            let data = try JSONEncoder().encode(Array(belege.values))
            try data.write(to: datei, options: .atomic)
        } catch {
            logger.error("Liegezeiten nicht gesichert: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Für Tests.
    func leeren() {
        belege = [:]
        try? FileManager.default.removeItem(at: datei)
    }
}

// MARK: - Was jetzt zu sagen ist

extension LiegezeitBuch {

    /// Die eine Frage, die der Mops an einer Kante beantworten muss.
    enum Lage: Equatable {
        /// Alles gut: die Zahl ist belegt und wird eingehalten.
        case belegtUndEingehalten(LiegezeitBeleg)
        /// 🔴 Jemand ist unter einen Beleg gegangen — dokumentiert.
        case unterschritten(LiegezeitBeleg)
        /// 🔴 Die Zahl ist kürzer als der Beleg, aber NICHTS steht dazu.
        case unterschrittenOhneGrund(beleg: LiegezeitBeleg, jetzt: Double)
        /// Kein Beleg da — der Katalog schlägt etwas vor, mehr nicht.
        case nurRichtwert(WartezeitKatalog.ZuKurz)
        /// Nichts zu sagen.
        case still
    }

    /// 🔴 Ein BELEG schlägt den Katalog. Steht auf dem Sack 2 Tage, sagt der Mops
    /// nicht mehr „bei mir stehen 3" — dann gelten 2, und er schweigt.
    func lage(kanteID: String, eingetragen: Double, nachVorgaenger: String) -> Lage {
        if let b = beleg(fuer: kanteID) {
            if b.istUnterschreitung { return .unterschritten(b) }
            if b.herkunft.istBelegt {
                if eingetragen < b.tage {
                    return .unterschrittenOhneGrund(beleg: b, jetzt: eingetragen)
                }
                return .belegtUndEingehalten(b)
            }
        }
        if let z = WartezeitKatalog.pruefe(eingetragen: eingetragen, nach: nachVorgaenger) {
            return .nurRichtwert(z)
        }
        return .still
    }
}
