import Foundation
import UniformTypeIdentifiers

// MARK: - Importergebnis

struct MaterialImportResult {
    let items: [AuftragLineItem]
    let fehler: [String]
}

// MARK: - Service

/// Parst SketchUp-Materiallisten (CSV oder JSON) und ordnet Positionen
/// automatisch DIN-276-Kostengruppen zu.
///
/// Unterstützte CSV-Formate (Semikolon oder Komma getrennt):
///   Name;Menge;Einheit
///   Name;Menge;Einheit;Notiz
///   SketchUp-Generate-Report-Format: Name,Count,Volume,Area,Length
///
/// Unterstütztes JSON-Format:
///   [ { "name": "...", "menge": "...", "einheit": "...", "notiz": "..." }, ... ]
struct MaterialImportService {

    static let shared = MaterialImportService()

    private let kg = KGZuordnungsService.shared

    // MARK: - Haupt-Eintrittspunkt

    func importiere(von url: URL) -> MaterialImportResult {
        let ext = url.pathExtension.lowercased()
        guard let inhalt = try? String(contentsOf: url, encoding: .utf8) else {
            return MaterialImportResult(items: [], fehler: ["Datei konnte nicht gelesen werden: \(url.lastPathComponent)"])
        }

        switch ext {
        case "json":
            return parseJSON(inhalt)
        case "csv", "txt":
            return parseCSV(inhalt)
        default:
            let jsonResult = parseJSON(inhalt)
            if !jsonResult.items.isEmpty { return jsonResult }
            return parseCSV(inhalt)
        }
    }

    // MARK: - CSV Parser

    private func parseCSV(_ text: String) -> MaterialImportResult {
        var items: [AuftragLineItem] = []
        var fehler: [String] = []

        let zeilen = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let ersteZeile = zeilen.first else {
            return MaterialImportResult(items: [], fehler: ["Datei ist leer"])
        }

        // String statt Character – components(separatedBy:) erwartet String oder CharacterSet
        let trenner: String = ersteZeile.contains(";") ? ";" : ","

        let startIndex = istHeaderZeile(ersteZeile, trenner: trenner) ? 1 : 0

        for (i, zeile) in zeilen[startIndex...].enumerated() {
            let spalten = zeile.components(separatedBy: trenner)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }

            guard let name = spalten.first, !name.isEmpty else {
                fehler.append("Zeile \(i + startIndex + 1): leerer Name — übersprungen")
                continue
            }

            let (menge, einheit, notiz) = extrahiereMengeEinheitNotiz(spalten: spalten, trenner: trenner)

            let kgNummer = kg.ordneZu(materialName: name) ?? ""

            items.append(AuftragLineItem(
                title: name,
                amount: menge,
                unit: einheit,
                note: notiz,
                kostenGruppeNummer: kgNummer
            ))
        }

        return MaterialImportResult(items: items, fehler: fehler)
    }

    // MARK: - JSON Parser

    private func parseJSON(_ text: String) -> MaterialImportResult {
        guard let data = text.data(using: .utf8) else {
            return MaterialImportResult(items: [], fehler: ["Ungültiges UTF-8"])
        }

        if let roh = try? JSONDecoder().decode([RohMaterial].self, from: data) {
            return konvertiereRohMaterialien(roh)
        }

        if let wrapper = try? JSONDecoder().decode(MaterialWrapper.self, from: data) {
            return konvertiereRohMaterialien(wrapper.materials)
        }

        return MaterialImportResult(items: [], fehler: ["JSON-Format nicht erkannt"])
    }

    private func konvertiereRohMaterialien(_ rohliste: [RohMaterial]) -> MaterialImportResult {
        var items: [AuftragLineItem] = []
        var fehler: [String] = []

        for roh in rohliste {
            let name = roh.name ?? roh.bezeichnung ?? roh.title ?? ""
            guard !name.isEmpty else {
                fehler.append("Eintrag ohne Namen übersprungen")
                continue
            }
            let menge = roh.menge ?? roh.amount ?? roh.quantity ?? roh.count.map(String.init) ?? ""
            let einheit = roh.einheit ?? roh.unit ?? ""
            let notiz = roh.notiz ?? roh.note ?? roh.beschreibung ?? ""
            let kgNummer = kg.ordneZu(materialName: name) ?? ""

            items.append(AuftragLineItem(
                title: name,
                amount: menge,
                unit: einheit,
                note: notiz,
                kostenGruppeNummer: kgNummer
            ))
        }

        return MaterialImportResult(items: items, fehler: fehler)
    }

    // MARK: - Hilfsmethoden

    private func istHeaderZeile(_ zeile: String, trenner: String) -> Bool {
        let first = zeile.components(separatedBy: trenner).first?.lowercased() ?? ""
        let headerBegriffe = ["name", "bezeichnung", "material", "bauteil", "beschreibung", "title", "position"]
        return headerBegriffe.contains(where: { first.contains($0) })
    }

    private func extrahiereMengeEinheitNotiz(spalten: [String], trenner: String) -> (menge: String, einheit: String, notiz: String) {
        if spalten.count >= 3 {
            let kandidatMenge = spalten[1]
            let kandidatEinheit = spalten[2]
            let notiz = spalten.count >= 4 ? spalten[3] : ""
            if Double(kandidatMenge.replacingOccurrences(of: ",", with: ".")) != nil {
                return (kandidatMenge, kandidatEinheit, notiz)
            }
            if let _ = Int(kandidatMenge) {
                return (kandidatMenge, "Stk", "")
            }
        }
        if spalten.count == 2 {
            return (spalten[1], "", "")
        }
        return ("", "", "")
    }

    // MARK: - Decodierbare Hilfsstrukturen

    private struct RohMaterial: Decodable {
        let name: String?
        let bezeichnung: String?
        let title: String?
        let menge: String?
        let amount: String?
        let quantity: String?
        let count: Int?
        let einheit: String?
        let unit: String?
        let notiz: String?
        let note: String?
        let beschreibung: String?
    }

    private struct MaterialWrapper: Decodable {
        let materials: [RohMaterial]
    }
}

// MARK: - UTType Erweiterung für Document Picker

extension UTType {
    static let materialCSV = UTType(filenameExtension: "csv") ?? .plainText
    static let materialJSON = UTType(filenameExtension: "json") ?? .json
}
