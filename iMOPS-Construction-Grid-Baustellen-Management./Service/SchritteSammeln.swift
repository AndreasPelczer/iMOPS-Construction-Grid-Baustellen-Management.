//
//  SchritteSammeln.swift
//
//  Arbeitsschritte für viele Aufträge auf einmal.
//
//  Andreas, 22.09.2026: „ich muss jetzt aber jeden einzeln anklicken zum übertragen."
//  Bei 34 Arbeitspaketen sind das 34 Runden — und der Weg ist jedes Mal derselbe.
//
//  🔴 Die Reihenfolge ist wichtig, und zwar aus einem einfachen Grund: eine
//  Server-Anfrage darf bis zu 180 Sekunden dauern (CPU-only). Bei dreissig Aufträgen
//  wären das anderthalb Stunden. Also zuerst alles, was NICHTS kostet:
//
//      1. Katalog   — schon einmal abgenommen, von einem Menschen. Sofort. 🟢
//      2. Vorlage   — eine der zwölf aus der Anfangszeit. Sofort, aber ungeprüft. 🟡
//      3. Rezept    — Material und Gerät der Position als Gerüst. Sofort, dürftig.
//      4. Der Prof  — nur für den Rest, einer nach dem anderen, abbrechbar.
//
//  🔴 Und nichts davon landet ungefragt im Auftrag. Gesammelt wird in eine Liste,
//  abgenommen wird von einem Menschen — sonst wären wir wieder bei ungeprüften
//  Schritten, die an Lehrlinge gehen (siehe `arbeitsschritte-ohne-quelle`).
//

import Foundation
import CoreData
import os

enum SchritteSammeln {

    private static let logger = Logger(subsystem: "io.imops", category: "Schritte")

    /// Woher die Schritte für einen Auftrag kommen könnten — ohne zu fragen.
    enum Quelle: String {
        case katalog, vorlage, rezept, offen

        var kurz: String {
            switch self {
            case .katalog: return "aus dem Katalog — schon abgenommen"
            case .vorlage: return "aus einer Vorlage — ungeprüft"
            case .rezept:  return "aus dem Rezept — nur ein Gerüst"
            case .offen:   return "der Mops muss fragen"
            }
        }
    }

    struct Fund: Identifiable {
        let id = UUID()
        let job: Auftrag
        let name: String
        var quelle: Quelle
        var schritte: [AnweisungsSchritt]
        /// Wird beim Übernehmen abgehakt — abgewählte bleiben liegen.
        var uebernehmen: Bool
    }

    /// Was ohne eine einzige Server-Anfrage zu holen ist.
    ///
    /// Der Katalog gewinnt immer: was ein Mensch abgenommen hat, schlägt jede Vorlage.
    @MainActor
    static func sofort(fuer event: Event) -> [Fund] {
        let jobs = ((event.jobs?.allObjects as? [Auftrag]) ?? [])
            .filter { $0.status != .completed }
            .filter { AuftragExtrasPayload.from($0.extras).checklist.isEmpty }
            .sorted { Kausalkette.bezeichnung($0) < Kausalkette.bezeichnung($1) }

        return jobs.map { job in
            let name = Kausalkette.bezeichnung(job)

            if let ausKatalog = AnweisungsKatalog.shared.schritte(fuer: name) {
                return Fund(job: job, name: name, quelle: .katalog,
                            schritte: ausKatalog, uebernehmen: true)
            }
            if let vorlage = AuftragTemplate.passend(zu: name) {
                let schritte = vorlage.steps.map {
                    AnweisungsSchritt(text: $0, herkunft: .vorlage)
                }
                // 🔴 Ungeprüft wird NICHT vorausgewählt. Wer eine Vorlage nimmt,
                // soll das entscheiden, nicht bloss mitnehmen.
                return Fund(job: job, name: name, quelle: .vorlage,
                            schritte: schritte, uebernehmen: false)
            }
            let ausRezept = AnweisungsAssistent.ausRezept(job)
            if !ausRezept.isEmpty {
                return Fund(job: job, name: name, quelle: .rezept,
                            schritte: ausRezept, uebernehmen: false)
            }
            return Fund(job: job, name: name, quelle: .offen,
                        schritte: [], uebernehmen: false)
        }
    }

    /// Fragt den Prof für einen einzelnen Auftrag. Der Aufrufer geht die Liste
    /// durch und kann jederzeit abbrechen — 180 Sekunden je Anfrage.
    @MainActor
    static func frageProf(fuer job: Auftrag) async -> [AnweisungsSchritt] {
        do {
            return try await AnweisungsAssistent.hole(fuer: job)
        } catch {
            logger.error("Prof nicht erreichbar: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// Schreibt die ausgewählten Schritte in ihre Aufträge.
    ///
    /// 🔴 In den KATALOG wandert dabei nichts. Der merkt sich nur, was jemand
    /// ausdrücklich abgenommen hat — hier wird übernommen, nicht abgenommen.
    @MainActor
    @discardableResult
    static func uebernehmen(_ funde: [Fund], in ctx: NSManagedObjectContext) -> Int {
        var n = 0
        for f in funde where f.uebernehmen && !f.schritte.isEmpty {
            var payload = AuftragExtrasPayload.from(f.job.extras)
            payload.checklist = f.schritte.map(AuftragChecklistItem.init)
            if let data = try? JSONEncoder().encode(payload) {
                f.job.extras = String(data: data, encoding: .utf8)
                n += 1
            }
        }
        logger.info("Schritte übernommen für \(n) Aufträge")
        return n
    }
}
