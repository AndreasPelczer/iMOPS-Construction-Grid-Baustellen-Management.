//
//  LagerStore.swift
//  Ein kleines, ehrliches Lagersystem — konform zu gängiger Lagersoftware:
//  Der Bestand ist die SUMME der Buchungen, keine editierbare Zahl. Wareneingang
//  bucht rein, Ausgang raus, Umlagerung verschiebt, Inventur korrigiert — der
//  Bestand ergibt sich. Das ist zugleich das Tao: Nachweis statt Kontrolle, und
//  ein Bestand ist nur so wahr wie seine Buchungen.
//
//  Bewusst KEIN Core Data (keine Modell-Migration): Codable + JSON-Datei, wie
//  AngebotsStore. Artikel = Katalog-Eintrag (CDLexikonEntry), referenziert über
//  `code` (String) — das Lager hängt nicht am Core-Data-Graphen.
//
//  Bewusst NICHT jetzt (dockt später an): Barcode/Scan (über BuildIQ), Chargen/
//  Seriennummern, automatisches Abbuchen bei Bestellung/Verbrauch.
//

import Foundation
import CoreData
import Combine

// MARK: - Modell

/// Ein Lagerort (Hof, Halle, Container, Baustellen-Depot …).
struct Lagerort: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var notiz: String

    init(id: UUID = UUID(), name: String, notiz: String = "") {
        self.id = id
        self.name = name
        self.notiz = notiz
    }
}

/// Die Art einer Buchung. `eingang` bucht plus, `ausgang` minus; `umlagerung`
/// entsteht als Paar (raus am Quell-, rein am Ziel-Ort); `inventur` bucht die
/// Differenz zum gezählten Ist; `korrektur` ist eine manuelle Berichtigung.
enum Buchungsart: String, Codable, CaseIterable {
    case eingang
    case ausgang
    case umlagerung
    case inventur
    case korrektur

    var anzeige: String {
        switch self {
        case .eingang:    return "Wareneingang"
        case .ausgang:    return "Warenausgang"
        case .umlagerung: return "Umlagerung"
        case .inventur:   return "Inventur"
        case .korrektur:  return "Korrektur"
        }
    }
}

/// Eine einzelne Lagerbewegung. `menge` ist **signiert**: + Zugang, − Abgang.
/// `artikelName`/`einheit` sind ein Schnappschuss für die Anzeige (falls der
/// Katalog-Eintrag später umbenannt oder gelöscht wird).
struct Lagerbuchung: Codable, Identifiable, Equatable {
    let id: UUID
    var artikelCode: String     // → CDLexikonEntry.code
    var artikelName: String
    var lagerortID: UUID
    var menge: Double           // signiert
    var einheit: String
    var art: Buchungsart
    var datum: Date
    var notiz: String
    var baustelle: String       // optionaler Bezug (Event-Titel) bei Ausgang

    init(id: UUID = UUID(), artikelCode: String, artikelName: String,
         lagerortID: UUID, menge: Double, einheit: String, art: Buchungsart,
         datum: Date = Date(), notiz: String = "", baustelle: String = "") {
        self.id = id
        self.artikelCode = artikelCode
        self.artikelName = artikelName
        self.lagerortID = lagerortID
        self.menge = menge
        self.einheit = einheit
        self.art = art
        self.datum = datum
        self.notiz = notiz
        self.baustelle = baustelle
    }
}

// MARK: - Reine Logik (ohne Persistenz — testbar)

/// Alle Bestandsrechnungen als reine Funktionen über einem Buchungs-Journal.
/// Der Store hält nur die Daten und ruft hier durch.
enum Lagerlogik {

    /// Bestand eines Artikels an EINEM Lagerort = Summe der signierten Mengen.
    static func bestand(_ buchungen: [Lagerbuchung], artikelCode: String, lagerortID: UUID) -> Double {
        buchungen.reduce(0) { summe, b in
            (b.artikelCode == artikelCode && b.lagerortID == lagerortID) ? summe + b.menge : summe
        }
    }

    /// Gesamtbestand eines Artikels über ALLE Lagerorte.
    static func gesamtbestand(_ buchungen: [Lagerbuchung], artikelCode: String) -> Double {
        buchungen.reduce(0) { $0 + ($1.artikelCode == artikelCode ? $1.menge : 0) }
    }

    /// Bestand je Lagerort für einen Artikel (nur Orte mit Bewegung, Bestand ≠ 0 optional).
    static func bestandJeOrt(_ buchungen: [Lagerbuchung], artikelCode: String) -> [UUID: Double] {
        var out: [UUID: Double] = [:]
        for b in buchungen where b.artikelCode == artikelCode {
            out[b.lagerortID, default: 0] += b.menge
        }
        return out
    }

    /// Alle Artikel-Codes, die je gebucht wurden (mit ihrem letzten Namen/Einheit).
    static func artikel(_ buchungen: [Lagerbuchung]) -> [(code: String, name: String, einheit: String)] {
        var latest: [String: Lagerbuchung] = [:]
        for b in buchungen {
            if let vorher = latest[b.artikelCode], vorher.datum > b.datum { continue }
            latest[b.artikelCode] = b
        }
        return latest.values
            .sorted { $0.artikelName.localizedCaseInsensitiveCompare($1.artikelName) == .orderedAscending }
            .map { ($0.artikelCode, $0.artikelName, $0.einheit) }
    }
}

// MARK: - Persistenz-Container

private struct LagerDaten: Codable {
    var lagerorte: [Lagerort] = []
    var buchungen: [Lagerbuchung] = []
    var mindestbestaende: [String: Double] = [:]   // artikelCode → Melde-/Mindestbestand
}

// MARK: - Store

/// Hält Lagerorte + Buchungen, persistiert als JSON (wie AngebotsStore). Der
/// Bestand wird nie gespeichert, immer aus den Buchungen gerechnet.
final class LagerStore: ObservableObject {
    static let shared = LagerStore()

    @Published private(set) var lagerorte: [Lagerort] = []
    @Published private(set) var buchungen: [Lagerbuchung] = []
    @Published private(set) var mindestbestaende: [String: Double] = [:]

    private let fileURL: URL

    /// `shared` nutzt die Standard-Datei; Tests geben eine eigene URL (kein
    /// gemeinsamer Zustand, keine Datei-Kollision).
    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docs.appendingPathComponent("lager.json")
        }()
        load()
    }

    // MARK: - Bestand lesen

    func bestand(artikelCode: String, lagerortID: UUID) -> Double {
        Lagerlogik.bestand(buchungen, artikelCode: artikelCode, lagerortID: lagerortID)
    }
    func gesamtbestand(artikelCode: String) -> Double {
        Lagerlogik.gesamtbestand(buchungen, artikelCode: artikelCode)
    }
    func bestandJeOrt(artikelCode: String) -> [(ort: Lagerort, menge: Double)] {
        let map = Lagerlogik.bestandJeOrt(buchungen, artikelCode: artikelCode)
        return lagerorte.compactMap { ort in
            guard let m = map[ort.id], abs(m) > 0.0001 else { return nil }
            return (ort, m)
        }
    }
    func artikelImLager() -> [(code: String, name: String, einheit: String)] {
        Lagerlogik.artikel(buchungen)
    }

    /// Artikel unter ihrem Meldebestand — „muss nachbestellt werden".
    func unterMindestbestand() -> [(code: String, name: String, bestand: Double, schwelle: Double, einheit: String)] {
        artikelImLager().compactMap { a in
            guard let schwelle = mindestbestaende[a.code], schwelle > 0 else { return nil }
            let b = gesamtbestand(artikelCode: a.code)
            return b < schwelle ? (a.code, a.name, b, schwelle, a.einheit) : nil
        }
    }

    // MARK: - Buchen

    private func buchen(_ b: Lagerbuchung) {
        buchungen.append(b)
        save()
    }

    /// Wareneingang (+menge). `menge` als positive Zahl übergeben.
    func eingang(artikelCode: String, name: String, einheit: String, menge: Double,
                 lagerortID: UUID, notiz: String = "", datum: Date = Date()) {
        buchen(Lagerbuchung(artikelCode: artikelCode, artikelName: name, lagerortID: lagerortID,
                            menge: abs(menge), einheit: einheit, art: .eingang, datum: datum, notiz: notiz))
    }

    /// Warenausgang (−menge). `menge` als positive Zahl übergeben.
    func ausgang(artikelCode: String, name: String, einheit: String, menge: Double,
                 lagerortID: UUID, baustelle: String = "", notiz: String = "", datum: Date = Date()) {
        buchen(Lagerbuchung(artikelCode: artikelCode, artikelName: name, lagerortID: lagerortID,
                            menge: -abs(menge), einheit: einheit, art: .ausgang, datum: datum,
                            notiz: notiz, baustelle: baustelle))
    }

    /// Umlagerung: zwei Buchungen — raus am Quell-, rein am Ziel-Ort. So bleibt der
    /// Gesamtbestand unverändert und jeder Ort stimmt für sich.
    func umlagern(artikelCode: String, name: String, einheit: String, menge: Double,
                  vonOrt: UUID, nachOrt: UUID, notiz: String = "", datum: Date = Date()) {
        guard vonOrt != nachOrt, abs(menge) > 0 else { return }
        let m = abs(menge)
        buchungen.append(Lagerbuchung(artikelCode: artikelCode, artikelName: name, lagerortID: vonOrt,
                                      menge: -m, einheit: einheit, art: .umlagerung, datum: datum, notiz: notiz))
        buchungen.append(Lagerbuchung(artikelCode: artikelCode, artikelName: name, lagerortID: nachOrt,
                                      menge: m, einheit: einheit, art: .umlagerung, datum: datum, notiz: notiz))
        save()
    }

    /// Inventur: der Nutzer zählt und trägt das IST am Ort ein. Gebucht wird die
    /// Differenz zum aktuellen Bestand (Korrektur), sodass der Bestand danach genau
    /// dem gezählten Wert entspricht.
    func inventur(artikelCode: String, name: String, einheit: String, gezaehlt: Double,
                  lagerortID: UUID, notiz: String = "", datum: Date = Date()) {
        let ist = bestand(artikelCode: artikelCode, lagerortID: lagerortID)
        let diff = gezaehlt - ist
        guard abs(diff) > 0.0001 else { return }
        let hinweis = notiz.isEmpty ? "Inventur: gezählt \(gezaehlt) \(einheit)" : notiz
        buchen(Lagerbuchung(artikelCode: artikelCode, artikelName: name, lagerortID: lagerortID,
                            menge: diff, einheit: einheit, art: .inventur, datum: datum, notiz: hinweis))
    }

    func setMindestbestand(artikelCode: String, schwelle: Double) {
        if schwelle > 0 { mindestbestaende[artikelCode] = schwelle }
        else { mindestbestaende.removeValue(forKey: artikelCode) }
        save()
    }

    // MARK: - Lagerorte

    @discardableResult
    func addLagerort(name: String, notiz: String = "") -> Lagerort {
        let ort = Lagerort(name: name, notiz: notiz)
        lagerorte.append(ort)
        save()
        return ort
    }
    func umbenennen(_ id: UUID, name: String, notiz: String) {
        guard let i = lagerorte.firstIndex(where: { $0.id == id }) else { return }
        lagerorte[i].name = name
        lagerorte[i].notiz = notiz
        save()
    }
    /// Löscht einen Lagerort NUR, wenn dort nie etwas gebucht wurde. Sobald es
    /// Buchungen gibt (auch bei Bestand 0), bleibt er — sonst verlöre die
    /// Historie ihren Bezug. Gibt false zurück, wenn nicht gelöscht wurde.
    @discardableResult
    func removeLagerort(_ id: UUID) -> Bool {
        let hatBuchungen = buchungen.contains { $0.lagerortID == id }
        if hatBuchungen { return false }
        lagerorte.removeAll { $0.id == id }
        save()
        return true
    }

    // MARK: - Persistenz

    private func load() {
        guard let raw = try? Data(contentsOf: fileURL),
              let d = try? JSONDecoder().decode(LagerDaten.self, from: raw) else { return }
        lagerorte = d.lagerorte
        buchungen = d.buchungen
        mindestbestaende = d.mindestbestaende
    }
    private func save() {
        let d = LagerDaten(lagerorte: lagerorte, buchungen: buchungen, mindestbestaende: mindestbestaende)
        guard let raw = try? JSONEncoder().encode(d) else { return }
        try? raw.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Materialstatus (für die Materialliste)

/// Der Status eines Materials in der Baustellen-Materialliste — die eine Frage,
/// die der Polier stellt: müssen wir das noch besorgen? UI-agnostisch (die View
/// mappt auf Farbe/Icon).
enum Materialstatus: Equatable {
    case bestellt                                                   // manuell markiert
    case reicht(lager: Double, einheit: String)                    // Lager deckt den Bedarf
    case teils(lager: Double, zuBestellen: Double, einheit: String)// etwas da, Rest bestellen
    case zuBestellen(menge: Double?, einheit: String)              // nichts da; menge = Bedarf, nil = unbekannt
    case aufLager(menge: Double, einheit: String)                  // Bestand da, aber kein Bedarf hinterlegt

    /// Reihenfolge der Wahrheit: „bestellt" schlägt alles; sonst rechnet der
    /// Bedarf gegen den echten Lagerbestand (zu bestellen = Bedarf − Lager); ohne
    /// hinterlegten Bedarf bleibt es beim schlichten „haben wir welche?".
    static func fuer(artikelCode: String, bedarf: Double?, einheit: String,
                     bestellt: Bool, store: LagerStore) -> Materialstatus {
        if bestellt { return .bestellt }
        let lager = store.gesamtbestand(artikelCode: artikelCode)
        if let bedarf, bedarf > 0 {
            let zuB = max(0, bedarf - lager)
            if zuB <= 0.0001    { return .reicht(lager: lager, einheit: einheit) }
            if lager > 0.0001   { return .teils(lager: lager, zuBestellen: zuB, einheit: einheit) }
            return .zuBestellen(menge: bedarf, einheit: einheit)
        }
        // Kein Bedarf hinterlegt.
        if lager > 0.0001 {
            let e = store.artikelImLager().first { $0.code == artikelCode }?.einheit ?? einheit
            return .aufLager(menge: lager, einheit: e)
        }
        return .zuBestellen(menge: nil, einheit: einheit)
    }

    private static func z(_ m: Double, _ e: String) -> String {
        let n = m.formatted(.number.precision(.fractionLength(0...2)))
        return e.isEmpty ? n : "\(n) \(e)"
    }

    var kurz: String {
        switch self {
        case .bestellt:                       return "bestellt"
        case .reicht(let l, let e):           return "auf Lager – reicht (\(Materialstatus.z(l, e)))"
        case .teils(let l, let z, let e):     return "Lager \(Materialstatus.z(l, e)) · zu bestellen \(Materialstatus.z(z, e))"
        case .zuBestellen(let m, let e):      return m == nil ? "zu bestellen" : "zu bestellen \(Materialstatus.z(m!, e))"
        case .aufLager(let m, let e):         return "auf Lager (\(Materialstatus.z(m, e)))"
        }
    }
}
