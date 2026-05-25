import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BauWissen")

// MARK: - BauWissenViewModel
// ViewModel fuer die BauWissen-View. Verwaltet Frage, Antwort, Loading-State und Fehler.
@Observable
final class BauWissenViewModel {

    // MARK: - State

    /// Die eingetippte Frage
    var questionText: String = ""

    /// Toggle: true = Prof (Claude Sonnet), false = Mops (lokales LLM)
    var useProf: Bool = false

    /// Antwort vom Server
    var response: MopsResponse? = nil

    /// Fehlermeldung (nil wenn alles ok)
    var errorMessage: String? = nil

    /// Ladezustand
    var isLoading: Bool = false

    // MARK: - Private

    private let client = MopsClient()

    // MARK: - Frage absenden

    /// Schickt die Frage an den Mops (oder Prof) und aktualisiert den State.
    func submitQuestion() {
        let trimmed = questionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        response = nil

        Task {
            do {
                let result = try await client.ask(question: trimmed, useProf: useProf)
                await MainActor.run {
                    self.response = result
                    self.isLoading = false
                }
                logger.info("Antwort erhalten: \(result.model), \(result.duration_ms)ms")
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
                logger.error("Fehler: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Retry

    /// Wiederholt die letzte Anfrage (nach Fehler).
    func retry() {
        submitQuestion()
    }

    // MARK: - Hilfsfunktionen

    /// Formatierte Dauer, z.B. "11.3s"
    var formattedDuration: String? {
        guard let r = response else { return nil }
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
        if model.contains("claude") {
            return "🎓 Prof (Claude Sonnet 4.5)"
        }
        return "🐶 Mops (\(model))"
    }

    /// Kann abgeschickt werden?
    var canSubmit: Bool {
        !questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}
