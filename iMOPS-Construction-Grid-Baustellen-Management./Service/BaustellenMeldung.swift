//
//  BaustellenMeldung.swift
//  Die Brücke (10.10.2026): die App meldet den Stand ihrer Baustellen an die Box.
//
//  Befund 30.09.: der Mops-Zustand hatte keine Adresse außerhalb der App – der Büromops
//  konnte „Was steht heute an?" nicht beantworten. Jetzt meldet die App, wenn sie in den
//  Hintergrund geht, je Baustelle Titel, Zeitraum und Aufträge an `POST /baustellen/stand`.
//
//  Einseitig: die App bleibt die Wahrheit, die Box ist ein Spiegel. Nichts kommt zurück.
//  Datensparsam: Bauherr, Adresse und Notizen bleiben hier – die Meldung hat kein Feld dafür.
//  Ohne Mops-Schlüssel (Einstellungen) wird nichts gemeldet.
//

import Foundation
import CoreData
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "BaustellenMeldung")

enum BaustellenMeldung {

    static let schluesselKey = "mops_schluessel"
    static let endpoint = "/baustellen/stand"

    struct AuftragMeldung: Codable, Equatable {
        var titel: String
        var gewerk: String
        var kg: String
        var status: String
        var fertig: Bool
        var dauer_tage: Double
        var termin: String?
        var mitarbeiter: String
    }

    struct Meldung: Codable, Equatable {
        var id: String
        var titel: String
        var nummer: String
        var ort: String
        var start: String?
        var ende: String?
        var auftraege: [AuftragMeldung]
        var von: String
    }

    private static let tag: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Stabile ID: die Baustellennummer, sonst das Ende der Core-Data-ID (z. B. "p3").
    static func id(fuer event: Event) -> String {
        if let n = event.eventNumber, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        return "baustelle-" + event.objectID.uriRepresentation().lastPathComponent
    }

    /// Was gemeldet wird – reine Werte, ohne Netz (testbar).
    static func meldung(fuer event: Event, von geraet: String = "") -> Meldung {
        let jobs = (event.jobs as? Set<Auftrag> ?? []).sorted { ($0.kostenGruppeNummer ?? "") < ($1.kostenGruppeNummer ?? "") }
        let auftraege = jobs.map { job -> AuftragMeldung in
            let extras = AuftragExtrasPayload.from(job.extras)
            return AuftragMeldung(
                titel: job.processingDetails ?? "",
                gewerk: extras.gewerk,
                kg: job.kostenGruppeNummer ?? "",
                status: job.statusRawValue ?? "",
                fertig: job.isCompleted,
                dauer_tage: job.dauerTage,
                termin: extras.deadline.map { tag.string(from: $0) },
                mitarbeiter: job.employeeName ?? ""
            )
        }
        return Meldung(
            id: id(fuer: event),
            titel: event.title ?? "",
            nummer: event.eventNumber ?? "",
            ort: event.location ?? "",
            start: event.eventStartTime.map { tag.string(from: $0) },
            ende: event.eventEndTime.map { tag.string(from: $0) },
            auftraege: auftraege,
            von: geraet
        )
    }

    /// Alle Baustellen melden. Leise: ohne Schlüssel oder ohne Netz passiert nichts Sichtbares.
    static func meldeAlle(context: NSManagedObjectContext) async {
        let schluessel = UserDefaults.standard.string(forKey: schluesselKey) ?? ""
        guard !schluessel.isEmpty, let url = URL(string: MopsConfig.host + endpoint) else { return }
        let meldungen: [Meldung] = await context.perform {
            let req = NSFetchRequest<Event>(entityName: "Event")
            return ((try? context.fetch(req)) ?? []).map { meldung(fuer: $0, von: "iMOPS-App") }
        }
        for m in meldungen {
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
            req.httpBody = try? JSONEncoder().encode(m)
            do {
                let (_, antwort) = try await URLSession.shared.data(for: req)
                let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
                if code != 200 { logger.warning("Meldung \(m.id, privacy: .public): HTTP \(code)") }
            } catch {
                logger.info("Meldung \(m.id, privacy: .public) nicht angekommen: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
