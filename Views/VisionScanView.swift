//
//  VisionScanView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//  Phase 2: ChefIQ Scanner Integration

import SwiftUI

/// Scan-Tab: Zeigt OmniProdukte, Seubert-Inventar-Suche, Scanner und AI-Analyse
struct VisionScanView: View {
    @State private var hub = IntelligenceHub()
    @State private var showingScanner = false
    @State private var searchText = ""
    @State private var seubertResults: [SeubertItem] = []

    var body: some View {
        VStack(spacing: 0) {
            // HEADER
            VStack(spacing: 4) {
                Text("iMOPS // ChefIQ")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                Text("Omni Scanner + Klinische Analyse")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(.top, 8)

            List {
                // 1. SYSTEM STATUS (KI-Fakten)
                Section(header: Label("SYSTEM STATUS", systemImage: "cpu")) {
                    Text(hub.nutritionNews)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.secondary)
                }

                // 2. OMNI PRODUKTE (aus Produkt.json)
                Section("Omni Produkte // iMOPS") {
                    let displayList = searchText.isEmpty ? hub.allProducts : hub.allProducts.filter {
                        $0.name.lowercased().contains(searchText.lowercased())
                    }

                    ForEach(displayList) { product in
                        Button(action: {
                            hub.triggerMumpsAnalysis(for: product)
                        }) {
                            HStack {
                                Image(systemName: "bolt.horizontal.circle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text(product.name).bold()
                                    Text("Kat: \(product.mumpsCategory) | \(product.baseTemperature)°C | \(product.baseTime) Min.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // 3. SEUBERT INVENTAR (CSV-Suche)
                if !seubertResults.isEmpty {
                    Section("Seubert Inventar") {
                        ForEach(seubertResults) { item in
                            Button(action: {
                                hub.activeSeubert = item
                                hub.showSeubertDetail = true
                            }) {
                                HStack {
                                    Image(systemName: "shippingbox.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(item.name).bold()
                                        HStack(spacing: 4) {
                                            Text(item.category)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            if !item.allergenCodes.isEmpty {
                                                Text("Allergene: \(item.allergenCodes)")
                                                    .font(.caption2)
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Produkt, iMOPS-ID oder Seubert...")

            // SCAN BUTTON
            Button(action: { showingScanner = true }) {
                HStack {
                    Image(systemName: "camera.viewfinder")
                    Text("iMOPS: Omni-Scan starten")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(radius: 4)
            }
            .padding()
        }
        .navigationTitle("Scan")
        .sheet(isPresented: $showingScanner) {
            ScannerView(hub: hub)
        }
        .navigationDestination(isPresented: $hub.showAIDetail) {
            ResultDetailView(hub: hub)
        }
        .sheet(isPresented: $hub.showSeubertDetail) {
            if let item = hub.activeSeubert {
                NavigationStack {
                    SeubertDetailView(item: item)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Fertig") { hub.showSeubertDetail = false }
                            }
                        }
                }
            }
        }
        .onChange(of: searchText) {
            seubertResults = hub.searchSeubert(query: searchText)
        }
    }
}
