import Foundation
import Network
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "MopsKalk")

// MARK: - MopsKalkulationsHelper
// Optionaler Bonus-Layer: fragt den Mops/Prof fuer Aufwandswerte, Material-Alternativen
// und Positionstexte. Gibt nil zurueck wenn offline — Kernfunktion laeuft immer lokal.
final class MopsKalkulationsHelper {

    static let shared = MopsKalkulationsHelper()

    private let client = MopsClient()
    private let monitor = NWPathMonitor()
    private var isConnected = false

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = (path.status == .satisfied)
        }
        monitor.start(queue: DispatchQueue(label: "MopsNetworkMonitor"))
    }

    /// Prueft ob der Mops-Server erreichbar ist
    var isAvailable: Bool { isConnected }

    // MARK: - Aufwandswert vorschlagen

    /// Fragt den Prof nach REFA-Aufwandswerten fuer eine Leistung.
    /// Returns: (Maurer-Stunden, Helfer-Stunden) oder nil wenn offline/Fehler.
    func aufwandswertVorschlag(leistung: String) async -> (maurer: Double, helfer: Double)? {
        guard isConnected else { return nil }

        let frage = "Aufwandswert REFA für: \(leistung). " +
            "Antworte NUR in diesem Format: MAURER=X.XX HELFER=X.XX (Stunden pro Einheit)"

        do {
            let response = try await client.ask(question: frage, useProf: true)
            return parseAufwandswert(response.answer)
        } catch {
            logger.warning("Aufwandswert-Anfrage fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Material-Alternative

    /// Fragt nach alternativen Materialien mit bestimmten Anforderungen.
    func materialAlternative(material: String, anforderung: String) async -> String? {
        guard isConnected else { return nil }

        let frage = "Alternative zu \(material) für \(anforderung)? " +
            "Nenne max. 3 Optionen mit ungefährem Preis pro Einheit."

        do {
            let response = try await client.ask(question: frage, useProf: true)
            return response.answer
        } catch {
            logger.warning("Material-Alternative-Anfrage fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - GAEB-Positionstext generieren

    /// Generiert einen formalen GAEB-Positionstext fuer eine Leistung.
    func positionstextGenerieren(leistung: String, details: String) async -> String? {
        guard isConnected else { return nil }

        let frage = "Generiere einen formalen GAEB-Positionstext (Kurztext + Langtext) für: " +
            "\(leistung). Details: \(details). " +
            "Format: KURZTEXT: ... LANGTEXT: ..."

        do {
            let response = try await client.ask(question: frage, useProf: true)
            return response.answer
        } catch {
            logger.warning("Positionstext-Anfrage fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Parser

    private func parseAufwandswert(_ text: String) -> (maurer: Double, helfer: Double)? {
        let upper = text.uppercased()

        // Suche nach MAURER=X.XX
        guard let maurerRange = upper.range(of: #"MAURER\s*=\s*(\d+[.,]?\d*)"#, options: .regularExpression),
              let helferRange = upper.range(of: #"HELFER\s*=\s*(\d+[.,]?\d*)"#, options: .regularExpression) else {
            return nil
        }

        let maurerStr = String(upper[maurerRange])
            .replacingOccurrences(of: "MAURER", with: "")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        let helferStr = String(upper[helferRange])
            .replacingOccurrences(of: "HELFER", with: "")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        guard let maurer = Double(maurerStr),
              let helfer = Double(helferStr) else { return nil }

        return (maurer: maurer, helfer: helfer)
    }
}
