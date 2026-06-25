import SwiftUI
import UIKit

// MARK: - BauWissenView
// Hauptansicht fuer die Mops/Prof-Integration.
// Der Polier kann hier Bau-Fachfragen stellen:
// - Mops (lokal, llama3.2:3b, CPU-only, 30-120s)
// - Prof (Cloud-Provider, 5-15s, braucht "/prof " Prefix)
struct BauWissenView: View {
    @State private var viewModel = BauWissenViewModel()
    @State private var didCopyResponse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                inputSection
                if showsExamples { examplesSection }
                if viewModel.isLoading { loadingSection }
                if let error = viewModel.errorMessage { errorSection(error) }
                if let response = viewModel.response { responseSection(response) }
            }
            .padding()
        }
        .navigationTitle("BauWissen")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Beispielfragen werden nur gezeigt solange noch nichts passiert ist —
    /// klassisches Onboarding-Verhalten. Sobald die erste Antwort da ist,
    /// verschwinden sie und der User ist im Flow.
    private var showsExamples: Bool {
        viewModel.response == nil
            && !viewModel.isLoading
            && viewModel.errorMessage == nil
    }

    // MARK: - Header mit Erklärung

    private var headerSection: some View {
        VStack(spacing: 8) {
            MopsAvatarView(kind: viewModel.useProf ? .prof : .mops, size: 88)

            Text(viewModel.useProf ? "Frag den Prof" : "Frag den Mops")
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
                        MopsAvatarView(kind: viewModel.useProf ? .prof : .mops, size: 28)
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

    // MARK: - Beispielfragen (Onboarding)

    private var examplesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Beispielfragen — tipp eine an")
                .font(.subheadline)
                .bold()
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Self.examples) { ex in
                    ExampleCard(example: ex) {
                        viewModel.questionText = ex.frage
                        viewModel.useProf = ex.useProf
                        viewModel.submitQuestion()
                    }
                }
            }

            Text("Tipp: \"Was kann ich hier fragen?\" zeigt dir die Übersicht.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }

    private static let examples: [BauWissenExample] = [
        BauWissenExample(
            kind: .localFachwissen,
            frage: "Was ist DIN 276?",
            untertitel: "Sofort aus Wissensbasis"
        ),
        BauWissenExample(
            kind: .localBedienung,
            frage: "Wie lege ich eine Baustelle an?",
            untertitel: "Sofort aus Bedienungshilfe"
        ),
        BauWissenExample(
            kind: .mops,
            frage: "Welche Frostschutzhöhe braucht ein Streifenfundament?",
            untertitel: "Mops (lokal, 30-120s)"
        ),
        BauWissenExample(
            kind: .prof,
            frage: "Was unterscheidet Eurocode 2 und DIN 1045-2?",
            untertitel: "Prof (Cloud, 5-15s)"
        )
    ]

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
                    .background(badgeBackground(viewModel.modelBadgeColor))
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

            Button {
                UIPasteboard.general.string = response.answer
                didCopyResponse = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    didCopyResponse = false
                }
            } label: {
                Label(
                    didCopyResponse ? "Antwort kopiert" : "Antwort kopieren",
                    systemImage: didCopyResponse ? "checkmark.circle.fill" : "doc.on.doc"
                )
            }
            .buttonStyle(.bordered)
            .tint(didCopyResponse ? .green : .orange)

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

    private func badgeBackground(_ color: BauWissenViewModel.ModelBadgeColor) -> Color {
        switch color {
        case .local: return Color.green.opacity(0.15)
        case .prof:  return Color.purple.opacity(0.12)
        case .mops:  return Color.orange.opacity(0.12)
        }
    }
}

private struct MopsAvatarView: View {
    let kind: BauWissenExample.Kind
    let size: CGFloat

    private var imageName: String? {
        switch kind {
        case .mops:
            return "bau_mops_avatar"
        case .prof:
            return "prof_mops_avatar"
        case .localFachwissen, .localBedienung:
            return nil
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(kind.accentColor.opacity(0.14))

            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(kind.icon)
                    .font(.system(size: size * 0.46))
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(kind.accentColor.opacity(0.28), lineWidth: max(1, size / 44))
        )
        .shadow(color: kind.accentColor.opacity(0.18), radius: size / 9, x: 0, y: size / 16)
        .accessibilityHidden(true)
    }
}

// MARK: - Example-Modell + Card

struct BauWissenExample: Identifiable {
    let id = UUID()
    let kind: Kind
    let frage: String
    let untertitel: String

    /// Steuert Icon, Farbe und ob Prof-Toggle aktiviert wird.
    /// Mops/Prof = Server-Pfad. LocalFachwissen/LocalBedienung = ExactMatch-Hit erwartet.
    var useProf: Bool {
        kind == .prof
    }

    enum Kind {
        case localFachwissen   // 📖 grün, lokal
        case localBedienung    // 🔧 grün, lokal
        case mops              // Baustellenmops, Server lokales LLM
        case prof              // Professormops, Server Cloud-Prof

        var icon: String {
            switch self {
            case .localFachwissen: return "📖"
            case .localBedienung:  return "🔧"
            case .mops:            return "🐶"
            case .prof:            return "🎓"
            }
        }

        var accentColor: Color {
            switch self {
            case .localFachwissen, .localBedienung: return .green
            case .mops:                              return .orange
            case .prof:                              return .purple
            }
        }
    }
}

struct ExampleCard: View {
    let example: BauWissenExample
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    MopsAvatarView(kind: example.kind, size: 30)
                    Spacer()
                }
                Text(example.frage)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(example.untertitel)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(example.kind.accentColor.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(example.kind.accentColor.opacity(0.25), lineWidth: 1)
            )
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}
