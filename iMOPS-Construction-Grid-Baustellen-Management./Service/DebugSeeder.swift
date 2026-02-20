import Foundation
internal import CoreData

enum DebugSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        #if DEBUG

        let key = "didSeedDemoEvent_v2"
        if UserDefaults.standard.bool(forKey: key) { return }

        let req: NSFetchRequest<Event> = Event.fetchRequest()
        req.fetchLimit = 1
        let existing = (try? context.fetch(req)) ?? []
        if !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        // MARK: - Baustelle
        let event = Event(context: context)
        event.name = "DEMO: Sanierung Altbau (Test)"
        event.title = "Sanierung Altbau Goethestrasse 8"
        event.location = "Goethestrasse 8, 60313 Frankfurt"
        event.setupTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())
        event.eventStartTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
        event.eventEndTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())
        event.timeStamp = Date()
        event.notes = "Kernsanierung 2. OG: Trockenbau, Elektro, Sanitaer, Maler"

        // MARK: - Auftraege
        let jobs: [(String, [String])] = [
            (
                "Trockenbau 2. OG – Waende stellen",
                [
                    "UW-/CW-Profile ausmessen + schneiden",
                    "Unterkonstruktion montieren",
                    "Daemmung einlegen (Mineralwolle 60mm)",
                    "Beplankung Seite 1 (GKB 12,5mm)",
                    "Elektro-Leerrohre einlegen",
                    "Beplankung Seite 2",
                    "Fugen verspachteln + schleifen",
                    "Freigabe fuer Maler einholen"
                ]
            ),
            (
                "Elektro 2. OG – Neuverkabelung",
                [
                    "Bestandsleitungen pruefen / demontieren",
                    "Neue Leerrohre in Trockenbau verlegen",
                    "Kabel einziehen nach E-Plan",
                    "Schalter- und Steckdosen setzen",
                    "Verteilerkasten verdrahten",
                    "Isolations- und Durchgangspruefung",
                    "Abnahmeprotokoll erstellen"
                ]
            ),
            (
                "Malerarbeiten 2. OG – Waende + Decken",
                [
                    "Untergrund pruefen + Risse ausbessern",
                    "Grundierung auftragen",
                    "Abkleben (Fenster, Boden, Tuerzargen)",
                    "1. Anstrich Waende + Decken",
                    "2. Anstrich nach Trocknungszeit",
                    "Abkleben entfernen + Nacharbeiten",
                    "Endkontrolle + Freigabe"
                ]
            )
        ]

        for (details, steps) in jobs {
            let job = Auftrag(context: context)
            job.processingDetails = details
            job.isCompleted = false
            job.event = event

            var payload = JobExtrasPayload()
            payload.trainingMode = true
            payload.checklist = steps.map { AuftragChecklistItem(title: $0) }

            if let data = try? JSONEncoder().encode(payload) {
                job.extras = String(data: data, encoding: .utf8)
            }
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print("DEBUG SEED: Demo-Baustelle mit Auftraegen angelegt.")
        } catch {
            print("DEBUG SEED Fehler: \(error)")
        }

        #endif
    }
}
