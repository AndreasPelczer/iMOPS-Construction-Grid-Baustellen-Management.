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
import UIKit
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

    /// Meldung + der Graph, den die App ohnehin für die Leinwand baut (`Grap8Graph`) –
    /// damit der Canvas auch im Browser (Jarvis) die echte Baustelle zeigt. Nur zum Ansehen:
    /// Titel, KG, Zustand, Position, Kanten. Kein Bauherr, keine Adresse.
    static func koerper(_ m: Meldung, graph: Grap8Graph) -> Data? {
        guard let md = try? JSONEncoder().encode(m),
              var obj = try? JSONSerialization.jsonObject(with: md) as? [String: Any],
              let gd = try? JSONEncoder().encode(graph),
              let g = try? JSONSerialization.jsonObject(with: gd) else { return nil }
        obj["graph"] = g
        return try? JSONSerialization.data(withJSONObject: obj)
    }

    /// Beim Wechsel in den Hintergrund: iOS um Zeit bitten, bis die Meldung raus ist.
    /// Befund 10.10.2026 (Box-Log): die App holte bei jedem Zurückkommen Entwürfe ab, meldete
    /// ihre Baustellen aber seit 13:35 nicht mehr – sie wurde eingefroren, bevor der Request rausging.
    @MainActor
    static func meldeImHintergrund(context: NSManagedObjectContext) {
        var aufgabe: UIBackgroundTaskIdentifier = .invalid
        aufgabe = UIApplication.shared.beginBackgroundTask(withName: "BaustellenMeldung") {
            UIApplication.shared.endBackgroundTask(aufgabe)
            aufgabe = .invalid
        }
        Task {
            await meldeAlle(context: context)
            await MainActor.run {
                if aufgabe != .invalid { UIApplication.shared.endBackgroundTask(aufgabe); aufgabe = .invalid }
            }
        }
    }

    /// Alle Baustellen melden. Leise: ohne Schlüssel oder ohne Netz passiert nichts Sichtbares.
    static func meldeAlle(context: NSManagedObjectContext) async {
        let schluessel = UserDefaults.standard.string(forKey: schluesselKey) ?? ""
        guard !schluessel.isEmpty, let url = URL(string: MopsConfig.host + endpoint) else { return }
        let meldungen: [(Meldung, Data?)] = await context.perform {
            let req = NSFetchRequest<Event>(entityName: "Event")
            return ((try? context.fetch(req)) ?? []).map { ev in
                let m = meldung(fuer: ev, von: "iMOPS-App")
                return (m, koerper(m, graph: Grap8Graph.aus(ev)))
            }
        }
        for (m, koerper) in meldungen {
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(schluessel, forHTTPHeaderField: "X-Mops-Schluessel")
            req.httpBody = koerper ?? (try? JSONEncoder().encode(m))
            do {
                let (_, antwort) = try await URLSession.shared.data(for: req)
                let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
                if code != 200 { logger.warning("Meldung \(m.id, privacy: .public): HTTP \(code)") }
            } catch {
                logger.info("Meldung \(m.id, privacy: .public) nicht angekommen: \(error.localizedDescription, privacy: .public)")
            }
        }
        await AbwesenheitenStore.shared.melde()   // gleicher Takt: wer nicht da ist, gehört zum Stand
    }
}
