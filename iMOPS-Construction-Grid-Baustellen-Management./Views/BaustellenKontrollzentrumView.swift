//
//  BaustellenKontrollzentrumView.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 22.06.26.
//

import SwiftUI

struct BaustellenKontrollzentrumView: View {
    // --- ZUSTAND FÜR DEN KONFIGURATOR (Deine Eingaben) ---
    @State private var wohnflaeche: Double = 150
    @State private var stockwerke: Int = 2
    @State private var dachform: String = "Satteldach"
    
    // Steuer-Zustände
    @State private var istBerechnet = false
    @State private var aktuellerReiter = 0
    
    // Berechnete Werte (Andi-Sprech / Wunsch-Baseline)
    @State private var berechneteBasisKosten: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if !istBerechnet {
                // =========================================================
                // 1. DER PLANER (Die Grundberechnung / Sofa-Eingabe)
                // =========================================================
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "pencil.and.rulers")
                                .font(.title)
                                .foregroundStyle(.orange)
                            Text("iMOPS Haus-Konfigurator")
                                .font(.title.bold())
                        }
                        .padding(.top)
                        
                        Text("Gib hier die Eckdaten deines Bauvorhabens ein, um die kalkulatorische Baseline und die VOB-Reiter zu generieren.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Divider()
                        
                        // Eingabe-Felder
                        VStack(spacing: 15) {
                            HStack {
                                Text("Wohnfläche (m²)")
                                Spacer()
                                TextField("Fläche", value: $wohnflaeche, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 80)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            Stepper("Anzahl Stockwerke: \(stockwerke)", value: $stockwerke, in: 1...4)
                            
                            Picker("Dachform", selection: $dachform) {
                                Text("Satteldach").tag("Satteldach")
                                Text("Flachdach").tag("Flachdach")
                                Text("Walmdach").tag("Walmdach")
                            }
                            .pickerStyle(.menu)
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Der magische Berechnen-Knopf
                        Button {
                            // Einfache Gastro-Kalkulation: m² * fiktiver Baupreis (z.B. 2500€)
                            berechneteBasisKosten = wohnflaeche * 2500
                            withAnimation {
                                istBerechnet = true // Schaltet um ins Cockpit!
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "bolt.fill")
                                Text("Projekt berechnen & Reiter generieren")
                                    .bold()
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                }
                
            } else {
                // =========================================================
                // 2. DAS KONTROLLZENTRUM (Die 4 Reiter mit den Daten)
                // =========================================================
                VStack(spacing: 0) {
                    // Header mit Projekt-Eckdaten und Glossar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cockpit: Individualbau (\(Int(wohnflaeche))m², \(dachform))")
                                .font(.title3.bold())
                            Spacer()
                            Button("Zurück zur Planung") {
                                withAnimation { istBerechnet = false }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        // Unsere Spalten-Definition mit Fragezeichen
                        HStack(spacing: 20) {
                            HStack(spacing: 4) {
                                Circle().fill(.gray.opacity(0.5)).frame(width: 8, height: 8)
                                Text("Kostenschätzung: \(Int(berechneteBasisKosten), format: .currency(code: "EUR"))")
                                    .font(.caption)
                                    .italic()
                                GlossarButton(schluessel: "kostenschaetzung")
                            }
                            
                            HStack(spacing: 4) {
                                Circle().fill(.yellow).frame(width: 8, height: 8)
                                Text("Kostenanschlag: \(Int(berechneteBasisKosten * 1.05), format: .currency(code: "EUR"))")
                                    .font(.caption)
                                GlossarButton(schluessel: "kostenanschlag")
                            }
                            
                            HStack(spacing: 4) {
                                Circle().fill(.green).frame(width: 8, height: 8)
                                Text("Kostenfeststellung: --")
                                    .font(.caption).bold()
                                GlossarButton(schluessel: "kostenfeststellung")
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    Divider()
                    
                    // Segmentierter Schalter für die 4 Reiter
                    Picker("Gewerke", selection: $aktuellerReiter) {
                        Text("Nebenkosten").tag(0)
                        Text("Rohbau").tag(1)
                        Text("Ausbau").tag(2)
                        Text("Zeitplan").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Inhalt der Reiter (Hier füttern wir die berechneten Daten rein)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15) {
                            switch aktuellerReiter {
                            case 0:
                                Text("Reiter 1: Baunebenkosten & Architekt (KG 700)")
                                    .font(.headline)
                                Text("Geschätzte Gebühren: \(Int(berechneteBasisKosten * 0.05), format: .currency(code: "EUR"))")
                            case 1:
                                Text("Reiter 2: Rohbau & Konstruktion (KG 300)")
                                    .font(.headline)
                                Text("Beton & Erdarbeiten für \(dachform): \(Int(berechneteBasisKosten * 0.4), format: .currency(code: "EUR"))")
                            case 2:
                                Text("Reiter 3: Technik & Ausbau (KG 400)")
                                    .font(.headline)
                                Text("Heizung, Sanitär, Fliesen: \(Int(berechneteBasisKosten * 0.55), format: .currency(code: "EUR"))")
                            case 3:
                                Text("Reiter 4: Bauzeitenplan")
                                    .font(.headline)
                                Text("Voraussichtliche Bauzeit: \(stockwerke * 4) Monate")
                            default:
                                EmptyView()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}
