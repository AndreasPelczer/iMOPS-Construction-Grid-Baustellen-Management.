import SwiftUI
import CoreData
import MessageUI
import UIKit

// MARK: - LV Hauptansicht

struct LVView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @FetchRequest private var positionen: FetchedResults<LVPosition>

    @State private var showingAdd            = false
    @State private var editPosition: LVPosition?
    @State private var showBestellliste      = false
    @State private var showAngebotsVergleich = false
    @State private var showImport            = false
    @State private var showGAEBImport        = false
    @State private var showHelp              = false
    @State private var showExportShare       = false
    @State private var exportURL: URL?
    // Warnung wenn X84-Export Positionen ohne Preis hat
    @State private var showMissingPricesAlert = false
    @State private var missingPricesCount = 0
    @State private var pendingExportFormat: GAEBExportFormat?

    @StateObject private var store = AngebotsStore.shared

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

    private var grouped: [(kg: String, items: [LVPosition])] {
        let dict = Dictionary(grouping: Array(positionen), by: { $0.kostenGruppeNummer ?? "—" })
        return dict.sorted { $0.key < $1.key }.map { (kg: $0.key, items: $0.value) }
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
                ForEach(grouped, id: \.kg) { gruppe in
                    Section {
                        ForEach(gruppe.items, id: \.objectID) { pos in
                            LVPositionRow(position: pos)
                                .contentShape(Rectangle())
                                .onTapGesture { editPosition = pos }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { delete(pos) } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button { editPosition = pos } label: {
                                        Label("Bearbeiten", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                    Button { duplicateAsAlternative(pos) } label: {
                                        Label("Alternative", systemImage: "doc.on.doc")
                                    }
                                    .tint(.blue)
                                }
                        }
                    } header: {
                        HStack {
                            Text("KG \(gruppe.kg) – \(dinBezeichnung(gruppe.kg))")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            let basis    = gruppe.items.filter { !LVPositionHelper.isAlternative($0) }
                            let altCount = gruppe.items.count - basis.count
                            if altCount > 0 {
                                Text("\(altCount) Alt.")
                                    .font(.caption2).foregroundStyle(.blue)
                                Text("·").foregroundStyle(.secondary).font(.caption2)
                            }
                            let summe = basis.reduce(0.0) { $0 + $1.menge }
                            Text("\(summe.formatted(.number.precision(.fractionLength(0...2)))) ges.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
                    // --- Lieferanten & Preise ---
                    Button { showBestellliste = true } label: {
                        Label("Bestellliste", systemImage: "envelope.badge")
                    }
                    .disabled(positionen.isEmpty)

                    Button { showAngebotsVergleich = true } label: {
                        Label("Angebotsvergleich", systemImage: "chart.bar.doc.horizontal")
                    }

                    Divider()

                    // --- Exportieren ---
                    Button { generatePDF() } label: {
                        Label("LV als PDF", systemImage: "arrow.up.doc")
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

                    Divider()

                    // --- Importieren ---
                    Button { showImport = true } label: {
                        Label("Aus PDF importieren", systemImage: "doc.text.magnifyingglass")
                    }

                    Button { showGAEBImport = true } label: {
                        Label("GAEB X83 importieren", systemImage: "doc.badge.arrow.up")
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
        .sheet(isPresented: $showingAdd) {
            AddLVPositionView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $editPosition) { pos in
            AddLVPositionView(event: event, editPosition: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showBestellliste) {
            LieferantenBestelllisteView(event: event, positionen: Array(positionen))
        }
        .sheet(isPresented: $showAngebotsVergleich) {
            AngebotsVergleichView(event: event, positionen: Array(positionen))
        }
        .sheet(isPresented: $showImport) {
            LVImportView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showGAEBImport) {
            GAEBImportView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showExportShare) {
            if let url = exportURL {
                LVShareSheet(url: url).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showHelp) {
            LVHelpView()
        }
        .alert("Fehlende Preise", isPresented: $showMissingPricesAlert) {
            Button("Trotzdem exportieren") {
                if let fmt = pendingExportFormat { doGAEBExport(fmt) }
            }
            Button("Abbrechen", role: .cancel) { pendingExportFormat = nil }
        } message: {
            Text("\(missingPricesCount) Position\(missingPricesCount == 1 ? " hat" : "en haben") noch keinen Preis im Angebotsvergleich. Der X84 wird mit leeren EP-Feldern exportiert.")
        }
    }

    // MARK: - Actions

    private func delete(_ pos: LVPosition) {
        viewContext.delete(pos)
        try? viewContext.save()
    }

    private func duplicateAsAlternative(_ base: LVPosition) {
        let alt = LVPosition(context: viewContext)
        let baseNr = base.posNr ?? "1"
        alt.posNr              = LVPositionHelper.nextAlternativeNr(for: baseNr, existing: Array(positionen))
        alt.bezeichnung        = (base.bezeichnung ?? "") + " (Alternative)"
        alt.menge              = base.menge
        alt.einheit            = base.einheit
        alt.kostenGruppeNummer = base.kostenGruppeNummer
        alt.artikelNummer      = base.artikelNummer
        alt.lieferant          = base.lieferant
        alt.event              = event
        try? viewContext.save()
    }

    private func generatePDF() {
        let data = LVPDFExporter.generate(event: event, positionen: Array(positionen))
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-").appending(".pdf")
        writeAndShare(data: data, filename: name)
    }

    private func triggerGAEBExport(_ format: GAEBExportFormat) {
        if format.includePrices {
            // Count positions without a price offer
            let missing = Array(positionen).filter { pos in
                let id = pos.objectID.uriRepresentation().absoluteString
                return store.guenstigster(for: id) == nil
            }.count
            if missing > 0 {
                missingPricesCount  = missing
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
        let name  = "\(title)-\(format.filenameSuffix).xml"
        writeAndShare(data: data, filename: name)
        pendingExportFormat = nil
    }

    private func writeAndShare(data: Data, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if (try? data.write(to: url)) != nil {
            exportURL = url
            showExportShare = true
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
        default:    return "Sonstige"
        }
    }
}

// MARK: - Alternative Position Helper

enum LVPositionHelper {
    static func isAlternative(_ pos: LVPosition) -> Bool {
        guard let nr = pos.posNr else { return false }
        return nr.range(of: #"\.A\d"#, options: .regularExpression) != nil
    }
    static func baseNr(for nr: String) -> String {
        guard let range = nr.range(of: #"\.A\d+$"#, options: .regularExpression) else { return nr }
        return String(nr[nr.startIndex..<range.lowerBound])
    }
    static func nextAlternativeNr(for baseNr: String, existing: [LVPosition]) -> String {
        let rootNr = isAlternativeNr(baseNr) ? Self.baseNr(for: baseNr) : baseNr
        let maxIdx = existing.compactMap { $0.posNr }
            .filter { $0.hasPrefix(rootNr + ".A") }
            .compactMap { nr -> Int? in
                guard let r = nr.range(of: #"\.A(\d+)$"#, options: .regularExpression) else { return nil }
                return Int(nr[r].dropFirst(2))
            }.max() ?? 0
        return "\(rootNr).A\(maxIdx + 1)"
    }
    private static func isAlternativeNr(_ nr: String) -> Bool {
        nr.range(of: #"\.A\d"#, options: .regularExpression) != nil
    }
}

// MARK: - Position Row

struct LVPositionRow: View {
    @ObservedObject var position: LVPosition
    @StateObject private var store = AngebotsStore.shared

    private var positionID: String { position.objectID.uriRepresentation().absoluteString }
    private var isAlt: Bool { LVPositionHelper.isAlternative(position) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isAlt {
                    Text("ALT")
                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.blue).clipShape(Capsule())
                }
                Text(position.posNr ?? "–")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(isAlt ? .blue : .secondary)
                    .frame(width: isAlt ? nil : 52, alignment: .leading)
                Text(position.bezeichnung ?? "–")
                    .font(.body).lineLimit(2)
                    .foregroundStyle(isAlt ? .secondary : .primary)
                Spacer()
                Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(isAlt ? .secondary : .primary)
            }
            HStack(spacing: 6) {
                if let art = position.artikelNummer, !art.isEmpty {
                    Image(systemName: "barcode").font(.caption2).foregroundStyle(.secondary)
                    Text(art).font(.caption).foregroundStyle(.secondary)
                    if let lief = position.lieferant, !lief.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(lief).font(.caption).foregroundStyle(.orange)
                    }
                    Text("·").foregroundStyle(.secondary)
                }
                if let best = store.guenstigster(for: positionID) {
                    Image(systemName: "tag.fill").font(.caption2).foregroundStyle(.green)
                    Text(best.einzelpreis, format: .currency(code: "EUR"))
                        .font(.caption.monospacedDigit()).foregroundStyle(.green)
                    Text(best.lieferant).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .opacity(isAlt ? 0.85 : 1.0)
    }
}

// MARK: - Add / Edit Sheet

struct AddLVPositionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let event: Event
    var editPosition: LVPosition?

    @State private var posNr = ""
    @State private var bezeichnung = ""
    @State private var menge = ""
    @State private var einheit = "m²"
    @State private var kg = "320"
    @State private var artikelNummer = ""
    @State private var lieferant = ""
    @State private var isAlternative = false
    @State private var showKatalog = false

    let einheiten  = ["m²", "m³", "lfm", "Stück", "kg", "t", "Psch", "h"]
    let lieferanten = ["Scharpegge", "Hauff", "Baumarkt", "Sonstige"]

    var isValid: Bool {
        !bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(menge.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    HStack {
                        Text("Pos.-Nr.").foregroundStyle(.secondary).frame(width: 80, alignment: .leading)
                        TextField("1.1.01", text: $posNr).keyboardType(.numbersAndPunctuation)
                    }
                    TextField("Bezeichnung *", text: $bezeichnung, axis: .vertical).lineLimit(2...4)
                    Toggle(isOn: $isAlternative) {
                        Label("Alternativposition", systemImage: "doc.on.doc")
                            .foregroundStyle(isAlternative ? .blue : .primary)
                    }
                    .tint(.blue)
                    if isAlternative {
                        Text("Wird als .A1, .A2 … an die Basisposition angehängt.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Menge & Einheit") {
                    HStack {
                        TextField("0,00", text: $menge).keyboardType(.decimalPad).frame(maxWidth: 120)
                        Picker("Einheit", selection: $einheit) {
                            ForEach(einheiten, id: \.self) { Text($0) }
                        }.pickerStyle(.menu)
                    }
                }
                Section("DIN 276 Kostengruppe") {
                    NavigationLink { KGPickerList(selected: $kg) } label: {
                        HStack { Text("KG"); Spacer(); Text(kg).foregroundStyle(.orange) }
                    }
                }
                Section("Material / Lieferant (optional)") {
                    HStack {
                        TextField("Artikelnummer", text: $artikelNummer)
                        Button { showKatalog = true } label: {
                            Image(systemName: "books.vertical").foregroundStyle(.orange)
                        }
                    }
                    Picker("Lieferant", selection: $lieferant) {
                        Text("–").tag("")
                        ForEach(lieferanten, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
            .navigationTitle(editPosition == nil ? "Neue Position" : "Position bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!isValid).tint(.orange)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showKatalog) {
                KatalogPickerSheet { entry in
                    artikelNummer = entry.code ?? ""
                    if lieferant.isEmpty {
                        if (entry.kategorie ?? "").hasPrefix("Scharpegge") { lieferant = "Scharpegge" }
                        else if (entry.kategorie ?? "").hasPrefix("Hauff") { lieferant = "Hauff" }
                    }
                    if bezeichnung.isEmpty { bezeichnung = entry.name ?? "" }
                }
                .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    private func prefill() {
        guard let p = editPosition else { return }
        posNr         = p.posNr ?? ""
        bezeichnung   = p.bezeichnung ?? ""
        menge         = p.menge == 0 ? "" : String(format: "%.2f", p.menge).replacingOccurrences(of: ".", with: ",")
        einheit       = p.einheit ?? "m²"
        kg            = p.kostenGruppeNummer ?? "320"
        artikelNummer = p.artikelNummer ?? ""
        lieferant     = p.lieferant ?? ""
        isAlternative = LVPositionHelper.isAlternative(p)
    }

    private func save() {
        let pos = editPosition ?? LVPosition(context: viewContext)
        var nr  = posNr.trimmingCharacters(in: .whitespacesAndNewlines)
        if isAlternative && !nr.isEmpty && !nr.contains(".A") {
            let req = NSFetchRequest<LVPosition>(entityName: "LVPosition")
            req.predicate = NSPredicate(format: "event == %@", event)
            let all = (try? viewContext.fetch(req)) ?? []
            nr = LVPositionHelper.nextAlternativeNr(for: nr, existing: all)
        }
        pos.posNr              = nr.isEmpty ? nil : nr
        pos.bezeichnung        = bezeichnung
        pos.menge              = Double(menge.replacingOccurrences(of: ",", with: ".")) ?? 0
        pos.einheit            = einheit
        pos.kostenGruppeNummer = kg
        pos.artikelNummer      = artikelNummer.isEmpty ? nil : artikelNummer
        pos.lieferant          = lieferant.isEmpty ? nil : lieferant
        pos.event              = event
        try? viewContext.save()
        dismiss()
    }
}

// MARK: - KG Picker

struct KGPickerList: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    let kgs: [(nr: String, name: String)] = [
        ("100","Grundstück"),("200","Herrichten & Erschließen"),
        ("300","Baukonstruktionen"),("310","Baugrube"),("320","Gründung"),
        ("330","Außenwände"),("340","Innenwände"),("350","Decken"),
        ("360","Dächer"),("370","Infrastruktur"),("380","Fenster & Türen"),
        ("390","Sonstige Baukonstruktion"),("400","Technische Anlagen"),
        ("410","Abwasser, Wasser, Gas"),("420","Wärmeversorgung"),
        ("430","Lufttechnische Anlagen"),("440","Starkstrom"),
        ("450","Fernmelde- & IT-Anlagen"),("500","Außenanlagen"),
        ("600","Ausstattung"),("700","Baunebenkosten")
    ]

    var body: some View {
        List(kgs, id: \.nr) { kg in
            Button { selected = kg.nr; dismiss() } label: {
                HStack {
                    Text("KG \(kg.nr)").font(.body.monospacedDigit()).foregroundStyle(.primary)
                    Text(kg.name).foregroundStyle(.secondary)
                    Spacer()
                    if selected == kg.nr { Image(systemName: "checkmark").foregroundStyle(.orange) }
                }
            }
        }
        .navigationTitle("Kostengruppe wählen")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Katalog Picker

struct KatalogPickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let onSelect: (CDLexikonEntry) -> Void

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
    ) private var entries: FetchedResults<CDLexikonEntry>

    @State private var search = ""

    private var filtered: [CDLexikonEntry] {
        guard !search.isEmpty else { return Array(entries) }
        let q = search.lowercased()
        return entries.filter {
            ($0.name ?? "").lowercased().contains(q) ||
            ($0.code ?? "").lowercased().contains(q) ||
            ($0.kategorie ?? "").lowercased().contains(q)
        }
    }

    private var grouped: [(String, [CDLexikonEntry])] {
        Dictionary(grouping: filtered, by: { $0.kategorie ?? "Sonstige" }).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { kat, items in
                    Section(kat) {
                        ForEach(items, id: \.objectID) { entry in
                            Button { onSelect(entry); dismiss() } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name ?? "").foregroundStyle(.primary)
                                    HStack(spacing: 4) {
                                        Text(entry.code ?? "").font(.caption).foregroundStyle(.secondary)
                                        if let d = entry.details, !d.isEmpty {
                                            Text("·").foregroundStyle(.secondary)
                                            Text(d).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $search, prompt: "Artikel suchen...")
            .navigationTitle("Katalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            }
        }
    }
}

// MARK: - Share Sheet

struct LVShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - Hilfe LV

struct LVHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Was ist das LV?") {
                    Text("Das Leistungsverzeichnis listet alle Bauleistungen strukturiert auf — mit Nummer, Beschreibung, Menge und Einheit.")
                }
                Section("Positionen") {
                    Label("+ anlegen, Swipe-links bearbeiten, Swipe-rechts löschen", systemImage: "hand.point.left")
                    Label("Swipe-links: 'Alternative' erstellt Alternativposition (.A1, .A2 …)", systemImage: "doc.on.doc")
                    Label("Sortierung: DIN 276 Kostengruppe → Pos.-Nr.", systemImage: "list.number")
                }
                Section("GAEB DA XML 3.3") {
                    Label("⋯ → 'GAEB X83 importieren': Angebotsaufforderung einlesen", systemImage: "doc.badge.arrow.up")
                    Label("⋯ → 'GAEB X84 exportieren': bepreistes Angebot rausschreiben", systemImage: "signature")
                    Label("Preisquelle für X84: günstigster Eintrag im Angebotsvergleich", systemImage: "tag.fill")
                    Label("Fehlende Preise → Warnung vor Export", systemImage: "exclamationmark.triangle")
                    Label("Encoding: UTF-8 und Windows-1252 werden erkannt", systemImage: "textformat")
                }
                Section("PDF Import & Export") {
                    Label("⋯ → 'Aus PDF importieren': Heuristik-Parser für LV-PDFs", systemImage: "doc.text.magnifyingglass")
                    Label("⋯ → 'LV als PDF': formatiertes PDF nach DIN 276", systemImage: "arrow.up.doc")
                }
                Section("Bestellliste & Angebotsvergleich") {
                    Label("Bestellliste: vorausgefüllte Preisanfrage-Mail pro Lieferant", systemImage: "envelope.badge")
                    Label("Angebotsvergleich: EP/GP erfassen, günstigster grün markiert", systemImage: "chart.bar.doc.horizontal")
                }
            }
            .navigationTitle("Hilfe: Leistungsverzeichnis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}
