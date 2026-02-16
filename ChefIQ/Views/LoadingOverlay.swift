//
//  LoadingOverlay.swift
//  ChefIQApp
//
//  Created by Andreas Pelczer on 03.01.26.
//


import SwiftUI

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            // Ein halbtransparenter Hintergrund wie ein Kraftfeld
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Der "R2-D2" Gedenk-Ladekreis
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(2.0)
                
                VStack(spacing: 10) {
                    Text("Analysiere Daten...")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Verbindung zum Gemini-Holonet steht.")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                
                // Ein kleiner technischer Effekt
                Text("BIP-BOP-BIP")
                    .font(.caption2)
                    .foregroundColor(.blue.opacity(0.6))
                    .italic()
            }
            .padding(40)
            .background(VisualEffectBlur(blurStyle: .systemUltraThinMaterialDark))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
    }
}

// Hilfs-Struktur für den Blur-Effekt
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}