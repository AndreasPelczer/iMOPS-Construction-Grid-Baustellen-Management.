import SwiftUI
import SafariServices
import CoreData
import Combine

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
    case all  = "Alle Aufträge"
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
    @State private var showingCADPicker = false
    @State private var showingMaterialPicker = false
    @State private var selectedJobFilter: JobFilter = .all
    @State private var extras = EventExtrasPayload()
    @State private var cadFiles: [CADFileInfo] = []
    @State private var pinnedMaterials: [CDLexikonEntry] = []
    @State private var newStepText: String = ""
    @State private var showingMaengelListe = false
    @State private var refreshID = UUID()
    @State private var showHelp = false

    @State private var isConverting = false
    @State private var conversionError: String?
    @State private var showConversionError = false
    @State private var showSketchUpWeb = false

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
    private var checklistDoneCount: Int  { extras.checklist.filter { $0.isDone }.count }
    private var checklistTotalCount: Int { extras.checklist.count }
    private var checklistProgress: Double {
        guard checklistTotalCount > 0 else { return 0 }
        return Double(checklistDoneCount) / Double(checklistTotalCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                WetterKarteView(ort: event.location ?? "")
                cadCard
                materialCard
                lvCard
                checklistCard
                maengelCard
                jobsCard
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(event.title ?? "Baustelle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") { showingEditSheet = true }
            }
        }
        .onAppear {
            extras = loadExtras()
            cadFiles = loadCADFiles()
            pinnedMaterials = fetchPinnedMaterials()
        }
        .sheet(isPresented: $showHelp) { EventDetailHelpView() }
        .sheet(isPresented: $showingEditSheet, onDismiss: { refreshID = UUID() }) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingAddJobSheet, onDismiss: { refreshID = UUID() }) {
            AddJobView(event: event, viewContext: viewContext)
        }
        .sheet(isPresented: $showingCADPicker) {
            CADDocumentPicker(
                onPicked: { importedURL in
                    let info = CADFileInfo(fileName: importedURL.lastPathComponent, relativePath: importedURL.lastPathComponent)
                    cadFiles.append(info)
                    saveCADFiles()
                },
                onServerConvert: { fileURL in convertFileToUSDZ(fileURL) },
                onSKPPicked: { skpFileURL in
                    if let url = skpFileURL {
                        let info = CADFileInfo(fileName: url.lastPathComponent, relativePath: url.lastPathComponent)
                        cadFiles.append(info)
                        saveCADFiles()
                    }
                }
            )
        }
        .overlay {
            if isConverting {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("Wird konvertiert...").font(.headline)
                        Text("Datei wird an den Server gesendet\nund automatisch in USDZ umgewandelt.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .alert("Konvertierung fehlgeschlagen", isPresented: $showConversionError) {
            Button("OK") {}
        } message: {
            Text(conversionError ?? "Unbekannter Fehler")
        }
        .sheet(isPresented: $showSketchUpWeb) {
            if let url = URL(string: "https://app.sketchup.com") {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingMaterialPicker, onDismiss: { pinnedMaterials = fetchPinnedMaterials() }) {
            MaterialPickerSheet(
                pinnedCodes: Binding(
                    get: { extras.pinnedLexikonCodes },
                    set: { newCodes in
                        extras.pinnedLexikonCodes = newCodes
                        saveExtras(extras)
                    }
                )
            )
        }
    }

    // MARK: - HEADER CARD
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title ?? "Unbenannte Baustelle").font(.title2.bold())
                    HStack(spacing: 10) {
                        if let nr = event.eventNumber, !nr.isEmpty {
                            Label(nr, systemImage: "number").font(.footnote).foregroundStyle(.secondary)
                        }
                        if let loc = event.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(checklistProgress * 100))%").font(.headline.monospacedDigit())
                    Text("Checkliste").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let setup = event.setupTime   { timeRow(icon: "timer",                         title: "Setup", date: setup, color: .orange) }
                if let start = event.eventStartTime { timeRow(icon: "calendar.day.timeline.leading", title: "Start", date: start, color: Color(uiColor: .tintColor)) }
                if let end   = event.eventEndTime   { timeRow(icon: "clock.badge.checkmark",         title: "Ende",  date: end,   color: .green) }
                EventTimelineBar(event: event)
            }
            let beteiligte: [(String, String)] = [
                ("person.crop.square", event.bauherr ?? ""),
                ("pencil.and.ruler",   event.architekt ?? ""),
                ("doc.badge.gearshape",event.baugenehmigungNr ?? "")
            ].filter { !$0.1.isEmpty }
            if !beteiligte.isEmpty {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(beteiligte, id: \.0) { icon, wert in
                        Label(wert, systemImage: icon).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
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
            Text("•").foregroundStyle(.secondary)
            Text(date, style: .time).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - CAD CARD
    private var cadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plaene & CAD").font(.headline)
                Spacer()
                Button { showingCADPicker = true } label: {
                    Label("Importieren", systemImage: "doc.badge.plus").font(.subheadline)
                }
            }
            if cadFiles.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "cube.transparent").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Keine Plaene importiert").font(.subheadline)
                        Text("USDZ, OBJ, DAE, FBX, STL oder glTF importieren").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                let grouped = Dictionary(grouping: cadFiles, by: { $0.planType })
                let sortedKeys = grouped.keys.sorted()
                ForEach(sortedKeys, id: \.self) { planType in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if let pt = PlanType(rawValue: planType) {
                                Image(systemName: pt.icon).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(planType).font(.subheadline.bold()).foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                        ForEach(grouped[planType] ?? []) { file in cadFileRow(file) }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func isSKPFile(_ file: CADFileInfo) -> Bool { file.fileName.lowercased().hasSuffix(".skp") }

    @ViewBuilder
    private func cadFileRow(_ file: CADFileInfo) -> some View {
        if let url = file.fullURL {
            if isSKPFile(file) {
                Button { showSketchUpWeb = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "safari.fill").font(.title3).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName).font(.body)
                            Text("Oeffnet in SketchUp Web (Safari)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .contextMenu {
                    Button { showSketchUpWeb = true } label: { Label("In SketchUp Web oeffnen", systemImage: "safari") }
                    Button { ExternalAppLauncher.shared.openInExternalApp(fileURL: url) } label: { Label("Teilen / Andere App", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { cadFiles.removeAll { $0.id == file.id }; saveCADFiles() } label: { Label("Loeschen", systemImage: "trash") }
                }
            } else {
                NavigationLink { CADViewerView(fileURL: url, fileName: file.fileName) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "cube.fill").font(.title3).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(file.fileName).font(.body)
                            Text(file.importDate.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .contextMenu {
                    Button { showSketchUpWeb = true } label: { Label("In SketchUp Web oeffnen", systemImage: "safari") }
                    Button { ExternalAppLauncher.shared.openInExternalApp(fileURL: url) } label: { Label("Teilen / Andere App", systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { cadFiles.removeAll { $0.id == file.id }; saveCADFiles() } label: { Label("Loeschen", systemImage: "trash") }
                }
            }
        }
    }

    // MARK: - MATERIAL CARD
    private var materialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Materialien").font(.headline)
                Spacer()
                Button { showingMaterialPicker = true } label: {
                    Label("Zuordnen", systemImage: "plus.circle").font(.subheadline)
                }
            }
            if pinnedMaterials.isEmpty && extras.pinnedLexikonCodes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Keine Materialien zugeordnet").font(.subheadline)
                        Text("Materialien aus dem Katalog dieser Baustelle zuweisen").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(pinnedMaterials, id: \.objectID) { mat in
                        HStack(spacing: 12) {
                            Image(systemName: iconForKategorie(mat.kategorie)).font(.title3).foregroundStyle(.orange).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mat.name ?? "").font(.body)
                                HStack(spacing: 6) {
                                    Text(mat.code ?? "").font(.caption).foregroundStyle(.secondary)
                                    Text("•").foregroundStyle(.secondary)
                                    Text(mat.kategorie ?? "").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button { unpinMaterial(code: mat.code ?? "") } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func iconForKategorie(_ kat: String?) -> String {
        switch kat {
        case "Rohbau":     return "building.2"
        case "Trockenbau": return "square.split.2x2"
        case "Elektro":    return "bolt.fill"
        case "Sanitaer":   return "drop.fill"
        case "Daemmung":   return "shield.fill"
        case "Ausbau":     return "paintbrush.fill"
        default:           return "shippingbox"
        }
    }

    private func unpinMaterial(code: String) {
        extras.pinnedLexikonCodes.removeAll { $0 == code }
        saveExtras(extras)
        pinnedMaterials = fetchPinnedMaterials()
    }

    private func fetchPinnedMaterials() -> [CDLexikonEntry] {
        guard !extras.pinnedLexikonCodes.isEmpty else { return [] }
        let req: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        req.predicate = NSPredicate(format: "code IN %@", extras.pinnedLexikonCodes)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)]
        return (try? viewContext.fetch(req)) ?? []
    }

    // MARK: - LV CARD
    private var lvCard: some View {
        NavigationLink {
            LVView(event: event)
                .environment(\.managedObjectContext, viewContext)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Leistungsverzeichnis").font(.headline).foregroundStyle(.primary)
                    let anzahl = event.lvPositionen?.count ?? 0
                    Text(anzahl == 0
                         ? "Noch keine Positionen"
                         : "\(anzahl) Position\(anzahl == 1 ? "" : "en")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
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
                } label: { Image(systemName: "wand.and.stars") }
            }
            HStack(spacing: 10) {
                TextField("Neuer Schritt...", text: $newStepText).textFieldStyle(.roundedBorder)
                Button { addChecklistItem(title: newStepText) } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                Text("\(checklistDoneCount)/\(checklistTotalCount) erledigt").font(.caption).foregroundStyle(.secondary)
                Spacer()
                ProgressView(value: checklistProgress).frame(width: 140)
            }
            if extras.checklist.isEmpty {
                Text("Noch keine Schritte.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(extras.checklist) { item in checklistRow(item) }
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
            Text(item.title).font(.body).strikethrough(item.isDone).foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
            Button(role: .destructive) { deleteChecklist(itemID: item.id) } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - MAENGEL CARD
    private var maengelAnzahl: Int { event.maengel?.count ?? 0 }
    private var maengelOffenAnzahl: Int {
        guard let set = event.maengel else { return 0 }
        return set.compactMap { $0 as? Mangel }.filter { $0.status == .offen || $0.status == .inArbeit }.count
    }

    private var maengelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Maengel (\(maengelAnzahl))").font(.headline)
                Spacer()
                Button { showingMaengelListe = true } label: {
                    Label("Alle anzeigen", systemImage: "list.bullet").font(.subheadline)
                }
            }
            if maengelAnzahl == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal").font(.title2).foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Keine Maengel erfasst").font(.subheadline)
                        Text("Maengel direkt vor Ort erfassen und verwalten.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("\(maengelOffenAnzahl)").font(.title2.bold()).foregroundStyle(maengelOffenAnzahl > 0 ? .red : .primary)
                        Text("Offen").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(maengelAnzahl - maengelOffenAnzahl)").font(.title2.bold()).foregroundStyle(.green)
                        Text("Erledigt").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { showingMaengelListe = true } label: {
                        Text("Details").font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(Color(.tertiarySystemFill)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $showingMaengelListe) {
            MangelListeView(event: event).environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - JOBS CARD
    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auftraege (\(filteredJobs.count))").font(.headline)
                Spacer()
                Menu {
                    Picker("Filter", selection: $selectedJobFilter) {
                        ForEach(JobFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                    }
                } label: { Image(systemName: "slider.horizontal.3") }
                Button { showingAddJobSheet = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            }
            if filteredJobs.isEmpty {
                Text("Keine Auftraege gefunden.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 2)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredJobs, id: \.objectID) { job in
                        NavigationLink { AuftragDetailView(job: job) } label: {
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
        guard let s = event.extras, let data = s.data(using: .utf8) else { return EventExtrasPayload() }
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

    // MARK: - CAD Files Load/Save
    private var cadStorageKey: String { "cadFiles_\(event.eventNumber ?? "unknown")" }
    private func loadCADFiles() -> [CADFileInfo] {
        guard let data = UserDefaults.standard.data(forKey: cadStorageKey),
              let payload = try? JSONDecoder().decode(CADFilesPayload.self, from: data) else { return [] }
        return payload.files
    }
    private func saveCADFiles() {
        let payload = CADFilesPayload(files: cadFiles)
        if let data = try? JSONEncoder().encode(payload) { UserDefaults.standard.set(data, forKey: cadStorageKey) }
    }

    // MARK: - Server-Konvertierung
    private func convertFileToUSDZ(_ fileURL: URL) {
        let service = SKPConversionService.shared
        if service.canConvertLocally(fileURL: fileURL) {
            do {
                let usdzURL = try service.convertLocally(fileURL: fileURL)
                let info = CADFileInfo(fileName: usdzURL.lastPathComponent, relativePath: usdzURL.lastPathComponent)
                cadFiles.append(info); saveCADFiles(); return
            } catch {}
        }
        isConverting = true; conversionError = nil
        Task {
            do {
                let usdzURL = try await service.convert(fileURL: fileURL)
                await MainActor.run {
                    let info = CADFileInfo(fileName: usdzURL.lastPathComponent, relativePath: usdzURL.lastPathComponent)
                    cadFiles.append(info); saveCADFiles(); isConverting = false
                }
            } catch {
                await MainActor.run { isConverting = false; conversionError = error.localizedDescription; showConversionError = true }
            }
        }
    }
}

// -------------------------------------------------------------
// MARK: - Material Picker Sheet
// -------------------------------------------------------------
struct MaterialPickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Binding var pinnedCodes: [String]

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
    ) private var allMaterials: FetchedResults<CDLexikonEntry>

    @State private var searchText = ""

    private var filtered: [CDLexikonEntry] {
        if searchText.isEmpty { return Array(allMaterials) }
        let q = searchText.lowercased()
        return allMaterials.filter {
            ($0.name ?? "").lowercased().contains(q) ||
            ($0.kategorie ?? "").lowercased().contains(q) ||
            ($0.code ?? "").lowercased().contains(q)
        }
    }

    private var grouped: [(String, [CDLexikonEntry])] {
        Dictionary(grouping: filtered, by: { $0.kategorie ?? "Sonstige" }).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { category, materials in
                    Section(category) {
                        ForEach(materials, id: \.objectID) { mat in
                            Button { togglePin(code: mat.code ?? "") } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mat.name ?? "").font(.body)
                                        Text(mat.code ?? "").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: pinnedCodes.contains(mat.code ?? "") ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(pinnedCodes.contains(mat.code ?? "") ? .green : .secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Material suchen...")
            .navigationTitle("Material zuordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }

    private func togglePin(code: String) {
        guard !code.isEmpty else { return }
        if let idx = pinnedCodes.firstIndex(of: code) { pinnedCodes.remove(at: idx) } else { pinnedCodes.append(code) }
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
        if now >= endTime  { return "Beendet" }
        return "Im Gange (\(Int(progressRatio * 100))%)"
    }
    var progressColor: Color {
        if let setupTime = event.setupTime, Date() < setupTime { return .blue }
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
            Text("Baustellen-Status: \(progressData.statusText)").font(.caption).foregroundColor(.secondary)
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
// MARK: - Hilfe: Baustellen-Detail
// -------------------------------------------------------------
struct EventDetailHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Übersicht") {
                    Text("Die Baustellen-Detail-Ansicht ist die Schaltzentrale für ein Projekt. Alle Informationen, Aufträge, Mängel und Pläne sind hier gebündelt.")
                }
                Section("Karten im Überblick") {
                    Label("Header: Name, Ort, Zeitraum, Bauherr, Architekt, Baugenehmigung", systemImage: "info.circle")
                    Label("Wetter: Aktuelle Bedingungen + Bau-Ampel für den Standort", systemImage: "cloud.sun.fill")
                    Label("Pläne & CAD: 3D-Modelle (USDZ, OBJ, FBX) und SketchUp-Dateien", systemImage: "cube.fill")
                    Label("Materialien: Verknüpfte Materialien aus dem Katalog", systemImage: "shippingbox")
                    Label("LV: Leistungsverzeichnis mit Positionen und Bestellliste", systemImage: "doc.text.fill")
                    Label("Checkliste: Schrittweise Arbeitsfortschritt abhaken", systemImage: "checkmark.square")
                    Label("Mängel: Qualitätsprobleme erfassen und verfolgen", systemImage: "exclamationmark.triangle")
                    Label("Aufträge: Einzelaufgaben anlegen und Mitarbeitern zuweisen", systemImage: "list.bullet.clipboard")
                }
                Section("LV") {
                    Label("Tippe auf die LV-Karte um das Leistungsverzeichnis zu öffnen", systemImage: "arrow.right.circle")
                    Label("Positionen anlegen, nach DIN 276 KG gruppiert", systemImage: "list.number")
                    Label("Bestellliste: strukturierte Mail an Lieferanten erstellen", systemImage: "envelope.badge")
                }
                Section("Checkliste") {
                    Label("Schritte manuell eingeben oder Vorlage (✶) für ein Gewerk laden", systemImage: "wand.and.stars")
                    Label("Fortschrittsanzeige oben rechts: % der erledigten Schritte", systemImage: "chart.bar.fill")
                }
                Section("Mängel") {
                    Label("Mängel = Abweichungen von der vereinbarten Leistung", systemImage: "exclamationmark.triangle.fill")
                    Label("Tippe auf \"Alle anzeigen\" → Mängelliste mit Fotos und Status", systemImage: "list.bullet")
                }
                Section("CAD / Pläne") {
                    Label("USDZ und OBJ: 3D-Vorschau direkt in der App", systemImage: "cube.fill")
                    Label("SKP (SketchUp): öffnet SketchUp Web in Safari", systemImage: "safari")
                    Label("FBX, STL, glTF: automatische Server-Konvertierung zu USDZ", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .navigationTitle("Hilfe: Baustellen-Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}
