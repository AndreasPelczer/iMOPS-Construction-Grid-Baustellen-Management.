import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BauWissen")

// MARK: - BauWissenViewModel
// ViewModel fuer die BauWissen-View. Verwaltet Frage, Antwort, Loading-State und Fehler.
//
// Phase 1b Pre-Filter:
// Vor jedem Server-Call wird ExactMatchKnowledge.lookup() gefragt. Bei einem Treffer
// wird sofort eine lokale Antwort gebaut — kein HTTP, kein LLM, sub-Millisekunde,
// offline-faehig. Das model-Feld der Response markiert die Quelle:
//   - "imops-wissen-local"     → Bau-Fachwissen aus DIN/Materialien (Kategorie fachwissen)
//   - "imops-bedienung-local"  → iMOPS-Bedienungshilfe (Kategorie app-bedienung)
@Observable
final class BauWissenViewModel {

    // MARK: - State

    /// Die eingetippte Frage
    var questionText: String = ""

    /// Toggle: true = Prof (Cloud-Provider), false = Mops (lokales LLM)
    /// Wird ignoriert wenn ExactMatch lokal greift.
    var useProf: Bool = false

    /// Antwort vom Server oder lokales Lookup
    var response: MopsResponse? = nil

    /// Fehlermeldung (nil wenn alles ok)
    var errorMessage: String? = nil

    /// Ladezustand
    var isLoading: Bool = false

    // MARK: - Private

    private let client = MopsClient()

    // MARK: - Frage absenden

    /// Schickt die Frage erst durch das lokale Exact-Match,
    /// bei Miss an den Mops (oder Prof).
    func submitQuestion() {
        let trimmed = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        response = nil

        Task {
            // 1. Lokaler Pre-Filter: Exact-Match in den YAMLs
            if let hit = await ExactMatchKnowledge.shared.lookup(trimmed) {
                let local = Self.buildLocalResponse(from: hit)
                await MainActor.run {
                    self.response = local
                    self.isLoading = false
                }
                logger.info("ExactMatch-Hit: \(hit.id) [\(hit.resolvedKategorie)]")
                return
            }

            // 2. Kein Hit → normaler Server-Call
            do {
                let result = try await client.ask(question: trimmed, useProf: useProf)
                await MainActor.run {
                    self.response = result
                    self.isLoading = false
                }
                logger.info("Server-Antwort: \(result.model), \(result.duration_ms)ms")
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                logger.error("Server-Fehler: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Lokale Antwort aus Knowledge-Entry bauen

    private static func buildLocalResponse(from hit: KnowledgeEntry) -> MopsResponse {
        let modelTag: String
        switch hit.resolvedKategorie {
        case "app-bedienung": modelTag = "imops-bedienung-local"
        case "easteregg":     modelTag = "imops-easteregg-local"
        default:              modelTag = "imops-wissen-local"
        }

        // Source-Card zeigt Herkunft (Norm-Nummer, Beuth-Hinweis etc.)
        let source = MopsSource(
            lemma_id: hit.id,
            titel: hit.quelleKurz,
            source_url: hit.quelleUrl,
            score: 1.0,
            chunk_preview: hit.licenseNote
        )

        return MopsResponse(
            answer: hit.antwort,
            model: modelTag,
            duration_ms: 1,         // sub-ms, gerundet auf 1
            tokens: 0,
            retrieval_ms: 0,
            sources: [source]
        )
    }

    // MARK: - Retry

    /// Wiederholt die letzte Anfrage (nach Fehler).
    func retry() {
        submitQuestion()
    }

    // MARK: - Hilfsfunktionen

    /// Formatierte Dauer, z.B. "11.3s" oder "lokal" bei sub-ms.
    var formattedDuration: String? {
        guard let r = response else { return nil }
        if r.model.hasSuffix("-local") {
            return "lokal"
        }
        let seconds = Double(r.duration_ms) / 1000.0
        return String(format: "%.1fs", seconds)
    }

    /// Anzahl der Quellen
    var sourceCount: Int {
        response?.sources?.count ?? 0
    }

    /// Model-Badge Text
    var modelBadge: String {
        guard let model = response?.model else { return "" }
        switch model {
        case "imops-wissen-local":     return "📖 iMOPS-Wissensbasis"
        case "imops-bedienung-local":  return "🔧 Bedienungshilfe"
        case "imops-easteregg-local":  return "🍺 Feierabend"
        default:
            if Self.isProfModel(model) {
                return "🎓 Prof (\(model))"
            }
            return "🐶 Mops (\(model))"
        }
    }

    /// Hintergrundfarbe fuer das Model-Badge (gruen lokal, lila Prof, orange Mops).
    var modelBadgeColor: ModelBadgeColor {
        guard let model = response?.model else { return .mops }
        if model == "imops-easteregg-local" { return .mops }
        if model.hasSuffix("-local") { return .local }
        if Self.isProfModel(model)  { return .prof }
        return .mops
    }

    private static func isProfModel(_ model: String) -> Bool {
        let lowercased = model.lowercased()
        return lowercased.contains("claude")
            || lowercased.contains("gpt")
            || lowercased.contains("openai")
            || lowercased.contains("gemini")
    }

    enum ModelBadgeColor {
        case local, prof, mops
    }

    /// Kann abgeschickt werden?
    var canSubmit: Bool {
        !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}
