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
    @State private var loeschZiel: LoeschZiel?   // sichtbares Löschen (auch am Mac, wo Swipe nicht geht)

    /// Was gelöscht werden soll (mit Klartext für die Sicherheitsabfrage).
    private struct LoeschZiel: Identifiable {
        let id = UUID()
        let objekt: NSManagedObject
        let beschreibung: String
    }

    @State private var eigen: Bool
    @State private var jeKostenart: Bool
    @State private var zLohn: Double
    @State private var zMaterial: Double
    @State private var zGeraet: Double

    init(position: LVPosition) {
        self.position = position
        // Immer die WIRKSAMEN Saetze anzeigen — also Firmenwert, solange die Position
        // nicht ausdruecklich abweicht. Sonst stuende im Regler etwas anderes als das,
        // womit gerechnet wird.
        _eigen = State(initialValue: position.zuschlagEigen)
        _wgProzent = State(initialValue: position.satzWagnisGewinn)
        _bgkProzent = State(initialValue: position.satzBGK)
        _jeKostenart = State(initialValue: position.rechnetJeKostenart)
        _zLohn = State(initialValue: position.satzLohn)
        _zMaterial = State(initialValue: position.satzMaterial)
        _zGeraet = State(initialValue: position.satzGeraet)
    }

    private var kalkulation: Kalkulation {
        // Ein Element rechnet ueber seine Bausteine, nicht ueber eine eigene
        // Tiefenkalkulation — sonst stuende hier 0.
        LVKalkulator.kalkulationFuer(position)
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
        .confirmationDialog("Zeile löschen?",
                            isPresented: Binding(get: { loeschZiel != nil },
                                                 set: { if !$0 { loeschZiel = nil } }),
                            presenting: loeschZiel) { ziel in
            Button("Löschen", role: .destructive) {
                viewContext.delete(ziel.objekt)
                try? viewContext.save()
                loeschZiel = nil
            }
            Button("Abbrechen", role: .cancel) { loeschZiel = nil }
        } message: { ziel in
            Text("\(ziel.beschreibung) aus der Kalkulation entfernen? Der Positionspreis wird neu berechnet.")
        }
        
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

    /// Leer-Zustand einer Kostenart.
    ///
    /// Beim Element ist die Liste immer leer — die Kosten stecken in den Bausteinen.
    /// „Noch nichts hinterlegt" wäre dort schlicht gelogen: die Kopfzeile zeigt ja
    /// einen Betrag. Stattdessen der Verweis dorthin, wo wirklich gerechnet wird.
    @ViewBuilder
    private func leerHinweis(_ text: String) -> some View {
        if position.istElement {
            Label("Kommt aus den \(position.unterPositionenArray.count) Bausteinen — dort bearbeiten",
                  systemImage: "square.stack.3d.down.right.fill")
                .font(.subheadline)
                .foregroundStyle(.indigo)
        } else {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Material

    private var materialSection: some View {
        Section {
            if position.materialArray.isEmpty {
                leerHinweis("Noch kein Material hinterlegt")
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
                        loeschButton { loeschZiel = LoeschZiel(objekt: pm, beschreibung: "Material: \(pm.materialName ?? "–")") }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loescheMaterial(pm) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            if !position.istElement {
                Button { showMaterialPicker = true } label: {
                    Label("Material hinzufügen", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .tint(.orange)
            }
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
                leerHinweis("Noch kein Lohnanteil hinterlegt")
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
                        loeschButton { loeschZiel = LoeschZiel(objekt: pl, beschreibung: "Lohn: \(pl.qualifikation ?? "–")") }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loescheLohn(pl) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            if !position.istElement {
                Button { showLohnPicker = true } label: {
                    Label("Lohnanteil hinzufügen", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .tint(.orange)
            }
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
                leerHinweis("Keine Gerätekosten hinterlegt")
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
                        loeschButton { loeschZiel = LoeschZiel(objekt: pg, beschreibung: "Gerät: \(pg.geraetName ?? "–")") }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { loescheGeraet(pg) } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            if !position.istElement {
                Button { showGeraetePicker = true } label: {
                    Label("Gerät hinzufügen", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .tint(.orange)
            }
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
            Toggle(isOn: $eigen) {
                Label("Von den Firmenwerten abweichen", systemImage: "building.2")
            }
            .tint(.orange)
            .onChange(of: eigen) { _, neu in
                position.zuschlagEigen = neu
                if neu {
                    // Beim Umschalten die Firmenwerte uebernehmen — sonst springt der
                    // Preis, obwohl der Nutzer nur "abweichen" angetippt hat.
                    position.uebernehmeFirmenwerte()
                } else {
                    // Zurueck zur Firma: die Regler wieder auf deren Stand ziehen.
                    jeKostenart = FirmenSettings.zuschlagJeKostenart
                    zLohn = FirmenSettings.zuschlagLohn
                    zMaterial = FirmenSettings.zuschlagMaterial
                    zGeraet = FirmenSettings.zuschlagGeraet
                    wgProzent = FirmenSettings.wagnisGewinn
                    bgkProzent = FirmenSettings.bgk
                }
            }

            Toggle(isOn: $jeKostenart) {
                Label("Je Kostenart aufschlagen", systemImage: "square.split.1x2")
            }
            .tint(.orange)
            .disabled(!eigen)
            .onChange(of: jeKostenart) { _, neu in position.zuschlagJeKostenart = neu }

            if jeKostenart {
                zuschlagRegler("Lohn", wert: $zLohn, farbe: .green, bis: 3.0) {
                    position.zuschlagLohnProzent = $0
                }
                zuschlagRegler("Material", wert: $zMaterial, farbe: .blue, bis: 1.0) {
                    position.zuschlagMaterialProzent = $0
                }
                zuschlagRegler("Geräte", wert: $zGeraet, farbe: .purple, bis: 1.0) {
                    position.zuschlagGeraetProzent = $0
                }
            } else {
                zuschlagRegler("Wagnis & Gewinn", wert: $wgProzent, farbe: .orange, bis: 0.25) {
                    position.wagnisGewinnProzent = $0
                }
                zuschlagRegler("BGK (Baustellengemeinkosten)", wert: $bgkProzent, farbe: .orange, bis: 0.25) {
                    position.bgkProzent = $0
                }
            }
        } header: {
            Label("Zuschläge", systemImage: "percent")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if eigen {
                    Text("Diese Position weicht ab. Änderungen hier gelten NUR für sie — die Firmenwerte bleiben unberührt.")
                        .foregroundStyle(.orange)
                } else {
                    Text("Es gelten die Firmenwerte (Einstellungen → Kalkulation). Ein Satz wird dort einmal gepflegt und wirkt in jeder Position, die nicht abweicht. Zum Ändern nur für diese Position den Schalter oben umlegen.")
                }
                if jeKostenart {
                    Text("""
                    Ein Bauunternehmen schlägt nicht auf alles gleich auf: der Lohn trägt \
                    den Löwenanteil von Gemeinkosten und Gewinn, Material und Gerät kaum \
                    etwas. Üblich sind Größenordnungen wie Lohn ×2,75, Material ×1,15, \
                    Gerät ×1,10. W&G und BGK werden in diesem Modus nicht gerechnet.
                    """)
                } else {
                    Text("W&G und BGK werden auf den EK aufgeschlagen, um den VK zu berechnen. Die Vorgabe 20 % je Kostenart ergibt exakt denselben Preis wie 8 % + 12 % auf alles.")
                }
            }
        }
    }

    /// Ein Zuschlags-Regler mit Prozentwert UND Faktor — der Faktor ist die Zahl,
    /// in der auf dem Bau gedacht wird („mal 2,75 auf den Lohn").
    @ViewBuilder
    private func zuschlagRegler(_ titel: String,
                                wert: Binding<Double>,
                                farbe: Color,
                                bis: Double,
                                speichern: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(titel)
                .foregroundStyle(eigen ? .primary : .secondary)
            Spacer()
            Text("\(Int(wert.wrappedValue * 100)) %")
                .font(.body.monospacedDigit())
                .foregroundStyle(eigen ? farbe : .secondary)
            Text("(×\((1 + wert.wrappedValue).formatted(.number.precision(.fractionLength(2)))))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        Slider(value: wert, in: 0...bis, step: 0.05)
            .tint(farbe)
            .disabled(!eigen)   // Firmenwert: sichtbar, aber nicht hier verstellbar
            .onChange(of: wert.wrappedValue) { _, neu in speichern(neu) }
    }

    // MARK: - Ergebnis

    /// Lohnstunden — je Einheit und für die ganze Position. Nicht Geld, aber die
    /// Größe, an der Termine und Mannschaftsstärke hängen.
    private var stundenZeile: some View {
        HStack {
            Label("Lohnstunden", systemImage: "clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(kalkulation.stundenGesamt.formatted(.number.precision(.fractionLength(0...2)))) Std")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text("\(kalkulation.stundenJeEinheit.formatted(.number.precision(.fractionLength(0...3)))) Std je \(position.einheit ?? "Einheit")")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ergebnisSection: some View {
        Section {
            // EK-Aufschluesselung
            VStack(spacing: 8) {
                ergebnisZeile(label: "Material", wert: kalkulation.materialKosten, farbe: .blue)
                ergebnisZeile(label: "Lohn", wert: kalkulation.lohnKosten, farbe: .green)
                ergebnisZeile(label: "Geräte", wert: kalkulation.geraeteKosten, farbe: .purple)
                Divider()
                ergebnisZeile(label: "EP (EK)", wert: kalkulation.einheitspreisEK, farbe: .primary, bold: true)
                if jeKostenart {
                    // Aufschlag dort zeigen, wo er entsteht — sonst sieht man nicht,
                    // dass der Lohn den Löwenanteil trägt.
                    ergebnisZeile(label: "+ auf Lohn (\(Int(zLohn * 100))%)",
                                  wert: kalkulation.zuschlagLohn, farbe: .green)
                    ergebnisZeile(label: "+ auf Material (\(Int(zMaterial * 100))%)",
                                  wert: kalkulation.zuschlagMaterial, farbe: .blue)
                    ergebnisZeile(label: "+ auf Geräte (\(Int(zGeraet * 100))%)",
                                  wert: kalkulation.zuschlagGeraet, farbe: .purple)
                } else {
                    ergebnisZeile(label: "+ W&G (\(Int(wgProzent * 100))%)",
                                  wert: kalkulation.zuschlagWG, farbe: .orange)
                    ergebnisZeile(label: "+ BGK (\(Int(bgkProzent * 100))%)",
                                  wert: kalkulation.zuschlagBGK, farbe: .orange)
                }
                Divider()
                ergebnisZeile(label: "EP (VK)", wert: kalkulation.einheitspreisVK, farbe: .primary, bold: true)

                if kalkulation.stundenJeEinheit > 0 {
                    Divider()
                    stundenZeile
                }
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
        position.zuschlagEigen = eigen
        // Nur schreiben, wenn die Position bewusst abweicht. Sonst wuerden die
        // angezeigten Firmenwerte als eigene Werte festgeschrieben — und eine spaetere
        // Aenderung an den Firmenwerten wuerde diese Position stillschweigend uebergehen.
        if eigen {
            position.wagnisGewinnProzent = wgProzent
            position.bgkProzent = bgkProzent
            position.zuschlagJeKostenart = jeKostenart
            position.zuschlagLohnProzent = zLohn
            position.zuschlagMaterialProzent = zMaterial
            position.zuschlagGeraetProzent = zGeraet
        }
        try? viewContext.save()
    }

    /// Sichtbarer Papierkorb-Button pro Zeile (funktioniert am Mac, wo Swipe nicht greift).
    /// `.borderless` → der Tap trifft den Button, nicht die ganze Zeile.
    private func loeschButton(_ action: @escaping () -> Void) -> some View {
        Button(role: .destructive, action: action) {
            Image(systemName: "trash").font(.subheadline)
        }
        .buttonStyle(.borderless)
        .tint(.red)
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
