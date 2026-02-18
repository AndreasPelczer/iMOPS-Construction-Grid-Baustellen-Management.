// Views/EventRowView.swift (NEU: Mit Fortschrittsbalken-Logik)

import SwiftUI

struct EventRowView: View {
    @ObservedObject var event: Event
    
    // Kommentar: ViewModel-Helper zur Berechnung der Fortschrittszahlen
    private var progress: EventJobProgressData {
        EventJobProgressData(event: event)
    }
    
    // Hilfsfunktion zur Berechnung der Breite des Balkens
    private func widthRatio(for count: Int) -> CGFloat {
        guard progress.totalJobs > 0 else { return 0 }
        return CGFloat(count) / CGFloat(progress.totalJobs)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // MARK: - Event-Details (unverändert)
            HStack {
                            Text(event.title ?? "Unbekanntes Event")
                                .font(.headline)
                            Spacer()
                            // Kommentar: Verwenden Sie eventStartTime wie in ContentView definiert
                            Text(event.eventStartTime ?? Date(), style: .date) // <--- eventStartTime verwenden
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
            
            // MARK: - Fortschrittsbalken (Hauptelement)
            // Kommentar: Zeigt den Fortschritt des Events an
            if progress.totalJobs > 0 {
                HStack(spacing: 0) {
                    GeometryReader { proxy in
                        HStack(spacing: 0) {
                            let totalWidth = proxy.size.width
                            
                            // 1. Abgeschlossene Aufträge (Grün)
                            // Kommentar: Balken für abgeschlossene Jobs
                            Color.green
                                .frame(width: totalWidth * widthRatio(for: progress.completedCount))
                            
                            // 2. In Bearbeitung (Orange)
                            // Kommentar: Balken für aktuell laufende Jobs
                            Color.orange
                                .frame(width: totalWidth * widthRatio(for: progress.inProgressCount))
                            
                            // 3. Pausiert (Rot)
                            // Kommentar: Balken für pausierte Jobs
                            Color.red
                                .frame(width: totalWidth * widthRatio(for: progress.onHoldCount))
                            
                            // 4. Neu/Pending (Blau)
                            // Kommentar: Balken für neue/wartende Jobs
                            Color.blue
                                .frame(width: totalWidth * widthRatio(for: progress.pendingCount))
                            
                            // 5. Restlicher Platz (Grau) - Nur als Fallback, falls die Summe < 1.0 ist
                            Color(.systemGray5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .frame(height: 6)
                }
            } else {
                // Kommentar: Meldung, wenn keine Aufträge vorhanden sind
                Text("Keine Aufträge vorhanden")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
