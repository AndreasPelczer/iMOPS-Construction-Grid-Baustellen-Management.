import SwiftUI
import CoreData

// Welle 9 — Kosten-Rollup nach Bau-Hierarchie (Gebäude · Geschoss).
// Klon von KostenübersichtView; einziger Unterschied ist der Gruppier-Schlüssel
// (Geschoss statt DIN-276-Kostengruppe). Die Preis-Wahrheit bleibt unangetastet:
// LVKalkulator.effektiverEP(for:store:) × menge.
struct GeschossKostenView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event
    let positionen: [LVPosition]

    @StateObject private var store = AngebotsStore.shared

    private struct GeschossKosten: Identifiable {
        var id: String
        var titel: String
        var items: [LVPosition]
        var gesamtGP: Double
        var ohnePreis: Int
    }

    private var geschossKosten: [GeschossKosten] {
        let base = positionen.filter { !LVPositionHelper.isAlternative($0) }
        let dict = Dictionary(grouping: base, by: { $0.geschoss })
        return dict.map { geschoss, items -> (sort: (Int16, Int16, String), row: GeschossKosten) in
            let gebName = geschoss?.gebaeude?.name ?? "—"
            let gesName = geschoss?.name ?? "Ohne Geschoss"
            let gp = items.reduce(0.0) { $0 + LVKalkulator.effektiverEP(for: $1, store: store) * $1.menge }
            let ohne = items.filter { LVKalkulator.effektiverEP(for: $0, store: store) == 0 }.count
            return (
                sort: (geschoss?.gebaeude?.reihenfolge ?? .max, geschoss?.reihenfolge ?? .max, gesName),
                row: GeschossKosten(
                    id: "geschoss-\(geschoss?.id?.uuidString ?? "ohne")",
                    titel: "\(gebName) · \(gesName)",
                    items: items, gesamtGP: gp, ohnePreis: ohne
                )
            )
        }
        .sorted { l, r in
            if l.sort.0 != r.sort.0 { return l.sort.0 < r.sort.0 }
            if l.sort.1 != r.sort.1 { return l.sort.1 < r.sort.1 }
            return l.sort.2 < r.sort.2
        }
        .map { $0.row }
    }

    private var gesamtNetto: Double  { geschossKosten.reduce(0.0) { $0 + $1.gesamtGP } }
    private var mwstSatz:    Double  { FirmenSettings.mwstSatz }
    private var mwstBetrag:  Double  { gesamtNetto * mwstSatz / 100 }
    private var gesamtBrutto: Double { gesamtNetto + mwstBetrag }
    private var maxGP:       Double  { geschossKosten.map { $0.gesamtGP }.max() ?? 1 }
    private var ohnePreisGesamt: Int { geschossKosten.reduce(0) { $0 + $1.ohnePreis } }

    var body: some View {
        NavigationStack {
            List {
                Section("Gesamtkosten") {
                    VStack(alignment: .leading, spacing: 10) {
                        row("Netto", value: gesamtNetto, font: .body)
                        row("MwSt. \(Int(mwstSatz)) %", value: mwstBetrag, font: .body, color: .secondary)
                        Divider()
                        row("Brutto", value: gesamtBrutto, font: .headline, color: .orange)
                    }
                    .padding(.vertical, 4)
                }

                Section("Nach Gebäude / Geschoss") {
                    ForEach(geschossKosten) { g in geschossRow(g) }
                }

                if ohnePreisGesamt > 0 {
                    Section("Fehlende Preise") {
                        Label(
                            "\(ohnePreisGesamt) Position\(ohnePreisGesamt == 1 ? " hat" : "en haben") noch keinen Preis.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.orange)
                        Text("Preise im Angebotsvergleich (⋯ → Angebotsvergleich) erfassen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Kosten nach Ebene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }

    private func row(_ label: String, value: Double,
                     font: Font, color: Color = .primary) -> some View {
        HStack {
            Text(label).foregroundStyle(color)
            Spacer()
            Text(value, format: .currency(code: "EUR"))
                .font(font.monospacedDigit())
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func geschossRow(_ g: GeschossKosten) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(g.titel).font(.subheadline)
                Spacer()
                Text(g.gesamtGP, format: .currency(code: "EUR"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(g.gesamtGP == 0 ? .secondary : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.orange.opacity(0.75))
                        .frame(width: max(4, geo.size.width
                                         * CGFloat(maxGP > 0 ? g.gesamtGP / maxGP : 0)))
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(g.items.count) Pos.")
                    .font(.caption2).foregroundStyle(.secondary)
                if g.ohnePreis > 0 {
                    Text("·").foregroundStyle(.secondary)
                    Text("\(g.ohnePreis) ohne Preis")
                        .font(.caption2).foregroundStyle(.red)
                }
                Spacer()
                if gesamtNetto > 0 {
                    Text("\(Int((g.gesamtGP / gesamtNetto) * 100)) %")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
