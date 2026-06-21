//
//  MopsSecurityCore.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 21.06.26.
//

import Foundation

struct MopsSecurityCore {
    // Die fest einbetonierten Master-PINs für die System-Architekten (GOATs)
    // 1976 für dich, 2026 für Raffi – Kannst du hier jederzeit anpassen.
    private static let andreasMasterPin = "3466"
    private static let raffiMasterPin   = "2026"
    
    /// Prüft lautlos und ohne Datenabfluss, ob ein eingegebener PIN ein allmächtiger GOAT-Code ist.
    static func istGoatCode(_ pin: String) -> Bool {
        return pin == andreasMasterPin || pin == raffiMasterPin
    }
}
