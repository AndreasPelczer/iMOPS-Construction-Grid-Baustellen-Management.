//
//  MopsSessionManager.swift
//  iMOPS-Construction-Grid-Baustellen-Management
//
//  Created by Andreas Pelczer on 21.06.26.
//

import SwiftUI
import CoreData
import Combine // <-- Das hier ist der magische Schlüssel!

/// Der zentrale System-Kern, der steuert, welcher Handwerker gerade den Mops bedient.
class MopsSessionManager: ObservableObject {
    
    /// Der aktuell aktive Nutzer auf der Baustelle. Wenn `nil`, ist das Gerät im Sperrbildschirm.
    @Published var aktiverNutzer: Employee?
    
    /// Zeigt an, ob das System im allmächtigen Meistermodus (Du & Raffi) operiert.
    @Published var istMeisterModusAktiv: Bool = false
    
    /// Versucht lautlos, einen Nutzer per PIN anzumelden.
    func versucheLogin(fuer user: Employee, mit pin: String) -> Bool {
        // 1. Doppelter Check: Ist es ein allmächtiger GOAT-Code von Andreas oder Raffi?
        if MopsSecurityCore.istGoatCode(pin) {
            self.aktiverNutzer = user
            self.istMeisterModusAktiv = true
            print("🔑 GOAT-Einbruch: Meistermodus für \(user.name ?? "Unbekannt") freigeschaltet.")
            return true
        }
        
        // 2. Regulärer Check: Passt der PIN zum hinterlegten Mitarbeiter-Profil?
        if let hinterlegterPin = user.pin, hinterlegterPin == pin {
            self.aktiverNutzer = user
            self.istMeisterModusAktiv = (user.rolle == "GOAT")
            print("👷‍♂️ Normaler Baustellen-Login: \(user.name ?? "") als \(user.rolle ?? "") angemeldet.")
            return true
        }
        
        // 3. Fallback: Wenn der Arbeiter gar keinen PIN hat, darf er ohne Sperre rein
        if (user.pin ?? "").isEmpty && user.rolle != "Polier" && user.rolle != "GOAT" {
            self.aktiverNutzer = user
            self.istMeisterModusAktiv = false
            print("🔓 Freier Zugang: Arbeiter \(user.name ?? "") ohne PIN eingeloggt.")
            return true
        }
        
        print("❌ Alarm: Falscher PIN-Versuch für \(user.name ?? "").")
        return false
    }
    
    /// Beendet die Schicht auf dem Gerät und sperrt den Mops für den nächsten Arbeiter.
    func logout() {
        self.aktiverNutzer = nil
        self.istMeisterModusAktiv = false
        print("🔒 Mops erfolgreich gesperrt. Bereit für Schichtwechsel.")
    }
}
