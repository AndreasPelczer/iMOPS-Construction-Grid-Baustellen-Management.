//
//  SnapshotProofView.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 17.01.26.
//


import SwiftUI

struct SnapshotProofView: View {
    let productName: String
    let category: String
    
    var body: some View {
        VStack(spacing: 15) {
            // 1. DER SCAN-RAHMEN (Der Beweis)
            ZStack {
                // Hintergrund: Ein dunkles Grau simuliert die Kamera-Optik
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black.opacity(0.8))
                    .frame(height: 200)
                
                // Platzhalter für das fehlende Foto
                VStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("Beweis-Snapshot")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Die "Scan-Ecken" (Grafik-Gimmick)
                VStack {
                    HStack { Image(systemName: "plus"); Spacer(); Image(systemName: "plus") }
                    Spacer()
                    HStack { Image(systemName: "plus"); Spacer(); Image(systemName: "plus") }
                }
                .padding()
                .foregroundColor(.orange.opacity(0.5))
                
                // Ein Overlay-Banner wie bei einem echten Scan-System
                VStack {
                    Spacer()
                    HStack {
                        Text("VERIFIED: \(productName.uppercased())")
                            .font(.system(size: 10, weight: .black))
                            .padding(6)
                            .background(Color.orange)
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            }
            .frame(height: 200)
            
            // 2. DIE ANALYSE-Werte (Was wurde "gemessen")
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("KATEGORIE").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                    Text(category).font(.subheadline).bold()
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading) {
                    Text("ZEITSTEMPEL").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                    Text(Date().formatted(date: .omitted, time: .shortened)).font(.subheadline).bold()
                }
                Divider().frame(height: 30)
                VStack(alignment: .leading) {
                    Text("STATUS").font(.system(size: 8, weight: .bold)).foregroundColor(.secondary)
                    Text("Checked").font(.subheadline).bold().foregroundColor(.green)
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

// Beispiel für die Einbindung in deiner MainView oder DetailView Preview:
struct SnapshotProof_Previews: PreviewProvider {
    static var previews: some View {
        SnapshotProofView(productName: "Hühnerbrust Supreme", category: "Geflügel")
            .padding()
    }
}