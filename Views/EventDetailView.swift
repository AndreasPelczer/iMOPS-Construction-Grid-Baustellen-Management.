import SwiftUI
import CoreData

// MARK: - Helpers: Extras JSON (Checkliste + Knowledge Pins)
// Wir speichern Zusatzdaten im Event.extras als JSON, damit wir KEIN neues CoreData Entity brauchen.

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


// MARK: - Filter für Jobs (bleibt kompatibel)
enum JobFilter: String, CaseIterable, Identifiable {
    case open = "Offene Aufträge"
    case all = "Alle Aufträge"
    var id: String { rawValue }
}

// -------------------------------------------------------------
// MARK: - HAUPT VIEW: EventDetailView (MODERN + CHECKLIST + KNOWLEDGE)
// -------------------------------------------------------------
struct EventDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    // Sheets
    @State private var showingEditSheet = false
    @State private var showingAddJobSheet = false
    @State private var showingKnowledgeSheet = false

    // Jobs Filter
    @State private var selectedJobFilter: JobFilter = .all

    // Extras (Checkliste + Pins)
    @State private var extras = EventExtrasPayload()

    // Neue Checklist-Eingabe
    @State private var newStepText: String = ""

    // Refresh Trigger (wenn JobSheet schließen etc.)
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
    private var checklistDoneCount: Int {
        extras.checklist.filter { $0.isDone }.count
    }

    private var checklistTotalCount: Int {
        extras.checklist.count
    }

    private var checklistProgress: Double {
        guard checklistTotalCount > 0 else { return 0 }
        return Double(checklistDoneCount) / Double(checklistTotalCount)
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // 0) MEIER-SCORE (Phase 3: Kognitive Last)
                meierScoreCard

                // 1) HEADER / STATUS / TIMES
                headerCard

                // 2) CHECKLISTE (Schritte abhaken)
                checklistCard

                // 3) AUFTRÄGE
                jobsCard

                // 4) WISSEN (Pins: Produkt + Lexikon)
                knowledgeCard

                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(event.title ?? "Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingKnowledgeSheet = true
                } label: {
                    Image(systemName: "books.vertical")
                }

                Button("Bearbeiten") {
                    showingEditSheet = true
                }
            }
        }
        .onAppear {
            extras = loadExtras()
        }
        .sheet(isPresented: $showingEditSheet, onDismiss: {
            refreshID = UUID()
        }) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingAddJobSheet, onDismiss: {
            refreshID = UUID()
        }) {
            AddJobView(event: event, viewContext: viewContext)
        }
        .sheet(isPresented: $showingKnowledgeSheet, onDismiss: {
            extras = loadExtras()
        }) {
            KnowledgePinSheet(
                pinnedProductIDs: $extras.pinnedProductIDs,
                pinnedLexikonCodes: $extras.pinnedLexikonCodes,
                onSave: {
                    saveExtras(extras)
                }
            )
            .environment(\.managedObjectContext, viewContext)
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
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        if let loc = event.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(checklistProgress * 100))%")
                        .font(.headline.monospacedDigit())
                    Text("Checkliste")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timeRow(icon: String, title: String, date: Date, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("\(title):")
                .font(.footnote.weight(.semibold))
            Text(date, style: .date)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("•")
                .foregroundStyle(.secondary)
            Text(date, style: .time)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - MEIER-SCORE CARD (Phase 3: Kognitive Last)
    private var meierScoreCard: some View {
        let brain = TheBrain.shared
        let score = brain.meierScore
        let color: Color = score < 40 ? .green : (score < 70 ? .yellow : .red)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("JOSHUA-Matrix", systemImage: "brain.head.profile")
                    .font(.headline)
                Spacer()
                Text("\(score)%")
                    .font(.title.monospacedDigit().bold())
                    .foregroundStyle(color)
            }

            Gauge(value: Double(score), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text("Kognitive Last")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .gaugeStyle(.linearCapacity)
            .tint(color)

            // Mini-Historie (letzte 10 Punkte)
            let recent = Array(brain.scoreHistory.suffix(10))
            if recent.count > 1 {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(recent) { point in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(point.score < 40 ? Color.green : (point.score < 70 ? Color.yellow : Color.red))
                            .frame(width: 8, height: max(4, CGFloat(point.score) * 0.4))
                    }
                }
                .frame(height: 40)
            }

            // Aktive Tasks Zähler
            let activeCount = filteredJobs.filter { !$0.isCompleted }.count
            Text("\(activeCount) aktive Aufträge im Kernel")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - CHECKLIST CARD
    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("✅ Schritte / Checkliste")
                    .font(.headline)
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
                TextField("Neuer Schritt…", text: $newStepText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    addChecklistItem(title: newStepText)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Text("\(checklistDoneCount)/\(checklistTotalCount) erledigt")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                ProgressView(value: checklistProgress)
                    .frame(width: 140)
            }

            if extras.checklist.isEmpty {
                Text("Noch keine Schritte.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
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

    private func checklistRow(_ item: EventChecklistItem) -> some View{
        HStack(spacing: 12) {
            Button {
                toggleChecklist(itemID: item.id)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }

            Text(item.title)
                .font(.body)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)

            Spacer()

            Button(role: .destructive) {
                deleteChecklist(itemID: item.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - JOBS CARD
    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🛠️ Aufträge (\(filteredJobs.count))")
                    .font(.headline)
                Spacer()

                Menu {
                    Picker("Filter Aufträge", selection: $selectedJobFilter) {
                        ForEach(JobFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }

                Button {
                    showingAddJobSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            if filteredJobs.isEmpty {
                Text("Keine Aufträge gefunden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredJobs, id: \.objectID) { job in
                        NavigationLink {
                            AuftragDetailView(job: job)
                        } label: {
                            AuftragRowView(auftrag: job) {
                                refreshID = UUID()
                            }
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

    // MARK: - KNOWLEDGE CARD
    private var knowledgeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📚 Wissen (Pins)")
                    .font(.headline)
                Spacer()
                Button {
                    showingKnowledgeSheet = true
                } label: {
                    Label("Pin", systemImage: "pin.fill")
                        .labelStyle(.iconOnly)
                }
            }

            // HINWEIS: Diese Views müssen in einer anderen Datei definiert sein
            PinnedProductsSection(productIDs: extras.pinnedProductIDs)
                .environment(\.managedObjectContext, viewContext)

            PinnedLexikonSection(codes: extras.pinnedLexikonCodes)
                .environment(\.managedObjectContext, viewContext)

            Text("Tipp: Pinne Produkte und Lexikon-Einträge für schnellen Zugriff.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Extras Load/Save
    private func loadExtras() -> EventExtrasPayload {
        guard let s = event.extras, let data = s.data(using: .utf8) else {
            return EventExtrasPayload()
        }
        do {
            return try JSONDecoder().decode(EventExtrasPayload.self, from: data)
        } catch {
            return EventExtrasPayload()
        }
    }

    private func saveExtras(_ payload: EventExtrasPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            event.extras = String(data: data, encoding: .utf8)
            try viewContext.save()
        } catch {
            print("❌ Fehler beim Speichern der Extras: \(error)")
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


    // Templates werden jetzt direkt aus AuftragTemplate.allCases im Menü geladen
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
        guard let setupTime = event.setupTime, let endTime = event.eventEndTime else { return "Zeit unvollständig" }
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
            Text("Event-Status: \(progressData.statusText)").font(.caption).foregroundColor(.secondary)
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

// -------------------------------------------------------------
// MARK: - KNOWLEDGE SHEET & DETAILS
// -------------------------------------------------------------

struct KnowledgePinSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx
    @Binding var pinnedProductIDs: [String]
    @Binding var pinnedLexikonCodes: [String]
    var onSave: () -> Void
    @State private var searchText: String = ""
    @State private var foundProducts: [CDProduct] = []
    @State private var foundLexikon: [CDLexikonEntry] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Suchen…", text: $searchText)
                    .textFieldStyle(.roundedBorder).padding(.horizontal)
                    .onChange(of: searchText) { runSearch() }

                List {
                    if !foundProducts.isEmpty {
                        Section("Produkte") {
                            ForEach(foundProducts, id: \.objectID) { p in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(p.name ?? "Produkt")
                                        Text(p.category ?? "").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button { pinProduct(p) } label: {
                                        Image(systemName: pinnedProductIDs.contains(p.id ?? "") ? "pin.fill" : "pin")
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if !foundLexikon.isEmpty {
                        Section("Lexikon") {
                            ForEach(foundLexikon, id: \.objectID) { e in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(e.name ?? "Eintrag")
                                        Text(e.kategorie ?? "").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button { pinLexikon(e) } label: {
                                        Image(systemName: pinnedLexikonCodes.contains(e.code ?? "") ? "pin.fill" : "pin")
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Wissen pinnen")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Schließen") { onSave(); dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Speichern") { onSave(); dismiss() } }
            }
            .onAppear { runSearch() }
        }
    }

    private func runSearch() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let pReq: NSFetchRequest<CDProduct> = CDProduct.fetchRequest()
        if !q.isEmpty { pReq.predicate = NSPredicate(format: "name CONTAINS[cd] %@", q) }
        pReq.fetchLimit = 20
        let lReq: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        if !q.isEmpty { lReq.predicate = NSPredicate(format: "name CONTAINS[cd] %@", q) }
        lReq.fetchLimit = 20
        do { foundProducts = try ctx.fetch(pReq); foundLexikon = try ctx.fetch(lReq) } catch { }
    }

    private func pinProduct(_ p: CDProduct) {
        guard let id = p.id else { return }
        if pinnedProductIDs.contains(id) { pinnedProductIDs.removeAll { $0 == id } } else { pinnedProductIDs.append(id) }
    }

    private func pinLexikon(_ e: CDLexikonEntry) {
        guard let code = e.code else { return }
        if pinnedLexikonCodes.contains(code) { pinnedLexikonCodes.removeAll { $0 == code } } else { pinnedLexikonCodes.append(code) }
    }
}

private struct ProductPinnedDetailView: View {
    @ObservedObject var product: CDProduct
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text(product.name ?? "").font(.title2.bold())
                    Text(product.category ?? "").foregroundStyle(.secondary)
                }.padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                
                if let b = product.beschreibung { infoCard(title: "Beschreibung", text: b) }
            }.padding()
        }
    }
    private func infoCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }.padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct LexikonPinnedDetailView: View {
    @ObservedObject var entry: CDLexikonEntry
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading) {
                    Text(entry.name ?? "").font(.title2.bold())
                    Text(entry.kategorie ?? "").foregroundStyle(.secondary)
                }.padding().background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                
                if let b = entry.beschreibung { infoCard(title: "Beschreibung", text: b) }
            }.padding()
        }
    }
    private func infoCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).foregroundStyle(.secondary)
        }.padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
