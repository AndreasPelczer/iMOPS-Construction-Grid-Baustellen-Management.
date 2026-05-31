import Foundation
import Yams
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "ExactMatchKnowledge")

// MARK: - KnowledgeEntry
// Ein einzelner Eintrag aus den YAMLs in Resources/Knowledge/.

struct KnowledgeEntry: Codable, Sendable, Identifiable {
    let id: String
    let aliases: [String]
    let antwort: String
    let quelleKurz: String
    let quelleUrl: String?
    let licenseNote: String?

    enum CodingKeys: String, CodingKey {
        case id, aliases, antwort
        case quelleKurz = "quelle_kurz"
        case quelleUrl = "quelle_url"
        case licenseNote = "license_note"
    }
}

// MARK: - ExactMatchKnowledge
// Lokale Wissensbasis fuer haeufige Bau-Fachfragen.
// Schema: siehe Resources/Knowledge/README.md
//
// Verwendung:
//   if let hit = await ExactMatchKnowledge.shared.lookup("Was ist DIN 276?") {
//       // hit.antwort, hit.quelleKurz verwenden
//   }
//
// Performance: erste lookup() laedt alle YAMLs (~ein paar ms),
// danach sub-Millisekunden-Lookup.

actor ExactMatchKnowledge {
    static let shared = ExactMatchKnowledge()

    private var entries: [KnowledgeEntry] = []
    private var loaded = false

    // Die Liste der YAML-Files muss hier gepflegt werden, weil iOS-Bundle
    // kein Verzeichnis-Listing erlaubt (nur explizite Resource-Lookups).
    private let yamlNames = [
        "din_normen",
        "betongueten",
        "wlg_werte",
        "moertelgruppen",
    ]

    private init() {}

    /// Sucht nach dem laengsten passenden Alias in der Frage.
    /// Case-insensitive. Erste lookup() triggert lazy load aller YAMLs.
    func lookup(_ question: String) -> KnowledgeEntry? {
        if !loaded {
            loadAll()
            loaded = true
        }

        let needle = question.lowercased()
        var bestMatch: (length: Int, entry: KnowledgeEntry)? = nil

        for entry in entries {
            for alias in entry.aliases {
                let aliasLower = alias.lowercased()
                guard needle.contains(aliasLower) else { continue }
                if bestMatch == nil || aliasLower.count > bestMatch!.length {
                    bestMatch = (aliasLower.count, entry)
                }
            }
        }
        return bestMatch?.entry
    }

    /// Kompletter Reload — fuer Tests oder bei dynamischer YAML-Aenderung.
    func reload() {
        entries = []
        loaded = false
    }

    /// Anzahl geladener Eintraege (fuer Diagnose).
    func entryCount() -> Int {
        if !loaded {
            loadAll()
            loaded = true
        }
        return entries.count
    }

    // MARK: - Loading

    private func loadAll() {
        let decoder = YAMLDecoder()
        var allEntries: [KnowledgeEntry] = []

        for name in yamlNames {
            guard let url = locateYAML(name: name) else {
                logger.warning("YAML not found in bundle: \(name).yaml")
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                let yaml = String(data: data, encoding: .utf8) ?? ""
                let parsed = try decoder.decode([KnowledgeEntry].self, from: yaml)
                allEntries.append(contentsOf: parsed)
                logger.info("Loaded \(parsed.count) entries from \(name).yaml")
            } catch {
                logger.error("Failed to parse \(name).yaml: \(error.localizedDescription)")
            }
        }

        entries = allEntries
        logger.info("Total entries loaded: \(allEntries.count)")
    }

    /// Sucht die YAML im Bundle — zuerst im Knowledge-Subdirectory,
    /// dann im Root falls als Group statt Folder-Reference eingebunden.
    private func locateYAML(name: String) -> URL? {
        let bundle = Bundle.main
        if let url = bundle.url(forResource: name, withExtension: "yaml", subdirectory: "Knowledge") {
            return url
        }
        if let url = bundle.url(forResource: name, withExtension: "yaml") {
            return url
        }
        return nil
    }
}
