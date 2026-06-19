//
//  LVKalkulationView.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 19.06.26.
//
import SwiftUI
import CoreData

struct LVKalkulationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event
    
    @State private var totalPrice: Double = 0.0

    // Alle LV-Positionen als generische NSManagedObject laden
    private var positionen: [NSManagedObject] {
        let set = event.value(forKey: "lvPositionen") as? Set<NSManagedObject> ?? []
        return set.sorted { ($0.value(forKey: "posNr") as? String ?? "") < ($1.value(forKey: "posNr") as? String ?? "") }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(positionen, id: \.objectID) { pos in
                    HStack {
                        // Position & Bezeichnung
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pos.value(forKey: "posNr") as? String ?? "")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                            Text(pos.value(forKey: "bezeichnung") as? String ?? "")
                                .font(.body)
                        }
                        
                        Spacer()
                        
                        // Menge & Einheit
                        let menge = pos.value(forKey: "menge") as? Double ?? 0
                        let einheit = pos.value(forKey: "einheit") as? String ?? ""
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.2f", menge))
                                .font(.body.monospacedDigit())
                            Text(einheit)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 70, alignment: .trailing)
                        
                        // Preis-Eingabe
                        VStack(alignment: .trailing, spacing: 2) {
                            TextField("0,00", value: Binding<Double>(
                                get: { pos.value(forKey: "einkaufspreis") as? Double ?? 0.0 },
                                set: { newValue in
                                    pos.setValue(newValue, forKey: "einkaufspreis")
                                    try? viewContext.save()
                                    calculateTotal()
                                }
                            ), format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .textFieldStyle(.roundedBorder)
                            
                            // Zeilensumme
                            let preis = pos.value(forKey: "einkaufspreis") as? Double ?? 0
                            Text(String(format: "%.2f €", menge * preis))
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Summenleiste unten
            HStack {
                Text("Angebotssumme (netto):")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f €", totalPrice))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
        .navigationTitle("Kalkulation (Welle 6)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            calculateTotal()
        }
    }
    
    private func calculateTotal() {
        var sum = 0.0
        for pos in positionen {
            let menge = pos.value(forKey: "menge") as? Double ?? 0
            let preis = pos.value(forKey: "einkaufspreis") as? Double ?? 0
            sum += (menge * preis)
        }
        totalPrice = sum
    }
}
