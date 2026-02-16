//
//  RCAStore.swift
//  test25B
//
//  RCA = Remote Chef Annotation
//  Speichert Foto-Annotationen (Bild + Text + Event-Zuordnung)
//  Bilder: Documents/RCA/*.jpg
//  Metadaten: Documents/RCA/rca_index.json
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Datenmodell

struct RCAEntry: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var eventObjectIDURI: String?   // Event-Zuordnung (optional)
    var eventTitle: String = ""
    var note: String = ""           // Annotation-Text
    var timestamp: Date = Date()
    var imageFilename: String       // "rca_<uuid>.jpg"
    var tags: [String] = []         // z.B. ["HACCP", "Temperatur", "Hygiene"]
}

// MARK: - RCA Store (Filesystem-basiert)

@Observable
final class RCAStore {
    static let shared = RCAStore()

    private(set) var entries: [RCAEntry] = []

    private let rcaDir: URL
    private let indexURL: URL

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        rcaDir = docs.appendingPathComponent("RCA", isDirectory: true)
        indexURL = rcaDir.appendingPathComponent("rca_index.json")

        // Ordner erstellen falls nötig
        try? FileManager.default.createDirectory(at: rcaDir, withIntermediateDirectories: true)
        loadIndex()
    }

    // MARK: - CRUD

    func addEntry(image: UIImage, note: String, tags: [String], event: Event?) -> RCAEntry {
        let filename = "rca_\(UUID().uuidString).jpg"
        let fileURL = rcaDir.appendingPathComponent(filename)

        // Bild speichern (JPEG, 80% Qualität)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }

        var entry = RCAEntry(
            note: note,
            imageFilename: filename,
            tags: tags
        )

        if let event = event {
            entry.eventObjectIDURI = event.objectID.uriRepresentation().absoluteString
            entry.eventTitle = event.title ?? "Event"
        }

        entries.insert(entry, at: 0)
        saveIndex()
        return entry
    }

    func updateNote(_ entryID: String, newNote: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[idx].note = newNote
        saveIndex()
    }

    func deleteEntry(_ entryID: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let filename = entries[idx].imageFilename
        let fileURL = rcaDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
        entries.remove(at: idx)
        saveIndex()
    }

    // MARK: - Bild laden

    func imageFor(_ entry: RCAEntry) -> UIImage? {
        let fileURL = rcaDir.appendingPathComponent(entry.imageFilename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Persistence (JSON)

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        entries = (try? JSONDecoder().decode([RCAEntry].self, from: data)) ?? []
    }

    private func saveIndex() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Filter

    func entriesForEvent(_ event: Event) -> [RCAEntry] {
        let uri = event.objectID.uriRepresentation().absoluteString
        return entries.filter { $0.eventObjectIDURI == uri }
    }

    var entriesWithoutEvent: [RCAEntry] {
        entries.filter { $0.eventObjectIDURI == nil }
    }
}
