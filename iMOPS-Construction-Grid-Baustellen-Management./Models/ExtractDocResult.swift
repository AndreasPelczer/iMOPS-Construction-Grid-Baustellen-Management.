import Foundation

/// Ergebnis der Stufe-2-Dokumenten-Extraktion (POST `/extract-doc`).
///
/// Das Backend (`mops-api`, `api/routes/extract_doc.py → ExtractDocResponse`) zieht aus
/// einem **Text-PDF** (Bodengutachten, Wohnflächenberechnung, Bebauungsplan, Erschließung)
/// die LV-relevanten Fakten und gibt sie als doctype-spezifisches JSON zurück.
///
/// `felder` ist bewusst `JSONValue` (locker typisiert), weil die Form je nach
/// erkanntem Doctype variiert. Human-in-the-loop: das Ergebnis ist ein **Entwurf**
/// (`meldung`), der geprüft werden muss — es ersetzt kein Gutachten / keinen Vermesser.
struct ExtractDocResult: Codable, Identifiable {
    let status: String
    let quelle: String
    let doctypeErkannt: String
    let confidence: Double
    let felder: JSONValue
    let model: String
    let meldung: String

    var id: String { quelle }

    enum CodingKeys: String, CodingKey {
        case status
        case quelle
        case doctypeErkannt = "doctype_erkannt"
        case confidence
        case felder
        case model
        case meldung
    }
}

extension ExtractDocResult {
    /// Menschenlesbares Label für den erkannten Doctype (für den Review-Header).
    var doctypeLabel: String {
        switch doctypeErkannt {
        case "bodengutachten": return "Bodengutachten"
        case "wohnflaeche":    return "Wohnfläche / Rauminhalt"
        case "bebauungsplan":  return "Bebauungsplan"
        case "erschliessung":  return "Erschließung"
        case "auto":           return "Allgemeines Dokument"
        default:                return doctypeErkannt
        }
    }

    /// SF-Symbol passend zum Doctype.
    var doctypeSymbol: String {
        switch doctypeErkannt {
        case "bodengutachten": return "square.3.layers.3d.down.right"
        case "wohnflaeche":    return "ruler"
        case "bebauungsplan":  return "map"
        case "erschliessung":  return "bolt.horizontal"
        default:                return "doc.text"
        }
    }
}
