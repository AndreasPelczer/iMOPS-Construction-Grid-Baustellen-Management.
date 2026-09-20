import SwiftUI

// MARK: - AngebotsCheckCard
//
// Der Angebots-Wächter im LV: meldet Lücken (Position ohne Preis / ohne Menge),
// bevor das Angebot rausgeht. Sagt „prüf das", nicht „falsch" — der Mensch
// entscheidet. Rechnet einmal beim Erscheinen (effektiver EP kann Lookups auslösen).
struct AngebotsCheckCard: View {
    let positionen: [LVPosition]

    @State private var luecken: [AngebotsLuecke] = []
    @State private var geprueft = false
    @State private var zeigeDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                if !luecken.isEmpty { withAnimation(.snappy) { zeigeDetails.toggle() } }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: kopfIcon).font(.title3).foregroundStyle(kopfFarbe).frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Angebots-Wächter").font(.headline)
                        Text(kopfText).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !luecken.isEmpty {
                        Image(systemName: zeigeDetails ? "chevron.up" : "chevron.down")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(luecken.isEmpty)

            if zeigeDetails {
                VStack(spacing: 8) {
                    ForEach(luecken) { l in lueckeZeile(l) }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: positionen.count) {
            luecken = AngebotsCheck.pruefe(positionen: positionen)
            geprueft = true
        }
    }

    private var kopfIcon: String {
        if !geprueft { return "hourglass" }
        return luecken.isEmpty ? "checkmark.seal" : "exclamationmark.triangle.fill"
    }
    private var kopfFarbe: Color {
        if !geprueft { return .secondary }
        return luecken.isEmpty ? .green : .orange
    }
    private var kopfText: String {
        if !geprueft { return "prüft das Angebot auf Lücken …" }
        if luecken.isEmpty { return "Kein Loch — jede Position hat Preis und Menge." }
        let n = luecken.count
        return "\(n) Lücke\(n == 1 ? "" : "n") vor dem Abschicken — tippen zum Ansehen."
    }

    private func lueckeZeile(_ l: AngebotsLuecke) -> some View {
        HStack(spacing: 10) {
            Image(systemName: l.art == .ohnePreis ? "eurosign.circle" : "number.circle")
                .foregroundStyle(.orange).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.bezeichnung).font(.subheadline).lineLimit(1)
                Text(l.art == .ohnePreis ? "ohne Preis" : "ohne Menge")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                Text(l.hinweis).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
