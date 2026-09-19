import Foundation

// MARK: - Zeitformat
//
// Feldforschung 19.9.: ein Bau-Mann kann „1,8 Stunden" nicht als Zeit erfassen — er
// denkt in Stunden UND Minuten. Diese Funktion macht aus Dezimalstunden eine menschliche
// Angabe: 1,8 → „1 Std 48 Min", 0,5 → „30 Min", 2,0 → „2 Std".

enum Zeitformat {
    static func menschlich(_ stunden: Double) -> String {
        let gesamtMin = Int((stunden * 60).rounded())
        let h = gesamtMin / 60
        let m = gesamtMin % 60
        if h == 0 { return "\(m) Min" }
        if m == 0 { return "\(h) Std" }
        return "\(h) Std \(m) Min"
    }
}
