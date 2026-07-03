import SwiftUI

// Eine Zeile in der Aufmaß-Liste: Menge · Quelle · Zeitstempel · Notiz.
// Der Zeitstempel ist der Nachweis-Anker (Buch Kap 4).
struct AufmassRowView: View {
    @ObservedObject var aufmass: Aufmass

    private var datum: String {
        guard let d = aufmass.erstelltAm else { return "—" }
        return d.formatted(date: .abbreviated, time: .shortened)
    }

    // Quelle als Icon-Badge — BuildIQ hebt sich (orange, Hirn) von Hand/Import ab,
    // damit der Polier die zweite Datenquelle in der Aufmaß-Liste sofort erkennt.
    private var quelleIcon: String {
        switch aufmass.quelle {
        case .buildiq:    return "brain.head.profile"
        case .importiert: return "tray.and.arrow.down"
        case .manuell:    return "hand.point.up.left"
        }
    }
    private var quelleLabel: String {
        switch aufmass.quelle {
        case .buildiq:    return "BuildIQ"
        case .importiert: return "Import"
        case .manuell:    return "manuell"
        }
    }
    private var quelleFarbe: Color {
        aufmass.quelle == .buildiq ? .orange : .gray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("\(aufmass.istMenge.formatted(.number.precision(.fractionLength(0...2)))) \(aufmass.istEinheit ?? "")")
                    .font(.body.monospacedDigit().weight(.medium))
                Spacer()
                Label(quelleLabel, systemImage: quelleIcon)
                    .font(.caption2)
                    .foregroundStyle(quelleFarbe)
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
