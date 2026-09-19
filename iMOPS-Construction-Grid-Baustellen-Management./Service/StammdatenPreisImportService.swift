import Foundation
import CoreData

// MARK: - StammdatenPreisImportService
//
// Der fehlende Baustein: Preislisten (Material + Lohn) EN BLOC in die Stammdaten
// bringen, statt jede Zahl von Hand in die Stammdaten-Pflege zu tippen. Bisher lagen
// Lieferantenlisten wochenlang auf der Platte, weil dieser Weg fehlte.
//
// TAO: Nachweis statt Behauptung. Der Import meldet nicht "fertig", sondern gibt einen
// ANKUNFTS-BERICHT zurück — was NEU angelegt, was AKTUALISIERT (alt→neu), was
// übersprungen wurde, Zeile für Zeile. Danach ist in der Stammdaten-Pflege / im
// Preis-Check sichtbar, dass die Zahl WIRKLICH liegt. Kein blindes "eingebaut".
//
// Idempotent: derselbe Import ein zweites Mal ändert nichts (Match über den Namen).
// Keine Kundendaten im Repo: der Mechanismus ist generisch, die Preis-CSV bleibt lokal.
//
// CSV-Format (Semikolon-getrennt, deutsches Excel; Komma-Dezimal erlaubt):
//   typ;name;einheit;preis;lieferant
//   material;Beton C25/30;m3;130,00;Transportbeton (Markt)
//   material;Ytong 24 PPW2/0,35;m2;34,00;Xella-Liste
//   lohn;Eisenflechter;h;47,00;
// - typ: "material" -> KalkMaterial, "lohn" -> Lohnsatz. Fehlt/unklar -> material.
// - lieferant ist optional und trägt die HERKUNFT der Zahl (Xella, Markt, dein Wert …).
// - Eine Kopfzeile (beginnt mit "typ" oder enthält "name") wird erkannt und übersprungen.

struct PreisImportBericht: Identifiable {
    let id = UUID()
    struct Aenderung { let name: String; let alt: Double; let neu: Double; let einheit: String }

    var neuMaterial: [String] = []
    var aktualisiertMaterial: [Aenderung] = []
    var unveraendertMaterial: [String] = []
    var neuLohn: [String] = []
    var aktualisiertLohn: [Aenderung] = []
    var unveraendertLohn: [String] = []
    var neuLeistung: [String] = []          // Firma-Preis-Katalog: EH-Preis je Leistung
    var aktualisiertLeistung: [Aenderung] = []
    var unveraendertLeistung: [String] = []
    var uebersprungen: [String] = []      // Zeile + Grund
    var gesamtZeilen = 0

    var landetGesamt: Int {
        neuMaterial.count + aktualisiertMaterial.count + neuLohn.count + aktualisiertLohn.count
            + neuLeistung.count + aktualisiertLeistung.count
    }
    var alleLiegen: Int {
        landetGesamt + unveraendertMaterial.count + unveraendertLohn.count + unveraendertLeistung.count
    }
}

struct StammdatenPreisImportService {

    static let shared = StammdatenPreisImportService()

    // MARK: - Eintrittspunkte

    /// Aus einer Datei importieren (CSV/TXT).
    func importiere(von url: URL, in ctx: NSManagedObjectContext) -> PreisImportBericht {
        guard let inhalt = try? String(contentsOf: url, encoding: .utf8) else {
            var b = PreisImportBericht()
            b.uebersprungen.append("Datei nicht lesbar: \(url.lastPathComponent)")
            return b
        }
        return importiere(csv: inhalt, in: ctx)
    }

    /// Aus CSV-Text importieren (testbar ohne Datei).
    func importiere(csv text: String, in ctx: NSManagedObjectContext) -> PreisImportBericht {
        var bericht = PreisImportBericht()

        let zeilen = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, zeile) in zeilen.enumerated() {
            // Kopfzeile überspringen (nur die erste, wenn sie wie ein Header aussieht).
            if index == 0 && istKopfzeile(zeile) { continue }

            let spalten = zeile.components(separatedBy: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard spalten.count >= 3 else {
                bericht.uebersprungen.append("„\(zeile)“ — zu wenige Spalten (typ;name;einheit;preis;lieferant)")
                continue
            }
            bericht.gesamtZeilen += 1

            let typ = spalten[0].lowercased()
            let name = spalten[1]
            let einheit = spalten.count > 2 ? spalten[2] : ""
            let preisText = spalten.count > 3 ? spalten[3] : ""
            let lieferant = spalten.count > 4 ? spalten[4] : ""

            guard !name.isEmpty else {
                bericht.uebersprungen.append("„\(zeile)“ — kein Name")
                continue
            }
            guard let preis = preisWert(preisText), preis > 0 else {
                bericht.uebersprungen.append("„\(zeile)“ — kein gültiger Preis")
                continue
            }

            if typ == "lohn" {
                verarbeiteLohn(name: name, preis: preis, in: ctx, bericht: &bericht)
            } else if typ == "leistung" {
                verarbeiteLeistung(name: name, einheit: einheit, preis: preis,
                                   lieferant: lieferant, in: ctx, bericht: &bericht)
            } else {
                verarbeiteMaterial(name: name, einheit: einheit, preis: preis,
                                   lieferant: lieferant, in: ctx, bericht: &bericht)
            }
        }

        if bericht.landetGesamt > 0 {
            try? ctx.save()
        }
        return bericht
    }

    // MARK: - Material -> KalkMaterial

    private func verarbeiteMaterial(name: String, einheit: String, preis: Double,
                                    lieferant: String, in ctx: NSManagedObjectContext,
                                    bericht: inout PreisImportBericht) {
        if let vorhanden = findeMaterial(name: name, in: ctx) {
            let alt = vorhanden.preisProEinheit
            if abs(alt - preis) < 0.001 {
                bericht.unveraendertMaterial.append(name)
            } else {
                vorhanden.preisProEinheit = preis
                vorhanden.letzteAktualisierung = Date()
                if !lieferant.isEmpty { vorhanden.lieferant = lieferant }
                if !einheit.isEmpty { vorhanden.einheit = einheit }
                bericht.aktualisiertMaterial.append(
                    .init(name: name, alt: alt, neu: preis, einheit: vorhanden.einheit ?? einheit))
            }
        } else {
            let km = KalkMaterial(context: ctx)
            km.id = UUID()
            km.name = name
            km.einheit = einheit.isEmpty ? "Stk" : einheit
            km.preisProEinheit = preis
            km.lieferant = lieferant.isEmpty ? "Import" : lieferant
            km.letzteAktualisierung = Date()
            bericht.neuMaterial.append(name)
        }
    }

    // MARK: - Leistung -> Firma-Preis am Leistungsbaustein

    /// Fertigen EH-Preis (Verkaufspreis) je Leistungstext in den Firma-Katalog schreiben.
    /// Match über Leistungstext + Einheit (LeistungskatalogService.finde). Idempotent.
    private func verarbeiteLeistung(name: String, einheit: String, preis: Double,
                                    lieferant: String, in ctx: NSManagedObjectContext,
                                    bericht: inout PreisImportBericht) {
        if let vorhanden = LeistungskatalogService.finde(leistung: name, einheit: einheit, in: ctx) {
            let alt = vorhanden.einheitspreisVK
            if abs(alt - preis) < 0.001 {
                bericht.unveraendertLeistung.append(name)
            } else {
                vorhanden.einheitspreisVK = preis
                bericht.aktualisiertLeistung.append(
                    .init(name: name, alt: alt, neu: preis, einheit: vorhanden.einheit ?? einheit))
            }
        } else {
            let b = Leistungsbaustein(context: ctx)
            b.id = UUID()
            b.leistung = name
            b.einheit = einheit.isEmpty ? "psch" : einheit
            b.einheitspreisVK = preis
            b.quelle = lieferant.isEmpty ? "firma-katalog" : lieferant
            b.erstelltAm = Date()
            bericht.neuLeistung.append(name)
        }
    }

    // MARK: - Lohn -> Lohnsatz

    private func verarbeiteLohn(name: String, preis: Double, in ctx: NSManagedObjectContext,
                                bericht: inout PreisImportBericht) {
        // preis = Brutto-EK je Stunde; wie beim Hand-Lernen: stundenlohn=preis, Zuschlag 1,0
        // (berechnungBruttoEK = stundenlohn × zuschlagFaktor = der eingegebene Brutto).
        if let vorhanden = findeLohn(qualifikation: name, in: ctx) {
            let alt = vorhanden.berechnungBruttoEK
            if abs(alt - preis) < 0.001 {
                bericht.unveraendertLohn.append(name)
            } else {
                vorhanden.stundenlohn = preis
                vorhanden.zuschlagFaktor = 1.0
                bericht.aktualisiertLohn.append(.init(name: name, alt: alt, neu: preis, einheit: "h"))
            }
        } else {
            let ls = Lohnsatz(context: ctx)
            ls.id = UUID()
            ls.qualifikation = name
            ls.stundenlohn = preis
            ls.zuschlagFaktor = 1.0
            bericht.neuLohn.append(name)
        }
    }

    // MARK: - Helfer

    private func istKopfzeile(_ zeile: String) -> Bool {
        let z = zeile.lowercased()
        return z.hasPrefix("typ;") || (z.contains("name") && z.contains("preis"))
    }

    /// Deutsche (Komma) und englische (Punkt) Dezimalschreibweise; Tausenderpunkte weg.
    private func preisWert(_ text: String) -> Double? {
        var t = text.replacingOccurrences(of: "€", with: "")
                    .replacingOccurrences(of: " ", with: "")
        if t.contains(",") {
            // deutsches Format: Punkt = Tausender, Komma = Dezimal
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        return Double(t)
    }

    private func findeMaterial(name: String, in ctx: NSManagedObjectContext) -> KalkMaterial? {
        let req: NSFetchRequest<KalkMaterial> = KalkMaterial.fetchRequest()
        req.predicate = NSPredicate(format: "name ==[c] %@", name)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }

    private func findeLohn(qualifikation: String, in ctx: NSManagedObjectContext) -> Lohnsatz? {
        let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
        req.predicate = NSPredicate(format: "qualifikation ==[c] %@", qualifikation)
        req.fetchLimit = 1
        return (try? ctx.fetch(req))?.first
    }
}
