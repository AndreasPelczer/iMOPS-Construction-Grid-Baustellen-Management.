import Foundation

/// Locker typisierter JSON-Wert für API-Felder, deren Form zur Compile-Zeit
/// nicht feststeht. Gebraucht für `/extract-doc` → `felder`: das Schema ist
/// **doctype-spezifisch** (Bodengutachten sieht anders aus als Wohnfläche oder
/// Erschließung), lässt sich also nicht in ein starres `Codable`-Struct pressen.
///
/// Der Review-Screen läuft den Baum generisch ab (siehe `UnterlageAuswertungView`),
/// darum reicht dieser eine Typ für alle vier Doctypes + den generischen Fallback.
indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        // Reihenfolge zählt: Bool VOR Number, sonst würde `true`/`false`
        // (in JSON kein Zahlwert) fälschlich als Zahl-Versuch scheitern und
        // umständlich weiterlaufen. Foundation dekodiert Bool nicht aus 0/1.
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: c, debugDescription: "Unbekannter JSON-Wert in /extract-doc-Feldern")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .bool(let b):   try c.encode(b)
        case .object(let o): try c.encode(o)
        case .array(let a):  try c.encode(a)
        case .null:          try c.encodeNil()
        }
    }
}

extension JSONValue {
    /// Menschenlesbare Kurzform eines Skalars (für die Wert-Spalte einer Zeile).
    /// Container (Objekt/Array) liefern `nil` — die werden aufgeklappt statt gezeigt.
    var skalarText: String? {
        switch self {
        case .string(let s):
            return s.isEmpty ? "—" : s
        case .number(let n):
            // Ganze Zahlen ohne ",0"; alles andere in deutscher Schreibweise.
            if n == n.rounded() && abs(n) < 1e15 {
                return String(Int(n))
            }
            return String(n).replacingOccurrences(of: ".", with: ",")
        case .bool(let b):
            return b ? "ja" : "nein"
        case .null:
            return "—"
        case .array, .object:
            return nil
        }
    }
}
