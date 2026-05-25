import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "MopsClient")

// MARK: - MopsConfig
// Server-Konfiguration fuer den Mops. Aktuell Heimnetz, spaeter Tailscale / Production.
struct MopsConfig {
    static let host = "http://192.168.2.42:8080"
    static let chatEndpoint = "/chat"
    static let healthEndpoint = "/health"
    static let defaultMaxTokens = 500
    static let defaultTopK = 3
    // Mops laeuft CPU-only, kann bis zu 120s+ brauchen
    static let requestTimeoutSeconds: TimeInterval = 180
}

// MARK: - MopsClientError
enum MopsClientError: LocalizedError {
    case serverOffline
    case timeout
    case httpError(statusCode: Int, body: String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .serverOffline:
            return "Mops ist offline – Server nicht erreichbar."
        case .timeout:
            return "Mops braucht länger als erwartet – bitte nochmal versuchen."
        case .httpError(let code, let body):
            return "Server-Fehler (\(code)): \(body)"
        case .invalidURL:
            return "Ungültige Server-URL."
        }
    }
}

// MARK: - MopsClient
// URLSession-Wrapper fuer den Mops-Server. Async/await, keine externen Dependencies.
final class MopsClient {

    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = MopsConfig.requestTimeoutSeconds
        config.timeoutIntervalForResource = MopsConfig.requestTimeoutSeconds
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Chat-Anfrage an den Mops senden

    /// Stellt eine Frage an den Mops (oder Prof, wenn useProf == true).
    /// Der Prof-Prefix "/prof " wird automatisch vorangestellt.
    func ask(question: String, useProf: Bool = false) async throws -> MopsResponse {
        guard let url = URL(string: MopsConfig.host + MopsConfig.chatEndpoint) else {
            throw MopsClientError.invalidURL
        }

        // Prof-Trigger: "/prof " vor die Frage setzen
        let finalQuestion = useProf ? "/prof \(question)" : question

        let requestBody = MopsRequest(
            question: finalQuestion,
            max_tokens: MopsConfig.defaultMaxTokens,
            top_k: MopsConfig.defaultTopK
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        logger.info("Mops-Anfrage: useProf=\(useProf), Frage: \(finalQuestion.prefix(80))…")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                logger.error("Mops Timeout nach \(MopsConfig.requestTimeoutSeconds)s")
                throw MopsClientError.timeout
            }
            logger.error("Mops nicht erreichbar: \(error.localizedDescription)")
            throw MopsClientError.serverOffline
        }

        // HTTP-Status pruefen
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<keine Antwort>"
            logger.error("Mops HTTP \(http.statusCode): \(body)")
            throw MopsClientError.httpError(statusCode: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(MopsResponse.self, from: data)
        logger.info("Mops-Antwort: model=\(decoded.model), tokens=\(decoded.tokens), dauer=\(decoded.duration_ms)ms")
        return decoded
    }

    // MARK: - Health-Check

    /// Prueft ob der Mops-Server erreichbar ist.
    func checkHealth() async -> Bool {
        guard let url = URL(string: MopsConfig.host + MopsConfig.healthEndpoint) else {
            return false
        }
        do {
            let (_, response) = try await urlSession.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
