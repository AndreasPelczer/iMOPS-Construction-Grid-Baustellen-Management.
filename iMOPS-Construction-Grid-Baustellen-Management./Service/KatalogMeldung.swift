//
//  KatalogMeldung.swift
//  Der Firma-Katalog geht als Spiegel an die Box (10.10.2026) – für Jarvis' Schnellkalkulation.
//
//  Andreas: „Wenn ich nur schnell was kalkulieren will …“. Gerechnet wird weiter NUR hier
//  (LVKalkulator, Leistungskatalog, Stammdaten). Die Box bekommt den Stand zum Nachschlagen:
//  gelernte Rezepte (Leistung, Einheit, EP VK, Stunden) und Stammdaten-Materialpreise.
//  Preise sind Firmendaten: nur an die eigene Box, nur mit Mops-Schlüssel.
//

import Foundation
import CoreData
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "KatalogMeldung")

enum KatalogMeldung {

    struct Leistung: Codable, Equatable {
        var leistung: String
        var einheit: String
        var ep: Double
        var stunden: Double
        var kg: String
        var quelle: String
    }

    struct Material: Codable, Equatable {
        var name: String
        var einheit: String
        var preis: Double
        var lieferant: String
        var stand: String?
    }

    struct Stand: Codable, Equatable {
        var leistungen: [Leistung]
        var material: [Material]
        var von: String
    }

    /// Was gemeldet wird – reine Werte, testbar.
    static func stand(in ctx: NSManagedObjectContext) -> Stand {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        let bausteine = (try? ctx.fetch(NSFetchRequest<Leistungsbaustein>(entityName: "Leistungsbaustein"))) ?? []
        let materialien = (try? ctx.fetch(NSFetchRequest<KalkMaterial>(entityName: "KalkMaterial"))) ?? []
        return Stand(
            leistungen: bausteine.compactMap { b in
                guard let l = b.leistung, !l.isEmpty else { return nil }
                return Leistung(leistung: l, einheit: b.einheit ?? "", ep: b.einheitspreisVK,
                                stunden: b.maurerStunden + b.helferStunden, kg: b.kostenGruppeNummer ?? "", quelle: b.quelle ?? "")
            },
            material: materialien.compactMap { m in
                guard let n = m.name, !n.isEmpty else { return nil }
                return Material(name: n, einheit: m.einheit ?? "", preis: m.preisProEinheit,
                                lieferant: m.lieferant ?? "", stand: m.letzteAktualisierung.map { f.string(from: $0) })
            },
            von: "iMOPS-App")
    }

    static func melde(context: NSManagedObjectContext) async {
        let schluessel = UserDefaults.standard.string(forKey: BaustellenMeldung.schluesselKey) ?? ""
        guard !schluessel.isEmpty, let url = URL(string: MopsConfig.host + "/katalog/stand") else { return }
        let body: Data? = await context.perform { try? JSONEncoder().encode(stand(in: context)) }
        guard let body else { return }
        var r = URLRequest(url: url, timeoutInterval: 20)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
        r.httpBody = body
        do {
            let (_, antwort) = try await URLSession.shared.data(for: r)
            let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            if code != 200 { logger.warning("Katalog: HTTP \(code)") }
        } catch {
            logger.info("Katalog nicht angekommen: \(error.localizedDescription, privacy: .public)")
        }
    }
}
