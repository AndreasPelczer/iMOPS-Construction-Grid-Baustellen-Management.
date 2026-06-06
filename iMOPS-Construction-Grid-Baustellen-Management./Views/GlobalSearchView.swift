import SwiftUI
import CoreData

struct GlobalSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var query = ""
    @State private var cat: SearchCat = .alle
    @State private var foundEvents:     [Event]          = []
    @State private var foundPositionen: [LVPosition]     = []
    @State private var foundMaengel:    [Mangel]         = []
    @State private var foundKatalog:    [CDLexikonEntry] = []
    @State private var foundAuftraege:  [Auftrag]        = []
    @State private var alleLVs: [(event: Event, anzahl: Int)] = []

    enum SearchCat: String, CaseIterable, Identifiable {
        case alle = "Alle", baustellen = "Baustellen", lv = "LV"
        case maengel = "Mängel", katalog = "Katalog", auftraege = "Aufträge"
        var id: String { rawValue }
    }

    private func zeigt(_ c: SearchCat) -> Bool { cat == .alle || cat == c }
    private var qLen: Int { query.trimmingCharacters(in: .whitespacesAndNewlines).count }
    private var alleLVModus: Bool { cat == .lv && qLen < 2 }

    private var hasResults: Bool {
        (zeigt(.baustellen) && !foundEvents.isEmpty) ||
        (zeigt(.lv) && !foundPositionen.isEmpty) ||
        (zeigt(.maengel) && !foundMaengel.isEmpty) ||
        (zeigt(.katalog) && !foundKatalog.isEmpty) ||
        (zeigt(.auftraege) && !foundAuftraege.isEmpty)
    }

    var body: some View {
        List {
            if alleLVModus {
                alleLVsSection
            } else if qLen < 2 {
                ContentUnavailableView(
                    "Suchen",
                    systemImage: "magnifyingglass",
                    description: Text("Baustellen, LV-Positionen, Mängel, Katalog, Aufträge — oder unten eine Kategorie wählen."))
            } else if !hasResults {
                ContentUnavailableView.search(text: query)
            } else {
                if zeigt(.baustellen) && !foundEvents.isEmpty { baustellenSection }
                if zeigt(.lv) && !foundPositionen.isEmpty { lvSection }
                if zeigt(.maengel) && !foundMaengel.isEmpty { maengelSection }
                if zeigt(.katalog) && !foundKatalog.isEmpty { katalogSection }
                if zeigt(.auftraege) && !foundAuftraege.isEmpty { auftraegeSection }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: searchPrompt)
        .navigationTitle("Suche")
        .onChange(of: query) { _, q in performSearch(q) }
        .onChange(of: cat) { _, _ in if cat == .lv { ladeAlleLVs() } }
        .onAppear { ladeAlleLVs() }
        .safeAreaInset(edge: .bottom) { chipBar }
    }

    // MARK: - Kategorie-Chips (unten)

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchCat.allCases) { c in
                    FilterChip(title: c.rawValue, isSelected: cat == c) { cat = c }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var searchPrompt: String {
        switch cat {
        case .alle:       return "Baustelle, Mangel, Position, Artikel, Auftrag..."
        case .baustellen: return "Baustelle, Ort, Bauherr..."
        case .lv:         return "LV durchsuchen — oder leer lassen für alle LVs"
        case .maengel:    return "Mangel, Ort, Gewerk..."
        case .katalog:    return "Material, Code, Kategorie..."
        case .auftraege:  return "Auftrag, Mitarbeiter, Kostengruppe..."
        }
    }

    // MARK: - Alle-LVs-Modus

    private var alleLVsSection: some View {
        Section("Alle Leistungsverzeichnisse (\(alleLVs.count))") {
            if alleLVs.isEmpty {
                Text("Noch keine LV-Positionen angelegt.").foregroundStyle(.secondary)
            }
            ForEach(alleLVs, id: \.event.objectID) { item in
                NavigationLink {
                    LVView(event: item.event).environment(\.managedObjectContext, viewContext)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text").foregroundStyle(.orange).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.event.title ?? "–").font(.body)
                            HStack(spacing: 6) {
                                Text("\(item.anzahl) Positionen").font(.caption).foregroundStyle(.secondary)
                                if let nr = item.event.eventNumber, !nr.isEmpty {
                                    Text("·").foregroundStyle(.secondary)
                                    Text(nr).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Ergebnis-Abschnitte

    private var baustellenSection: some View {
        Section("Baustellen (\(foundEvents.count))") {
            ForEach(foundEvents, id: \.objectID) { event in
                NavigationLink {
                    EventDetailView(event: event).environment(\.managedObjectContext, viewContext)
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

    private var lvSection: some View {
        Section("LV-Positionen (\(foundPositionen.count))") {
            ForEach(foundPositionen, id: \.objectID) { pos in
                if let ev = pos.event {
                    NavigationLink {
                        LVView(event: ev).environment(\.managedObjectContext, viewContext)
                    } label: { lvRow(pos) }
                } else {
                    lvRow(pos)
                }
            }
        }
    }

    private func lvRow(_ pos: LVPosition) -> some View {
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

    private var maengelSection: some View {
        Section("Mängel (\(foundMaengel.count))") {
            ForEach(foundMaengel, id: \.objectID) { mangel in
                NavigationLink {
                    MangelDetailView(mangel: mangel).environment(\.managedObjectContext, viewContext)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mangel.status.symbol)
                            .foregroundStyle(mangel.status.farbe).frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mangel.titel ?? "–").font(.body).lineLimit(1)
                            HStack(spacing: 4) {
                                if let ort = mangel.ort, !ort.isEmpty {
                                    Text(ort).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    Text("·").foregroundStyle(.secondary)
                                }
                                Text(mangel.status.displayName).font(.caption).foregroundStyle(mangel.status.farbe)
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

    private var katalogSection: some View {
        Section("Katalog (\(foundKatalog.count))") {
            ForEach(foundKatalog, id: \.objectID) { entry in
                NavigationLink { MaterialDetailView(material: entry) } label: {
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

    private var auftraegeSection: some View {
        Section("Aufträge (\(foundAuftraege.count))") {
            ForEach(foundAuftraege, id: \.objectID) { job in
                NavigationLink { AuftragDetailView(job: job) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: job.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(job.isCompleted ? .green : .orange).frame(width: 20)
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

    // MARK: - Daten

    private func ladeAlleLVs() {
        let req: NSFetchRequest<LVPosition> = LVPosition.fetchRequest()
        let all = (try? viewContext.fetch(req)) ?? []
        let groups = Dictionary(grouping: all, by: { $0.event })
        alleLVs = groups.compactMap { (ev, pos) in ev.map { (event: $0, anzahl: pos.count) } }
            .sorted { ($0.event.title ?? "") < ($1.event.title ?? "") }
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
        posReq.fetchLimit = 30
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
