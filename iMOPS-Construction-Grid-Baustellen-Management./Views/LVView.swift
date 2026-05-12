import SwiftUI
import CoreData
import MessageUI
import UIKit

// MARK: - LV Hauptansicht

struct LVView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @FetchRequest private var positionen: FetchedResults<LVPosition>

    @State private var showingAdd        = false
    @State private var editPosition: LVPosition?
    @State private var showBestellliste  = false
    @State private var showHelp          = false
    @State private var showMailUnavailable = false
    @State private var showPDFShare      = false
    @State private var generatedPDFURL: URL?

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
                    description: Text("Tippe auf + um die erste Position anzulegen.")
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
                                }
                        }
                    } header: {
                        HStack {
                            Text("KG \(gruppe.kg) – \(dinBezeichnung(gruppe.kg))")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            let summe = gruppe.items.reduce(0.0) { $0 + $1.menge }
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
                Button {
                    if MFMailComposeViewController.canSendMail() {
                        showBestellliste = true
                    } else {
                        showMailUnavailable = true
                    }
                } label: {
                    Label("Bestellliste", systemImage: "envelope.badge")
                }
                .disabled(positionen.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    let data = LVPDFExporter.generate(event: event, positionen: Array(positionen))
                    let name = "LV-\(event.title ?? "Baustelle")"
                        .replacingOccurrences(of: " ", with: "-")
                        .appending(".pdf")
                    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                    if (try? data.write(to: url)) != nil {
                        generatedPDFURL = url
                        showPDFShare    = true
                    }
                } label: {
                    Label("PDF", systemImage: "arrow.up.doc")
                }
                .disabled(positionen.isEmpty)
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
            BestelllisteMailView(event: event, positionen: Array(positionen))
        }
        .sheet(isPresented: $showPDFShare) {
            if let url = generatedPDFURL {
                LVShareSheet(url: url).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showHelp) {
            LVHelpView()
        }
        .alert("Mail nicht verfügbar", isPresented: $showMailUnavailable) {
            Button("OK") {}
        } message: {
            Text("Auf diesem Gerät ist kein Mail-Account eingerichtet.")
        }
    }

    private func delete(_ pos: LVPosition) {
        viewContext.delete(pos)
        try? viewContext.save()
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

// MARK: - Position Row

struct LVPositionRow: View {
    @ObservedObject var position: LVPosition

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(position.posNr ?? "–")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
                Text(position.bezeichnung ?? "–")
                    .font(.body)
                    .lineLimit(2)
                Spacer()
                Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                    .font(.footnote.monospacedDigit())
            }
            if let art = position.artikelNummer, !art.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "barcode").font(.caption2).foregroundStyle(.secondary)
                    Text(art).font(.caption).foregroundStyle(.secondary)
                    if let lief = position.lieferant, !lief.isEmpty {
                        Text("·").foregroundStyle(.secondary)
                        Text(lief).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
    @State private var showKatalog = false

    let einheiten = ["m²", "m³", "lfm", "Stück", "kg", "t", "Psch", "h"]
    let lieferanten = ["Scharpegge", "Baumarkt", "Sonstige"]

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
                }
                Section("Menge & Einheit") {
                    HStack {
                        TextField("0,00", text: $menge).keyboardType(.decimalPad).frame(maxWidth: 120)
                        Picker("Einheit", selection: $einheit) {
                            ForEach(einheiten, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                Section("DIN 276 Kostengruppe") {
                    NavigationLink {
                        KGPickerList(selected: $kg)
                    } label: {
                        HStack {
                            Text("KG")
                            Spacer()
                            Text(kg).foregroundStyle(.orange)
                        }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!isValid).tint(.orange)
                }
            }
            .onAppear { prefill() }
            .sheet(isPresented: $showKatalog) {
                KatalogPickerSheet { entry in
                    artikelNummer = entry.code ?? ""
                    if lieferant.isEmpty   { lieferant   = "Scharpegge" }
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
    }

    private func save() {
        let pos = editPosition ?? LVPosition(context: viewContext)
        pos.posNr              = posNr.isEmpty ? nil : posNr
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
            Button {
                selected = kg.nr
                dismiss()
            } label: {
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
            NSSortDescriptor(keyPath: \CDLexikonEntry.name,      ascending: true)
        ]
    ) private var entries: FetchedResults<CDLexikonEntry>

    @State private var search = ""

    private var filtered: [CDLexikonEntry] {
        guard !search.isEmpty else { return Array(entries) }
        let q = search.lowercased()
        return entries.filter {
            ($0.name      ?? "").lowercased().contains(q) ||
            ($0.code      ?? "").lowercased().contains(q) ||
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
                            Button {
                                onSelect(entry)
                                dismiss()
                            } label: {
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Share Sheet (PDF)

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
                    Text("Das Leistungsverzeichnis (LV) listet alle Bauleistungen einer Baustelle strukturiert auf. Jede Position hat Nummer, Beschreibung, Menge und Einheit.")
                }
                Section("Positionen verwalten") {
                    Label("Tippe auf + um eine neue Position anzulegen", systemImage: "plus.circle")
                    Label("Wische links zum Bearbeiten, rechts zum Löschen", systemImage: "hand.point.left")
                    Label("Positionen sind nach DIN 276 Kostengruppe sortiert", systemImage: "list.number")
                }
                Section("DIN 276 Kostengruppen") {
                    Label("KG 300: Baukonstruktionen (Fundament, Wände, Decken)", systemImage: "building.2")
                    Label("KG 400: Technische Anlagen (Sanitär, Heizung, Elektro)", systemImage: "bolt")
                    Label("KG 500: Außenanlagen", systemImage: "tree")
                }
                Section("Artikelzuordnung") {
                    Label("Tippe auf das Buch-Symbol um aus dem Scharpegge-Katalog zu wählen", systemImage: "books.vertical")
                    Label("Artikelnummer und Lieferant werden automatisch gefüllt", systemImage: "checkmark.circle")
                }
                Section("Bestellliste & PDF") {
                    Label("Tippe auf 'Bestellliste' für eine Preisanfrage-Mail", systemImage: "envelope.badge")
                    Label("Tippe auf 'PDF' um das LV als PDF zu exportieren und zu teilen", systemImage: "arrow.up.doc")
                    Label("Für Scharpegge: info@scharpegge.gmbh ist vorausgefüllt", systemImage: "envelope")
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
