//
//  TrennlinienKatalog.swift
//
//  Woran man erkennt, dass in einem Kostentitel zwei Arbeiten stecken.
//
//  Andreas, 22.09.2026: „Wenn du etwas baust, dann ist das doch allgemeingültig oder
//  nur für diesen Fall und diese Baustelle? Das sollte nie passieren."
//
//  Der erste Wurf kannte eine einzige Trennlinie — Erdreich gegen Bauwerk, genau die,
//  die sein Fall brauchte. Ein Werkzeug, das nur den einen Fall kann, ist keins.
//

import Foundation
import Yams
import os

struct Trennlinie: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let begruendung: String
    /// Wortstämme, umlaut-flach geschrieben (siehe `SchrittPassung.flach`).
    let stamm: [String]
}

enum TrennlinienKatalog {

    private static let logger = Logger(subsystem: "io.imops", category: "Trennlinien")

    static let alle: [Trennlinie] = {
        guard let url = Bundle.main.url(forResource: "trennlinien", withExtension: "yaml"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            logger.error("trennlinien.yaml nicht gefunden")
            return []
        }
        do {
            return try YAMLDecoder().decode([Trennlinie].self, from: text)
        } catch {
            logger.error("trennlinien.yaml nicht lesbar: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }()
}
