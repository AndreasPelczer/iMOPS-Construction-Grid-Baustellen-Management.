//
//  GlossarButton.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 22.06.26.
//

import SwiftUI

struct GlossarButton: View {
    let schluessel: String // z.B. "kostenschaetzung"
    @State private var zeigeErklaerung = false
    
    var body: some View {
        if let eintrag = BauGlossar.eintraege[schluessel.lowercased()] {
            Button {
                zeigeErklaerung.toggle()
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
            // Das kleine Info-Fenster, das direkt am Fragezeichen aufploppt
            .popover(isPresented: $zeigeErklaerung) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(eintrag.begriff)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(eintrag.definition)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    Divider()
                    
                    HStack(alignment: .top, spacing: 6) {
                        Text("💡 iMOPS-Kern:")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text(eintrag.andiSprechErklaerung)
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Status: \(eintrag.farbCode)")
                        .font(.caption2.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding()
                .frame(width: 280)
                .presentationCompactAdaptation(.popover) // Erzwingt das kleine Popover auch auf dem iPhone
            }
        }
    }
}
