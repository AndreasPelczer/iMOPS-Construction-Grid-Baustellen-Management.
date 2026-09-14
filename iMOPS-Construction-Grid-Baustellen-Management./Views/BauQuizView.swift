//
//  BauQuizView.swift
//  Das Bau-Quiz — kleine Runde Baufragen (1. Lehrjahr), das Gegenstück zum Kochquiz.
//  Eine Frage nach der anderen, sofortiges Feedback mit kurzer Erklärung, am Ende der
//  Punktestand. Lernen darf Spaß machen.
//

import SwiftUI

struct BauQuizView: View {
    var anzahl: Int = 5
    var onFertig: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    /// Eine Frage mit gemischter Antwort-Reihenfolge (Antwortindex neu gerechnet).
    private struct Runde {
        let frage: Baufrage
        let antworten: [String]
        let richtige: Int
    }

    @State private var runde: [Runde] = []
    @State private var index = 0
    @State private var gewaehlt: Int? = nil
    @State private var punkte = 0

    var body: some View {
        NavigationStack {
            Group {
                if index >= runde.count && !runde.isEmpty {
                    ergebnis
                } else if let r = runde[safe: index] {
                    frageAnsicht(r)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Baufragen 🧱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { onFertig(); dismiss() }
                }
            }
        }
        .onAppear(perform: starten)
    }

    // MARK: - Frage

    private func frageAnsicht(_ r: Runde) -> some View {
        VStack(spacing: 16) {
            fortschritt
            Text(r.frage.thema.uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(r.frage.frage)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(Array(r.antworten.enumerated()), id: \.offset) { i, text in
                    antwortKnopf(i: i, text: text, r: r)
                }
            }
            .padding(.horizontal)

            if gewaehlt != nil {
                Text(r.frage.erklaerung)
                    .font(.callout).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                Button(index + 1 < runde.count ? "Weiter" : "Ergebnis") { weiter() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding(.top)
    }

    private func antwortKnopf(i: Int, text: String, r: Runde) -> some View {
        Button { waehle(i, r: r) } label: {
            HStack {
                Text(text).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if gewaehlt != nil {
                    if i == r.richtige {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if i == gewaehlt {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hintergrund(i: i, r: r), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(gewaehlt != nil)
    }

    private func hintergrund(i: Int, r: Runde) -> Color {
        guard gewaehlt != nil else { return Color(.secondarySystemBackground) }
        if i == r.richtige { return .green.opacity(0.18) }
        if i == gewaehlt { return .red.opacity(0.18) }
        return Color(.secondarySystemBackground)
    }

    private var fortschritt: some View {
        Text("Frage \(min(index + 1, runde.count)) von \(runde.count)  ·  \(punkte) richtig")
            .font(.caption).foregroundStyle(.secondary)
    }

    // MARK: - Ergebnis

    private var ergebnis: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(punkte == runde.count ? "🏆" : "🧱").font(.system(size: 60))
            Text("\(punkte) von \(runde.count) richtig")
                .font(.title2.bold())
            Text(lob).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)
            Spacer()
            VStack(spacing: 10) {
                Button("Nochmal") { starten() }
                    .buttonStyle(.borderedProminent)
                Button("Fertig") { onFertig(); dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(maxWidth: .infinity)
    }

    private var lob: String {
        switch punkte {
        case runde.count: return "Alles richtig — sitzt wie eine saubere Fuge."
        case 0: return "Kein Treffer — macht nichts, jetzt weißt du die Antworten."
        default: return "Solide. Die Erklärungen bleiben hängen."
        }
    }

    // MARK: - Logik

    private func starten() {
        runde = Baufragen.runde(anzahl: anzahl).map { f in
            let paare = f.antworten.enumerated().shuffled()
            let neueAntworten = paare.map { $0.element }
            let neuRichtig = paare.firstIndex { $0.offset == f.richtige } ?? 0
            return Runde(frage: f, antworten: neueAntworten, richtige: neuRichtig)
        }
        index = 0; gewaehlt = nil; punkte = 0
    }

    private func waehle(_ i: Int, r: Runde) {
        guard gewaehlt == nil else { return }
        gewaehlt = i
        if i == r.richtige { punkte += 1 }
    }

    private func weiter() {
        index += 1
        gewaehlt = nil
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
