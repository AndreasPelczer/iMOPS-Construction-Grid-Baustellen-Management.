import Foundation
import CoreData

enum DebugSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        #if DEBUG

        let key = "didSeedDemoEvent_v1"
        if UserDefaults.standard.bool(forKey: key) { return }

        // Nur seeden, wenn noch keine Events existieren
        let req: NSFetchRequest<Event> = Event.fetchRequest()
        req.fetchLimit = 1
        let existing = (try? context.fetch(req)) ?? []
        if !existing.isEmpty {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        // MARK: - Event
        let event = Event(context: context)
        event.name = "DEMO: Kantine & Produktion (MEP Test)"
        event.title = "Kantine & Produktion"
        event.location = "Produktionsküche / Kantine"
        event.setupTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
        event.eventStartTime = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())
        event.eventEndTime = Calendar.current.date(bySettingHour: 15, minute: 0, second: 0, of: Date())
        event.timeStamp = Date()
        event.notes = "Internes Test-Event zum Durchspielen von MEP, SOP und Übergaben"

        // MARK: - Aufträge
        let jobs: [(String, [String])] = [
            (
                "Setzarbeiten Küchenbereich 2",
                [
                    "MEP: GN-Bleche 1/1 bereitstellen (Geschirrlager 1 – Regal 2 Fach 7)",
                    "MEP: Etiketten, Stift, Klebeband bereitstellen",
                    "MEP: Handschuhe & Reinigungstücher prüfen",
                    "SOP: Ware holen (Menge + Charge prüfen)",
                    "SOP: Bleche belegen nach Standard",
                    "SOP: Beschriften (Datum / Uhrzeit / Allergene)",
                    "SOP: In Kühlkette zurückstellen",
                    "SOP: Auftrag übergabefähig markieren"
                ]
            ),
            (
                "Produktion: Spätzle anbraten",
                [
                    "MEP: Pfanne/Kipper & Butter bereitstellen",
                    "MEP: GN 1/1 6,5 cm bereitstellen (Ziel: ca. 5 cm Füllhöhe)",
                    "MEP: Hortenwagen 15 prüfen & vorheizen",
                    "SOP: Spätzle in Butter leicht anbraten",
                    "SOP: Gleichmäßig auf GN-Bleche verteilen",
                    "SOP: In Hortenwagen 15 einhängen",
                    "SOP: Temperatur prüfen & dokumentieren",
                    "SOP: Übergabe an Kantine markieren",
                    "SOP: Spülküche informieren – Kipper reinigen"
                ]
            ),
            (
                "VA: Essensausgabe Kantine 12–15 Uhr",
                [
                    "MEP: Ausgabeplatz prüfen & vorbereiten",
                    "SOP: Spätzle aus Hortenwagen übernehmen",
                    "SOP: Ausgabe starten",
                    "SOP: Nachschubstatus beobachten",
                    "SOP: Ausgabe beenden & Rückmeldung geben"
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
            print("🧪 DEBUG SEED: Demo-Event mit MEP/SOP-Aufträgen angelegt.")
        } catch {
            print("❌ DEBUG SEED Fehler: \(error)")
        }

        #endif
    }
}
