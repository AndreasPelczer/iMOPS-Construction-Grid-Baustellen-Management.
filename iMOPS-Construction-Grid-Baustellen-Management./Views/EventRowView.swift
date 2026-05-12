import SwiftUI

struct EventRowView: View {
    @ObservedObject var event: Event

    private var progress: EventJobProgressData {
        EventJobProgressData(event: event)
    }

    private func widthRatio(for count: Int) -> CGFloat {
        guard progress.totalJobs > 0 else { return 0 }
        return CGFloat(count) / CGFloat(progress.totalJobs)
    }

    private var offeneMaengel: [Mangel] {
        (event.maengel?.allObjects as? [Mangel] ?? [])
            .filter { $0.status != .behoben && $0.status != .abgenommen }
    }

    private var hatUeberfaellige: Bool {
        offeneMaengel.contains { $0.istUeberfaellig }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(event.title ?? "Unbenannte Baustelle")
                    .font(.headline)
                Spacer()
                if offeneMaengel.count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: hatUeberfaellige
                              ? "exclamationmark.triangle.fill"
                              : "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text("\(offeneMaengel.count)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(hatUeberfaellige ? .red : .orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((hatUeberfaellige ? Color.red : Color.orange).opacity(0.12))
                    .clipShape(Capsule())
                }
                Text(event.eventStartTime ?? Date(), style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if progress.totalJobs > 0 {
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        let w = proxy.size.width
                        Color.green  .frame(width: w * widthRatio(for: progress.completedCount))
                        Color.orange .frame(width: w * widthRatio(for: progress.inProgressCount))
                        Color.red    .frame(width: w * widthRatio(for: progress.onHoldCount))
                        Color.blue   .frame(width: w * widthRatio(for: progress.pendingCount))
                        Color(.systemGray5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(height: 6)
            } else {
                Text("Keine Auftr\u{00e4}ge vorhanden")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
