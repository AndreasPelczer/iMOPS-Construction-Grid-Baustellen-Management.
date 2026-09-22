import Foundation
import CoreData

/// „Die Firma" von einem Gerät aufs andere bringen — Stammdaten (Materialien, Löhne, Geräte)
/// + Firmensettings (Zuschläge, Verrechnungssatz, Firmendaten) als EINE Datei.
///
/// Warum: diese echten Zahlen liegen lokal (Core Data + UserDefaults) und gehören NICHT ins
/// Repo (Kundendaten). Damit Andreas' und Raphis App mit denselben Werten rechnen, exportiert
/// der eine „die Firma" in eine Datei, die über die Box/Tailscale zum anderen läuft, und der
/// importiert sie. Keine Cloud, kein Repo — Datenhoheit.
///
/// Import ist idempotent (Upsert über die id) — mehrfaches Importieren dupliziert nichts.
enum FirmaTransfer {

    static let dateiEndung = "mopsfirma"   // .mopsfirma (JSON drin)

    // MARK: - Paket (was in die Datei kommt)

    struct Paket: Codable {
        var version = 1
        var exportiert = Date()
        var texte: [String: String] = [:]     // Firmensettings-Strings (firma_*)
        var zahlen: [String: Double] = [:]     // Firmensettings-Zahlen (Zuschläge, Sätze …)
        var flags: [String: Bool] = [:]        // Firmensettings-Schalter
        var materialien: [MaterialDTO] = []
        var loehne: [LohnDTO] = []
        var geraete: [GeraetDTO] = []
        /// OPTIONAL mit Absicht: eine .mopsfirma aus der Zeit vor diesem Feld muss weiter
        /// lesbar bleiben. Ein nicht-optionales Feld mit Default-Wert reicht dafuer NICHT —
        /// Swifts synthetisiertes Decodable wirft dann keyNotFound. (Dieselbe Falle wie
        /// beim EventExtrasPayload.)
        var leistungen: [LeistungDTO]? = []
    }

    /// Der Firmen-Leistungskatalog: fertige Positionen mit dem eigenen EH-Preis. Das ist
    /// der Topf, aus dem die Vorschlaege beim Tippen kommen (`LeistungskatalogService`) —
    /// ohne ihn bekommt der Empfaenger zwar die Materialpreise, aber keine Positionstexte.
    struct LeistungDTO: Codable {
        var id: UUID; var leistung: String?; var einheit: String?
        var maurerStunden: Double; var helferStunden: Double
        var kostenGruppeNummer: String?; var quelle: String?
        var rezeptJSON: String?; var einheitspreisVK: Double
        var erstelltAm: Date?
    }

    struct MaterialDTO: Codable {
        var id: UUID; var name: String?; var einheit: String?
        var preisProEinheit: Double; var lieferant: String?
        var verbrauchProM2: Double; var verschnittProzent: Double
        var quelleRaw: String?; var letzteAktualisierung: Date?
    }
    struct LohnDTO: Codable {
        var id: UUID; var qualifikation: String?
        var stundenlohn: Double; var zuschlagFaktor: Double
    }
    struct GeraetDTO: Codable {
        var id: UUID; var name: String?; var anschaffungsKosten: Double
        var nutzungsdauerStunden: Int32; var notiz: String?; var leistung: Double
    }

    // Nur DIESER Firmensettings-Key ist ein Schalter (Bool) — der Rest Text/Zahl.
    private static let flagKeys: Set<String> = ["firma_zuschlag_je_kostenart"]
    // Der Logo-Verweis wird NICHT mitgeschickt (Bilddatei liegt separat) — nur eine Notiz wert.
    private static let ueberspringen: Set<String> = ["firma_logo_datei"]

    // MARK: - Export

    static func exportieren(in ctx: NSManagedObjectContext) throws -> Data {
        var paket = Paket()

        // Firmensettings aus UserDefaults (alle firma_*).
        let ud = UserDefaults.standard
        for (key, wert) in ud.dictionaryRepresentation() where key.hasPrefix("firma_") {
            if ueberspringen.contains(key) { continue }
            if flagKeys.contains(key) { paket.flags[key] = (wert as? Bool) ?? false }
            else if let s = wert as? String { paket.texte[key] = s }
            else if let n = wert as? Double { paket.zahlen[key] = n }
            else if let i = wert as? Int { paket.zahlen[key] = Double(i) }
        }

        // Stammdaten aus Core Data.
        for m in (try? ctx.fetch(KalkMaterial.fetchRequest())) ?? [] {
            paket.materialien.append(MaterialDTO(
                id: m.id ?? UUID(), name: m.name, einheit: m.einheit,
                preisProEinheit: m.preisProEinheit, lieferant: m.lieferant,
                verbrauchProM2: m.verbrauchProM2, verschnittProzent: m.verschnittProzent,
                quelleRaw: m.quelleRaw, letzteAktualisierung: m.letzteAktualisierung))
        }
        for l in (try? ctx.fetch(Lohnsatz.fetchRequest())) ?? [] {
            paket.loehne.append(LohnDTO(id: l.id ?? UUID(), qualifikation: l.qualifikation,
                                        stundenlohn: l.stundenlohn, zuschlagFaktor: l.zuschlagFaktor))
        }
        for g in (try? ctx.fetch(Geraet.fetchRequest())) ?? [] {
            paket.geraete.append(GeraetDTO(id: g.id ?? UUID(), name: g.name,
                                           anschaffungsKosten: g.anschaffungsKosten,
                                           nutzungsdauerStunden: g.nutzungsdauerStunden,
                                           notiz: g.notiz, leistung: g.leistung))
        }

        for l in (try? ctx.fetch(Leistungsbaustein.fetchRequest())) ?? [] {
            paket.leistungen?.append(LeistungDTO(
                id: l.id ?? UUID(), leistung: l.leistung, einheit: l.einheit,
                maurerStunden: l.maurerStunden, helferStunden: l.helferStunden,
                kostenGruppeNummer: l.kostenGruppeNummer, quelle: l.quelle,
                rezeptJSON: l.rezeptJSON, einheitspreisVK: l.einheitspreisVK,
                erstelltAm: l.erstelltAm))
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(paket)
    }

    // MARK: - Import (Upsert über die id)

    struct Bilanz { let materialien: Int; let loehne: Int; let geraete: Int
                    let leistungen: Int; let settings: Int }

    @discardableResult
    static func importieren(_ data: Data, in ctx: NSManagedObjectContext) throws -> Bilanz {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let paket = try dec.decode(Paket.self, from: data)

        // Firmensettings zurückschreiben.
        let ud = UserDefaults.standard
        for (k, v) in paket.texte  { ud.set(v, forKey: k) }
        for (k, v) in paket.zahlen { ud.set(v, forKey: k) }
        for (k, v) in paket.flags  { ud.set(v, forKey: k) }
        let settingsAnzahl = paket.texte.count + paket.zahlen.count + paket.flags.count

        for d in paket.materialien {
            let m = findeOderNeu(KalkMaterial.self, id: d.id, in: ctx)
            m.id = d.id; m.name = d.name; m.einheit = d.einheit
            m.preisProEinheit = d.preisProEinheit; m.lieferant = d.lieferant
            m.verbrauchProM2 = d.verbrauchProM2; m.verschnittProzent = d.verschnittProzent
            m.quelleRaw = d.quelleRaw; m.letzteAktualisierung = d.letzteAktualisierung
        }
        for d in paket.loehne {
            let l = findeOderNeu(Lohnsatz.self, id: d.id, in: ctx)
            l.id = d.id; l.qualifikation = d.qualifikation
            l.stundenlohn = d.stundenlohn; l.zuschlagFaktor = d.zuschlagFaktor
        }
        for d in paket.geraete {
            let g = findeOderNeu(Geraet.self, id: d.id, in: ctx)
            g.id = d.id; g.name = d.name; g.anschaffungsKosten = d.anschaffungsKosten
            g.nutzungsdauerStunden = d.nutzungsdauerStunden; g.notiz = d.notiz; g.leistung = d.leistung
        }
        for d in paket.leistungen ?? [] {
            let l = findeOderNeu(Leistungsbaustein.self, id: d.id, in: ctx)
            l.id = d.id; l.leistung = d.leistung; l.einheit = d.einheit
            l.maurerStunden = d.maurerStunden; l.helferStunden = d.helferStunden
            l.kostenGruppeNummer = d.kostenGruppeNummer; l.quelle = d.quelle
            l.rezeptJSON = d.rezeptJSON; l.einheitspreisVK = d.einheitspreisVK
            l.erstelltAm = d.erstelltAm ?? Date()
        }
        try ctx.save()
        return Bilanz(materialien: paket.materialien.count, loehne: paket.loehne.count,
                      geraete: paket.geraete.count, leistungen: (paket.leistungen ?? []).count,
                      settings: settingsAnzahl)
    }

    /// Vorhandenes Objekt mit dieser id finden, sonst ein neues anlegen (Upsert).
    private static func findeOderNeu<T: NSManagedObject>(_ typ: T.Type, id: UUID,
                                                         in ctx: NSManagedObjectContext) -> T {
        let name = String(describing: typ)
        let req = NSFetchRequest<T>(entityName: name)
        req.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        if let vorhanden = (try? ctx.fetch(req))?.first { return vorhanden }
        return T(context: ctx)
    }
}
