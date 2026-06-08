import SwiftUI

// Eine Zeile in der Aufmaß-Liste: Menge · Quelle · Zeitstempel · Notiz.
// Der Zeitstempel ist der Nachweis-Anker (Buch Kap 4).
struct AufmassRowView: View {
    @ObservedObject var aufmass: Aufmass

    private var datum: String {
        guard let d = aufmass.erstelltAm else { return "—" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(aufmass.istMenge.formatted(.number.precision(.fractionLength(0...2)))) \(aufmass.istEinheit ?? "")")
                    .font(.body.monospacedDigit().weight(.medium))
                Spacer()
                Text(aufmass.quelle.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                Text(datum).font(.caption).foregroundStyle(.secondary)
                if let n = aufmass.notiz, !n.isEmpty {
                    Text("· \(n)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
