import SwiftUI
import CoreData

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
    @State private var kgProposal: KGProposal?
    @State private var selectedGeschoss: Geschoss?   // Welle 9 — Ebene der Position

    let einheiten = ["m²", "m³", "lfm", "Stück", "kg", "t", "Psch", "h"]
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
                Section {
                    Picker("Geschoss", selection: $selectedGeschoss) {
                        ForEach(verfuegbareGeschosse, id: \.objectID) { g in
                            Text(geschossLabel(g)).tag(Optional(g))
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Ebene (Welle 9)")
                } footer: {
                    Text("Ordnet die Position einem Geschoss zu (Gruppierung Ebene + Kosten nach Ebene). Verwaltung: LV → ⋯ → Ebenen verwalten.")
                }

                Section("DIN 276 Kostengruppe") {
                    NavigationLink { KGPickerList(selected: $kg) } label: {
                        HStack { Text("KG"); Spacer(); Text(kg).foregroundStyle(.orange) }
                    }

                    if let kgProposal {
                        KGProposalBox(proposal: kgProposal) {
                            kg = kgProposal.suggestedKG
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
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!isValid).tint(.orange)
                }
            }
            .onAppear { prefill(); setupGeschoss() }
            .onChange(of: bezeichnung) { _, _ in
                refreshKGProposal()
            }
            .onChange(of: einheit) { _, _ in
                refreshKGProposal()
            }
            .fullScreenCover(isPresented: $showKatalog) {
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
        posNr = p.posNr ?? ""
        bezeichnung = p.bezeichnung ?? ""
        menge = p.menge == 0 ? "" : String(format: "%.2f", p.menge).replacingOccurrences(of: ".", with: ",")
        einheit = p.einheit ?? "m²"
        kg = p.kostenGruppeNummer ?? "320"
        artikelNummer = p.artikelNummer ?? ""
        lieferant = p.lieferant ?? ""
        isAlternative = LVPositionHelper.isAlternative(p)
        refreshKGProposal()
    }

    private func save() {
        let pos = editPosition ?? LVPosition(context: viewContext)
        var nr = posNr.trimmingCharacters(in: .whitespacesAndNewlines)
        if isAlternative && !nr.isEmpty && !nr.contains(".A") {
            let req = NSFetchRequest<LVPosition>(entityName: "LVPosition")
            req.predicate = NSPredicate(format: "event == %@", event)
            let all = (try? viewContext.fetch(req)) ?? []
            nr = LVPositionHelper.nextAlternativeNr(for: nr, existing: all)
        }
        pos.posNr = nr.isEmpty ? nil : nr
        pos.bezeichnung = bezeichnung
        pos.menge = Double(menge.replacingOccurrences(of: ",", with: ".")) ?? 0
        pos.einheit = einheit
        pos.kostenGruppeNummer = kg
        pos.artikelNummer = artikelNummer.isEmpty ? nil : artikelNummer
        pos.lieferant = lieferant.isEmpty ? nil : lieferant
        pos.event = event
        // Welle 9 — Ebene setzen (nie nil): gewähltes Geschoss oder Default der Baustelle.
        pos.geschoss = selectedGeschoss
            ?? HierarchieHelfer.sichereDefaultGeschoss(for: event, in: viewContext).geschoss
        try? viewContext.save()
        dismiss()
    }

    // MARK: - Welle 9: Ebene

    private var verfuegbareGeschosse: [Geschoss] {
        HierarchieHelfer.alleGeschosse(for: event)
    }

    private func geschossLabel(_ g: Geschoss) -> String {
        "\(g.gebaeude?.name ?? "—") · \(g.name ?? "Geschoss")"
    }

    /// Sichert, dass die Baustelle mind. ein Geschoss hat, und setzt die Vorauswahl
    /// (bearbeitete Position: ihr Geschoss; neue Position: Default-Geschoss).
    private func setupGeschoss() {
        let ergebnis = HierarchieHelfer.sichereDefaultGeschoss(for: event, in: viewContext)
        if ergebnis.geaendert { try? viewContext.save() }
        if selectedGeschoss == nil {
            selectedGeschoss = editPosition?.geschoss ?? ergebnis.geschoss
        }
    }

    private func refreshKGProposal() {
        kgProposal = ExpertValidationService.proposeKG(
            for: LVDraftPosition(
                bezeichnung: bezeichnung,
                einheit: einheit
            )
        )
    }
}
