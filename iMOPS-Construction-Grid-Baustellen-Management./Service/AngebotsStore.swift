import Foundation
import Combine

// MARK: - Model

struct Angebot: Codable, Equatable {
    var lieferant: String
    var einzelpreis: Double
    var notiz: String = ""
    var datum: Date = Date()
}

// MARK: - Store

/// Persists supplier price offers outside CoreData using a JSON file in the Documents directory.
/// Keyed by LVPosition objectID URI string → [Lieferant: Angebot]
final class AngebotsStore: ObservableObject {
    static let shared = AngebotsStore()

    @Published private(set) var data: [String: [String: Angebot]] = [:]

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("angebote.json")
    }()

    private init() { load() }

    // MARK: - Read

    func angebote(for positionID: String) -> [Angebot] {
        (data[positionID] ?? [:]).values.sorted { $0.lieferant < $1.lieferant }
    }

    func guenstigster(for positionID: String) -> Angebot? {
        angebote(for: positionID).min { $0.einzelpreis < $1.einzelpreis }
    }

    // MARK: - Write

    func upsert(_ angebot: Angebot, for positionID: String) {
        data[positionID, default: [:]][angebot.lieferant] = angebot
        save()
    }

    func remove(lieferant: String, for positionID: String) {
        data[positionID]?[lieferant] = nil
        if data[positionID]?.isEmpty == true { data.removeValue(forKey: positionID) }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: [String: Angebot]].self, from: raw) else { return }
        data = decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
