import SwiftUI

// MARK: - PreisCheckCard
//
// Der Preis-Wächter im LV: fängt die falsche Zahl, bevor das Angebot rausgeht.
// Vergleicht jeden Einheitspreis mit den gleichartigen Positionen und meldet vor
// allem die Komma-/Zehnerpotenz-Falle (8,02 statt 80,21). Sagt „prüf diese Zahl",
// nie „falsch" — der Mensch entscheidet.
//
// Rechnet den effektiven EP je Position (kann Core-Data-Lookups auslösen), darum
// EINMAL beim Erscheinen, nicht in jedem Render.
struct PreisCheckCard: View {
    let positionen: [LVPosition]

    @State private var befunde: [PreisBefund] = []
    @State private var geprueft = false
    @State private var zeigeDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if !befunde.isEmpty { withAnimation(.snappy) { zeigeDetails.toggle() } }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: kopfIcon).font(.title3).foregroundStyle(kopfFarbe).frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Preis-Wächter").font(.headline)
                        Text(kopfText).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !befunde.isEmpty {
                        Image(systemName: zeigeDetails ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(befunde.isEmpty)

            if zeigeDetails {
                VStack(spacing: 8) {
                    ForEach(befunde) { b in befundZeile(b) }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: positionen.count) {
            befunde = PreisWaechter.pruefe(positionen: positionen)
            geprueft = true
        }
    }

    private var kopfIcon: String {
        if !geprueft { return "hourglass" }
        return befunde.isEmpty ? "checkmark.seal" : "exclamationmark.triangle.fill"
    }
    private var kopfFarbe: Color {
        if !geprueft { return .secondary }
        return befunde.isEmpty ? .green : .orange
    }
    private var kopfText: String {
        if !geprueft { return "prüft die Einheitspreise …" }
        if befunde.isEmpty { return "Keine auffälligen Zahlen — sieht sauber aus." }
        let n = befunde.count
        return "\(n) Zahl\(n == 1 ? "" : "en") prüfen — tippen zum Ansehen."
    }

    private func befundZeile(_ b: PreisBefund) -> some View {
        HStack(spacing: 10) {
            Image(systemName: b.art == .zehnerpotenz ? "textformat.123" : "chart.line.flattrend.xyaxis")
                .foregroundStyle(.orange).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.bezeichnung).font(.subheadline).lineLimit(1)
                Text("\(b.einzelpreis.formatted(.currency(code: "EUR"))) — "
                     + (b.art == .zehnerpotenz ? "Komma prüfen" : "Ausreißer"))
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                Text(b.hinweis).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
