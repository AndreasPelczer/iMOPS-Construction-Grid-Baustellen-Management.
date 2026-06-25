import SwiftUI
import CoreData

// MARK: - LVTiefenkalkulationView
// Hauptansicht fuer die Kalkulation einer einzelnen LV-Position.
// Zeigt Material, Lohn, Geraete und berechnet EK/VK/Gesamt.
// Offline-first: alles lokal, Mops nur als optionaler Bonus-Button.

struct LVTiefenkalkulationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var position: LVPosition
    @State private var showKalkHelp = false
    @State private var wgProzent: Double
    @State private var bgkProzent: Double
    @State private var showMaterialPicker = false
    @State private var showLohnPicker = false
    @State private var showGeraetePicker = false
    @State private var showMopsSheet = false
    @State private var mopsAntwort: String?

    init(position: LVPosition) {
        self.position = position
        _wgProzent = State(initialValue: position.wagnisGewinnProzent)
        _bgkProzent = State(initialValue: position.bgkProzent)
    }

    private var kalkulation: Kalkulation {
        LVKalkulator.kalkuliere(position: position)
    }

    var body: some View {
        List {
            positionKopfSection
            materialSection
            lohnSection
            geraeteSection
            zuschlagSection
            ergebnisSection
            mopsBonusSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kalkulation")
        .navigationBarTitleDisplayMode(.inline)
        
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showKalkHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
        }
        .fullScreenCover(isPresented: $showKalkHelp) {
            // Hier kannst du eine kurze Hilfe-View für die Kalkulation einbauen
            // oder die bestehende LVHelpView nehmen.
        }
        
        .fullScreenCover(isPresented: $showMaterialPicker) {
            MaterialHinzufuegenView(position: position)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showLohnPicker) {
            LohnHinzufuegenView(position: position)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showGeraetePicker) {
            GeraetHinzufuegenView(position: position)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showMopsSheet) {
            MopsVorschlagSheet(position: position, antwort: $mopsAntwort)
                .environment(\.managedObjectContext, viewContext)
        }
    }

    // MARK: - Positions-Kopf

    private var positionKopfSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(position.posNr ?? "–")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                    if let kg = position.kostenGruppeNummer {
                        Text("· KG \(kg)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(position.bezeichnung ?? "Unbenannte Position")
                    .font(.headline)
                HStack {
                    Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Material

    private var materialSection: some View {
        Section {
            if position.materialArray.isEmpty {
                Text("Noch kein Material hinterlegt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(position.materialArray, id: \.objectID) { pm in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pm.materialName ?? "–")
                                .font(.subheadline)
                            Text("\(pm.mengeProEinheit.formatted(.number.precision(.fractionLength(0...3)))) \(pm.einheit ?? "") × \(pm.einzelpreis.formatted(.currency(code: "EUR")))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if pm.verschnittProzent > 0 {
                                Text("+\(Int(pm.verschnittProzent * 100))% Verschnitt")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        Spacer()
                        Text(pm.kostenProEinheit.formatted(.currency(code: "EUR")))
                            .font(.subheadline.monospacedDigit())
                            .bold()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loescheMaterial(pm) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            Button { showMaterialPicker = true } label: {
                Label("Material hinzufügen", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            HStack {
                Label("Material", systemImage: "shippingbox")
                Spacer()
                Text(kalkulation.materialKosten.formatted(.currency(code: "EUR")))
                    .font(.caption.monospacedDigit())
            }
        }
    }

    // MARK: - Lohn

    private var lohnSection: some View {
        Section {
            if position.lohnArray.isEmpty {
                Text("Noch kein Lohnanteil hinterlegt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(position.lohnArray, id: \.objectID) { pl in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pl.qualifikation ?? "–")
                                .font(.subheadline)
                            Text("\(pl.stunden.formatted(.number.precision(.fractionLength(0...2)))) h × \(pl.stundenBruttoEK.formatted(.currency(code: "EUR")))/h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(pl.kostenProEinheit.formatted(.currency(code: "EUR")))
                            .font(.subheadline.monospacedDigit())
                            .bold()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loescheLohn(pl) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            Button { showLohnPicker = true } label: {
                Label("Lohnanteil hinzufügen", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            HStack {
                Label("Lohn", systemImage: "person.fill")
                Spacer()
                Text(kalkulation.lohnKosten.formatted(.currency(code: "EUR")))
                    .font(.caption.monospacedDigit())
            }
        }
    }

    // MARK: - Geraete

    private var geraeteSection: some View {
        Section {
            if position.geraeteArray.isEmpty {
                Text("Keine Gerätekosten hinterlegt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(position.geraeteArray, id: \.objectID) { pg in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pg.geraetName ?? "–")
                                .font(.subheadline)
                            Text("\(pg.stunden.formatted(.number.precision(.fractionLength(0...2)))) h × \(pg.kostenProStunde.formatted(.currency(code: "EUR")))/h")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(pg.kostenProEinheit.formatted(.currency(code: "EUR")))
                            .font(.subheadline.monospacedDigit())
                            .bold()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loescheGeraet(pg) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            Button { showGeraetePicker = true } label: {
                Label("Gerät hinzufügen", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            HStack {
                Label("Geräte", systemImage: "wrench.and.screwdriver")
                Spacer()
                Text(kalkulation.geraeteKosten.formatted(.currency(code: "EUR")))
                    .font(.caption.monospacedDigit())
            }
        }
    }

    // MARK: - Zuschlaege

    private var zuschlagSection: some View {
        Section {
            HStack {
                Text("Wagnis & Gewinn")
                Spacer()
                Text("\(Int(wgProzent * 100)) %")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Slider(value: $wgProzent, in: 0...0.25, step: 0.01)
                .tint(.orange)
                .onChange(of: wgProzent) { _, newVal in
                    position.wagnisGewinnProzent = newVal
                }

            HStack {
                Text("BGK (Baustellengemeinkosten)")
                Spacer()
                Text("\(Int(bgkProzent * 100)) %")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.orange)
            }
            Slider(value: $bgkProzent, in: 0...0.25, step: 0.01)
                .tint(.orange)
                .onChange(of: bgkProzent) { _, newVal in
                    position.bgkProzent = newVal
                }
        } header: {
            Label("Zuschläge", systemImage: "percent")
        } footer: {
            Text("W&G und BGK werden auf den EK aufgeschlagen, um den VK zu berechnen.")
        }
    }

    // MARK: - Ergebnis

    private var ergebnisSection: some View {
        Section {
            // EK-Aufschluesselung
            VStack(spacing: 8) {
                ergebnisZeile(label: "Material", wert: kalkulation.materialKosten, farbe: .blue)
                ergebnisZeile(label: "Lohn", wert: kalkulation.lohnKosten, farbe: .green)
                ergebnisZeile(label: "Geräte", wert: kalkulation.geraeteKosten, farbe: .purple)
                Divider()
                ergebnisZeile(label: "EP (EK)", wert: kalkulation.einheitspreisEK, farbe: .primary, bold: true)
                ergebnisZeile(label: "+ W&G (\(Int(wgProzent * 100))%)", wert: kalkulation.zuschlagWG, farbe: .orange)
                ergebnisZeile(label: "+ BGK (\(Int(bgkProzent * 100))%)", wert: kalkulation.zuschlagBGK, farbe: .orange)
                Divider()
                ergebnisZeile(label: "EP (VK)", wert: kalkulation.einheitspreisVK, farbe: .primary, bold: true)
            }
            .padding(.vertical, 4)

            // Gesamtpreis
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gesamtpreis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "") × \(kalkulation.einheitspreisVK.formatted(.currency(code: "EUR")))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(kalkulation.gesamtpreis.formatted(.currency(code: "EUR")))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)

            // Anteils-Balken (nur wenn Kalkulation vorhanden)
            if kalkulation.einheitspreisEK > 0 {
                anteilsBalken
            }
        } header: {
            Label("Kalkulations-Ergebnis", systemImage: "equal.circle")
        }
    }

    private func ergebnisZeile(label: String, wert: Double, farbe: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(farbe)
            Spacer()
            Text(wert.formatted(.currency(code: "EUR")))
                .font(bold ? .subheadline.bold().monospacedDigit() : .subheadline.monospacedDigit())
        }
    }

    private var anteilsBalken: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if kalkulation.materialAnteil > 0 {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * kalkulation.materialAnteil)
                }
                if kalkulation.lohnAnteil > 0 {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * kalkulation.lohnAnteil)
                }
                if kalkulation.geraeteAnteil > 0 {
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: geo.size.width * kalkulation.geraeteAnteil)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
    }

    // MARK: - Mops Bonus

    private var mopsBonusSection: some View {
        Section {
            Button {
                showMopsSheet = true
            } label: {
                HStack {
                    Text("🐶")
                    Text("Mops fragen")
                        .font(.subheadline)
                    Spacer()
                    if !MopsKalkulationsHelper.shared.isAvailable {
                        Text("offline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(!MopsKalkulationsHelper.shared.isAvailable)
            .tint(.orange)

            if let antwort = mopsAntwort {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mops-Vorschlag:")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(antwort)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("KI-Assistent (optional)", systemImage: "sparkles")
        } footer: {
            Text("Mops-Vorschläge sind IMMER nur Vorschläge — du entscheidest.")
        }
    }

    // MARK: - Actions

    private func speichern() {
        position.wagnisGewinnProzent = wgProzent
        position.bgkProzent = bgkProzent
        try? viewContext.save()
    }

    private func loescheMaterial(_ pm: PositionMaterial) {
        viewContext.delete(pm)
        try? viewContext.save()
    }

    private func loescheLohn(_ pl: PositionLohn) {
        viewContext.delete(pl)
        try? viewContext.save()
    }

    private func loescheGeraet(_ pg: PositionGeraet) {
        viewContext.delete(pg)
        try? viewContext.save()
    }
}
