//
//  NormenSpurView.swift
//  Die berührten DIN-Normen — blass im Hintergrund, ambient statt mahnend.
//  „Gute Systeme sind still": wer dran gedacht hat, sieht Bestätigung; wer nicht,
//  stolpert leise drüber. Kein Alarm, keine Rechtsberatung.
//

import SwiftUI

struct NormenSpurView: View {
    let normen: [Baunorm]

    var body: some View {
        if normen.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("NORMEN-SPUR")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text("berührt — keine Rechtsberatung")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(normen) { norm in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(norm.id)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(.tint)
                                .frame(minWidth: 92, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(norm.was)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(norm.quelleKurz)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.quaternary.opacity(0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.quaternary)
            )
            .opacity(0.78)   // das „blasse" Wasserzeichen
            .tint(.blue)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Berührte Normen: " + normen.map(\.id).joined(separator: ", "))
        }
    }
}

#Preview {
    ScrollView {
        NormenSpurView(normen: Baunormen.berührt(
            vonLeistungen: ["Betonpflaster verlegen, abrütteln",
                            "Schottertragschicht 0/32",
                            "Baustelleneinrichtung",
                            "Randeinfassung Tiefbord in Beton"],
            hatLV: true))
        .padding()
    }
}
