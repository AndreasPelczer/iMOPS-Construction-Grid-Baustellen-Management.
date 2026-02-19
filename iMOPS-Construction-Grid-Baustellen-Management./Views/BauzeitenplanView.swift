//
//  BauzeitenplanView.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Gantt-artige Darstellung des Bauzeitenplans.
//

import SwiftUI

struct BauzeitenplanView: View {
    let phasen: [Bauphase]

    private var maxWoche: Int {
        phasen.map { $0.endeWoche }.max() ?? 1
    }

    private var gewerkeColors: [String: Color] {
        [
            "Rohbau": .brown,
            "Erdarbeiten": .orange,
            "Dach": .red,
            "Fenster & Tueren": .cyan,
            "Elektro": .yellow,
            "Sanitaer": .blue,
            "Heizung": .pink,
            "Trockenbau": .purple,
            "Estrich & Boden": .gray,
            "Malerarbeiten": .mint,
            "Aussenanlagen": .green,
            "Ausbau": .teal,
            "Allgemein": .indigo
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Bauzeitenplan").font(.headline)
                Spacer()
                Text("\(maxWoche) Wochen Bauzeit")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Monats-Leiste
            monatsLeiste

            // Gantt-Balken
            VStack(spacing: 6) {
                ForEach(phasen) { phase in
                    ganttRow(phase)
                }
            }

            // Legende
            legendeView
        }
    }

    // MARK: - Monats-Leiste

    private var monatsLeiste: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let monateAnzahl = max(1, (maxWoche + 3) / 4) // ~4 Wochen pro Monat

            HStack(spacing: 0) {
                ForEach(0..<monateAnzahl, id: \.self) { monat in
                    Text("M\(monat + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: totalWidth / CGFloat(monateAnzahl))
                }
            }
        }
        .frame(height: 16)
    }

    // MARK: - Gantt-Zeile

    private func ganttRow(_ phase: Bauphase) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Label
            HStack(spacing: 6) {
                Text(phase.name)
                    .font(.caption2)
                    .lineLimit(1)
                Spacer()
                Text("KW \(phase.startWoche)–\(phase.endeWoche)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Balken
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let startFraction = CGFloat(phase.startWoche) / CGFloat(max(1, maxWoche))
                let durationFraction = CGFloat(phase.dauerWochen) / CGFloat(max(1, maxWoche))
                let barColor = gewerkeColors[phase.gewerk] ?? .gray

                ZStack(alignment: .leading) {
                    // Hintergrund-Schiene
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray6))
                        .frame(height: 14)

                    // Phase-Balken
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.opacity(0.8))
                        .frame(
                            width: max(8, totalWidth * durationFraction),
                            height: 14
                        )
                        .offset(x: totalWidth * startFraction)
                }
            }
            .frame(height: 14)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Legende

    private var legendeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gewerke").font(.caption.bold()).foregroundStyle(.secondary)

            let gewerke = Array(Set(phasen.map { $0.gewerk })).sorted()
            let columns = [GridItem(.adaptive(minimum: 130), spacing: 8)]

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(gewerke, id: \.self) { gewerk in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(gewerkeColors[gewerk] ?? .gray)
                            .frame(width: 14, height: 14)
                        Text(gewerk)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
}
