//
//  Erdbauleistung.swift
//  Wie lange braucht der Bagger? — Gerätestunden aus der Aushubmenge herleiten,
//  statt sie zu raten. Erstmal über einen RICHTWERT (m³ fester Boden je Stunde,
//  inkl. Laden/Umsetzen — der Praxiswert, nicht der theoretische Bagger-Wert).
//
//  Später ersetzt die Bagger-Simulation (Löffel × Spielzeit × Boden × Nutzungs-
//  grad) diesen Richtwert — die Struktur bleibt gleich: Stunden = Menge ÷ Leistung.
//
//  Die Richtwerte sind Firmensache; hier Startwerte. Gehören später in die
//  Geräte-Stammdaten.
//

import Foundation

enum Erdbauleistung {

    /// Richtwerte in **m³ (fester Boden) je Stunde**, inkl. Laden/Umsetzen.
    /// - Minibagger 4,4: entspricht der bisherigen Demo (≈ 35 m³ in 8 h). Andreas'
    ///   sehr vorsichtiger Praxiswert wäre 1,0 m³/h (dann ≈ 35 h) — bewusst noch
    ///   nicht gesetzt, siehe Rückfrage.
    static let minibagger: Double = 4.4
    static let bagger5t:   Double = 12.0
    static let bagger9t:   Double = 25.0

    /// Gerätestunden = Aushubmenge ÷ Leistung. Nachvollziehbar statt geschätzt.
    static func stunden(menge: Double, leistung: Double) -> Double {
        leistung > 0 ? menge / leistung : 0
    }
}
