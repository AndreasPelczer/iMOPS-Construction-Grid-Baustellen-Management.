import SwiftUI
import CoreData

struct AuftragRowView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var auftrag: Auftrag
    var onChanged: () -> Void

    // Extras lesen (Zettelkopf, Positionen, SOP)
    private var extras: AuftragExtrasPayload { .from(auftrag.extras) }

    private var checklistDone: Int { extras.checklist.filter { $0.isDone }.count }
    private var checklistTotal: Int { extras.checklist.count }

    private var progress: AuftragProgressData {
        AuftragProgressData(
            status: auftrag.status,
            checklistDone: checklistDone,
            checklistTotal: checklistTotal
        )
    }

    private var isActive: Bool { auftrag.status == .inProgress }

    // Zettel-Headline: “Was ist zu tun?”
    private var whatToDoText: String {
        if let d = auftrag.processingDetails, !d.isEmpty { return d }
        if let first = extras.lineItems.first?.title, !first.isEmpty { return first }
        return "Auftrag"
    }

    // Deadline Text
    private var deadlineText: String? {
        guard let d = extras.deadline else { return nil }
        return d.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // 1) Kopf: Was ist zu tun? + Status Badge
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(whatToDoText)
                            .font(.headline)
                            .lineLimit(2)

                        // Allergen-Kompakt-Icons (Phase 3)
                        if !extras.allergenSummary.isEmpty {
                            HStack(spacing: 2) {
                                ForEach(extras.allergenSummary.prefix(3), id: \.self) { code in
                                    Text(code)
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Capsule())
                                }
                                if extras.allergenSummary.count > 3 {
                                    Text("+\(extras.allergenSummary.count - 3)")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    // 2) Zettel-Kopf: Nummer • Station • Deadline • Personen
                    zettelMetaLine
                }

                Spacer()

                statusBadge
            }

            // 3) Mini-Fortschritt (ruhig)
            HStack(spacing: 8) {
                if checklistTotal > 0 {
                    Text("\(checklistDone)/\(checklistTotal)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .leading)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.10))
                            .frame(height: 6)

                        Capsule()
                            .fill(auftrag.status.color.opacity(0.85))
                            .frame(
                                width: geo.size.width * CGFloat(min(max(progress.ratio, 0), 1)),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }

            // 4) Quick Actions (optional)
            HStack(spacing: 10) {
                Button { setStatus(.inProgress) } label: {
                    Image(systemName: "play.fill").frame(width: 34, height: 30)
                }
                .buttonStyle(.bordered)
                .disabled(auftrag.status == .inProgress || auftrag.status == .completed)

                Button { setStatus(.onHold) } label: {
                    Image(systemName: "pause.fill").frame(width: 34, height: 30)
                }
                .buttonStyle(.bordered)
                .disabled(auftrag.status == .pending || auftrag.status == .completed)

                Button { setStatus(.completed) } label: {
                    Image(systemName: "checkmark").frame(width: 34, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .disabled(auftrag.status == .completed)

                Spacer()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(uiColor: .secondarySystemBackground)))
        .overlay(alignment: .leading) {
            if isActive {
                RoundedRectangle(cornerRadius: 12).fill(Color.accentColor).frame(width: 4)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
        )
        .contextMenu {
            Button("Start") { setStatus(.inProgress) }
            Button("Pause") { setStatus(.onHold) }
            Button("Fertig") { setStatus(.completed) }
            Divider()
            Button(role: .destructive) { delete() } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        Text(auftrag.status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(auftrag.status.color.opacity(0.15))
            .foregroundStyle(auftrag.status.color)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var zettelMetaLine: some View {
        HStack(spacing: 8) {
            if !extras.orderNumber.isEmpty {
                Label(extras.orderNumber, systemImage: "number")
            }

            if !extras.station.isEmpty {
                Label(extras.station, systemImage: "mappin.and.ellipse")
            }

            if let t = deadlineText {
                Label(t, systemImage: "clock")
            }

            if extras.persons > 0 {
                Label("\(extras.persons)", systemImage: "person.2")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    // MARK: - Actions

    private func setStatus(_ s: AuftragStatus) {
        KernelBridge.shared.syncStatus(auftrag, newStatus: s)
        auftrag.status = s
        save()
    }

    private func delete() {
        KernelBridge.shared.removeJob(auftrag)
        ctx.delete(auftrag)
        save()
    }

    private func save() {
        do {
            try ctx.save()
            onChanged()
        } catch {
            print("❌ Save Fehler: \(error)")
        }
    }
}
