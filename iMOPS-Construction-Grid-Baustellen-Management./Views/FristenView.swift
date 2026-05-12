import SwiftUI
import CoreData

struct FristenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Mangel.frist, ascending: true)],
        predicate: NSPredicate(
            format: "frist != nil AND statusRawValue != %@ AND statusRawValue != %@",
            "behoben", "abgenommen"),
        animation: .default
    ) private var maengel: FetchedResults<Mangel>

    private var ueberfaellig: [Mangel] { maengel.filter { $0.istUeberfaellig } }
    private var dieseWoche:   [Mangel] { maengel.filter { !$0.istUeberfaellig && isInDays($0, max: 7) } }
    private var naechste30:   [Mangel] { maengel.filter { !$0.istUeberfaellig && !isInDays($0, max: 7) && isInDays($0, max: 30) } }
    private var spaeter:      [Mangel] { maengel.filter { !$0.istUeberfaellig && !isInDays($0, max: 30) } }

    var body: some View {
        NavigationStack {
            Group {
                if maengel.isEmpty {
                    ContentUnavailableView(
                        "Keine offenen Fristen",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("Alle Mängel mit Frist sind erledigt oder es wurden noch keine Fristen gesetzt.")
                    )
                } else {
                    List {
                        if !ueberfaellig.isEmpty {
                            Section {
                                ForEach(ueberfaellig) { mangel in mangelRow(mangel) }
                            } header: {
                                Label("Überfällig (\(ueberfaellig.count))",
                                      systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                        if !dieseWoche.isEmpty {
                            Section("Diese Woche (\(dieseWoche.count))") {
                                ForEach(dieseWoche) { mangel in mangelRow(mangel) }
                            }
                        }
                        if !naechste30.isEmpty {
                            Section("Nächste 30 Tage (\(naechste30.count))") {
                                ForEach(naechste30) { mangel in mangelRow(mangel) }
                            }
                        }
                        if !spaeter.isEmpty {
                            Section("Später (\(spaeter.count))") {
                                ForEach(spaeter) { mangel in mangelRow(mangel) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Fristen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func mangelRow(_ mangel: Mangel) -> some View {
        NavigationLink {
            MangelDetailView(mangel: mangel)
                .environment(\.managedObjectContext, ctx)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: mangel.status.symbol)
                    .foregroundStyle(mangel.status.farbe)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mangel.titel ?? "Mangel ohne Titel")
                        .font(.body).lineLimit(1)
                    HStack(spacing: 4) {
                        if let frist = mangel.frist {
                            Text(frist, style: .date)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(mangel.istUeberfaellig ? .red : .secondary)
                        }
                        if let ort = mangel.ort, !ort.isEmpty {
                            Text("·").foregroundStyle(.secondary)
                            Text(ort).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        if let ev = mangel.event?.title {
                            Text("·").foregroundStyle(.secondary)
                            Text(ev).font(.caption).foregroundStyle(.orange).lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: mangel.mangelSchwere.symbol)
                    .font(.caption)
                    .foregroundStyle(mangel.mangelSchwere.farbe)
            }
            .padding(.vertical, 2)
        }
    }

    private func isInDays(_ mangel: Mangel, max days: Int) -> Bool {
        guard let frist = mangel.frist else { return false }
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return frist <= cutoff
    }
}
