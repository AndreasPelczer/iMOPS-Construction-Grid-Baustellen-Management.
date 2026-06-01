// ============================================================
//  KernelArbeitsschritt.swift
//  iMOPS Construction Grid
//
//  Spike: Kopiert aus iMOPS_OS_CORE (Sonntag 31.05.2026).
//  Typsicheres Task-Modell als Brücke zwischen TheBrain ([String: Any])
//  und der typisierten Swift-Welt.
//
//  Hinweis: Für die Spike-Phase ist das eine 1:1-Kopie des Originals.
//  Spätere Iteration: ggf. Construction-spezifische Felder ergänzen
//  (z.B. baustellenID, gewerk) ODER iMOPS_OS_CORE als SPM-Package
//  einbinden statt copy-in.
// ============================================================

import Foundation

// MARK: - ArbeitsschrittStatus

/// Der Lebenszyklus eines Arbeitsschritts.
/// Vier Stufen, klar definiert, nicht verhandelbar.
enum ArbeitsschrittStatus: String, Codable, CaseIterable {
    /// Neu erstellt, wartet auf Bearbeitung
    case offen
    /// Wird gerade bearbeitet (Posten hat uebernommen)
    case inArbeit
    /// Fertig gemeldet, bereit fuer Archivierung
    case erledigt
    /// Vom Commander abgenommen, HACCP-versiegelt
    case abgenommen

    /// Mapping von TheBrain-Storage-Strings auf den Enum
    /// "OPEN" ist das Legacy-Format aus dem MUMPS-Storage
    init(fromStorage value: String) {
        switch value.uppercased() {
        case "OPEN":        self = .offen
        case "IN_ARBEIT":   self = .inArbeit
        case "ERLEDIGT":    self = .erledigt
        case "ABGENOMMEN":  self = .abgenommen
        default:            self = .offen
        }
    }

    /// Zurueck in den Storage-String fuer TheBrain
    var storageValue: String {
        switch self {
        case .offen:       return "OPEN"
        case .inArbeit:    return "IN_ARBEIT"
        case .erledigt:    return "ERLEDIGT"
        case .abgenommen:  return "ABGENOMMEN"
        }
    }

    /// Zaehlt dieser Status als "aktive Last" fuer die Pelczer-Matrix?
    var isActiveLoad: Bool {
        self == .offen || self == .inArbeit
    }

    /// Ist dieser Schritt abgeschlossen?
    var isCompleted: Bool {
        self == .erledigt || self == .abgenommen
    }
}

// MARK: - KernelArbeitsschritt

/// Ein typisierter Arbeitsschritt im iMOPS-Kernel.
/// Materialisiert aus dem TheBrain-Storage, typsicher und testbar.
struct KernelArbeitsschritt: Identifiable, Codable, Equatable {

    /// Eindeutige ID (z.B. "001", "STRESS_3")
    let id: String

    /// Titel des Arbeitsschritts
    let title: String

    /// Kognitive Last (Standard: 10)
    let weight: Int

    /// Erstellungszeitpunkt (Unix Timestamp)
    let created: Double

    /// Aktueller Status im Lebenszyklus
    var status: ArbeitsschrittStatus

    /// Medizinische/HACCP-Pins (optional)
    var pinsMedical: String?

    /// SOP-Referenz (optional)
    var pinsSOP: String?

    // MARK: - Factory: Aus TheBrain-Storage materialisieren

    /// Liest einen Arbeitsschritt aus dem TheBrain-Storage.
    /// Gibt nil zurueck wenn die Mindestdaten (TITLE, STATUS) fehlen.
    static func fromStorage(id: String, storage: [String: Any]) -> KernelArbeitsschritt? {
        guard let title = storage["^TASK.\(id).TITLE"] as? String,
              let statusRaw = storage["^TASK.\(id).STATUS"] as? String
        else { return nil }

        return KernelArbeitsschritt(
            id: id,
            title: title,
            weight: storage["^TASK.\(id).WEIGHT"] as? Int ?? 10,
            created: storage["^TASK.\(id).CREATED"] as? Double ?? Date().timeIntervalSince1970,
            status: ArbeitsschrittStatus(fromStorage: statusRaw),
            pinsMedical: storage["^TASK.\(id).PINS.MEDICAL"] as? String,
            pinsSOP: storage["^TASK.\(id).PINS.SOP"] as? String
        )
    }
}
