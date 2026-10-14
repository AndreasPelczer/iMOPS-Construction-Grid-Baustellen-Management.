//
//  LagerMeldung.swift
//  Das Lager geht an die Box (14.10.2026, Andreas: „bau die Leitung“).
//  Gleicher Weg wie die Abwesenheiten: leise, nur mit Mops-Schlüssel, ganzer
//  Stand statt einzelner Buchungen. Gemeldet wird je Artikel nur, was der Hof
//  hat — Code, Name, Einheit, Bestand, Meldebestand, Menge je Ort. Keine Preise,
//  keine Buchungen, keine Notizen. Der Büromops rechnet damit „zu bestellen“.
//

import Foundation
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "LagerMeldung")

extension LagerStore {

    /// Was gemeldet wird – reine Werte, testbar. Ein Artikel, der je gebucht
    /// wurde, steht drin, auch mit Bestand 0 (0 heißt „leer“, fehlen heißt „kennen wir nicht“).
    func meldung() -> Data? {
        let liste: [[String: Any]] = artikelImLager().map { a in
            var eintrag: [String: Any] = [
                "code": a.code, "name": a.name, "einheit": a.einheit,
                "bestand": gesamtbestand(artikelCode: a.code),
                "orte": bestandJeOrt(artikelCode: a.code).map { ["ort": $0.ort.name, "menge": $0.menge] },
            ]
            if let m = mindestbestaende[a.code] { eintrag["mindestbestand"] = m }
            return eintrag
        }
        return try? JSONSerialization.data(withJSONObject: ["artikel": liste, "von": "iMOPS-App"])
    }

    func melde() async {
        let schluessel = UserDefaults.standard.string(forKey: BaustellenMeldung.schluesselKey) ?? ""
        guard !schluessel.isEmpty, let url = URL(string: MopsConfig.host + "/lager/stand"), let body = meldung() else { return }
        await LagerStore.sende(body, an: url, schluessel: schluessel)
    }

    static func sende(_ body: Data, an url: URL, schluessel: String) async {
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
        r.httpBody = body
        do {
            let (_, antwort) = try await URLSession.shared.data(for: r)
            let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            if code != 200 { logger.warning("Lager: HTTP \(code)") }
        } catch {
            logger.info("Lager nicht angekommen: \(error.localizedDescription, privacy: .public)")
        }
    }
}
