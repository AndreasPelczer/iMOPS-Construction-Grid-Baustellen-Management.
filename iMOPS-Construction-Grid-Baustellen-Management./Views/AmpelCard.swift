//
//  AmpelCard.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 21.06.26.
//
import SwiftUI

struct AmpelCard: View {
    @ObservedObject var event: Event

    // 🔗 DIE KAUSALBAUKETTE: Sequentielle Prüfung von oben nach unten
    private var ampelStatus: (farbe: Color, text: String, subtext: String) {
        
        // -----------------------------------------------------------------
        // GLIED 1 & 2: RECHTLICH & BEHÖRDLICH (Die harte iMOPS-Bremse)
        // -----------------------------------------------------------------
        let baugenehmigung = event.baugenehmigungNr?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if baugenehmigung.isEmpty {
            return (
                .red,
                "Baustart BLOCKIERT",
                "Keine Baugenehmigungsnummer hinterlegt. Operative Gewerke gesperrt."
            )
        }
        
        // -----------------------------------------------------------------
        // GLIED 3: INFRASTRUCTUR (Baustrom, Bauwasser, Bauzaun)
        // -----------------------------------------------------------------
        let auftraege = event.jobs?.allObjects as? [Auftrag] ?? []
        
        // Wir suchen nach Infrastruktur-Aufträgen, die noch nicht fertig sind
        let infraOffen = auftraege.contains { job in
            let details = job.processingDetails?.lowercased() ?? ""
            let istInfra = details.contains("bauzaun") ||
                           details.contains("baustrom") ||
                           details.contains("bauwasser") ||
                           details.contains("einrichtung")
            return istInfra && !job.isCompleted
        }
        
        if infraOffen {
            return (
                .orange,
                "Infrastruktur unvollständig",
                "Baustelleneinrichtung, Strom oder Zaun fehlen. Teilweise Baufreiheit."
            )
        }
        
        // -----------------------------------------------------------------
        // GLIED 4: OPERATIV & QUALITÄT (Laufende Arbeiten & Mängel)
        // -----------------------------------------------------------------
        let offeneMaengel = (event.maengel?.allObjects as? [Mangel] ?? [])
            .filter { $0.status == .offen || $0.status == .inArbeit }.count
        
        if offeneMaengel > 0 {
            return (
                .red,
                "Mängel offen (\(offeneMaengel))",
                "Qualitätsmängel blockieren die nächste Abnahme-Stufe."
            )
        }
        
        // Prüfen, ob noch reguläre Handwerker-Aufträge offen sind
        let handwerkOffen = auftraege.contains(where: { !$0.isCompleted })
        if handwerkOffen {
            return (
                .orange,
                "Gewerke in Arbeit",
                "Baugenehmigung erteilt, Infrastruktur steht. Handwerker sind aktiv."
            )
        }

        // -----------------------------------------------------------------
        // ZIEL: ALLES ERLEDIGT
        // -----------------------------------------------------------------
        if !auftraege.isEmpty && auftraege.allSatisfy({ $0.isCompleted }) {
            return (
                .green,
                "Baufreiheit vollständig erteilt",
                "Alle Aufträge abgeschlossen, keine offenen Mängel. Projekt bereit zur Abnahme."
            )
        }

        // Default-Sicherheitsnetz
        return (
            .gray,
            "Wartet auf Start",
            "Projekt angelegt. Kausalbaukette bereit zur Validierung."
        )
    }

    var body: some View {
        HStack(spacing: 16) {
            // Die leuchtende iMOPS-Ampel
            Circle()
                .fill(ampelStatus.farbe)
                .frame(width: 50, height: 50)
                .shadow(color: ampelStatus.farbe.opacity(0.5), radius: 8)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 2)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(ampelStatus.text)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(ampelStatus.subtext)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
