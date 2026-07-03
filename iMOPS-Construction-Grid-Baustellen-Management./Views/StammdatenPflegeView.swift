import SwiftUI
import CoreData

// Welle 6 — Stammdaten-Pflege: die Kalkulations-Vorlagen (Löhne / Materialien /
// Geräte) anlegen, bearbeiten, löschen. Bisher nur per StammdatenSeeder hartcodiert
// + in den *HinzufuegenViews auswählbar; hier werden sie erstmals gepflegt.
//
// App-weit (nicht pro Baustelle). Wichtig fürs Löschen: die Position*-Einträge
// KOPIEREN die Werte (qualifikation/einzelpreis/geraetName …), sie referenzieren die
// Stammdaten nicht → eine Vorlage zu löschen trifft keine bestehende Kalkulation.

// MARK: - Zahl-Helfer (deutsches Komma ↔ Double)

private func stammFormat(_ d: Double, _ frac: Int = 2) -> String {
    d.formatted(.number.precision(.fractionLength(0...frac)))
}
private func stammParse(_ s: String) -> Double? {
    Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
}

// MARK: - Container

struct StammdatenPflegeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var bereich: Bereich = .loehne

    enum Bereich: String, CaseIterable, Identifiable {
        case loehne   = "Löhne"
        case material = "Materialien"
        case geraete  = "Geräte"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .loehne:   return "person.2"
            case .material: return "shippingbox"
            case .geraete:  return "wrench.and.screwdriver"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Bereich", selection: $bereich) {
                    ForEach(Bereich.allCases) { b in
                        Label(b.rawValue, systemImage: b.icon).tag(b)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch bereich {
                case .loehne:   LohnsatzListe()
                case .material: MaterialListe()
                case .geraete:  GeraetListe()
                }
            }
            .navigationTitle("Stammdaten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}

// MARK: - Löhne

private struct LohnsatzListe: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Lohnsatz.qualifikation, ascending: true)])
    private var eintraege: FetchedResults<Lohnsatz>

    @State private var sheetTarget: Lohnsatz?   // nil = neu
    @State private var zeigeSheet = false
    @State private var loeschKandidat: Lohnsatz?

    var body: some View {
        List {
            if eintraege.isEmpty {
                ContentUnavailableView("Keine Lohnsätze", systemImage: "person.2",
                                       description: Text("Mit + einen anlegen."))
            } else {
                ForEach(eintraege) { ls in
                    Button { sheetTarget = ls; zeigeSheet = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ls.qualifikation ?? "—").font(.headline).foregroundStyle(.primary)
                                Text("Zuschlag ×\(stammFormat(ls.zuschlagFaktor))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(ls.stundenlohn.formatted(.currency(code: "EUR")))/h")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loeschKandidat = ls } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { neuButton("Neuer Lohnsatz") { sheetTarget = nil; zeigeSheet = true } }
        .sheet(isPresented: $zeigeSheet) {
            LohnsatzEditSheet(lohnsatz: sheetTarget).environment(\.managedObjectContext, ctx)
        }
        .confirmationDialog("Lohnsatz löschen?",
                            isPresented: Binding(get: { loeschKandidat != nil },
                                                 set: { if !$0 { loeschKandidat = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let k = loeschKandidat { ctx.delete(k); try? ctx.save() }
                loeschKandidat = nil
            }
            Button("Abbrechen", role: .cancel) { loeschKandidat = nil }
        } message: {
            Text("\(loeschKandidat?.qualifikation ?? "") löschen. Das entfernt nur die Vorlage — bereits kalkulierte Positionen behalten ihre Werte.")
        }
    }
}

private struct LohnsatzEditSheet: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let lohnsatz: Lohnsatz?

    @State private var qualifikation: String
    @State private var stundenlohn: String
    @State private var zuschlag: String

    init(lohnsatz: Lohnsatz?) {
        self.lohnsatz = lohnsatz
        _qualifikation = State(initialValue: lohnsatz?.qualifikation ?? "")
        _stundenlohn = State(initialValue: lohnsatz.map { stammFormat($0.stundenlohn) } ?? "")
        _zuschlag = State(initialValue: lohnsatz.map { stammFormat($0.zuschlagFaktor) } ?? "1")
    }

    private var valid: Bool {
        !qualifikation.trimmingCharacters(in: .whitespaces).isEmpty && stammParse(stundenlohn) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Qualifikation") {
                    TextField("z. B. Maurer", text: $qualifikation)
                }
                Section("Stundenlohn (EK)") {
                    HStack {
                        TextField("0,00", text: $stundenlohn).keyboardType(.decimalPad)
                        Text("€/h").foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        TextField("1,0", text: $zuschlag).keyboardType(.decimalPad)
                        Text("×").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Zuschlagsfaktor")
                } footer: {
                    Text("Multiplikator auf den Stundenlohn (Lohnnebenkosten). 1,0 = ohne Zuschlag.")
                }
            }
            .navigationTitle(lohnsatz == nil ? "Neuer Lohnsatz" : "Lohnsatz bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!valid).tint(.orange)
                }
            }
        }
    }

    private func save() {
        let obj = lohnsatz ?? Lohnsatz(context: ctx)
        if lohnsatz == nil { obj.id = UUID() }
        obj.qualifikation = qualifikation.trimmingCharacters(in: .whitespaces)
        obj.stundenlohn = stammParse(stundenlohn) ?? 0
        obj.zuschlagFaktor = stammParse(zuschlag) ?? 1
        try? ctx.save()
        dismiss()
    }
}

// MARK: - Materialien

private struct MaterialListe: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \KalkMaterial.name, ascending: true)])
    private var eintraege: FetchedResults<KalkMaterial>

    @State private var sheetTarget: KalkMaterial?
    @State private var zeigeSheet = false
    @State private var loeschKandidat: KalkMaterial?

    var body: some View {
        List {
            if eintraege.isEmpty {
                ContentUnavailableView("Keine Materialien", systemImage: "shippingbox",
                                       description: Text("Mit + eines anlegen."))
            } else {
                ForEach(eintraege) { m in
                    Button { sheetTarget = m; zeigeSheet = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name ?? "—").font(.headline).foregroundStyle(.primary)
                                if let lief = m.lieferant, !lief.isEmpty {
                                    Text(lief).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text("\(m.preisProEinheit.formatted(.currency(code: "EUR")))/\(m.einheit ?? "")")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loeschKandidat = m } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { neuButton("Neues Material") { sheetTarget = nil; zeigeSheet = true } }
        .sheet(isPresented: $zeigeSheet) {
            MaterialEditSheet(material: sheetTarget).environment(\.managedObjectContext, ctx)
        }
        .confirmationDialog("Material löschen?",
                            isPresented: Binding(get: { loeschKandidat != nil },
                                                 set: { if !$0 { loeschKandidat = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let k = loeschKandidat { ctx.delete(k); try? ctx.save() }
                loeschKandidat = nil
            }
            Button("Abbrechen", role: .cancel) { loeschKandidat = nil }
        } message: {
            Text("\(loeschKandidat?.name ?? "") löschen. Das entfernt nur die Vorlage — bereits kalkulierte Positionen behalten ihre Werte.")
        }
    }
}

private struct MaterialEditSheet: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let material: KalkMaterial?

    @State private var name: String
    @State private var einheit: String
    @State private var preis: String
    @State private var lieferant: String
    @State private var verbrauch: String
    @State private var verschnitt: String

    init(material: KalkMaterial?) {
        self.material = material
        _name = State(initialValue: material?.name ?? "")
        _einheit = State(initialValue: material?.einheit ?? "")
        _preis = State(initialValue: material.map { stammFormat($0.preisProEinheit) } ?? "")
        _lieferant = State(initialValue: material?.lieferant ?? "")
        _verbrauch = State(initialValue: material.map { stammFormat($0.verbrauchProM2) } ?? "")
        _verschnitt = State(initialValue: material.map { stammFormat($0.verschnittProzent) } ?? "0")
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && stammParse(preis) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Material") {
                    TextField("z. B. Porenbeton PP2-0.4", text: $name)
                    HStack {
                        Text("Einheit").foregroundStyle(.secondary)
                        Spacer()
                        TextField("m³ / Stk / m²", text: $einheit)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 140)
                    }
                }
                Section("Preis (EK)") {
                    HStack {
                        TextField("0,00", text: $preis).keyboardType(.decimalPad)
                        Text("€/\(einheit.isEmpty ? "Einheit" : einheit)").foregroundStyle(.secondary)
                    }
                }
                Section("Lieferant (optional)") {
                    TextField("z. B. Xella", text: $lieferant)
                }
                Section {
                    HStack {
                        Text("Verbrauch/m²").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $verbrauch).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 100)
                    }
                    HStack {
                        Text("Verschnitt").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $verschnitt).keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 100)
                        Text("%").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Kalkulations-Parameter (optional)")
                }
            }
            .navigationTitle(material == nil ? "Neues Material" : "Material bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!valid).tint(.orange)
                }
            }
        }
    }

    private func save() {
        let obj = material ?? KalkMaterial(context: ctx)
        if material == nil { obj.id = UUID() }
        obj.name = name.trimmingCharacters(in: .whitespaces)
        obj.einheit = einheit.isEmpty ? nil : einheit
        obj.preisProEinheit = stammParse(preis) ?? 0
        obj.lieferant = lieferant.isEmpty ? nil : lieferant
        obj.verbrauchProM2 = stammParse(verbrauch) ?? 0
        obj.verschnittProzent = stammParse(verschnitt) ?? 0
        obj.quelle = .manuell               // von Hand gepflegt
        obj.letzteAktualisierung = Date()
        try? ctx.save()
        dismiss()
    }
}

// MARK: - Geräte

private struct GeraetListe: View {
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Geraet.name, ascending: true)])
    private var eintraege: FetchedResults<Geraet>

    @State private var sheetTarget: Geraet?
    @State private var zeigeSheet = false
    @State private var loeschKandidat: Geraet?

    var body: some View {
        List {
            if eintraege.isEmpty {
                ContentUnavailableView("Keine Geräte", systemImage: "wrench.and.screwdriver",
                                       description: Text("Mit + eines anlegen."))
            } else {
                ForEach(eintraege) { g in
                    Button { sheetTarget = g; zeigeSheet = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.name ?? "—").font(.headline).foregroundStyle(.primary)
                                Text("\(g.nutzungsdauerStunden) h Nutzungsdauer")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(g.anschaffungsKosten.formatted(.currency(code: "EUR")))
                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loeschKandidat = g } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { neuButton("Neues Gerät") { sheetTarget = nil; zeigeSheet = true } }
        .sheet(isPresented: $zeigeSheet) {
            GeraetEditSheet(geraet: sheetTarget).environment(\.managedObjectContext, ctx)
        }
        .confirmationDialog("Gerät löschen?",
                            isPresented: Binding(get: { loeschKandidat != nil },
                                                 set: { if !$0 { loeschKandidat = nil } }),
                            titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                if let k = loeschKandidat { ctx.delete(k); try? ctx.save() }
                loeschKandidat = nil
            }
            Button("Abbrechen", role: .cancel) { loeschKandidat = nil }
        } message: {
            Text("\(loeschKandidat?.name ?? "") löschen. Das entfernt nur die Vorlage — bereits kalkulierte Positionen behalten ihre Werte.")
        }
    }
}

private struct GeraetEditSheet: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let geraet: Geraet?

    @State private var name: String
    @State private var kosten: String
    @State private var stunden: String
    @State private var notiz: String

    init(geraet: Geraet?) {
        self.geraet = geraet
        _name = State(initialValue: geraet?.name ?? "")
        _kosten = State(initialValue: geraet.map { stammFormat($0.anschaffungsKosten) } ?? "")
        _stunden = State(initialValue: geraet.map { String($0.nutzungsdauerStunden) } ?? "")
        _notiz = State(initialValue: geraet?.notiz ?? "")
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && stammParse(kosten) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Gerät") {
                    TextField("z. B. Kettenbagger 5 t", text: $name)
                }
                Section("Anschaffungskosten") {
                    HStack {
                        TextField("0,00", text: $kosten).keyboardType(.decimalPad)
                        Text("€").foregroundStyle(.secondary)
                    }
                }
                Section {
                    HStack {
                        TextField("0", text: $stunden).keyboardType(.numberPad)
                        Text("h").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Nutzungsdauer")
                } footer: {
                    Text("Gesamte Nutzungsdauer in Stunden — Basis für den Stundensatz (Kosten ÷ Stunden).")
                }
                Section("Notiz (optional)") {
                    TextField("z. B. inkl. Wartung", text: $notiz, axis: .vertical).lineLimit(1...3)
                }
            }
            .navigationTitle(geraet == nil ? "Neues Gerät" : "Gerät bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!valid).tint(.orange)
                }
            }
        }
    }

    private func save() {
        let obj = geraet ?? Geraet(context: ctx)
        if geraet == nil { obj.id = UUID() }
        obj.name = name.trimmingCharacters(in: .whitespaces)
        obj.anschaffungsKosten = stammParse(kosten) ?? 0
        obj.nutzungsdauerStunden = Int32(stunden.trimmingCharacters(in: .whitespaces)) ?? 0
        obj.notiz = notiz.isEmpty ? nil : notiz
        try? ctx.save()
        dismiss()
    }
}

// MARK: - Gemeinsamer „Neu"-Button

@ViewBuilder
private func neuButton(_ titel: String, _ action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Label(titel, systemImage: "plus.circle.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
    }
    .buttonStyle(.borderedProminent)
    .tint(.orange)
    .padding()
}
