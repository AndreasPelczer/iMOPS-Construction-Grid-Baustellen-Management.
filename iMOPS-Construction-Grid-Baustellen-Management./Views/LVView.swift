import SwiftUI
import Combine
import CoreData
import MessageUI
import UIKit

// MARK: - LV Hauptansicht

private enum LVGruppierung: String, CaseIterable, Identifiable {
    case kostenGruppe
    case dokumentStruktur

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kostenGruppe: return "KG"
        case .dokumentStruktur: return "Dokument"
        }
    }

    var systemImage: String {
        switch self {
        case .kostenGruppe: return "folder"
        case .dokumentStruktur: return "doc.text"
        }
    }
}

private struct LVSectionGroup: Identifiable {
    let id: String
    let title: String
    let items: [LVPosition]
}

struct LVView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(ImportedFileHandler.self) private var importedFileHandler
    @ObservedObject var event: Event

    @FetchRequest private var positionen: FetchedResults<LVPosition>
    @State private var sourcePDFURL: URL? = nil
    @State private var showingAdd = false
    @State private var editPosition: LVPosition?
    @State private var actionPosition: LVPosition?
    @State private var positionToDelete: LVPosition?
    @State private var kalkPosition: LVPosition?
    @State private var fortschrittPosition: LVPosition?
    @State private var aufmassPosition: LVPosition?
    @State private var showBestellliste = false
    @State private var showAngebotsVergleich = false
    @State private var showKostenübersicht = false
    @State private var showImport = false
    @State private var showGAEBImport = false
    @State private var showBausteine = false
    @State private var droppedGAEBURL: URL?
    @State private var showHelp = false
    @State private var exportURL: URL?
    @State private var gruppierung: LVGruppierung = .kostenGruppe

    @State private var showMissingPricesAlert = false
    @State private var missingPricesCount = 0
    @State private var pendingExportFormat: GAEBExportFormat?

    @State private var showXRMissingAlert = false
    @State private var xrMissingCount = 0

    @StateObject private var store = AngebotsStore.shared
    @StateObject private var fortStore = LVFortschrittStore.shared

    init(event: Event) {
        self.event = event
        _positionen = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \LVPosition.kostenGruppeNummer, ascending: true),
                NSSortDescriptor(keyPath: \LVPosition.posNr, ascending: true)
            ],
            predicate: NSPredicate(format: "event == %@", event),
            animation: .default
        )
    }

    private var grouped: [LVSectionGroup] {
        switch gruppierung {
        case .kostenGruppe:
            return groupedByKostenGruppe
        case .dokumentStruktur:
            return groupedByDokumentStruktur
        }
    }

    private var groupedByKostenGruppe: [LVSectionGroup] {
        let dict = Dictionary(grouping: Array(positionen), by: { $0.kostenGruppeNummer ?? "—" })
        return dict.sorted { $0.key < $1.key }.map { key, items in
            LVSectionGroup(
                id: "kg-\(key)",
                title: "KG \(key) – \(dinBezeichnung(key))",
                items: items
            )
        }
    }

    private var groupedByDokumentStruktur: [LVSectionGroup] {
        let dict = Dictionary(grouping: Array(positionen), by: dokumentAbschnitt)
        return dict.sorted { lhs, rhs in
            documentSortBefore(lhs.key, rhs.key)
        }.map { key, items in
            LVSectionGroup(
                id: "doc-\(key)",
                title: key == "—" ? "Ohne Abschnitt" : "Abschnitt \(key)",
                items: items
            )
        }
    }

    private var gesamtFortschritt: Double {
        let base = Array(positionen).filter { !LVPositionHelper.isAlternative($0) }
        guard !base.isEmpty else { return 0 }
        let sum = base.map {
            fortStore.fortschritt(for: $0.objectID.uriRepresentation().absoluteString)?.prozent ?? 0
        }.reduce(0, +)
        return Double(sum) / Double(base.count) / 100.0
    }

    private var gesamtSumme: Double {
        Array(positionen).filter { !LVPositionHelper.isAlternative($0) }.reduce(0.0) { sum, pos in
            let preis: Double
            if pos.hatKalkulation {
                preis = LVKalkulator.kalkuliere(position: pos).einheitspreisVK
            } else if let best = store.guenstigster(for: pos.objectID.uriRepresentation().absoluteString) {
                preis = best.einzelpreis
            } else {
                preis = pos.value(forKey: "einkaufspreis") as? Double ?? 0
            }
            return sum + (pos.menge * preis)
        }
    }

    var body: some View {
        List {
            if positionen.isEmpty {
                ContentUnavailableView(
                    "Kein LV vorhanden",
                    systemImage: "doc.text",
                    description: Text("Tippe auf + oder importiere ein LV.")
                )
            } else {
                Section {
                    Picker("LV-Ansicht", selection: $gruppierung) {
                        ForEach(LVGruppierung.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if gesamtFortschritt > 0 {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Gesamtfortschritt", systemImage: "chart.bar.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(gesamtFortschritt >= 1 ? .green : .orange)
                                Spacer()
                                Text("\(Int(gesamtFortschritt * 100)) %")
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(gesamtFortschritt >= 1 ? .green : .orange)
                            }
                            ProgressView(value: gesamtFortschritt)
                                .progressViewStyle(.linear)
                                .tint(gesamtFortschritt >= 1 ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(grouped) { gruppe in
                    Section {
                        ForEach(gruppe.items, id: \.objectID) { pos in
                            LVPositionRow(position: pos) { targetURL in
                                sourcePDFURL = targetURL
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { actionPosition = pos }
                            .contextMenu {
                                Button { editPosition = pos } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                Button { kalkPosition = pos } label: {
                                    Label("Kalkulation", systemImage: "function")
                                }
                                Button { duplicateAsAlternative(pos) } label: {
                                    Label("Alternative", systemImage: "doc.on.doc")
                                }
                                Button { fortschrittPosition = pos } label: {
                                    Label("Fortschritt", systemImage: "chart.bar")
                                }
                                Button { aufmassPosition = pos } label: {
                                    Label("Aufmaß", systemImage: "ruler")
                                }
                                Divider()
                                Button(role: .destructive) { positionToDelete = pos } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button { positionToDelete = pos } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading) {
                                Button { editPosition = pos } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.orange)
                                Button { kalkPosition = pos } label: {
                                    Label("Kalkulation", systemImage: "function")
                                }
                                .tint(.indigo)
                                Button { duplicateAsAlternative(pos) } label: {
                                    Label("Alternative", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)
                                Button { fortschrittPosition = pos } label: {
                                    Label("Fortschritt", systemImage: "chart.bar")
                                }
                                .tint(.green)
                                Button { aufmassPosition = pos } label: {
                                    Label("Aufmaß", systemImage: "ruler")
                                }
                                .tint(.teal)
                            }
                        }
                    } header: {
                        sectionHeader(gruppe)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if gesamtSumme > 0 {
                HStack {
                    Text("Angebotssumme (netto):")
                        .font(.headline)
                    Spacer()
                    Text(gesamtSumme, format: .currency(code: "EUR"))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(.green)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .gaebDropTarget { url in
            droppedGAEBURL = url
            showGAEBImport = true
        }
        .navigationTitle("LV – \(event.title ?? "Baustelle")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Ansicht", selection: $gruppierung) {
                        ForEach(LVGruppierung.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }

                    Divider()

                    Button { showBestellliste = true } label: {
                        Label("Bestellliste", systemImage: "envelope.badge")
                    }
                    .disabled(positionen.isEmpty)

                    Button { showAngebotsVergleich = true } label: {
                        Label("Angebotsvergleich", systemImage: "chart.bar.doc.horizontal")
                    }

                    Button { showKostenübersicht = true } label: {
                        Label("Kostenzusammenfassung", systemImage: "chart.pie")
                    }
                    .disabled(positionen.isEmpty)

                    Divider()

                    Button { generatePDF() } label: {
                        Label("LV als PDF", systemImage: "arrow.up.doc")
                    }
                    .disabled(positionen.isEmpty)

                    Button { generateCSV() } label: {
                        Label("LV als CSV (Excel)", systemImage: "tablecells")
                    }
                    .disabled(positionen.isEmpty)

                    Button { triggerGAEBExport(.x83_v33) } label: {
                        Label("GAEB X83 exportieren", systemImage: "arrow.up.doc.fill")
                    }
                    .disabled(positionen.isEmpty)

                    Button { triggerGAEBExport(.x84_v33) } label: {
                        Label("GAEB X84 exportieren (Angebot)", systemImage: "signature")
                    }
                    .disabled(positionen.isEmpty)

                    Button { triggerXRechnungExport() } label: {
                        Label("XRechnung exportieren", systemImage: "eurosign.circle")
                    }
                    .disabled(positionen.isEmpty)

                    Divider()

                    Button { showImport = true } label: {
                        Label("Aus PDF importieren", systemImage: "doc.text.magnifyingglass")
                    }

                    Button { showGAEBImport = true } label: {
                        Label("GAEB X83 importieren", systemImage: "doc.badge.arrow.up")
                    }

                    Button { showBausteine = true } label: {
                        Label("LV-Bausteine auswählen", systemImage: "checklist")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fullScreenCover(isPresented: $showingAdd) {
            AddLVPositionView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(item: $editPosition) { pos in
            AddLVPositionView(event: event, editPosition: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .navigationDestination(item: $kalkPosition) { pos in
            LVTiefenkalkulationView(position: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(item: $fortschrittPosition) { pos in
            LVFortschrittSheet(position: pos)
        }
        .fullScreenCover(item: $aufmassPosition) { pos in
            AufmassSheet(position: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showBestellliste) {
            LieferantenBestelllisteView(event: event, positionen: Array(positionen))
        }
        .fullScreenCover(isPresented: $showAngebotsVergleich) {
            AngebotsVergleichView(event: event, positionen: Array(positionen))
        }
        .fullScreenCover(isPresented: $showKostenübersicht) {
            KostenübersichtView(event: event, positionen: Array(positionen))
        }
        .fullScreenCover(isPresented: $showImport) {
            LVImportView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showGAEBImport, onDismiss: { droppedGAEBURL = nil }) {
            GAEBImportView(event: event, initialURL: droppedGAEBURL)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showBausteine) {
            LVBausteinAuswahlView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: importedFileHandler.pendingGAEBURL) { _, newURL in
            if let url = newURL {
                droppedGAEBURL = url
                importedFileHandler.pendingGAEBURL = nil
                showGAEBImport = true
            }
        }
        .fullScreenCover(item: $exportURL) { url in
            LVShareSheet(url: url).ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showHelp) {
            LVHelpView()
        }
        .fullScreenCover(item: Binding(
            get: { sourcePDFURL.map { IdentifiableURL(url: $0) } },
            set: { sourcePDFURL = $0?.url }
        )) { identifiableURL in
            PDFPreviewView(url: identifiableURL.url)
        }
        .confirmationDialog(
            actionPosition?.bezeichnung ?? "LV-Position",
            isPresented: Binding(
                get: { actionPosition != nil },
                set: { if !$0 { actionPosition = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pos = actionPosition {
                Button {
                    showAngebotsVergleich = true
                    actionPosition = nil
                } label: {
                    Label("Rückmeldung / Angebot erfassen", systemImage: "chart.bar.doc.horizontal")
                }
                Button {
                    editPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Position bearbeiten", systemImage: "pencil")
                }
                Button {
                    kalkPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Kalkulation", systemImage: "function")
                }
                Button {
                    fortschrittPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Fortschritt", systemImage: "chart.bar")
                }
                Button {
                    aufmassPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Aufmaß", systemImage: "ruler")
                }
                Button(role: .destructive) {
                    positionToDelete = pos
                    actionPosition = nil
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .modifier(DeletePositionConfirm(position: $positionToDelete) { delete($0) })
        .alert("Fehlende Preise", isPresented: $showMissingPricesAlert) {
            Button("Trotzdem exportieren") {
                if let fmt = pendingExportFormat { doGAEBExport(fmt) }
            }
            Button("Abbrechen", role: .cancel) { pendingExportFormat = nil }
        } message: {
            Text("\(missingPricesCount) Position\(missingPricesCount == 1 ? " hat" : "en haben") keinen Preis (weder Angebot noch Kalkulation). Der X84 wird für diese mit leeren EP-Feldern exportiert.")
        }
        .alert("Export nicht möglich – fehlende Preise", isPresented: $showXRMissingAlert) {
            Button("Verstanden", role: .cancel) { }
        } message: {
            Text("\(xrMissingCount) Position\(xrMissingCount == 1 ? " hat" : "en haben") keinen Preis (weder Angebot noch Kalkulation). Eine Rechnung mit 0,00-€-Positionen wird nicht exportiert – bitte erst Preis im Angebotsvergleich erfassen oder die Position kalkulieren.")
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(_ gruppe: LVSectionGroup) -> some View {
        HStack {
            Text(gruppe.title)
                .font(.caption.weight(.semibold))
            Spacer()
            let basis = gruppe.items.filter { !LVPositionHelper.isAlternative($0) }
            let altCount = gruppe.items.count - basis.count
            if altCount > 0 {
                Text("\(altCount) Alt.")
                    .font(.caption2).foregroundStyle(.blue)
                Text("·").foregroundStyle(.secondary).font(.caption2)
            }
            let summe = basis.reduce(0.0) { $0 + $1.menge }
            Text("\(summe.formatted(.number.precision(.fractionLength(0...2)))) ges.")
                .font(.caption2).foregroundStyle(.secondary)
            if !basis.isEmpty {
                let avg = basis.map {
                    fortStore.fortschritt(
                        for: $0.objectID.uriRepresentation().absoluteString)?.prozent ?? 0
                }.reduce(0, +) / basis.count
                if avg > 0 {
                    Text("·").foregroundStyle(.secondary).font(.caption2)
                    Text("ø \(avg)%")
                        .font(.caption2)
                        .foregroundStyle(avg == 100 ? .green : .orange)
                }
            }
        }
    }

    private func dokumentAbschnitt(_ position: LVPosition) -> String {
        let nr = (position.posNr ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nr.isEmpty else { return "—" }

        let parts = nr.split(separator: ".").map(String.init)
        if parts.count >= 3 {
            return parts.prefix(2).joined(separator: ".")
        }
        if parts.count >= 2, parts[0].count <= 2 {
            return parts[0]
        }
        if parts.count >= 2 {
            return parts.prefix(2).joined(separator: ".")
        }
        return nr
    }

    private func documentSortBefore(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "—" { return false }
        if rhs == "—" { return true }

        let left = lhs.split(separator: ".").map { Int($0) ?? Int.max }
        let right = rhs.split(separator: ".").map { Int($0) ?? Int.max }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r }
        }

        return lhs < rhs
    }

    // MARK: - Actions

    private func delete(_ pos: LVPosition) {
        viewContext.delete(pos)
        try? viewContext.save()
    }

    private func duplicateAsAlternative(_ base: LVPosition) {
        let alt = LVPosition(context: viewContext)
        let baseNr = base.posNr ?? "1"
        alt.posNr = LVPositionHelper.nextAlternativeNr(for: baseNr, existing: Array(positionen))
        alt.bezeichnung = (base.bezeichnung ?? "") + " (Alternative)"
        alt.menge = base.menge
        alt.einheit = base.einheit
        alt.kostenGruppeNummer = base.kostenGruppeNummer
        alt.artikelNummer = base.artikelNummer
        alt.lieferant = base.lieferant
        alt.event = event
        try? viewContext.save()
    }

    private func generatePDF() {
        let data = LVPDFExporter.generate(event: event, positionen: Array(positionen))
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-").appending(".pdf")
        writeAndShare(data: data, filename: name)
    }

    private func generateCSV() {
        let data = LVCSVExporter.generate(event: event, positionen: Array(positionen))
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-").appending(".csv")
        writeAndShare(data: data, filename: name)
    }

    private func triggerGAEBExport(_ format: GAEBExportFormat) {
        if format.includePrices {
            let missing = Array(positionen).filter { pos in
                LVKalkulator.effektiverEP(for: pos, store: store) == 0
            }.count
            if missing > 0 {
                missingPricesCount = missing
                pendingExportFormat = format
                showMissingPricesAlert = true
                return
            }
        }
        doGAEBExport(format)
    }

    private func doGAEBExport(_ format: GAEBExportFormat) {
        let data = GAEBExporter.export(
            event: event,
            positionen: Array(positionen),
            format: format,
            store: store
        )
        let title = (event.title ?? "Baustelle").replacingOccurrences(of: " ", with: "-")
        let name = "\(title)-\(format.filenameSuffix).xml"
        writeAndShare(data: data, filename: name)
        pendingExportFormat = nil
    }

    private func triggerXRechnungExport() {
        let nonAlt = Array(positionen).filter { !LVPositionHelper.isAlternative($0) }
        let missing = nonAlt.filter { pos in
            LVKalkulator.effektiverEP(for: pos, store: store) == 0
        }.count
        if missing > 0 {
            xrMissingCount = missing
            showXRMissingAlert = true
            return
        }
        doXRechnungExport()
    }

    private func doXRechnungExport() {
        let data = XRechnungExporter.export(
            event: event,
            positionen: Array(positionen),
            store: store
        )
        let title = (event.title ?? "Baustelle").replacingOccurrences(of: " ", with: "-")
        writeAndShare(data: data, filename: "\(title)-XRechnung.xml")
    }

    private func writeAndShare(data: Data, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if (try? data.write(to: url)) != nil {
            exportURL = url
        }
    }

    private func dinBezeichnung(_ kg: String) -> String {
        switch kg {
        case "100": return "Grundstück"
        case "200": return "Herrichten & Erschließen"
        case "300": return "Baukonstruktionen"
        case "310": return "Baugrube"
        case "320": return "Gründung"
        case "330": return "Außenwände"
        case "340": return "Innenwände"
        case "350": return "Decken"
        case "360": return "Dächer"
        case "370": return "Infrastruktur"
        case "380": return "Fenster & Türen"
        case "390": return "Sonstige Baukonstruktion"
        case "400": return "Technische Anlagen"
        case "410": return "Abwasser, Wasser, Gas"
        case "420": return "Wärmeversorgung"
        case "430": return "Lufttechnische Anlagen"
        case "440": return "Starkstrom"
        case "450": return "Fernmelde- & IT-Anlagen"
        case "500": return "Außenanlagen"
        case "600": return "Ausstattung"
        case "700": return "Baunebenkosten"
        default: return "Sonstige"
        }
    }
}
