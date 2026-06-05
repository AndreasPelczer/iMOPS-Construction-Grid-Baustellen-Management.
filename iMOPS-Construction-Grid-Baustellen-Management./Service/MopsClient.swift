import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "MopsClient")

// MARK: - MopsConfig
// Server-Konfiguration fuer den Mops. Die Base-URL ist konfigurierbar
// (Settings → Mops-Server), damit User von unterwegs auch einen
// Cloudflare-Tunnel oder Tailscale-Address eintragen koennen.
// Default ist die Mops-Box im Heimnetz.
struct MopsConfig {
    /// Fallback-URL wenn der User nichts in Settings konfiguriert hat.
    static let defaultHost = "http://192.168.2.42:8080"

    /// UserDefaults-Keys fuer Server-Settings.
    enum Keys {
        static let baseURL = "mops_base_url"
    }

    /// Aktuell aktive Base-URL — liest dynamisch aus UserDefaults damit
    /// Settings-Aenderungen sofort wirken (ohne App-Neustart).
    static var host: String {
        let stored = UserDefaults.standard.string(forKey: Keys.baseURL) ?? ""
        return stored.isEmpty ? defaultHost : stored
    }

    static let chatEndpoint = "/chat"
    static let healthEndpoint = "/health"
    static let classifyEndpoint = "/classify"
    static let extractPlanEndpoint = "/extract-plan"
    static let defaultMaxTokens = 500
    static let defaultTopK = 3
    // Mops laeuft CPU-only, kann bis zu 120s+ brauchen
    static let requestTimeoutSeconds: TimeInterval = 180
    // Classify ist leichtgewichtig — kuerzerer Timeout
    static let classifyTimeoutSeconds: TimeInterval = 30
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

    // MARK: - File Classification

    /// Klassifiziert eine Datei anhand von Filename, Endung und Groesse via Mops-KI.
    func classifyFile(name: String, ext: String, sizeBytes: Int64) async throws -> FileClassification {
        guard let url = URL(string: MopsConfig.host + MopsConfig.classifyEndpoint) else {
            throw MopsClientError.invalidURL
        }

        let payload = ClassifyRequest(filename: name, fileExtension: ext, sizeBytes: sizeBytes)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = MopsConfig.classifyTimeoutSeconds
        request.httpBody = try JSONEncoder().encode(payload)

        logger.info("Mops classify: \(name) (.\(ext), \(sizeBytes) bytes)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                throw MopsClientError.timeout
            }
            throw MopsClientError.serverOffline
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<keine Antwort>"
            throw MopsClientError.httpError(statusCode: http.statusCode, body: body)
        }

        let result = try JSONDecoder().decode(FileClassification.self, from: data)
        logger.info("Mops classify result: \(result.category) (confidence \(result.confidence))")
        return result
    }

    // MARK: - Plan-Extraktion (Welle 4 — App-Brücke)

    /// Lädt eine Plan-PDF zur Box (POST /extract-plan, multipart) und bekommt
    /// LV-Positionen + Mauerwerks-Bestellliste zurück. CPU-only → bis 180s.
    func extractPlan(pdf data: Data, filename: String = "plan.pdf",
                     projekt: String? = nil, baustelle: String? = nil) async throws -> ExtractPlanResult {
        guard let url = URL(string: MopsConfig.host + MopsConfig.extractPlanEndpoint) else {
            throw MopsClientError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.multipartBody(boundary: boundary, pdf: data, filename: filename,
                                              projekt: projekt, baustelle: baustelle)

        logger.info("Mops extract-plan: \(filename) (\(data.count) bytes)")

        let respData: Data
        let response: URLResponse
        do {
            (respData, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                logger.error("extract-plan Timeout nach \(MopsConfig.requestTimeoutSeconds)s")
                throw MopsClientError.timeout
            }
            logger.error("extract-plan nicht erreichbar: \(error.localizedDescription)")
            throw MopsClientError.serverOffline
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: respData, encoding: .utf8) ?? "<keine Antwort>"
            logger.error("extract-plan HTTP \(http.statusCode): \(body)")
            throw MopsClientError.httpError(statusCode: http.statusCode, body: body)
        }

        let result = try JSONDecoder().decode(ExtractPlanResult.self, from: respData)
        logger.info("extract-plan: \(result.lvPositionen.count) LV-Pos, \(result.bestellliste.count) Bestellzeilen")
        return result
    }

    /// Baut den multipart/form-data-Body: PDF-Datei + optionale Projekt-/Baustellen-Felder.
    private static func multipartBody(boundary: String, pdf: Data, filename: String,
                                      projekt: String?, baustelle: String?) -> Data {
        var body = Data()
        let nl = "\r\n"

        // Datei-Teil (Feldname "file" — so erwartet es der Endpoint)
        body.append("--\(boundary)\(nl)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\(nl)".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\(nl)\(nl)".data(using: .utf8)!)
        body.append(pdf)
        body.append(nl.data(using: .utf8)!)

        // optionale Formfelder
        for (name, value) in [("projekt", projekt), ("baustelle", baustelle)] {
            guard let value, !value.isEmpty else { continue }
            body.append("--\(boundary)\(nl)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\(nl)\(nl)".data(using: .utf8)!)
            body.append("\(value)\(nl)".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\(nl)".data(using: .utf8)!)
        return body
    }
}
