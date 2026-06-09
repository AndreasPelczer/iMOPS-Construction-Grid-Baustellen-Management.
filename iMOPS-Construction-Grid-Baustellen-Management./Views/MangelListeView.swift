import SwiftUI
import Combine
import CoreData

// MARK: - MangelListeView

struct MangelListeView: View {
    @Environment(\.managedObjectContext) private var ctx
    let event: Event

    @FetchRequest private var maengel: FetchedResults<Mangel>
    @State private var zeigeErfassen  = false
    @State private var statusFilter: MangelStatus? = nil
    @State private var gewerkFilter: String?        = nil
    @State private var pdfURL: URL?
    @State private var showFristen    = false
    @State private var mangelToDelete: Mangel?

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

    // MARK: - Gewerk-Liste (eindeutig, sortiert)
    private var verfuegbareGewerke: [String] {
        let gewerke = maengel.compactMap { $0.gewerk }.filter { !$0.isEmpty }
        return Array(Set(gewerke)).sorted()
    }

    // MARK: - Gefilterte Liste (Status + Gewerk)
    private var gefiltert: [Mangel] {
        maengel.filter { mangel in
            let statusOK = statusFilter == nil || mangel.status == statusFilter
            let gewerkOK = gewerkFilter == nil || mangel.gewerk == gewerkFilter
            return statusOK && gewerkOK
        }
    }

    // MARK: - Statistik-Kennzahlen (immer über alle Mängel)
    private var anzahlOffen:        Int { maengel.filter { $0.status == .offen    }.count }
    private var anzahlInArbeit:     Int { maengel.filter { $0.status == .inArbeit }.count }
    private var anzahlBehoben:      Int { maengel.filter { $0.status == .behoben || $0.status == .abgenommen }.count }
    private var anzahlUeberfaellig: Int { maengel.filter { $0.istUeberfaellig }.count }

    var body: some View {
        NavigationStack {
            List {
                if !maengel.isEmpty {
                    statistikKarte
                }
                filterPicker
                if !verfuegbareGewerke.isEmpty && verfuegbareGewerke.count >= 2 {
                    gewerkPicker
                }
                if gefiltert.isEmpty {
                    leerHinweis
                } else {
                    ForEach(gefiltert) { mangel in
                        NavigationLink {
                            MangelDetailView(mangel: mangel)
                        } label: {
                            MangelZeile(mangel: mangel)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { mangelToDelete = mangel } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .modifier(MangelDeleteConfirm(mangel: $mangelToDelete) { loeschen($0) })
            .navigationTitle("Mängel (\(maengel.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showFristen = true } label: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .tint(.orange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { exportPDF() } label: {
                        Image(systemName: "arrow.up.doc")
                    }
                    .tint(.red)
                    .disabled(maengel.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { zeigeErfassen = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $zeigeErfassen) {
                MangelErfassenView(event: event)
                    .environment(\.managedObjectContext, ctx)
            }
            .sheet(item: $pdfURL) { url in
                LVShareSheet(url: url).ignoresSafeArea()
            }
            .sheet(isPresented: $showFristen) {
                FristenView()
                    .environment(\.managedObjectContext, ctx)
            }
        }
    }

    // MARK: - Statistik-Kachel

    @ViewBuilder
    private var statistikKarte: some View {
        Section {
            HStack(spacing: 0) {
                statistikZelle(label: "Gesamt",     wert: maengel.count,      farbe: .primary)
                Divider().frame(height: 32)
                statistikZelle(label: "Offen",      wert: anzahlOffen,        farbe: .orange)
                Divider().frame(height: 32)
                statistikZelle(label: "In Arbeit",  wert: anzahlInArbeit,     farbe: .blue)
                Divider().frame(height: 32)
                statistikZelle(label: "Behoben",    wert: anzahlBehoben,      farbe: .green)
                Divider().frame(height: 32)
                statistikZelle(label: "Überfällig", wert: anzahlUeberfaellig, farbe: .red)
            }
            .padding(.vertical, 4)
        }
    }

    private func statistikZelle(label: String, wert: Int, farbe: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(wert)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(wert > 0 ? farbe : Color.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status-Filter-Chips

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

    // MARK: - Gewerk-Filter-Chips

    @ViewBuilder
    private var gewerkPicker: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    gewerkChip(label: "Alle Gewerke", gewerk: nil)
                    ForEach(verfuegbareGewerke, id: \.self) { g in
                        gewerkChip(label: g, gewerk: g)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Gewerk")
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
    }

    private func gewerkChip(label: String, gewerk: String?) -> some View {
        let aktiv = gewerkFilter == gewerk
        return Button {
            gewerkFilter = gewerk
        } label: {
            Text(label)
                .font(.subheadline.weight(aktiv ? .semibold : .regular))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(aktiv ? Color.purple : Color(.tertiarySystemFill))
                .foregroundStyle(aktiv ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Leer-Hinweis

    private var leerHinweis: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: statusFilter == nil && gewerkFilter == nil
                      ? "checkmark.seal" : "line.3.horizontal.decrease.circle")
                    .font(.title2)
                    .foregroundStyle(statusFilter == nil && gewerkFilter == nil ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusFilter == nil && gewerkFilter == nil
                         ? "Keine Mängel" : "Keine Mängel für diesen Filter")
                    Text(statusFilter == nil && gewerkFilter == nil
                         ? "Tippe auf + um einen Mangel zu erfassen."
                         : "Filter zurücksetzen um alle Mängel zu sehen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Export + Löschen

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
        }
    }

    private func loeschen(_ m: Mangel) {
        if let pfad = m.fotoPfad {
            try? FileManager.default.removeItem(atPath: pfad)
        }
        NotificationService.shared.cancel(for: m)
        ctx.delete(m)
        try? ctx.save()
    }
}

// Sicherheitsabfrage vor dem Löschen eines Mangels (gegen Full-Swipe-Fehler).
// Wie DeletePositionConfirm im LV ausgelagert (body bleibt type-checkbar). Buch Kap 4/9.
struct MangelDeleteConfirm: ViewModifier {
    @Binding var mangel: Mangel?
    let onDelete: (Mangel) -> Void

    func body(content: Content) -> some View {
        content.alert(
            "Mangel löschen?",
            isPresented: Binding(
                get: { mangel != nil },
                set: { if !$0 { mangel = nil } }
            ),
            presenting: mangel
        ) { m in
            Button("Ja, löschen", role: .destructive) {
                onDelete(m)
                mangel = nil
            }
            Button("Abbrechen", role: .cancel) { mangel = nil }
        } message: { m in
            Text("\(m.titel ?? "Mangel")\(m.fotoPfad != nil ? " (inkl. Foto)" : "") wird dauerhaft entfernt. Das lässt sich nicht rückgängig machen.")
        }
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
