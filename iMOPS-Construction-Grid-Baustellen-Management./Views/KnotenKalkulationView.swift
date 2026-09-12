import SwiftUI
import CoreData

// MARK: - KnotenKalkulationView
//
// Der Weg vom Grap8-Knoten in die Kalkulation — die drei Drähte des Bogen-0-Auftrags:
//
//   Draht 1  Ein Knoten IST ein `Auftrag`. Der bekommt hier seine EIGENE `LVPosition`
//            (Relationship `Auftrag.lvPosition`, neu im Modell). Vorher hing die
//            Kalkulation nur am `Event` — „vom Auftrag aus führt kein Weg zur
//            LVPosition" (Grap8Graph.swift). Diese Ansicht schlägt genau diese Brücke.
//
//   Draht 2  Der Vorschlag ist VOM KNOTEN AUS auslösbar: der Knopf ruft
//            `MopsKalkulationsHelper.shared.aufwandswertVorschlag(leistung:)` mit dem
//            Knoten-Text (`Kausalkette.bezeichnung`, = `Auftrag.processingDetails`).
//
//   Draht 3  Das Ergebnis `(maurer, helfer)` landet als ZAHL in der Kalkulation, nicht
//            als Text: zwei `PositionLohn`-Einträge (Maurer/Helfer) mit `stunden`
//            (h je Einheit) × `stundenBruttoEK` (Lohnsatz aus den Stammdaten). Die
//            Kalkulation rechnet daraus selbst Maurer-h × Menge × Lohnsatz.
//
// Die Menge kommt vorerst von Hand (Hinweis im Auftrag). Alles Übrige — Zuschläge,
// Material, Geräte — bleibt der bestehenden Tiefenkalkulation überlassen, die von hier
// aus mit einem Tipp erreichbar ist. Katalog-Kompatibilität: Leistung (bezeichnung),
// Einheit und die Maurer/Helfer-Stunden liegen an EINEM Ort — der Position —, damit ein
// späterer Leistungskatalog sie als wiederverwendbaren Baustein aufgreifen kann.

struct KnotenKalkulationView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var auftrag: Auftrag

    // Menge von Hand — als Text, damit deutsches Komma sauber durchgeht.
    @State private var mengeText: String = "1"
    @State private var einheit: String = "psch"

    // Prof-Vorschlag
    @State private var isLoading = false
    @State private var vorschlag: (maurer: Double, helfer: Double)?
    @State private var meldung: String?
    @State private var uebernommen = false

    // Katalog-Treffer (Bogen 1): gibt es diese Leistung schon als Baustein?
    @State private var katalogTreffer: Leistungsbaustein?

    /// Der Knoten-Text — genau das Feld, das die Leinwand als Titel zeigt.
    private var leistung: String { Kausalkette.bezeichnung(auftrag) }

    var body: some View {
        Form {
            kopfSection
            positionSection
            if auftrag.lvPosition != nil {
                if let treffer = katalogTreffer {
                    katalogSection(treffer)
                }
                vorschlagSection
                if let pos = auftrag.lvPosition, pos.hatKalkulation {
                    kalkulationSection(pos)
                }
                weiterSection
            }
        }
        .navigationTitle("Knoten kalkulieren")
        .onAppear {
            if let pos = auftrag.lvPosition {
                mengeText = Self.zahl(pos.menge)
                einheit = pos.einheit ?? "psch"
            }
            katalogTrefferAktualisieren()
        }
    }

    /// Sucht den passenden Katalog-Baustein zu Leistung + aktueller Einheit.
    private func katalogTrefferAktualisieren() {
        katalogTreffer = LeistungskatalogService.finde(
            leistung: leistung, einheit: einheit, in: viewContext)
    }

    // MARK: - Kopf

    private var kopfSection: some View {
        Section {
            HStack(spacing: 12) {
                Text("🐶").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(leistung)
                        .font(.headline)
                    Text("Grap8-Knoten · KG \(auftrag.kostenGruppeNummer ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Position (Draht 1)

    @ViewBuilder
    private var positionSection: some View {
        if let pos = auftrag.lvPosition {
            Section {
                mengeFeld
                Text("Position angelegt — die Kalkulation dieses Knotens hängt jetzt an ihr.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Eigene LV-Position")
            } footer: {
                Text("Menge von Hand. Die Auto-Ableitung (Standort → Menge) ist ein späterer Bogen.")
            }
            .onChange(of: mengeText) { _, neu in
                pos.menge = Self.parse(neu) ?? pos.menge
            }
            .onChange(of: einheit) { _, neu in
                pos.einheit = neu.trimmingCharacters(in: .whitespaces)
                katalogTrefferAktualisieren()
            }
        } else {
            Section {
                mengeFeld
                Button {
                    positionAnlegen()
                } label: {
                    Label("Position anlegen", systemImage: "plus.rectangle.on.rectangle")
                }
                .tint(.orange)
            } header: {
                Text("Eigene LV-Position")
            } footer: {
                Text("Dieser Knoten hat noch keine Kalkulations-Position. Sie wird an der Baustelle „\(auftrag.event?.title ?? auftrag.event?.name ?? "—")“ angelegt und trägt den Knoten-Text.")
            }
        }
    }

    private var mengeFeld: some View {
        HStack {
            Text("Menge")
            Spacer()
            TextField("1", text: $mengeText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            TextField("Einheit", text: $einheit)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Aus dem Katalog (Bogen 1: nachschlagen statt neu ableiten)

    private func katalogSection(_ baustein: Leistungsbaustein) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Schon im Katalog:")
                    .font(.caption).foregroundStyle(.secondary)
                Text(baustein.aufwandAnzeige)
                    .font(.subheadline)
                if baustein.verwendungen > 0 {
                    Text("\(baustein.verwendungen)× verwendet")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Button {
                ausKatalogUebernehmen(baustein)
            } label: {
                Label(uebernommen ? "Übernommen" : "Aus Katalog übernehmen",
                      systemImage: uebernommen ? "checkmark.circle.fill" : "tray.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(uebernommen ? .green : .orange)
            .disabled(uebernommen)
        } header: {
            Text("Katalog")
        } footer: {
            Text("Diese Leistung wurde schon einmal abgeleitet. Übernehmen spart die Prof-Frage — Werte trotzdem prüfen.")
        }
    }

    // MARK: - Aufwandswert-Vorschlag (Draht 2 + 3)

    private var vorschlagSection: some View {
        Section {
            Button {
                vorschlagHolen()
            } label: {
                if isLoading {
                    HStack { ProgressView(); Text("Prof rechnet …") }
                } else {
                    Label("Aufwandswert vom Prof holen", systemImage: "questionmark.bubble")
                }
            }
            .tint(.orange)
            .disabled(isLoading)

            if let v = vorschlag {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vorschlag (REFA), h je \(auftrag.lvPosition?.einheit ?? "Einheit"):")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("• Maurer: \(Self.zahl(v.maurer)) h")
                    Text("• Helfer: \(Self.zahl(v.helfer)) h")
                }
                .font(.subheadline)

                Button {
                    inKalkulationUebernehmen(v)
                } label: {
                    Label(uebernommen ? "In Kalkulation übernommen" : "In Kalkulation übernehmen",
                          systemImage: uebernommen ? "checkmark.circle.fill" : "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(uebernommen ? .green : .orange)
                .disabled(uebernommen)
            }

            if let m = meldung {
                Text(m).font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("Aufwandswert")
        } footer: {
            Text("Der Vorschlag ist ein Richtwert vom Prof — du entscheidest. Er wird als Lohnstunden gespeichert (× Menge × Lohnsatz), nicht als Text.")
        }
    }

    // MARK: - Kalkulation sichtbar (der Nachweis: Zahl, nicht Text)

    private func kalkulationSection(_ pos: LVPosition) -> some View {
        let menge = pos.effektiveMenge
        let lohnSummeJeEinheit = pos.lohnArray.reduce(0) { $0 + $1.kostenProEinheit }
        let lohnGesamt = lohnSummeJeEinheit * menge
        return Section {
            ForEach(pos.lohnArray, id: \.objectID) { pl in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pl.qualifikation ?? "–").font(.subheadline)
                        Text("\(Self.zahl(pl.stunden)) h/E × \(pl.stundenBruttoEK.formatted(.currency(code: "EUR")))/h")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(pl.kostenProEinheit.formatted(.currency(code: "EUR")))
                        .font(.subheadline)
                }
            }
            HStack {
                Text("Lohn gesamt (× \(Self.zahl(menge)) \(pos.einheit ?? "E"))").bold()
                Spacer()
                Text(lohnGesamt.formatted(.currency(code: "EUR"))).bold()
            }
            .foregroundStyle(.green)
        } header: {
            Text("Lohn in der Kalkulation")
        }
    }

    // MARK: - Weiter in die Tiefe / zur Baustelle

    private var weiterSection: some View {
        Section {
            if let pos = auftrag.lvPosition {
                NavigationLink {
                    LVTiefenkalkulationView(position: pos)
                } label: {
                    Label("Tiefenkalkulation öffnen", systemImage: "function")
                }
            }
            if let event = auftrag.event {
                NavigationLink {
                    LVKalkulationView(event: event)
                } label: {
                    Label("Ganze Baustelle", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .tint(.orange)
    }

    // MARK: - Aktionen

    /// Draht 1: die eigene Position anlegen und mit dem Knoten verdrahten.
    private func positionAnlegen() {
        guard auftrag.lvPosition == nil else { return }
        let pos = LVPosition(context: viewContext)
        pos.bezeichnung = leistung
        pos.menge = Self.parse(mengeText) ?? 1
        pos.einheit = einheit.trimmingCharacters(in: .whitespaces)
        pos.mengenQuelle = .manuell
        // Die Kostengruppe des Knotens mitnehmen — die DIN-276-KG steht schon am Auftrag.
        pos.kostenGruppeNummer = auftrag.kostenGruppeNummer
        pos.event = auftrag.event      // Position lebt an der Baustelle wie jede andere
        auftrag.lvPosition = pos       // … und ist zugleich die des Knotens
        speichern()
        katalogTrefferAktualisieren()  // gibt's die Leistung schon im Katalog?
    }

    /// Draht 2: den Prof mit dem Knoten-Text fragen.
    private func vorschlagHolen() {
        isLoading = true
        meldung = nil
        vorschlag = nil
        uebernommen = false
        let text = leistung
        Task {
            let wert = await MopsKalkulationsHelper.shared.aufwandswertVorschlag(leistung: text)
            await MainActor.run {
                isLoading = false
                if let wert {
                    vorschlag = wert
                } else {
                    // Ehrlichkeit: kein Wert erfunden.
                    meldung = "Kein verlässlicher Aufwandswert erhalten (Mops offline oder keine klare Antwort). Nichts eingetragen."
                }
            }
        }
    }

    /// Draht 3: die Stunden als PositionLohn schreiben (Maurer + Helfer).
    /// Zugleich ERNTEN (Bogen 1): die Leistung wandert in den Katalog — einmal fragen,
    /// für immer picken.
    private func inKalkulationUebernehmen(_ v: (maurer: Double, helfer: Double)) {
        guard let pos = auftrag.lvPosition else { return }
        stundenSchreiben(maurer: v.maurer, helfer: v.helfer, in: pos)
        LeistungskatalogService.merke(
            leistung: leistung,
            einheit: pos.einheit ?? "",
            maurer: v.maurer, helfer: v.helfer,
            kostenGruppeNummer: auftrag.kostenGruppeNummer,
            quelle: "prof",
            in: viewContext)
        speichern()
        katalogTrefferAktualisieren()
        uebernommen = true
    }

    /// Bogen 1: den Aufwandswert aus einem bestehenden Katalog-Baustein übernehmen,
    /// ohne den Prof zu fragen. Der Baustein zählt eine Verwendung.
    private func ausKatalogUebernehmen(_ baustein: Leistungsbaustein) {
        guard let pos = auftrag.lvPosition else { return }
        stundenSchreiben(maurer: baustein.maurerStunden, helfer: baustein.helferStunden, in: pos)
        LeistungskatalogService.benutzt(baustein)
        speichern()
        uebernommen = true
    }

    /// Die beiden Lohnzeilen (Maurer/Helfer) schreiben — über den gemeinsamen Service, damit
    /// Knoten und Katalog-Picker (`LVBausteinAuswahlView`) exakt dieselbe Logik nutzen.
    /// Idempotent: ein früherer Vorschlag wird ersetzt, nicht gestapelt.
    private func stundenSchreiben(maurer: Double, helfer: Double, in pos: LVPosition) {
        LeistungskatalogService.schreibeAufwandAlsLohn(
            maurer: maurer, helfer: helfer, auf: pos, in: viewContext)
    }

    private func speichern() {
        do { try viewContext.save() }
        catch { meldung = "Konnte nicht speichern: \(error.localizedDescription)" }
    }

    // MARK: - Zahl-Helfer (deutsches Komma)

    private static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private static func zahl(_ d: Double) -> String {
        d.formatted(.number.precision(.fractionLength(0...2)))
    }
}
