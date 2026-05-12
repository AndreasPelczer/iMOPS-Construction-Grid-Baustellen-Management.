import SwiftUI
import CoreData

struct GlobalSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var query = ""
    @State private var foundEvents:     [Event]          = []
    @State private var foundPositionen: [LVPosition]     = []
    @State private var foundMaengel:    [Mangel]         = []
    @State private var foundKatalog:    [CDLexikonEntry] = []
    @State private var foundAuftraege:  [Auftrag]        = []

    private var hasResults: Bool {
        !foundEvents.isEmpty || !foundPositionen.isEmpty ||
        !foundMaengel.isEmpty || !foundKatalog.isEmpty || !foundAuftraege.isEmpty
    }

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                ContentUnavailableView(
                    "Suchen",
                    systemImage: "magnifyingglass",
                    description: Text("Baustellen, LV-Positionen, Mängel, Katalog, Aufträge — alles auf einmal.")
                )
            } else if !hasResults {
                ContentUnavailableView.search(text: query)
            } else {
                if !foundEvents.isEmpty {
                    Section("Baustellen (\(foundEvents.count))") {
                        ForEach(foundEvents, id: \.objectID) { event in
                            NavigationLink {
                                EventDetailView(event: event)
                                    .environment(\.managedObjectContext, viewContext)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.title ?? "–").font(.body)
                                    HStack(spacing: 6) {
                                        if let loc = event.location, !loc.isEmpty {
                                            Text(loc).font(.caption).foregroundStyle(.secondary)
                                        }
                                        if let nr = event.eventNumber, !nr.isEmpty {
                                            Text("·").foregroundStyle(.secondary)
                                            Text(nr).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if !foundPositionen.isEmpty {
                    Section("LV-Positionen (\(foundPositionen.count))") {
                        ForEach(foundPositionen, id: \.objectID) { pos in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pos.bezeichnung ?? "–").font(.body).lineLimit(1)
                                HStack(spacing: 6) {
                                    if let nr = pos.posNr { Text(nr).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                                    if let art = pos.artikelNummer, !art.isEmpty {
                                        Text("·").foregroundStyle(.secondary)
                                        Text(art).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if let ev = pos.event?.title {
                                        Text("·").foregroundStyle(.secondary)
                                        Text(ev).font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                if !foundMaengel.isEmpty {
                    Section("Mängel (\(foundMaengel.count))") {
                        ForEach(foundMaengel, id: \.objectID) { mangel in
                            NavigationLink {
                                MangelDetailView(mangel: mangel)
                                    .environment(\.managedObjectContext, viewContext)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: mangel.status.symbol)
                                        .foregroundStyle(mangel.status.farbe)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mangel.titel ?? "–").font(.body).lineLimit(1)
                                        HStack(spacing: 4) {
                                            if let ort = mangel.ort, !ort.isEmpty {
                                                Text(ort).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                                Text("·").foregroundStyle(.secondary)
                                            }
                                            Text(mangel.status.displayName)
                                                .font(.caption)
                                                .foregroundStyle(mangel.status.farbe)
                                            if let ev = mangel.event?.title {
                                                Text("·").foregroundStyle(.secondary)
                                                Text(ev).font(.caption).foregroundStyle(.orange).lineLimit(1)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if !foundKatalog.isEmpty {
                    Section("Katalog (\(foundKatalog.count))") {
                        ForEach(foundKatalog, id: \.objectID) { entry in
                            NavigationLink {
                                MaterialDetailView(material: entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name ?? "–").font(.body).lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(entry.code ?? "").font(.caption).foregroundStyle(.secondary)
                                        if let kat = entry.kategorie, !kat.isEmpty {
                                            Text("·").foregroundStyle(.secondary)
                                            Text(kat).font(.caption).foregroundStyle(.orange).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if !foundAuftraege.isEmpty {
                    Section("Aufträge (\(foundAuftraege.count))") {
                        ForEach(foundAuftraege, id: \.objectID) { job in
                            NavigationLink { AuftragDetailView(job: job) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: job.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(job.isCompleted ? .green : .orange)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(job.employeeName ?? "–").font(.body).lineLimit(1)
                                        HStack(spacing: 6) {
                                            if let kg = job.kostenGruppeBezeichnung, !kg.isEmpty {
                                                Text(kg).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                                Text("·").foregroundStyle(.secondary)
                                            }
                                            if let ev = job.event?.title {
                                                Text(ev).font(.caption).foregroundStyle(.orange).lineLimit(1)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Baustelle, Mangel, Position, Artikel, Auftrag...")
        .navigationTitle("Suche")
        .onChange(of: query) { _, q in performSearch(q) }
    }

    private func performSearch(_ raw: String) {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            foundEvents = []; foundPositionen = []; foundMaengel = []
            foundKatalog = []; foundAuftraege = []
            return
        }

        let eventReq: NSFetchRequest<Event> = Event.fetchRequest()
        eventReq.predicate = NSPredicate(
            format: "title CONTAINS[cd] %@ OR location CONTAINS[cd] %@ OR bauherr CONTAINS[cd] %@", q, q, q)
        eventReq.sortDescriptors = [NSSortDescriptor(keyPath: \Event.title, ascending: true)]
        eventReq.fetchLimit = 20
        foundEvents = (try? viewContext.fetch(eventReq)) ?? []

        let posReq: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        posReq.predicate = NSPredicate(
            format: "bezeichnung CONTAINS[cd] %@ OR artikelNummer CONTAINS[cd] %@ OR posNr CONTAINS[cd] %@", q, q, q)
        posReq.sortDescriptors = [NSSortDescriptor(keyPath: \LVPosition.bezeichnung, ascending: true)]
        posReq.fetchLimit = 20
        foundPositionen = (try? viewContext.fetch(posReq)) ?? []

        let mangelReq: NSFetchRequest<Mangel> = Mangel.fetchRequest()
        mangelReq.predicate = NSPredicate(
            format: "titel CONTAINS[cd] %@ OR beschreibung CONTAINS[cd] %@ OR ort CONTAINS[cd] %@ OR gewerk CONTAINS[cd] %@",
            q, q, q, q)
        mangelReq.sortDescriptors = [NSSortDescriptor(keyPath: \Mangel.titel, ascending: true)]
        mangelReq.fetchLimit = 20
        foundMaengel = (try? viewContext.fetch(mangelReq)) ?? []

        let katReq: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        katReq.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR code CONTAINS[cd] %@ OR kategorie CONTAINS[cd] %@", q, q, q)
        katReq.sortDescriptors = [NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)]
        katReq.fetchLimit = 25
        foundKatalog = (try? viewContext.fetch(katReq)) ?? []

        let jobReq: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        jobReq.predicate = NSPredicate(
            format: "employeeName CONTAINS[cd] %@ OR kostenGruppeBezeichnung CONTAINS[cd] %@ OR kostenGruppeNummer CONTAINS[cd] %@ OR processingDetails CONTAINS[cd] %@ OR storageLocation CONTAINS[cd] %@",
            q, q, q, q, q)
        jobReq.sortDescriptors = [NSSortDescriptor(key: "employeeName", ascending: true)]
        jobReq.fetchLimit = 20
        foundAuftraege = (try? viewContext.fetch(jobReq)) ?? []
    }
}
