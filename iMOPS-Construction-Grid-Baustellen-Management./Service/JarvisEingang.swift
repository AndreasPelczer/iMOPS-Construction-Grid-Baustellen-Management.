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

    static func offene() async -> [Entwurf] {
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

    /// Einen Schritt quittieren. Gibt den neuen Stand zurück – nil heißt: nicht angekommen, nochmal versuchen.
    @discardableResult
    static func quittiere(_ e: Entwurf, schritt: Int, zustand: String, baustelleID: String = "") async -> Entwurf? {
        let body = try? JSONEncoder().encode(["zustand": zustand, "baustelle_id": baustelleID, "von": "iMOPS-App"])
        return await senden(anfrage("/entwuerfe/\(e.id)/schritt/\(schritt)", methode: "POST", body: body))
    }

    @discardableResult
    static func verwerfe(_ e: Entwurf) async -> Entwurf? {
        await senden(anfrage("/entwuerfe/\(e.id)/verwerfen", methode: "POST"))
    }

    private static func senden(_ r: URLRequest?) async -> Entwurf? {
        guard let r else { return nil }
        do {
            let (daten, antwort) = try await URLSession.shared.data(for: r)
            let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { logger.warning("Quittung: HTTP \(code)"); return nil }
            return try JSONDecoder().decode(Entwurf.self, from: daten)
        } catch {
            logger.info("Quittung nicht angekommen: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
