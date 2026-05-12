import SwiftUI
import CoreData

// MARK: - MangelListeView

struct MangelListeView: View {
    @Environment(\.managedObjectContext) private var ctx
    let event: Event

    @FetchRequest private var maengel: FetchedResults<Mangel>
    @State private var zeigeErfassen  = false
    @State private var statusFilter: MangelStatus? = nil
    @State private var showPDFShare   = false
    @State private var pdfURL: URL?

    init(event: Event) {
        self.event = event
        _maengel = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \Mangel.erfasstAm, ascending: false)
            ],
            predicate: NSPredicate(format: "event == %@", event),
            animation: .default
        )
    }

    private var gefiltert: [Mangel] {
        guard let f = statusFilter else { return Array(maengel) }
        return maengel.filter { $0.status == f }
    }

    var body: some View {
        NavigationStack {
            List {
                filterPicker
                if gefiltert.isEmpty {
                    leerHinweis
                } else {
                    ForEach(gefiltert) { mangel in
                        NavigationLink {
                            MangelDetailView(mangel: mangel)
                        } label: {
                            MangelZeile(mangel: mangel)
                        }
                    }
                    .onDelete(perform: loeschen)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Mängel (\(maengel.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportPDF() } label: {
                        Image(systemName: "arrow.up.doc")
                    }
                    .tint(.red)
                    .disabled(maengel.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        zeigeErfassen = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $zeigeErfassen) {
                MangelErfassenView(event: event)
                    .environment(\.managedObjectContext, ctx)
            }
            .sheet(isPresented: $showPDFShare) {
                if let url = pdfURL { LVShareSheet(url: url).ignoresSafeArea() }
            }
        }
    }

    @ViewBuilder
    private var filterPicker: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    filterChip(label: "Alle", status: nil)
                    ForEach(MangelStatus.allCases) { s in
                        filterChip(label: s.displayName, status: s)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private func filterChip(label: String, status: MangelStatus?) -> some View {
        let aktiv = statusFilter == status
        return Button {
            statusFilter = status
        } label: {
            Text(label)
                .font(.subheadline.weight(aktiv ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(aktiv ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(aktiv ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var leerHinweis: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.seal")
                    .font(.title2).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keine Mängel")
                    Text("Tippe auf + um einen Mangel zu erfassen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func exportPDF() {
        let data = MangelPDFExporter.generate(event: event, maengel: Array(maengel))
        let fmt  = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let name = "Mängelprotokoll-\(fmt.string(from: Date()))-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-")
            .appending(".pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if (try? data.write(to: url)) != nil {
            pdfURL = url
            showPDFShare = true
        }
    }

    private func loeschen(offsets: IndexSet) {
        for i in offsets {
            let m = gefiltert[i]
            if let pfad = m.fotoPfad {
                try? FileManager.default.removeItem(atPath: pfad)
            }
            ctx.delete(m)
        }
        try? ctx.save()
    }
}

// MARK: - Mangel-Zeile

struct MangelZeile: View {
    @ObservedObject var mangel: Mangel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: mangel.status.symbol)
                .font(.title3)
                .foregroundStyle(mangel.status.farbe)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(mangel.titel ?? "Unbekannter Mangel").font(.body)
                HStack(spacing: 6) {
                    if let ort = mangel.ort, !ort.isEmpty {
                        Label(ort, systemImage: "mappin").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if let gew = mangel.gewerk, !gew.isEmpty {
                        Text("· \(gew)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(mangel.status.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(mangel.status.farbe)
                    Image(systemName: mangel.mangelSchwere.symbol)
                        .font(.caption)
                        .foregroundStyle(mangel.mangelSchwere.farbe)
                    Text(mangel.mangelSchwere.displayName)
                        .font(.caption)
                        .foregroundStyle(mangel.mangelSchwere.farbe)
                    if mangel.istUeberfaellig {
                        Label("Überfällig", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
            Spacer()
            if let datum = mangel.erfasstAm {
                Text(datum, style: .date).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
