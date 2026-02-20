import SwiftUI
internal import CoreData

// MARK: - Master = AuftragExtrasPayload
typealias JobExtrasPayload = AuftragExtrasPayload

// MARK: - AuftragDetailView
struct AuftragDetailView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var job: Auftrag

    @State private var extras = JobExtrasPayload()
    @State private var newStepText: String = ""

    private var doneCount: Int { extras.checklist.filter { $0.isDone }.count }
    private var totalCount: Int { extras.checklist.count }
    private var progress: Double { totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount) }

    private var nextOpenStepTitle: String? {
        extras.checklist.first(where: { !$0.isDone })?.title
    }

    private var whatToDoText: String {
        if let d = job.processingDetails, !d.isEmpty { return d }
        if let first = extras.lineItems.first?.title, !first.isEmpty { return first }
        return "Auftrag"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                jetztCard
                productionListCard
                headerCard
                modeCard
                checklistCard
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(whatToDoText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { extras = loadExtras() }
    }

    // MARK: - UI Cards

    private var jetztCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("JETZT")
                .font(.caption).foregroundStyle(.secondary)
            Text(whatToDoText)
                .font(.title2.weight(.bold)).lineLimit(3)
            if extras.trainingMode,
               let next = nextOpenStepTitle,
               !job.isCompleted {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text(next)
                }
                .font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(whatToDoText).font(.title2.bold()).lineLimit(3)

            HStack(spacing: 10) {
                if !extras.orderNumber.isEmpty {
                    Label(extras.orderNumber, systemImage: "number")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !extras.station.isEmpty {
                    Label(extras.station, systemImage: "mappin.and.ellipse")
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            HStack(spacing: 12) {
                if let deadline = extras.deadline {
                    Label(deadline.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if extras.persons > 0 {
                    Label("\(extras.persons) Pers.", systemImage: "person.2")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let emp = job.employeeName, !emp.isEmpty {
                    Label(emp, systemImage: "person.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if extras.trainingMode, let next = nextOpenStepTitle, !job.isCompleted {
                Text("Jetzt: \(next)")
                    .font(.subheadline.weight(.semibold)).padding(.top, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var modeCard: some View {
        HStack {
            Text(extras.trainingMode ? "Schrittweise" : "Schnellmodus")
                .font(.headline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { extras.trainingMode },
                set: { extras.trainingMode = $0; saveExtras(extras) }
            ))
            .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var productionListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Materialliste").font(.headline)
                Spacer()
                Text("\(extras.lineItems.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }

            if extras.lineItems.isEmpty {
                Text("Keine Positionen hinterlegt.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(extras.lineItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.body.weight(.semibold))
                            if !(item.amount.isEmpty && item.unit.isEmpty) {
                                Text("\(item.amount) \(item.unit)".trimmingCharacters(in: .whitespaces))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(item.note).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                            }
                        }
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Arbeitsschritte").font(.headline)
                Spacer()
                Menu {
                    ForEach(AuftragTemplate.allCases) { tpl in
                        Button("Vorlage: \(tpl.rawValue)") {
                            applyTemplate(tpl, mode: .append)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        extras.checklist.removeAll()
                        job.isCompleted = false
                        saveExtras(extras)
                    } label: {
                        Label("Leeren", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                }
            }

            if extras.trainingMode {
                HStack(spacing: 10) {
                    TextField("Neuer Schritt...", text: $newStepText)
                        .textFieldStyle(.roundedBorder)
                    Button { addStep(newStepText) } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if extras.checklist.isEmpty {
                    Text("Noch keine Schritte. Nutze eine Vorlage oder fuege Schritte hinzu.")
                        .foregroundStyle(.secondary).font(.subheadline)
                } else {
                    VStack(spacing: 8) {
                        ForEach(extras.checklist) { item in
                            trainingStepRow(item)
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button { markJobCompleted() } label: {
                        Label(job.isCompleted ? "Auftrag ist fertig" : "Auftrag fertig",
                              systemImage: job.isCompleted ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) { resetCompletion() } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!job.isCompleted)
                }

                if extras.checklist.isEmpty {
                    Text("Keine Arbeitsschritte hinterlegt.")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
                } else {
                    DisclosureGroup("Schritte anzeigen (\(extras.checklist.count))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(extras.checklist) { item in
                                proStepRow(item)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trainingStepRow(_ item: AuftragChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button { toggleStep(item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title2)
            }
            Text(item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
            Button(role: .destructive) { deleteStep(item.id) } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func proStepRow(_ item: AuftragChecklistItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.badge.checkmark").foregroundStyle(.secondary)
            Text(item.title)
            Spacer()
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Data: load/save extras
    private func loadExtras() -> AuftragExtrasPayload {
        guard let s = job.extras, let data = s.data(using: .utf8) else { return AuftragExtrasPayload() }
        return (try? JSONDecoder().decode(AuftragExtrasPayload.self, from: data)) ?? AuftragExtrasPayload()
    }

    private func saveExtras(_ payload: AuftragExtrasPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            job.extras = String(data: data, encoding: .utf8)
            try ctx.save()
        } catch {
            print("Auftrag extras save error: \(error)")
        }
    }

    // MARK: - Checklist actions
    private func addStep(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        extras.checklist.append(AuftragChecklistItem(title: t))
        newStepText = ""
        job.isCompleted = false
        saveExtras(extras)
    }

    private func toggleStep(_ id: String) {
        guard let idx = extras.checklist.firstIndex(where: { $0.id == id }) else { return }
        extras.checklist[idx].isDone.toggle()
        let allDone = !extras.checklist.isEmpty && extras.checklist.allSatisfy { $0.isDone }
        job.isCompleted = allDone
        saveExtras(extras)
    }

    private func deleteStep(_ id: String) {
        extras.checklist.removeAll { $0.id == id }
        let allDone = !extras.checklist.isEmpty && extras.checklist.allSatisfy { $0.isDone }
        job.isCompleted = allDone
        saveExtras(extras)
    }

    private func markJobCompleted() {
        job.isCompleted = true
        job.status = .completed
        for i in extras.checklist.indices { extras.checklist[i].isDone = true }
        saveExtras(extras)
    }

    private func resetCompletion() {
        job.isCompleted = false
        for i in extras.checklist.indices { extras.checklist[i].isDone = false }
        saveExtras(extras)
    }

    // MARK: - Templates
    private enum TemplateInsertMode { case replace, append }

    private func applyTemplate(_ template: AuftragTemplate, mode: TemplateInsertMode) {
        let newItems = template.steps.map { AuftragChecklistItem(title: $0) }
        if mode == .replace {
            extras.checklist = newItems
        } else {
            extras.checklist.append(contentsOf: newItems)
        }
        job.isCompleted = false
        saveExtras(extras)
    }
}
