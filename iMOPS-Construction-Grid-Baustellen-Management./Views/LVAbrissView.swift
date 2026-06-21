

//  LVAbrissSheet.swift
//  test25B
//
//  Created by Andreas Pelczer on 21.06.26.
//

import SwiftUI
import CoreData

struct LVAbrissSheet: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    
    let event: NSManagedObject // Deine Baustelle
    let baustellenName: String
    
    @State private var pinEingabe = ""
    @State private var fehlerMeldung = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    
                    Text("GESAMT-LV ATOMISIEREN")
                        .font(.title3.bold())
                    
                    Text("Du entleerst das komplette Leistungsverzeichnis der Baustelle:\n»\(baustellenName)«")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                VStack(spacing: 12) {
                    Text("Bitte 4-stelligen GOAT-Code eingeben:")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    
                    SecureField("GOAT-PIN", text: $pinEingabe)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 140)
                        .multilineTextAlignment(.center)
                        .onChange(of: pinEingabe) { _, newValue in
                            if newValue.count > 4 { pinEingabe = String(newValue.prefix(4)) }
                        }
                    
                    if !fehlerMeldung.isEmpty {
                        Text(fehlerMeldung)
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                        
                    }
                }
                .padding()
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("LV LEEREN") {
                        probiereLVAbriss()
                    }
                    .bold()
                    .foregroundStyle(.red)
                    .disabled(pinEingabe.count != 4)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func probiereLVAbriss() {
        if MopsSecurityCore.istGoatCode(pinEingabe) {
            // GOAT-Code verifiziert -> Wir holen alle Positionen dieses Events und löschen sie
            if let positionenSet = event.value(forKey: "lvPositionen") as? NSSet {
                for pos in positionenSet {
                    if let managedObject = pos as? NSManagedObject {
                        ctx.delete(managedObject)
                    }
                }
            }
            
            do {
                try ctx.save()
                print("💥 iMOPS: LV für \(baustellenName) erfolgreich geleert.")
                dismiss()
            } catch {
                fehlerMeldung = "Datenbank-Fehler: \(error.localizedDescription)"
            }
        } else {
            fehlerMeldung = "❌ CODE FALSCH! ZUGRIFF VERWEIGERT."
            pinEingabe = ""
        }
    }
}
