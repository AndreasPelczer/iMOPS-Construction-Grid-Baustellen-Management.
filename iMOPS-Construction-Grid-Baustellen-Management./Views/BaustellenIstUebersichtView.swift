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
    @StateObject private var store = AngebotsStore.shared
    @State private var reiter: Reiter = .kosten

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
            ForEach(titelGruppen) { g in
                let gesamt = g.positionen.count
                let gemessen = g.positionen.filter { !$0.istGeschaetzt }.count
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(gruppenTitel(g)).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(gemessen)/\(gesamt) gemessen")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(gemessen), total: Double(max(gesamt, 1))).tint(.orange)
                }
            }
        } header: { Text("Gewerke-Fortschritt (gemessen vs. geschätzt)") }
        footer: {
            Text("Gemessen = belastbare Menge (Aufmaß), geschätzt = Planwert. Detaillierte Termin-Planung pro Phase folgt später.")
                .font(.caption)
        }
    }

    // MARK: - Formatierung

    private func euro(_ v: Double) -> String { v.formatted(.currency(code: "EUR")) }
    private func menge(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(0...2))) }
    private func gruppenTitel(_ g: TitelGruppe) -> String {
        g.hinweis.isEmpty ? g.titel : "\(g.titel) · \(g.hinweis)"
    }
}
