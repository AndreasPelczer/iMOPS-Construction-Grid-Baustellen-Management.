import SwiftUI

// MARK: - BauWissenView
// Hauptansicht fuer die Mops/Prof-Integration.
// Der Polier kann hier Bau-Fachfragen stellen:
// - Mops (lokal, llama3.2:3b, CPU-only, 30-120s)
// - Prof (Claude Sonnet 4.5, 5-15s, braucht "/prof " Prefix)
struct BauWissenView: View {
    @State private var viewModel = BauWissenViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                inputSection
                if viewModel.isLoading { loadingSection }
                if let error = viewModel.errorMessage { errorSection(error) }
                if let response = viewModel.response { responseSection(response) }
            }
            .padding()
        }
        .navigationTitle("BauWissen")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header mit Erklärung

    private var headerSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Text("🐶")
                    .font(.system(size: 40))
            }

            Text("Frag den Mops")
                .font(.title2)
                .bold()

            Text("Bau-Fachwissen direkt auf der Baustelle – powered by Mops & Prof")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    // MARK: - Eingabebereich

    private var inputSection: some View {
        VStack(spacing: 12) {
            // Textfeld fuer die Frage
            TextField("z.B. Was ist eine tragende Wand?", text: $viewModel.questionText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
                .submitLabel(.send)
                .onSubmit {
                    if viewModel.canSubmit { viewModel.submitQuestion() }
                }

            HStack {
                // Prof-Toggle
                Toggle(isOn: $viewModel.useProf) {
                    HStack(spacing: 6) {
                        Text(viewModel.useProf ? "🎓" : "🐶")
                        Text(viewModel.useProf ? "Frag den Prof" : "Frag den Mops")
                            .font(.subheadline)
                    }
                }
                .toggleStyle(.switch)
                .tint(.orange)

                Spacer()

                // Senden-Button
                Button {
                    viewModel.submitQuestion()
                } label: {
                    Label("Fragen", systemImage: "paperplane.fill")
                        .font(.subheadline)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!viewModel.canSubmit)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Loading-Indicator

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.3)

            Text(viewModel.useProf
                 ? "Prof denkt nach …"
                 : "Mops kaut auf der Frage rum …")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Hinweis bei Mops: kann dauern
            if !viewModel.useProf {
                Text("(CPU-only, kann 30–120 Sekunden dauern)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Fehleranzeige

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                viewModel.retry()
            } label: {
                Label("Nochmal versuchen", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
        .background(Color.red.opacity(0.08))
        .cornerRadius(12)
    }

    // MARK: - Antwort-Bereich

    private func responseSection(_ response: MopsResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Model-Badge + Timing
            HStack(spacing: 12) {
                // Model-Badge
                Text(viewModel.modelBadge)
                    .font(.caption)
                    .bold()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(response.model.contains("claude")
                                ? Color.purple.opacity(0.12)
                                : Color.orange.opacity(0.12))
                    .cornerRadius(8)

                Spacer()

                // Timing + Quellen-Info
                if let duration = viewModel.formattedDuration {
                    HStack(spacing: 8) {
                        Label(duration, systemImage: "timer")
                        if viewModel.sourceCount > 0 {
                            Label("\(viewModel.sourceCount) Quellen", systemImage: "books.vertical")
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }

            // Antwort-Text
            Text(response.answer)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            // Quellen-Liste
            if let sources = response.sources, !sources.isEmpty {
                Divider()

                Text("Quellen")
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.secondary)

                ForEach(sources) { source in
                    SourceCardView(source: source)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
