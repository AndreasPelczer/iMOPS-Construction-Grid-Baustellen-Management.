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
    func aufwandswertVorschlag(leistung: String, langtext: String? = nil) async -> (maurer: Double, helfer: Double)? {
        guard isConnected else { return nil }

        var frage = "Aufwandswert REFA für: \(leistung)."
        if let lt = langtext?.trimmingCharacters(in: .whitespacesAndNewlines), !lt.isEmpty {
            // Der volle LV-Langtext trägt Tiefe, Bodenklasse, Verbau, Wasserhaltung usw. —
            // ohne den schätzt der Prof für den nackten Titel ins Blaue.
            frage += " Vollständige Leistungsbeschreibung (Tiefe, Bodenklasse, Verbau, Umfang beachten): \(lt)."
        }
        frage += " Antworte NUR in diesem Format: MAURER=X.XX HELFER=X.XX (Stunden pro Einheit)"

        do {
            let response = try await client.ask(question: frage, useProf: true)
            return parseAufwandswert(response.answer)
        } catch {
            logger.warning("Aufwandswert-Anfrage fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Markt-Orientierung (Büro-Vorarbeit, online)

    /// Grobe Markt-Orientierung (KI-Schätzung, KEIN Angebot): fragt den Prof nach einem
    /// ungefähren Marktpreis je Einheit. Das ist Büro-Vorarbeit vor Baustellenbeginn (online) —
    /// nicht die Offline-Baustellen-Regel. Immer als Schätzung markieren, Mensch entscheidet.
    func marktpreisVorschlag(material: String, einheit: String) async -> Double? {
        guard isConnected else { return nil }
        let frage = "Ungefährer Marktpreis für \(material) pro \(einheit) in EUR "
            + "(Deutschland, grobe Orientierung, kein verbindliches Angebot). "
            + "Antworte NUR in diesem Format: PREIS=X.XX"
        do {
            let response = try await client.ask(question: frage, useProf: true)
            return parsePreis(response.answer)
        } catch {
            logger.warning("Marktpreis-Anfrage fehlgeschlagen: \(error.localizedDescription)")
            return nil
        }
    }

    private func parsePreis(_ text: String) -> Double? {
        parseZahl("PREIS", text)
    }

    /// Grobe KI-Schätzung für eine GANZE Bauleistung: Material- UND Einbauanteil
    /// (Lohn + Gerät) je Einheit. So bekommt eine „herstellen"-Position (liefern + einbauen
    /// + verdichten) gleich den ganzen Preis, nicht nur das Material.
    /// KI-Schätzung, KEIN Angebot — immer als „geraten" markieren, Mensch prüft.
    func leistungsSchaetzung(leistung: String, einheit: String) async -> (material: Double?, einbau: Double?) {
        guard isConnected else { return (nil, nil) }
        let frage = "Für die Bauleistung \(leistung) (Deutschland, grobe Orientierung, kein verbindliches Angebot), "
            + "je \(einheit): ungefährer Materialanteil und ungefährer Einbauanteil (Lohn + Gerät) in EUR. "
            + "Ist es reine Materiallieferung, setze EINBAU=0. "
            + "Antworte NUR in diesem Format: MATERIAL=X.XX EINBAU=Y.YY"
        do {
            let response = try await client.ask(question: frage, useProf: true)
            return (parseZahl("MATERIAL", response.answer), parseZahl("EINBAU", response.answer))
        } catch {
            logger.warning("Leistungs-Schätzung fehlgeschlagen: \(error.localizedDescription)")
            return (nil, nil)
        }
    }

    private func parseZahl(_ schluessel: String, _ text: String) -> Double? {
        let upper = text.uppercased()
        let muster = "\(schluessel.uppercased())\\s*=?\\s*(\\d+[.,]?\\d*)"
        guard let r = upper.range(of: muster, options: .regularExpression) else { return nil }
        let num = String(upper[r])
            .replacingOccurrences(of: schluessel.uppercased(), with: "")
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        return Double(num)
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
