//
//  JarvisEingang.swift
//  Der Rückweg der Brücke (10.10.2026): Entwürfe, die Jarvis auf die Box gelegt hat, abholen.
//
//  Andreas tippt während eines Telefonats „Lege eine neue Baustelle an, Name Müller …".
//  Jarvis führt das nicht aus – er legt einen Entwurf in den Eingang der Box. Die App holt
//  ihn ab; ANGELEGT wird erst hier, im Planer, durch einen Fingertipp. Die App bleibt die Wahrheit.
//
//  Ein Entwurf ist eine Liste von Schritten (Baustelle, Termin, Canvas), jeder einzeln
//  offen → übernommen | verworfen. Jeder Schritt wird an die Box quittiert – ohne Quittung
//  stünde „Müller" beim nächsten Öffnen wieder da und würde zweimal angelegt.
//  Die Vorlage kommt nur als Name („hofeinfahrt"); der Planer löst sie beim Öffnen auf.
//

import Foundation
import CoreData
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "JarvisEingang")

enum JarvisEingang {

    struct Schritt: Codable, Identifiable, Equatable {
        var nr: Int
        var art: String                    // "baustelle" | "termin" | "canvas"
        var felder: [String: String]
        var zustand: String                // "offen" | "uebernommen" | "verworfen"
        var baustelle_id: String?
        var id: Int { nr }
        var offen: Bool { zustand == "offen" }
    }

    struct Entwurf: Codable, Identifiable, Equatable {
        var id: String
        var erstellt: String
        var von: String
        var satz: String
        var zustand: String
        var schritte: [Schritt]

        var erstelltDatum: Date? { ISO8601DateFormatter().date(from: erstellt) }
        var baustelle: Schritt? { schritte.first { $0.art == "baustelle" } }

        /// „Müller, Sachsenhausen" – was oben im Hinweis steht.
        var kurz: String {
            let f = baustelle?.felder ?? [:]
            let teile = [f["name"], f["ort"]].compactMap { $0 }.filter { !$0.isEmpty }
            return teile.isEmpty ? "Entwurf" : teile.joined(separator: ", ")
        }
    }

    /// Was der Planer aus dem Baustellen-Schritt vorbelegt. Nur Werte – die Vorlage als Name.
    struct Vorgabe: Equatable {
        var name: String
        var ort: String
        var start: Date?
        var vorlage: ProjektTyp?
        var angebotBis: Date?
        var angebotBetrag: Double?
        var flaeche: Double?               // nur wenn genannt – sonst nimmt der Planer seinen Standard (und zeigt ihn)

        init(_ f: [String: String]) {
            name = f["name"] ?? ""
            ort = f["ort"] ?? ""
            start = f["start"].flatMap(JarvisEingang.tag)
            vorlage = f["vorlage"].flatMap { ProjektTyp(rawValue: $0.lowercased()) }
            angebotBis = f["angebot_bis"].flatMap(JarvisEingang.tag)
            angebotBetrag = f["angebot_betrag"].flatMap(Double.init)
            flaeche = f["flaeche"].flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) }
        }

        /// Was zum Angebot gesagt wurde – nur zum Anzeigen. Gespeichert wird es als Feld (`uebertrage`).
        var angebotText: String? {
            if let d = angebotBis { return "Angebot bis \(d.formatted(date: .numeric, time: .omitted))" }
            if let b = angebotBetrag { return "Angebotssumme \(b.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE"))))" }
            return nil
        }

        /// „Hofeinfahrt · Fläche 100 m² (Standard aus dem Planer)" – auch was NICHT gesagt wurde, wird gezeigt.
        var vorlageText: String? {
            guard let v = vorlage else { return nil }
            guard v == .hofeinfahrt else { return "Vorlage \(v.anzeige)" }
            if let f = flaeche { return "Hofeinfahrt · Fläche \(Int(f)) m²" }
            return "Hofeinfahrt · Fläche \(Int(HofeinfahrtVorlage.standardFlaeche)) m² (Standard aus dem Planer)"
        }

        /// Betrag → Feld Angebotssumme, Datum → Feld Angebotsfrist. Keine Notiz: die Rückfrage hatte einen Sinn.
        func uebertrage(in extras: inout EventExtrasPayload) {
            if let b = angebotBetrag { extras.angebotSumme = b }
            if let d = angebotBis { extras.angebotFrist = d }
        }

    }

    // MARK: - Schnellkalkulation zuweisen (Schritt „kalkulation“)

    struct KalkPosition: Codable, Equatable {
        var text: String
        var menge: Double
        var einheit: String
        var rezept: String
    }

    static func kalkPositionen(_ f: [String: String]) -> [KalkPosition] {
        guard let d = f["positionen"]?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([KalkPosition].self, from: d)) ?? []
    }

    /// Jarvis schreibt normierte Einheiten (m2, m3, stk) – die App und ihr Katalog sprechen m², m³, Stk.
    static func einheit(_ e: String) -> String {
        ["m2": "m²", "m3": "m³", "stk": "Stk", "psch": "psch", "m": "m", "t": "t", "h": "h", "kg": "kg"][e.lowercased()] ?? e
    }

    /// Die Positionen als LV-Positionen in die Baustelle legen – das iPad rechnet sie selbst
    /// (`LeistungskatalogService.autoMatch` holt das Rezept, wie bei jeder anderen Position).
    /// Gibt zurück: (angelegt, davon mit Rezept). Speichern macht der Aufrufer.
    @discardableResult
    static func legeKalkulation(_ f: [String: String], in event: Event, ctx: NSManagedObjectContext) -> (angelegt: Int, mitRezept: Int) {
        var nr = (event.lvPositionen?.count ?? 0) + 1
        var angelegt = 0, mitRezept = 0
        for p in kalkPositionen(f) where p.menge > 0 {
            let pos = LVPosition(context: ctx)
            pos.posNr = String(format: "01.%02d", nr)
            pos.event = event
            pos.bezeichnung = p.rezept.isEmpty ? p.text : p.rezept
            pos.einheit = einheit(p.einheit)
            pos.menge = p.menge
            pos.mengenQuelle = .schaetzung
            pos.quellDatei = "Jarvis-Schnellkalkulation"
            pos.langtext = "Aus Jarvis: „\(f["satz"] ?? p.text)“ – Menge geschätzt, bitte prüfen."
            if LeistungskatalogService.autoMatch(position: pos, in: ctx) { mitRezept += 1 }
            nr += 1; angelegt += 1
        }
        return (angelegt, mitRezept)
    }

    static func tag(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(s.prefix(10)))
    }

    /// Termin-Schritt → Datum (mit Uhrzeit, wenn genannt). Ohne Uhrzeit: ganztägig.
    static func termin(_ f: [String: String]) -> (start: Date, ganztags: Bool)? {
        guard let tag = f["tag"].flatMap(tag) else { return nil }
        guard let uhr = f["uhrzeit"], uhr.count >= 4 else { return (tag, true) }
        let hm = uhr.split(separator: ":").compactMap { Int($0) }
        guard hm.count == 2,
              let d = Calendar.current.date(bySettingHour: hm[0], minute: hm[1], second: 0, of: tag) else { return (tag, true) }
        return (d, false)
    }

    /// „von heute 11:20" / „von gestern 16:05" / „vom 03.10., 09:12" – das Alter gehört in den Hinweis.
    static func alter(_ d: Date?, jetzt: Date = Date()) -> String {
        guard let d else { return "" }
        let cal = Calendar.current
        let uhr = d.formatted(date: .omitted, time: .shortened)
        if cal.isDate(d, inSameDayAs: jetzt) { return "von heute \(uhr)" }
        if let g = cal.date(byAdding: .day, value: -1, to: jetzt), cal.isDate(d, inSameDayAs: g) { return "von gestern \(uhr)" }
        return "vom \(d.formatted(.dateTime.day(.twoDigits).month(.twoDigits))), \(uhr)"
    }

    // MARK: - Netz (leise: ohne Schlüssel oder Netz passiert nichts Sichtbares)

    private static var schluessel: String { UserDefaults.standard.string(forKey: BaustellenMeldung.schluesselKey) ?? "" }

    private static func anfrage(_ pfad: String, methode: String = "GET", body: Data? = nil) -> URLRequest? {
        guard !schluessel.isEmpty, let url = URL(string: MopsConfig.host + pfad) else { return nil }
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.httpMethod = methode
        r.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = body
        }
        return r
    }

    // MARK: - Ausstehende Quittungen
    //
    // Regel (10.10., Chat-Claude): der Zustand wird nie lokal erfunden, er kommt von der Box.
    // Aber was HIER passiert ist (Baustelle angelegt), ist passiert – kam die Quittung nicht an,
    // merkt sich die App sie und schickt sie nach. Sonst stünde „Baustelle Müller" beim nächsten
    // Öffnen wieder offen da und würde doppelt angelegt.

    struct Ausstehend: Codable, Equatable {
        var entwurf: String
        var schritt: Int
        var zustand: String
        var baustelleID: String
    }

    private static let ausstehendKey = "jarvis_ausstehende_quittungen"

    static var ausstehend: [Ausstehend] {
        get { UserDefaults.standard.data(forKey: ausstehendKey).flatMap { try? JSONDecoder().decode([Ausstehend].self, from: $0) } ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: ausstehendKey) }
    }

    static func istAusstehend(_ e: Entwurf, _ s: Schritt) -> Bool {
        ausstehend.contains { $0.entwurf == e.id && $0.schritt == s.nr }
    }

    static func merke(_ a: Ausstehend) {
        var liste = ausstehend.filter { !($0.entwurf == a.entwurf && $0.schritt == a.schritt) }
        liste.append(a)
        ausstehend = liste
    }

    /// Ausstehende nachschicken. Angekommen ODER abgelehnt (Box hat eigenen Stand) → aus der Liste.
    static func nachschicken() async {
        for a in ausstehend {
            let body = try? JSONEncoder().encode(["zustand": a.zustand, "baustelle_id": a.baustelleID, "von": "iMOPS-App"])
            switch await senden(anfrage("/entwuerfe/\(a.entwurf)/schritt/\(a.schritt)", methode: "POST", body: body), id: a.entwurf) {
            case .angekommen, .abgelehnt: ausstehend = ausstehend.filter { $0 != a }
            case .nichtErreicht: return
            }
        }
    }

    static func offene() async -> [Entwurf] {
        await nachschicken()
        guard let r = anfrage("/entwuerfe?zustand=offen") else { return [] }
        do {
            let (daten, antwort) = try await URLSession.shared.data(for: r)
            guard (antwort as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return try JSONDecoder().decode([Entwurf].self, from: daten)
        } catch {
            logger.info("Eingang nicht geholt: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Was aus einer Quittung wurde. „abgelehnt" ist NICHT „nicht erreicht": die Box hat
    /// einen anderen Stand (z. B. Schritt schon verworfen) – dann gilt ihrer, nicht unserer.
    /// (Befund 10.10.: Canvas war verworfen, das iPad zeigte nach der Ablehnung trotzdem grün.)
    enum Antwort {
        case angekommen(Entwurf)
        case abgelehnt(Entwurf?)        // mit dem Stand der Box, wenn er sich holen ließ
        case nichtErreicht
    }

    static func quittiere(_ e: Entwurf, schritt: Int, zustand: String, baustelleID: String = "") async -> Antwort {
        let body = try? JSONEncoder().encode(["zustand": zustand, "baustelle_id": baustelleID, "von": "iMOPS-App"])
        return await senden(anfrage("/entwuerfe/\(e.id)/schritt/\(schritt)", methode: "POST", body: body), id: e.id)
    }

    static func verwerfe(_ e: Entwurf) async -> Antwort {
        await senden(anfrage("/entwuerfe/\(e.id)/verwerfen", methode: "POST"), id: e.id)
    }

    static func stand(_ id: String) async -> Entwurf? {
        guard let r = anfrage("/entwuerfe/\(id)"),
              let (daten, antwort) = try? await URLSession.shared.data(for: r),
              (antwort as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(Entwurf.self, from: daten)
    }

    private static func senden(_ r: URLRequest?, id: String) async -> Antwort {
        guard let r else { return .nichtErreicht }
        do {
            let (daten, antwort) = try await URLSession.shared.data(for: r)
            let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200, let e = try? JSONDecoder().decode(Entwurf.self, from: daten) { return .angekommen(e) }
            logger.warning("Quittung abgelehnt: HTTP \(code)")
            return (400..<500).contains(code) ? .abgelehnt(await stand(id)) : .nichtErreicht
        } catch {
            logger.info("Quittung nicht angekommen: \(error.localizedDescription, privacy: .public)")
            return .nichtErreicht
        }
    }
}
