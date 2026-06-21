//
//  AmpelCard.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 21.06.26.
//
import SwiftUI

struct AmpelCard: View {
    @ObservedObject var event: Event

    // Vereinfachte Logik für das Sofa-MVP
    private var ampelStatus: (farbe: Color, text: String) {
        let offeneMaengel = (event.maengel?.allObjects as? [Mangel] ?? []).filter { $0.status == .offen || $0.status == .inArbeit }.count

        // 1. Rote Ampel: Offene Mängel blockieren die Baufrei
        if offeneMaengel > 0 {
            return (.red, "Mängel offen – Baufrei blockiert")
        }
        
        // 2. Orange Ampel: Baustelle läuft, aber noch nicht fertig
        let auftraege = event.jobs?.allObjects as? [Auftrag] ?? []
        if !auftraege.isEmpty && auftraege.contains(where: { !$0.isCompleted }) {
            return (.orange, "Baustelle in Arbeit – teilweise Baufrei")
        }

        // 3. Grüne Ampel: Alles erledigt
        if !auftraege.isEmpty && auftraege.allSatisfy({ $0.isCompleted }) {
            return (.green, "Alle Aufträge erledigt – Baufrei erteilt")
        }

        // Default: Noch nichts los
        return (.gray, "Wartet auf Start – Voraussetzungen prüfen")
    }

    var body: some View {
        HStack(spacing: 16) {
            // Die Ampel selbst
            Circle()
                .fill(ampelStatus.farbe)
                .frame(width: 50, height: 50)
                .shadow(color: ampelStatus.farbe.opacity(0.5), radius: 8)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.5), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Voraussetzungs-Ampel")
                    .font(.headline)
                Text(ampelStatus.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

