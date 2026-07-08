import SwiftUI
import CoreData

/// Ist-Übersicht der echten Baustelle (Weg B, Spec §4/§8).
/// Baut die Übersicht aus den importierten LV-Daten am `Event` — nicht aus der
/// Planer-Schätzung (das ist die „Soll-Übersicht"). MVP-Reiter: Kosten / Massen /
/// Material. Zeitplan folgt später (Spec §5).
///
/// Achsen (Code-verifiziert, Spec §9.1):
/// - Kosten  → DIN-276-Kostengruppe (`kostenGruppeNummer`)
/// - Massen  → posNr-Titel-Präfix (führende Ziffer, provider-unabhängig; kein `gewerk`-Feld)
/// - Material→ Positionen mit Artikel-Nr./Lieferant (bei Statik-/Bestell-Import gefüllt)
struct BaustellenIstUebersichtView: View {
    let event: Event
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var store = AngebotsStore.shared
    @State private var reiter: Reiter = .kosten
    @State private var bauphasen: [IstBauphase] = []
    @State private var phaseImEditor: IstBauphase?
    @State private var editorIstNeu = false

    enum Reiter: String, CaseIterable, Identifiable {
        case kosten = "Kosten", massen = "Massen", material = "Material", zeitplan = "Zeitplan"
        var id: String { rawValue }
    }

    // MARK: - Daten

    private var positionen: [LVPosition] {
        (event.lvPositionen?.allObjects as? [LVPosition] ?? [])
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
    }

    private var herkunft: ImportHerkunft? { EventExtrasPayload.laden(aus: event).importHerkunft }

    // Kosten nach DIN-276-KG
    private struct KGZeile: Identifiable {
        let id: String, kg: String, label: String
        let anzahl: Int
        let netto: Double
    }
    private var kgZeilen: [KGZeile] {
        let grouped = Dictionary(grouping: positionen, by: { $0.kostenGruppeNummer ?? "—" })
        var zeilen: [KGZeile] = []
        for (kg, items) in grouped {
            var netto = 0.0
            for p in items {
                netto += LVKalkulator.effektiverEP(for: p, store: store) * p.menge
            }
            let label = DIN276KostenGruppe.alle.first { $0.nummer == kg }?.bezeichnung ?? "Kostengruppe \(kg)"
            zeilen.append(KGZeile(id: kg, kg: kg, label: label, anzahl: items.count, netto: netto))
        }
        return zeilen.sorted { $0.kg < $1.kg }
    }
    private var gesamtNetto: Double { kgZeilen.reduce(0) { $0 + $1.netto } }
    private var mwst: Double { gesamtNetto * FirmenSettings.mwstSatz / 100 }
    private var gesamtBrutto: Double { gesamtNetto + mwst }

    // Massen nach posNr-Titel-Präfix (robust: split auf ".", nicht literal [:2])
    private struct TitelGruppe: Identifiable {
        let id: String, titel: String, hinweis: String
        let positionen: [LVPosition]
    }
    private func titelPraefix(_ p: LVPosition) -> String {
        guard let first = p.posNr?.split(separator: ".").first else { return "—" }
        return String(first)
    }
    private var titelGruppen: [TitelGruppe] {
        let grouped = Dictionary(grouping: positionen, by: { titelPraefix($0) })
        var gruppen: [TitelGruppe] = []
        for (t, items) in grouped {
            let sorted = items.sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
            gruppen.append(TitelGruppe(id: t, titel: "Titel \(t)",
                                       hinweis: sorted.first?.bezeichnung ?? "", positionen: sorted))
        }
        return gruppen.sorted { $0.id < $1.id }
    }

    // Material: Positionen mit Artikel-Nr. oder Lieferant
    private var materialPositionen: [LVPosition] {
        positionen.filter { ($0.artikelNummer?.isEmpty == false) || ($0.lieferant?.isEmpty == false) }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            kopf
                .padding()
                .background(Color(.secondarySystemBackground))
            Picker("Reiter", selection: $reiter) {
                ForEach(Reiter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.vertical, 8)

            if positionen.isEmpty {
                leerHinweis
            } else {
                List {
                    switch reiter {
                    case .kosten:   kostenReiter
                    case .massen:   massenReiter
                    case .material: materialReiter
                    case .zeitplan: zeitplanReiter
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Ist-Übersicht")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bauphasen = (EventExtrasPayload.laden(aus: event).bauphasen ?? [])
                .sorted { $0.start < $1.start }
        }
        .sheet(item: $phaseImEditor) { p in
            BauphaseEditorView(
                phase: p, istNeu: editorIstNeu,
                onSave: uebernehmen,
                onDelete: editorIstNeu ? nil : { loeschen(p) }
            )
        }
    }

    // MARK: - Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(event.title ?? "Baustelle").font(.title3.bold())
            if let h = herkunft {
                HStack(spacing: 8) {
                    if let p = h.projekt, !p.isEmpty { chip("Projekt", p) }
                    if let b = h.baustelle, !b.isEmpty { chip("Baustelle", b) }
                }
                if let d = h.datei, !d.isEmpty {
                    Label(d, systemImage: "doc").font(.caption).foregroundStyle(.secondary)
                }
            }
            // Bonus: Kern-Fakten aus den gespeicherten Unterlagen-Auswertungen
            if !unterlagenFakten.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(unterlagenFakten, id: \.self) { faktChip($0) }
                    }
                }
            }
            HStack(spacing: 18) {
                kpi("\(positionen.count)", "Positionen")
                kpi(euro(gesamtNetto), "Netto")
                kpi(euro(gesamtBrutto), "Brutto")
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kpi(_ wert: String, _ titel: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(wert).font(.headline.monospacedDigit())
            Text(titel).font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func chip(_ k: String, _ v: String) -> some View {
        HStack(spacing: 4) {
            Text(k).font(.caption2).foregroundStyle(.secondary)
            Text(v).font(.caption).bold()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }

    private func faktChip(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.text.magnifyingglass").font(.caption2)
            Text(text).font(.caption).bold()
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.orange.opacity(0.12))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
    }

    /// 2–4 Kern-Fakten aus den gespeicherten `/extract-doc`-Auswertungen (Bonus im Kopf).
    /// Fehlt Doctype/Feld → Fakt weglassen (nie „—" zeigen). Feldnamen = Backend-Schema
    /// (`api/services/doc_extract.py`): bodenklassen[] · wohnflaeche_gesamt_m2 · zone/grz · medien[].
    private var unterlagenFakten: [String] {
        let auswertungen = EventExtrasPayload.laden(aus: event).auswertungen ?? []
        var fakten: [String] = []
        for a in auswertungen {
            let f = a.ergebnis.felder
            switch a.ergebnis.doctypeErkannt {
            case "bodengutachten":
                if let bkl = f["bodenklassen"]?.erstesArrayElement?.skalarText, bkl != "—" {
                    fakten.append("Bodenklasse: \(bkl)")
                }
            case "wohnflaeche":
                if let wf = f["wohnflaeche_gesamt_m2"]?.skalarText, wf != "—" {
                    fakten.append("Wohnfläche: \(wf) m²")
                }
            case "bebauungsplan":
                var teile: [String] = []
                if let z = f["zone"]?.skalarText, z != "—" { teile.append("Zone \(z)") }
                if let g = f["grz"]?.skalarText, g != "—" { teile.append("GRZ \(g)") }
                if !teile.isEmpty { fakten.append(teile.joined(separator: " · ")) }
            case "erschliessung":
                if let n = f["medien"]?.arrayAnzahl, n > 0 {
                    fakten.append("Erschließung: \(n) Medien")
                }
            default:
                break
            }
        }
        return Array(fakten.prefix(4))
    }

    private var leerHinweis: some View {
        ContentUnavailableView("Noch keine LV-Positionen",
                               systemImage: "tray",
                               description: Text("Importiere ein LV (PDF oder JSON), dann erscheint hier die Ist-Übersicht."))
    }

    // MARK: - Reiter Kosten

    @ViewBuilder private var kostenReiter: some View {
        Section {
            ForEach(kgZeilen) { z in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KG \(z.kg) · \(z.label)").font(.subheadline)
                        Text("\(z.anzahl) Position\(z.anzahl == 1 ? "" : "en")").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(euro(z.netto)).font(.subheadline.monospacedDigit())
                }
            }
        } header: { Text("Nach DIN-276-Kostengruppe") }
        footer: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Netto \(euro(gesamtNetto)) · MwSt \(euro(mwst)) · Brutto \(euro(gesamtBrutto))")
                Text("Preise aus dem Angebots-/Kalkulationsstand; 0 € = noch kein Preis hinterlegt.")
            }.font(.caption)
        }
    }

    // MARK: - Reiter Massen

    @ViewBuilder private var massenReiter: some View {
        ForEach(titelGruppen) { g in
            Section {
                ForEach(g.positionen, id: \.objectID) { p in
                    HStack(alignment: .top) {
                        Text(p.posNr ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.bezeichnung ?? "—").font(.subheadline).lineLimit(2)
                            HStack(spacing: 6) {
                                Text("\(menge(p.menge)) \(p.einheit ?? "")").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                if p.istGeschaetzt {
                                    Text("geschätzt").font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.yellow.opacity(0.25)).clipShape(Capsule())
                                }
                            }
                        }
                    }
                }
            } header: {
                Text(gruppenTitel(g)).lineLimit(1)
            }
        }
    }

    // MARK: - Reiter Material

    @ViewBuilder private var materialReiter: some View {
        if materialPositionen.isEmpty {
            Section {
                Text("Keine Materialangaben in diesem LV.\nArtikel-Nr./Lieferant werden bei Statik-/Bestell-Import gefüllt (Xella-Mat-Nr aus dem abZ-Resolver), nicht bei reinen Vision/JSON-LVs.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } else {
            Section {
                ForEach(materialPositionen, id: \.objectID) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.bezeichnung ?? "—").font(.subheadline)
                        HStack(spacing: 8) {
                            if let a = p.artikelNummer, !a.isEmpty {
                                Label(a, systemImage: "number").font(.caption).foregroundStyle(.secondary)
                            }
                            if let l = p.lieferant, !l.isEmpty {
                                Label(l, systemImage: "shippingbox").font(.caption).foregroundStyle(.secondary)
                            }
                            Text("\(menge(p.menge)) \(p.einheit ?? "")").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: { Text("Positionen mit Material (Artikel-Nr./Lieferant)") }
        }
    }

    // MARK: - Reiter Zeitplan

    @ViewBuilder private var zeitplanReiter: some View {
        Section {
            EventTimelineBar(event: event).padding(.vertical, 4)
            if let s = event.eventStartTime {
                LabeledContent("Start", value: s.formatted(date: .abbreviated, time: .omitted))
            }
            if let e = event.eventEndTime {
                LabeledContent("Ende", value: e.formatted(date: .abbreviated, time: .omitted))
            }
            if event.eventStartTime == nil && event.eventEndTime == nil {
                Text("Bauzeitraum noch nicht gesetzt — über Bearbeiten pflegen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("Bauzeitraum") }

        Section {
            Button {
                editorIstNeu = true
                phaseImEditor = neueBauphase()
            } label: {
                Label("Bauphase anlegen", systemImage: "plus.circle.fill")
            }
            if bauphasen.isEmpty {
                Text("Noch keine Bauphasen geplant. Lege Phasen mit Start/Ende an — sie erscheinen hier als Terminplan.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                if let span = zeitSpanne {
                    HStack {
                        Text(span.start.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(span.ende.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(bauphasen) { p in
                    Button {
                        editorIstNeu = false
                        phaseImEditor = p
                    } label: {
                        if let span = zeitSpanne { ganttZeile(p, span: span) }
                        else { bauphaseZeile(p) }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in idx.map { bauphasen[$0] }.forEach(loeschen) }
            }
        } header: { Text("Bauphasen (Terminplan)") }
        footer: {
            Text("Balken je Phase über der Bauzeit; Farbe = Status (grün erledigt, orange laufend, hell geplant), rote Linie = heute. Antippen = bearbeiten, Wischen = löschen.")
                .font(.caption)
        }
    }

    private func bauphaseZeile(_ p: IstBauphase) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(p.name).font(.subheadline)
                if let g = p.gewerk, !g.isEmpty {
                    Text(g).font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color(.tertiarySystemBackground)).clipShape(Capsule())
                }
                Spacer()
                Text("\(p.start.formatted(date: .abbreviated, time: .omitted)) – \(p.ende.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: phaseFortschritt(p)).tint(.orange)
        }
    }

    /// Zeitfenster für den Mini-Gantt: Vereinigung aus Bauzeitraum und allen Phasen.
    private var zeitSpanne: (start: Date, ende: Date)? {
        var starts = bauphasen.map { $0.start }
        var enden = bauphasen.map { $0.ende }
        if let s = event.eventStartTime { starts.append(s) }
        if let e = event.eventEndTime { enden.append(e) }
        guard let minS = starts.min(), let maxE = enden.max(), maxE > minS else { return nil }
        return (minS, maxE)
    }

    /// Eine Phase als Gantt-Balken über dem gemeinsamen Zeitfenster (Farbe = Status,
    /// rote Linie = heute). Antippen (auf der Zeile) bearbeitet die Phase.
    private func ganttZeile(_ p: IstBauphase, span: (start: Date, ende: Date)) -> some View {
        let total = span.ende.timeIntervalSince(span.start)
        let offset = max(0, p.start.timeIntervalSince(span.start)) / total
        let dauer  = max(0, p.ende.timeIntervalSince(p.start)) / total
        let heute  = min(max(Date().timeIntervalSince(span.start) / total, 0), 1)
        let farbe: Color = p.ende < Date() ? .green
                         : (p.start <= Date() ? .orange : Color.orange.opacity(0.45))
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(p.name).font(.subheadline)
                if let g = p.gewerk, !g.isEmpty {
                    Text(g).font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color(.tertiarySystemBackground)).clipShape(Capsule())
                }
                Spacer()
                Text("\(p.start.formatted(.dateTime.day().month())) – \(p.ende.formatted(.dateTime.day().month()))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5)).frame(height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(farbe)
                        .frame(width: max(4, w * dauer), height: 12)
                        .offset(x: w * offset)
                    Rectangle().fill(Color.red.opacity(0.75))
                        .frame(width: 1.5, height: 16)
                        .offset(x: w * heute - 0.75)
                }
            }
            .frame(height: 16)
        }
    }

    // MARK: - Bauphasen-Logik

    private func neueBauphase() -> IstBauphase {
        let start = event.eventStartTime ?? Date()
        return IstBauphase(name: "", start: start, ende: start)
    }
    private func phaseFortschritt(_ p: IstBauphase) -> Double {
        let jetzt = Date()
        if jetzt <= p.start { return 0 }
        if jetzt >= p.ende { return 1 }
        let gesamt = p.ende.timeIntervalSince(p.start)
        return gesamt > 0 ? jetzt.timeIntervalSince(p.start) / gesamt : 1
    }
    private func uebernehmen(_ p: IstBauphase) {
        if let i = bauphasen.firstIndex(where: { $0.id == p.id }) {
            bauphasen[i] = p
        } else {
            bauphasen.append(p)
        }
        speicherePhasen()
    }
    private func loeschen(_ p: IstBauphase) {
        bauphasen.removeAll { $0.id == p.id }
        speicherePhasen()
    }
    private func speicherePhasen() {
        bauphasen.sort { $0.start < $1.start }
        var extras = EventExtrasPayload.laden(aus: event)
        extras.bauphasen = bauphasen
        extras.speichern(in: event)
        try? viewContext.save()
    }

    // MARK: - Formatierung

    private func euro(_ v: Double) -> String { v.formatted(.currency(code: "EUR")) }
    private func menge(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...2))) }
    private func gruppenTitel(_ g: TitelGruppe) -> String {
        g.hinweis.isEmpty ? g.titel : "\(g.titel) · \(g.hinweis)"
    }
}
