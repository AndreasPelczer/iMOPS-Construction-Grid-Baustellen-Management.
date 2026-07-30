import SwiftUI
import CoreData

struct KostenübersichtView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event
    let positionen: [LVPosition]

    @StateObject private var store = AngebotsStore.shared

    private struct KGKosten: Identifiable {
        var id: String { kg }
        var kg:          String
        var bezeichnung: String
        var items:       [LVPosition]
        var gesamtGP:    Double
        var ohnePreis:   Int
    }

    private var kgKosten: [KGKosten] {
        let base = positionen.filter { !LVPositionHelper.isAlternative($0) }.zaehlbarePositionen()
        let grouped = Dictionary(grouping: base, by: { $0.kostenGruppeNummer ?? "—" })
        return grouped.keys.sorted().map { kg in
            let items = grouped[kg] ?? []
            let gp = items.reduce(0.0) { sum, pos in
                sum + LVKalkulator.effektiverEP(for: pos, store: store) * pos.menge
            }
            let ohne = items.filter {
                LVKalkulator.effektiverEP(for: $0, store: store) == 0
            }.count
            return KGKosten(kg: kg, bezeichnung: dinBezeichnung(kg),
                            items: items, gesamtGP: gp, ohnePreis: ohne)
        }
    }

    private var gesamtNetto: Double  { kgKosten.reduce(0.0) { $0 + $1.gesamtGP } }
    private var mwstSatz:    Double  { FirmenSettings.mwstSatz }
    private var mwstBetrag:  Double  { gesamtNetto * mwstSatz / 100 }
    private var gesamtBrutto: Double { gesamtNetto + mwstBetrag }
    private var maxKGGP:     Double  { kgKosten.map { $0.gesamtGP }.max() ?? 1 }
    private var ohnePreisGesamt: Int { kgKosten.reduce(0) { $0 + $1.ohnePreis } }

    var body: some View {
        NavigationStack {
            List {

                // --- Gesamtkosten ---
                Section("Gesamtkosten") {
                    VStack(alignment: .leading, spacing: 10) {
                        row("Netto", value: gesamtNetto, font: .body)
                        row("MwSt. \(Int(mwstSatz)) %",
                            value: mwstBetrag,
                            font: .body,
                            color: .secondary)
                        Divider()
                        row("Brutto", value: gesamtBrutto, font: .headline, color: .orange)
                    }
                    .padding(.vertical, 4)
                }

                // --- Nach KG ---
                Section("Nach DIN 276 Kostengruppe") {
                    ForEach(kgKosten) { kg in
                        kgRow(kg)
                    }
                }

                // --- Fehlende Preise ---
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
            .navigationTitle("Kostenzusammenfassung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }

    // MARK: - Rows

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
    private func kgRow(_ kg: KGKosten) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("KG \(kg.kg)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
                Text(kg.bezeichnung).font(.subheadline)
                Spacer()
                Text(kg.gesamtGP, format: .currency(code: "EUR"))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(kg.gesamtGP == 0 ? .secondary : .primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(Color.orange.opacity(0.75))
                        .frame(width: max(4, geo.size.width
                                         * CGFloat(maxKGGP > 0 ? kg.gesamtGP / maxKGGP : 0)))
                }
            }
            .frame(height: 6)
            HStack {
                Text("\(kg.items.count) Pos.")
                    .font(.caption2).foregroundStyle(.secondary)
                if kg.ohnePreis > 0 {
                    Text("·").foregroundStyle(.secondary)
                    Text("\(kg.ohnePreis) ohne Preis")
                        .font(.caption2).foregroundStyle(.red)
                }
                Spacer()
                if gesamtNetto > 0 {
                    Text("\(Int((kg.gesamtGP / gesamtNetto) * 100)) %")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - DIN 276

    /// DIN-276-Bezeichnung zu einer KG-Nummer.
    /// Kommt aus DIN276KostenGruppe (abgeleitet aus dem Baum-Katalog) — vorher stand
    /// hier eine eigene switch-Kopie, die nur Hunderter/Zehner kannte.
    private func dinBezeichnung(_ kg: String) -> String {
        DIN276KostenGruppe.bezeichnung(fuer: kg)
    }
}
