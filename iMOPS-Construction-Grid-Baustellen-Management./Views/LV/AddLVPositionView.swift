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
    @State private var rezeptMass = ""               // B-Element: Aufwand je Element-Einheit

    /// Das Element, unter dem diese Position als Baustein hängt (nil = kein Baustein).
    private var elternElement: LVPosition? {
        guard let deckel = editPosition?.deckel, deckel.istElement else { return nil }
        return deckel
    }

    let einheiten = ["m²", "m³", "lfm", "Stück", "kg", "t", "Psch", "h"]
    let lieferanten = ["Scharpegge", "Hauff", "Baumarkt", "Sonstige"]

    var isValid: Bool {
        guard !bezeichnung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        // Baustein unter einem Element: die Menge ergibt sich aus dem Rezept-Maß, das
        // Mengenfeld bleibt leer. Dann muss das Rezept stimmen, nicht die Menge —
        // sonst liesse sich ein Baustein nie speichern.
        if elternElement != nil {
            return Double(rezeptMass.replacingOccurrences(of: ",", with: ".")) != nil
        }
        return Double(menge.replacingOccurrences(of: ",", with: ".")) != nil
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
                Section {
                    HStack {
                        TextField("0,00", text: $menge).keyboardType(.decimalPad).frame(maxWidth: 120)
                        Picker("Einheit", selection: $einheit) {
                            ForEach(einheiten, id: \.self) { Text($0) }
                        }.pickerStyle(.menu)
                    }
                } header: {
                    Text("Menge & Einheit")
                } footer: {
                    // Beim Baustein eines Elements ist das Mengenfeld bewusst leer —
                    // sonst sucht man den Fehler an der falschen Stelle.
                    if elternElement != nil {
                        Text("Die Menge kommt aus dem Rezept-Maß unten — dieses Feld bleibt leer. Die Einheit brauchst du: sie sagt, in was der Baustein rechnet.")
                    }
                }
                // Nur wenn die Position ein Baustein unter einem Element ist: das Rezept-Maß.
                // Nicht die Menge zählt hier, sondern wie viel je Einheit des Elements nötig ist.
                if let element = elternElement {
                    Section {
                        HStack {
                            TextField("0,00", text: $rezeptMass)
                                .keyboardType(.decimalPad).frame(maxWidth: 120)
                            Text("\(einheit) je \(element.einheit ?? "Einheit")")
                                .foregroundStyle(.secondary)
                        }
                        if let vorschau = rezeptVorschau(element) {
                            HStack {
                                Text("ergibt").foregroundStyle(.secondary)
                                Spacer()
                                Text(vorschau).monospacedDigit()
                            }
                            .font(.caption)
                        }
                    } header: {
                        Label("Rezept-Maß für: \(element.bezeichnung ?? "Element")",
                              systemImage: "square.stack.3d.down.right.fill")
                    } footer: {
                        Text("""
                        Beispiel: 0,35 m³ Schotter je m² Pflaster. Bei \
                        \(element.menge.formatted(.number.precision(.fractionLength(0...2)))) \
                        \(element.einheit ?? "") ergibt das die tatsächliche Menge.
                        Zuschläge (BGK, Wagnis & Gewinn) werden hier NICHT gerechnet — die trägt \
                        das Element einmal für alle Bausteine.
                        """)
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
        rezeptMass = p.mengeJeDeckelEinheit == 0
            ? ""
            : p.mengeJeDeckelEinheit.formatted(.number.precision(.fractionLength(0...3)))
        refreshKGProposal()
    }

    // MARK: - B-Element: Rezept-Maß

    /// „0,35 m³/m² × 100 m² = 35 m³" — macht sichtbar, was das Rezept konkret bedeutet.
    private func rezeptVorschau(_ element: LVPosition) -> String? {
        guard let faktor = Double(rezeptMass.replacingOccurrences(of: ",", with: ".")),
              faktor > 0 else { return nil }
        let gesamt = faktor * element.menge
        let zahl = gesamt.formatted(.number.precision(.fractionLength(0...2)))
        return "\(zahl) \(einheit)"
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
        // Rezept-Maß nur schreiben, wenn das Feld überhaupt zu sehen war (Baustein
        // unter einem Element) — sonst würde eine normale Position es auf 0 setzen.
        if elternElement != nil {
            pos.mengeJeDeckelEinheit = Double(rezeptMass.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
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
