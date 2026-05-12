import Foundation
import Combine

struct LVFortschritt: Codable, Equatable {
    var prozent:  Int
    var bemerkung: String = ""
    var datum:    Date    = Date()
}

final class LVFortschrittStore: ObservableObject {
    static let shared = LVFortschrittStore()

    @Published private(set) var data: [String: LVFortschritt] = [:]

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("lv_fortschritt.json")
    }()

    private init() { load() }

    func fortschritt(for positionID: String) -> LVFortschritt? {
        data[positionID]
    }

    func setFortschritt(_ f: LVFortschritt, for positionID: String) {
        data[positionID] = f
        save()
    }

    func remove(for positionID: String) {
        data.removeValue(forKey: positionID)
        save()
    }

    private func load() {
        guard let d = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: LVFortschritt].self, from: d)
        else { return }
        data = decoded
    }

    private func save() {
        try? JSONEncoder().encode(data).write(to: fileURL)
    }
}
