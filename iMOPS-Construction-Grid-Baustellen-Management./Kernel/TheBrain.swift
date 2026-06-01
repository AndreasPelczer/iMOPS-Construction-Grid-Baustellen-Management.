//
//  TheBrain.swift
//  iMOPS Construction Grid
//
//  Spike: Kopiert aus iMOPS_OS_CORE (Sonntag 31.05.2026, Kernel 1.1 Matrix Edition).
//  - Thread-safe Storage & Matrix Calculation
//  - Reaktive Meier-Score Überwachung
//  - Service-Fieberkurve (Score-Historie)
//  - Mensch-Meier-Formel & Fatigue-Vektor integriert
//
//  Architektur-Entscheidung (Andreas 01.06.2026):
//  - Variante 1c: Copy-In für Spike (statt SPM-Dependency)
//  - Variante 3b: Kernel als NEUE Wahrheit für neue Domänen
//    → Keine Synchronisation mit CoreData. TheBrain läuft parallel.
//

import Foundation
import Observation

/// Ein präziser Datenpunkt für die Service-Fieberkurve
struct MatrixPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let score: Int
}

/// ^iMOPS GLOBAL - Die unbestechliche Wahrheit (Kernel)
@available(iOS 17.0, *)
@Observable
final class TheBrain {
    static let shared = TheBrain()

    /// Der "Global Store" (MUMPS Global)
    private var storage: [String: Any] = [:]

    /// Der "Wachrüttler" für die UI-Synchronisation
    var archiveUpdateTrigger: Int = 0

    /// DIE PELCZER-MATRIX (Meier-Score)
    private(set) var meierScore: Int = 0

    /// DAS SERVICE-GEDÄCHTNIS
    var scoreHistory: [MatrixPoint] = []

    /// Kernel-Lock: Schützt den Store vor Race-Conditions.
    private let kernelQueue = DispatchQueue(label: "imops.kernel.queue", qos: .userInitiated)

    // MARK: - Matrix Engine (Internal)

    private func refreshMeierScore() {
        let allKeys = storage.keys

        // Alle offenen Tasks
        let activeTasks = allKeys.filter {
            $0.hasPrefix("^TASK.") &&
            $0.hasSuffix(".STATUS") &&
            (storage[$0] as? String == "OPEN")
        }

        var totalLoad = 0
        var oldestTimestamp: Double = Date().timeIntervalSince1970

        for key in activeTasks {
            let components = key.components(separatedBy: ".")
            if components.count >= 2 {
                let taskID = components[1]

                let weight = storage["^TASK.\(taskID).WEIGHT"] as? Int ?? 10
                totalLoad += weight

                let created = storage["^TASK.\(taskID).CREATED"] as? Double ?? Date().timeIntervalSince1970
                if created < oldestTimestamp { oldestTimestamp = created }
            }
        }

        // 1. Ermüdungs-Vektor
        let hoursOnClock = (Date().timeIntervalSince1970 - oldestTimestamp) / 3600
        let fatigueFactor = 1.0 + (hoursOnClock / 10.0)

        // 2. Kapazitäts-Check
        let staffCount = allKeys.filter { $0.hasPrefix("^BRIGADE.") && $0.hasSuffix(".NAME") }.count
        let systemCapacity = Double(max(staffCount, 1) * 20)

        // 3. Pelczer-Matrix
        var finalLoad = (Double(totalLoad) / systemCapacity) * fatigueFactor * 100

        // 4. BOURDAIN-GUARD
        let shiftStart = storage["^SYS.SHIFT_START"] as? Date ?? Date()
        let taskValidation = BourdainGuard.validateTaskAction(startTime: shiftStart)
        switch BourdainGuard.checkWorkLifeBalance(startTime: shiftStart) {
        case .warning: finalLoad *= 1.15
        case .reset:   finalLoad *= 1.30
        case .fresh:   break
        }

        // 5. RIO-REISER-JITTER
        let normalizedLoad = min(max(finalLoad / 100.0, 0.0), 1.0)
        let noise = Double.random(in: -taskValidation.jitterStrength...taskValidation.jitterStrength)
        let jitteredLoad = min(max(normalizedLoad + noise, 0.0), 1.0) * 100.0

        let scoreResult = Int(min(max(jitteredLoad, 0), 100))

        // 6. WHISPER-MESSAGE
        if let whisper = taskValidation.whisper {
            print("iMOPS-BOURDAIN: \(whisper)")
        }

        DispatchQueue.main.async {
            self.meierScore = scoreResult

            let newPoint = MatrixPoint(timestamp: Date(), score: scoreResult)
            self.scoreHistory.append(newPoint)

            if self.scoreHistory.count > 50 {
                self.scoreHistory.removeFirst()
            }
        }
    }

    // MARK: - Kernel Safety

    private func validate(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        guard path.hasPrefix("^") else { return false }
        guard !path.contains(" ") else { return false }
        return true
    }

    // MARK: - Core Commands (SET / GET / KILL)

    /// Der S-Befehl (Set) - schreibt Daten und triggert Matrix-Berechnung.
    func set(_ path: String, _ value: Any) {
        guard validate(path) else {
            print("iMOPS-KERNEL-ERROR: Ungültiger Pfad (SET): \(path)")
            return
        }

        kernelQueue.sync {
            storage[path] = value
            refreshMeierScore()
        }
    }

    /// Der G-Befehl (Get) - typsicherer Zugriff.
    func get<T>(_ path: String) -> T? {
        guard validate(path) else {
            print("iMOPS-KERNEL-ERROR: Ungültiger Pfad (GET): \(path)")
            return nil
        }

        return kernelQueue.sync {
            storage[path] as? T
        }
    }

    /// Der KILL-Befehl - Einzel-Key löschen.
    func kill(_ path: String) {
        guard validate(path) else {
            print("iMOPS-KERNEL-ERROR: Ungültiger Pfad (KILL): \(path)")
            return
        }

        kernelQueue.sync {
            storage.removeValue(forKey: path)
            refreshMeierScore()
        }
    }

    /// KILL-TREE - löscht ganze Baumstrukturen.
    func killTree(prefix: String) {
        guard validate(prefix) else {
            print("iMOPS-KERNEL-ERROR: Ungültiger Prefix (KILLTREE): \(prefix)")
            return
        }

        kernelQueue.sync {
            let keysToRemove = storage.keys.filter { $0.hasPrefix(prefix) }
            for k in keysToRemove {
                storage.removeValue(forKey: k)
            }
            refreshMeierScore()
        }
    }

    // MARK: - Bridge: KernelArbeitsschritt

    /// Materialisiert alle aktiven Tasks als typisierte KernelArbeitsschritt-Objekte.
    func getArbeitsschritte() -> [KernelArbeitsschritt] {
        let snapshot: [String: Any] = kernelQueue.sync { storage }

        let taskIDs = Set(
            snapshot.keys
                .filter { $0.hasPrefix("^TASK.") }
                .compactMap { key -> String? in
                    let parts = key.components(separatedBy: ".")
                    return parts.count >= 2 ? parts[1] : nil
                }
        )

        return taskIDs.compactMap { id in
            KernelArbeitsschritt.fromStorage(id: id, storage: snapshot)
        }
    }

    // MARK: - Inventory

    /// Inventur: alle Keys (Snapshot für Debugging)
    func allKeys() -> [String] {
        kernelQueue.sync {
            Array(storage.keys)
        }
    }

    /// Holt alle Brigade-Mitglieder aus dem Kernel
    func getBrigadeIDs() -> [String] {
        let snapshot = kernelQueue.sync { storage }
        return snapshot.keys
            .filter { $0.hasPrefix("^BRIGADE.") && $0.hasSuffix(".NAME") }
            .compactMap { $0.components(separatedBy: ".").dropFirst().first }
            .sorted()
    }

    // MARK: - Seed / Boot

    /// Boot-Sequenz für iMOPS Construction (Baustellen-Branche).
    /// Im Spike-Modus laeuft das bei jedem App-Start (TheBrain ist in-memory).
    func seed() {
        // 1) Branche im Kernel merken
        set("^SYS.BRANCHE", "BAUSTELLE")

        // 2) Demo-Brigade (Crew) — wird in Phase 2 durch echte Mitarbeiter-Daten ersetzt
        set("^BRIGADE.STEFAN.NAME", "Stefan K.")
        set("^BRIGADE.STEFAN.ROLE", "Vorarbeiter")
        set("^BRIGADE.TIMO.NAME", "Timo R.")
        set("^BRIGADE.TIMO.ROLE", "Maurer")

        // 3) Demo-Task für Pelczer-Matrix-Berechnung
        set("^TASK.001.TITLE", "GERÜSTPRÜFUNG ABSCHNITT B")
        set("^TASK.001.CREATED", Date().timeIntervalSince1970)
        set("^TASK.001.WEIGHT", 9)
        set("^TASK.001.STATUS", "OPEN")
        set("^TASK.001.PINS.MEDICAL", "PSA: Helm, Gurt, Handschuhe | Windstärke < 6")
        set("^TASK.001.PINS.SOP", "DGUV Vorschrift 38. Sichtprüfung + Protokoll.")

        // 4) System-Status
        set("^SYS.STATUS", "KERNEL ONLINE")

        // 5) Schicht-Start registrieren (BourdainGuard Gen 3)
        kernelQueue.sync { storage["^SYS.SHIFT_START"] = Date() }

        // 6) Guard-System initialisieren
        set("^SYS.SECURITY_LEVEL", "standard")
        set("^SYS.ADMIN_REQUEST_COUNT", 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("iMOPS-KERNEL: Seed abgeschlossen. Matrix-Score: \(self.meierScore)")
            print("iMOPS-KERNEL: Branche: BAUSTELLE")
        }
    }

    /// Setzt den Schicht-Start neu — fuer "echte" Crew-Sessions in Phase 2.
    /// Im Spike wird das beim App-Start automatisch via seed() gesetzt.
    func startNewShift() {
        kernelQueue.sync { storage["^SYS.SHIFT_START"] = Date() }
        print("iMOPS-KERNEL: Neue Schicht gestartet @ \(Date())")
    }
}
