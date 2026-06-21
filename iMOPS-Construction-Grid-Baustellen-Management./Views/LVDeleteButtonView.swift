//
//  LVDeleteButtonView.swift
//  iMOPS-Construction-Grid-Baustellen-Management
//
//  Created by Andreas Pelczer on 21.06.26.
//

import SwiftUI
import CoreData

struct LVDeleteButtonView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss // Schließt die Detailansicht nach dem Löschen automatisch
    
    /// Der konkrete Auftrag (das LV), das vernichtet werden soll
    @ObservedObject var currentLV: Auftrag
    
    @State private var zeigeCodeEingabe = false
    @State private var pinEingabe = ""
    @State private var fehlerMeldung = ""
    
    var body: some View {
        VStack(spacing: 12) {
            if !zeigeCodeEingabe {
                // Der unschuldige, aber rote Knopf
                Button(role: .destructive) {
                    zeigeCodeEingabe = true
                    fehlerMeldung = ""
                } label: {
                    Label("Komplette Materialliste unwiderruflich löschen", systemImage: "trash.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                // Das aufgeploppte Nummernfeld
                VStack(spacing: 12) {
                    Text("⚠️ KRITISCHE AKTION")
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                    
                    Text("Bitte 4-stelligen GOAT-Code eingeben, um diese Liste restlos zu vernichten:")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        SecureField("GOAT-PIN", text: $pinEingabe)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 120)
                            .multilineTextAlignment(.center)
                            .onChange(of: pinEingabe) { _, newValue in
                                if newValue.count > 4 { pinEingabe = String(newValue.prefix(4)) }
                            }
                        
                        Button("Bestätigen") {
                            probiereLoeschen()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(pinEingabe.count != 4)
                    }
                    
                    if !fehlerMeldung.isEmpty {
                        Text(fehlerMeldung)
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                    }
                    
                    Button("Abbrechen") {
                        zeigeCodeEingabe = false
                        pinEingabe = ""
                        fehlerMeldung = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemRed).opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.vertical)
    }
    
    /// Die CoreData-Abrissbirne
    private func probiereLoeschen() {
        // Nutzen wir unser schickes Sicherheits-Uhrwerk!
        if MopsSecurityCore.istGoatCode(pinEingabe) {
            print("💥 iMOPS GOAT-Schnittstelle: Lösche Auftrag \(currentLV.processingDetails ?? "")")
            
            ctx.delete(currentLV)
            
            do {
                try ctx.save()
                zeigeCodeEingabe = false
                dismiss() // Wir springen elegant zurück in die Hauptliste, da die Daten weg sind!
            } catch {
                fehlerMeldung = "Fehler beim Datenbank-Delete: \(error.localizedDescription)"
            }
        } else {
            print("🚨 iMOPS ALARM: Unberechtigter Löschversuch mit PIN: \(pinEingabe)")
            fehlerMeldung = "❌ CODE FALSCH! ZUGRIFF VERWEIGERT."
            pinEingabe = ""
        }
    }
}
