import SwiftUI
import CoreData

// MARK: - Helpers: Extras JSON (Checkliste)

struct EventExtrasPayload: Codable {
    var checklist: [EventChecklistItem] = []
    var pinnedProductIDs: [String] = []
    var pinnedLexikonCodes: [String] = []
}

struct EventChecklistItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isDone: Bool = false
}

// MARK: - Filter für Jobs
enum JobFilter: String, CaseIterable, Identifiable {
    case open = "Offene Aufträge"
    case all = "Alle Aufträge"
    var id: String { rawValue }
}

// -------------------------------------------------------------
// MARK: - HAUPT VIEW: EventDetailView
// -------------------------------------------------------------
struct EventDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var showingEditSheet = false
    @State private var showingAddJobSheet = false
    @State private var selectedJobFilter: JobFilter = .all
    @State private var extras = EventExtrasPayload()
    @State private var newStepText: String = ""
    @State private var refreshID = UUID()

    // MARK: Jobs: gefiltert + sortiert
    private var filteredJobs: [Auftrag] {
        _ = refreshID
        guard let jobsSet = event.jobs,
              var allJobs = jobsSet.allObjects as? [Auftrag] else { return [] }
        if selectedJobFilter == .open {
            allJobs = allJobs.filter { !$0.isCompleted }
        }
        return allJobs.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return (a.employeeName ?? "") < (b.employeeName ?? "")
        }
    }

    // MARK: Checklist Progress
    private var checklistDoneCount: Int { extras.checklist.filter { $0.isDone }.count }
    private var checklistTotalCount: Int { extras.checklist.count }
    private var checklistProgress: Double {
        guard checklistTotalCount > 0 else { return 0 }
        return Double(checklistDoneCount) / Double(checklistTotalCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                checklistCard
                jobsCard
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(event.title ?? "Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") { showingEditSheet = true }
            }
        }
        .onAppear { extras = loadExtras() }
        .sheet(isPresented: $showingEditSheet, onDismiss: { refreshID = UUID() }) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingAddJobSheet, onDismiss: { refreshID = UUID() }) {
            AddJobView(event: event, viewContext: viewContext)
        }
    }

    // MARK: - HEADER CARD
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title ?? "Unbenanntes Event")
                        .font(.title2.bold())
                    HStack(spacing: 10) {
                        if let nr = event.eventNumber, !nr.isEmpty {
                            Label(nr, systemImage: "number")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if let loc = event.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse")
                                .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(checklistProgress * 100))%")
                        .font(.headline.monospacedDigit())
                    Text("Checkliste").font(.caption).foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let setup = event.setupTime {
                    timeRow(icon: "timer", title: "Setup", date: setup, color: .orange)
                }
                if let start = event.eventStartTime {
                    timeRow(icon: "calendar.day.timeline.leading", title: "Start", date: start, color: .accentColor)
                }
                if let end = event.eventEndTime {
                    timeRow(icon: "clock.badge.checkmark", title: "Ende", date: end, color: .green)
                }
                EventTimelineBar(event: event)
            }

            if let notes = event.notes, !notes.isEmpty {
                Divider().opacity(0.4)
                Text(notes).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timeRow(icon: String, title: String, date: Date, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text("\(title):").font(.footnote.weight(.semibold))
            Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
            Text("\u{2022}").foregroundStyle(.secondary)
            Text(date, style: .time).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - CHECKLIST CARD
    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schritte / Checkliste").font(.headline)
                Spacer()
                Menu {
                    ForEach(AuftragTemplate.allCases) { tpl in
                        Button("Vorlage: \(tpl.rawValue)") {
                            extras.checklist.append(contentsOf: tpl.steps.map { EventChecklistItem(title: $0) })
                            saveExtras(extras)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        extras.checklist.removeAll()
                        saveExtras(extras)
                    } label: {
                        Label("Checkliste leeren", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                }
            }

            HStack(spacing: 10) {
                TextField("Neuer Schritt...", text: $newStepText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    addChecklistItem(title: newStepText)
                } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Text("\(checklistDoneCount)/\(checklistTotalCount) erledigt")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                ProgressView(value: checklistProgress).frame(width: 140)
            }

            if extras.checklist.isEmpty {
                Text("Noch keine Schritte.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(extras.checklist) { item in
                        checklistRow(item)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func checklistRow(_ item: EventChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button { toggleChecklist(itemID: item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title3)
            }
            Text(item.title).font(.body)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
            Button(role: .destructive) { deleteChecklist(itemID: item.id) } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - JOBS CARD
    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auftraege (\(filteredJobs.count))").font(.headline)
                Spacer()
                Menu {
                    Picker("Filter", selection: $selectedJobFilter) {
                        ForEach(JobFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                Button { showingAddJobSheet = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
            }

            if filteredJobs.isEmpty {
                Text("Keine Auftraege gefunden.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.top, 2)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredJobs, id: \.objectID) { job in
                        NavigationLink {
                            AuftragDetailView(job: job)
                        } label: {
                            AuftragRowView(auftrag: job) { refreshID = UUID() }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(radius: 1, y: 1)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .id(refreshID)
    }

    // MARK: - Extras Load/Save
    private func loadExtras() -> EventExtrasPayload {
        guard let s = event.extras, let data = s.data(using: .utf8) else {
            return EventExtrasPayload()
        }
        return (try? JSONDecoder().decode(EventExtrasPayload.self, from: data)) ?? EventExtrasPayload()
    }

    private func saveExtras(_ payload: EventExtrasPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            event.extras = String(data: data, encoding: .utf8)
            try viewContext.save()
        } catch {
            print("Fehler beim Speichern der Extras: \(error)")
        }
    }

    // MARK: - Checklist Actions
    private func addChecklistItem(title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        extras.checklist.append(EventChecklistItem(title: t))
        newStepText = ""
        saveExtras(extras)
    }

    private func toggleChecklist(itemID: String) {
        guard let idx = extras.checklist.firstIndex(where: { $0.id == itemID }) else { return }
        extras.checklist[idx].isDone.toggle()
        saveExtras(extras)
    }

    private func deleteChecklist(itemID: String) {
        extras.checklist.removeAll { $0.id == itemID }
        saveExtras(extras)
    }
}

// -------------------------------------------------------------
// MARK: - ZEIT-FORTSCHRITT HELPERS
// -------------------------------------------------------------
struct EventTimeProgress {
    let event: Event
    var progressRatio: Double {
        guard let setupTime = event.setupTime, let endTime = event.eventEndTime, setupTime < endTime else { return 0.0 }
        let totalDuration = endTime.timeIntervalSince(setupTime)
        let elapsedTime = Date().timeIntervalSince(setupTime)
        return min(1.0, max(0.0, elapsedTime / totalDuration))
    }
    var statusText: String {
        guard let setupTime = event.setupTime, let endTime = event.eventEndTime else { return "Zeit unvollstaendig" }
        let now = Date()
        if now < setupTime { return "Geplant" }
        if now >= endTime { return "Beendet" }
        return "Im Gange (\(Int(progressRatio * 100))%)"
    }
    var progressColor: Color {
        let now = Date()
        if let setupTime = event.setupTime, now < setupTime { return .blue }
        return progressRatio >= 1.0 ? .green : .orange
    }
}

struct EventTimelineBar: View {
    @ObservedObject var event: Event
    @State private var now = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var progressData: EventTimeProgress { EventTimeProgress(event: event) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Event-Status: \(progressData.statusText)")
                .font(.caption).foregroundColor(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 6).fill(progressData.progressColor)
                        .frame(width: geometry.size.width * CGFloat(progressData.progressRatio), height: 10)
                        .animation(.linear, value: progressData.progressRatio)
                }
            }
            .frame(height: 10)
        }
        .onReceive(timer) { _ in now = Date() }
    }
}
