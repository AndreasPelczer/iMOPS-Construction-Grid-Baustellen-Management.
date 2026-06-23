//
//  HausplanerDashboardView.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 22.06.26.
//
import SwiftUI

struct HausplanerDashboardView: View {
    // Dummy-Status zum Testen ohne Datenbank-Stress
    @State private var ausgewaehlteBaustelle: String? = nil
    
    var body: some View {
        NavigationSplitView {
            // --- LINKER REITER: Globale Baustellenliste ---
            List(selection: $ausgewaehlteBaustelle) {
                Section(header: Text("Aktive Projekte")) {
                    Text("Einfamilienhaus Wertheim").tag("projekt_1")
                    Text("Umbau Scheune").tag("projekt_2")
                }
            }
            .navigationTitle("iMOPS Planer")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Neue Baustelle anlegen
                    } label: {
                        Label("Planen", systemImage: "plus.app.fill")
                    }
                }
            }
        } detail: {
            // --- RECHTER REITER: Der Kontext-Morph ---
            if ausgewaehlteBaustelle != nil {
                // SONDERSTATUS: Baustelle offen -> Kontrollzentrum aktiv!
                BaustellenKontrollzentrumView()
            } else {
                // STANDARDSTATUS: Keine Baustelle offen -> Globales Planer-Tool aktiv!
                VStack(spacing: 20) {
                    Image(systemName: "pencil.and.rulers")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("Willkommen im iMOPS Planer-Tool")
                        .font(.title2.bold())
                    
                    Text("Wähle links eine Baustelle aus, um das Kontrollzentrum zu aktivieren, oder erstelle ein neues Projekt auf Basis statistischer Daten.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button {
                        ausgewaehlteBaustelle = "projekt_1" // Test-Klick simuliert Auswahl
                    } label: {
                        Text("Beispielprojekt laden (Die schöne Ansicht)")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
