import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - BautagesberichtListeView
//
// Die Historie: alle Bautagesberichte einer Baustelle, neuester zuerst.
//
// Ein gespeicherter Bericht wird hier NICHT bearbeitet. Er dokumentiert einen
// vergangenen Tag — ihn nachträglich zu ändern hieße, die Vergangenheit
// umzuschreiben. Deshalb führt das Antippen in eine Ansicht zum Lesen und
// Ausdrucken, nicht in ein Formular.

struct BautagesberichtListeView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @FetchRequest private var berichte: FetchedResults<Bautagesbericht>
    @State private var pdfURL: URL?

    init(event: Event) {
        self.event = event
        _berichte = FetchRequest(
            sortDescriptors: [
                // Neuester zuerst. `erstelltAm` als zweiter Schlüssel, damit
                // zwei Berichte vom selben Tag eine feste Reihenfolge haben.
                NSSortDescriptor(keyPath: \Bautagesbericht.datum, ascending: false),
                NSSortDescriptor(keyPath: \Bautagesbericht.erstelltAm, ascending: false)
            ],
            predicate: NSPredicate(format: "event == %@", event),
            animation: .default
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if berichte.isEmpty {
                    leererStand
                } else {
                    List {
                        ForEach(berichte) { bericht in
                            NavigationLink {
                                BautagesberichtDetailView(bericht: bericht)
                            } label: {
                                BautagesberichtZeile(bericht: bericht)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bautagesberichte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .teilenOderSpeichern(datei: $pdfURL)
        }
    }

    private var leererStand: some View {
        ContentUnavailableView {
            Label("Noch kein Bericht", systemImage: "doc.text")
        } description: {
            Text("Bautagesberichte dieser Baustelle erscheinen hier, sobald du den ersten gespeichert hast.")
        }
    }
}

// MARK: - Eine Zeile in der Historie

struct BautagesberichtZeile: View {
    let bericht: Bautagesbericht

    private var datumText: String {
        guard let d = bericht.datum else { return "ohne Datum" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, d. MMMM yyyy"
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(datumText)
                    .font(.headline)
                if bericht.istGesperrt {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if bericht.istKorrektur {
                    Text("Korrektur")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 10) {
                if let w = bericht.witterung, !w.isEmpty {
                    Label(w, systemImage: Witterung(rawValue: w)?.symbol ?? "cloud.fill")
                }
                Label("\(bericht.personalAnzahl)", systemImage: "person.2.fill")
                if bericht.snapMaengel > 0 {
                    Label("\(bericht.snapMaengel)", systemImage: "exclamationmark.triangle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let arbeiten = bericht.ausgefuehrteArbeiten, !arbeiten.isEmpty {
                Text(arbeiten)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Detailansicht (lesen und ausdrucken, nicht ändern)

struct BautagesberichtDetailView: View {
    let bericht: Bautagesbericht
    @State private var pdfURL: URL?
    @State private var pdfData: Data?
    @State private var showSaveDialog = false
    @State private var saveFilename = "Bautagesbericht"
    @State private var showShare = false

    private var datumText: String {
        guard let d = bericht.datum else { return "ohne Datum" }
        let f = DateFormatter()
        f.dateStyle = .full
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: d)
    }

    var body: some View {
        Form {
            Section("Tag") {
                zeile("Datum", datumText)
                if let w = bericht.witterung, !w.isEmpty { zeile("Witterung", w) }
                if let t = bericht.temperatur, !t.isEmpty { zeile("Temperatur", t) }
                zeile("Personal", "\(bericht.personalAnzahl)")
            }

            Section("Stand am Berichtstag") {
                zeile("Aufträge gesamt", "\(bericht.snapAuftraegeGesamt)")
                zeile("davon offen", "\(bericht.snapAuftraegeOffen)")
                zeile("LV-Positionen", "\(bericht.snapLVPositionen)")
                zeile("Mängel", "\(bericht.snapMaengel)")
                Text("Diese Zahlen wurden beim Speichern festgehalten und ändern sich nicht mehr.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let g = bericht.geraete, !g.isEmpty {
                Section("Maschinen und Geräte") { Text(g) }
            }
            if let a = bericht.ausgefuehrteArbeiten, !a.isEmpty {
                Section("Ausgeführte Arbeiten") { Text(a) }
            }
            if let b = bericht.behinderungen, !b.isEmpty {
                Section("Behinderungen") { Text(b) }
            }
            if let n = bericht.notizen, !n.isEmpty {
                Section("Notizen") { Text(n) }
            }

            Section {
                if bericht.istGesperrt, let d = bericht.gesperrtAm {
                    Label("Freigegeben am \(d.formatted(date: .abbreviated, time: .shortened))"
                          + (bericht.freigegebenVon.map { " von \($0)" } ?? ""),
                          systemImage: "lock.fill")
                        .font(.caption)
                }
                if let erstellt = bericht.erstelltAm {
                    Text("Erfasst am \(erstellt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Bericht")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Als PDF") { exportiere() }.tint(.orange)
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfURL { LVShareSheet(url: url).ignoresSafeArea() }
        }
        .fileExporter(
            isPresented: $showSaveDialog,
            document: PDFFileDocument(data: pdfData ?? Data()),
            contentType: .pdf,
            defaultFilename: saveFilename
        ) { _ in }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel)
            Spacer()
            Text(wert).foregroundStyle(.secondary)
        }
    }

    /// Das PDF kommt aus dem Datensatz — mit den Zahlen von damals.
    private func exportiere() {
        guard let data = BautagesberichtPDFExporter.generate(bericht: bericht) else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let datum = bericht.datum ?? bericht.erstelltAm ?? Date()
        let base = "Bautagesbericht-\(fmt.string(from: datum))-\(bericht.event?.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        // Dieselbe Laufzeit-Weiche wie im Formular: „Mac (Designed for iPad)"
        // wird von #if targetEnvironment(macCatalyst) NICHT erfasst.
        let laeuftAmMac = ProcessInfo.processInfo.isiOSAppOnMac
            || ProcessInfo.processInfo.isMacCatalystApp
        if laeuftAmMac {
            pdfData = data
            saveFilename = base
            showSaveDialog = true
        } else {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(base + ".pdf")
            if (try? data.write(to: url)) != nil {
                pdfURL = url
                showShare = true
            }
        }
    }
}
