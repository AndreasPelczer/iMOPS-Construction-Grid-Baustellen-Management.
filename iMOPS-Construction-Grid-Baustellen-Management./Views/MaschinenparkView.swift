//
//  MaschinenparkView.swift
//  Der ganze Maschinenpark auf einen Blick — ZUERST deine eigenen Geräte (Stammdaten, deine
//  Preise), DANN der Richtwert-Katalog aus maschinenkatalog.yaml (mit Quelle). Eigenes vor
//  Katalog, wie überall im Mops: dein Wert schlägt den Richtwert.
//

import SwiftUI
import CoreData

struct MaschinenparkView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Geraet.name, ascending: true)])
    private var firmenGeraete: FetchedResults<Geraet>

    @State private var suche = ""

    /// Katalog-Maschinen nach Sektion gruppiert (erdbau, verdichtung, …), gefiltert.
    private var katalogGruppen: [(String, [Maschine])] {
        let alle = MaschinenKatalog.shared.alle().filter { passt($0.bezeichnung) || passt($0.kategorie ?? "") }
        return Dictionary(grouping: alle, by: { $0.sektion })
            .map { ($0.key, $0.value.sorted { ($0.hauptLeistung?.wert ?? 0) > ($1.hauptLeistung?.wert ?? 0) }) }
            .sorted { $0.0 < $1.0 }
    }

    private var firmenGefiltert: [Geraet] {
        firmenGeraete.filter { passt($0.name ?? "") }
    }

    private func passt(_ s: String) -> Bool {
        suche.isEmpty || s.lowercased().contains(suche.lowercased())
    }

    var body: some View {
        List {
            // 1) DEIN Maschinenpark — zuerst, dein Wert vor Richtwert.
            Section {
                if firmenGefiltert.isEmpty {
                    Text("Noch keine eigenen Geräte. Leg deinen Maschinenpark in den Stammdaten an — dann rechnen die Angebote mit DEINEN Sätzen statt mit Richtwerten.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(firmenGefiltert, id: \.objectID) { g in firmenZeile(g) }
                }
            } header: {
                Label("Dein Maschinenpark (\(firmenGefiltert.count))", systemImage: "wrench.and.screwdriver.fill")
            } footer: {
                Text("Deine eigenen Geräte mit deinen Kosten (€/h aus Anschaffung ÷ Nutzungsdauer). Haben Vorrang vor dem Katalog.")
                    .font(.caption2)
            }

            // 2) Richtwert-Katalog (maschinenkatalog.yaml), nach Sektion.
            ForEach(katalogGruppen, id: \.0) { sektion, maschinen in
                Section(sektion.capitalized) {
                    ForEach(maschinen) { m in katalogZeile(m) }
                }
            }
        }
        .searchable(text: $suche, prompt: "Maschine suchen …")
        .navigationTitle("Maschinenpark")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Zeilen

    private func firmenZeile(_ g: Geraet) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(g.name ?? "Gerät").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(euro(g.kostenProStunde))/h").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                if g.leistung > 0 {
                    Text("\(zahl(g.leistung)) m³/h").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                QuelleBadge(quelle: .eigen)
            }
            if let n = g.notiz, !n.isEmpty {
                Text(n).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func katalogZeile(_ m: Maschine) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                Text(m.bezeichnung).font(.subheadline.weight(.medium))
                Spacer()
                if let tag = m.mieteTag {
                    Text("\(euro(tag))/Tag").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                if let l = m.hauptLeistung {
                    Text("\(zahl(l.wert)) \(l.einheit)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                QuelleBadge(quelle: .katalog)
                if !m.quelleKurz.isEmpty {
                    Text("Quelle: \(m.quelleKurz)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            if let s = m.brauchtSchein, !s.isEmpty, s.lowercased() != "keinen" {
                Text("Schein: \(s)").font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 2)
    }

    private func euro(_ d: Double) -> String { String(format: "%.0f €", d) }
    private func zahl(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }
}
