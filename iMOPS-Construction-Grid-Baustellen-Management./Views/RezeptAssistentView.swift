import SwiftUI
import CoreData

// MARK: - RezeptAssistentView  („Rezept mit dem Mops")
//
// Geführt, Schritt für Schritt, in Küchensprache: der Mops SCHLÄGT VOR, du bestätigst oder
// korrigierst. Aus einer roten/gelben Position entsteht so ein Rezept (Aufwandswert +
// Material + Gerät), das der Katalog lernt — die nächste gleiche Position wird von allein grün.
//
// Ehrlich markiert: Vorschläge sind „Schätzung", bis du sie bestätigst/änderst. Kein Wert
// wird erfunden — der Zeit-Vorschlag kommt vom Prof (offline: dein Erfahrungswert), die
// Material-Preise zentral aus den Stammdaten.
struct RezeptAssistentView: View {

    let position: LVPosition
    var onFertig: () -> Void = {}

    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var schritt = 1
    @State private var maurer = 0.0
    @State private var helfer = 0.0
    @State private var vorschlagMaurer = 0.0
    @State private var vorschlagHelfer = 0.0
    @State private var vorschlagStatus = "Ich frage kurz den Prof …"
    @State private var zutaten: [Zutat] = []
    @State private var geraetWahl: Geraet?          // aus dem Maschinenpark (Stammdaten)
    @State private var geraetStunden = 0.0
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)])
    private var geraetePark: FetchedResults<Geraet>

    struct Zutat: Identifiable { let id = UUID(); var name = ""; var menge = 0.0; var einheit = ""; var verschnitt = 5.0 }

    private var leistung: String { position.bezeichnung ?? "" }
    private var einheit: String { let e = position.einheit ?? ""; return e.isEmpty ? "Einheit" : e }

    var body: some View {
        NavigationStack {
            Form {
                switch schritt {
                case 1:  schrittZeit
                case 2:  schrittMaterial
                case 3:  schrittGeraet
                default: schrittFertig
                }
            }
            .navigationTitle("🐕 Rezept mit dem Mops")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .principal) {
                    Text("Schritt \(schritt)/4").font(.caption).foregroundStyle(.secondary)
                }
            }
            .task { await ladeVorschlag() }
        }
    }

    // MARK: Schritt 1 — Die Zeit
    @ViewBuilder private var schrittZeit: some View {
        Section {
            Text(leistung).font(.headline)
            Text("je \(einheit) · Lass uns das Rezept zusammen kochen.")
                .font(.caption).foregroundStyle(.secondary)
        }
        Section("⏱ Die Zeit — wie lange braucht der Maurer für 1 \(einheit)?") {
            stundenZeile("Maurer", $maurer)
            stundenZeile("Helfer", $helfer)
            Text(vorschlagStatus).font(.caption).foregroundStyle(.orange)
        }
        Section {
            Button("Passt so – weiter") { schritt = 2 }.frame(maxWidth: .infinity)
        }
    }

    // MARK: Schritt 2 — Die Zutaten (Material)
    @ViewBuilder private var schrittMaterial: some View {
        Section("🧱 Die Zutaten — was steckt in 1 \(einheit)?") {
            ForEach($zutaten) { $z in
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Material (z. B. Beton C25/30)", text: $z.name)
                    HStack {
                        TextField("Menge", value: $z.menge, format: .number)
                            .frame(width: 70).multilineTextAlignment(.trailing)
                        TextField("Einheit", text: $z.einheit).frame(width: 60)
                        Spacer()
                        Text(preisHinweis(z.name)).font(.caption).foregroundStyle(preisFarbe(z.name))
                    }
                    #if !os(macOS)
                    .keyboardType(.decimalPad)
                    #endif
                }
            }
            .onDelete { zutaten.remove(atOffsets: $0) }
            Button {
                zutaten.append(Zutat(einheit: ""))
            } label: { Label("Zutat hinzufügen", systemImage: "plus") }
        }
        Section {
            Button("Weiter") { schritt = 3 }.frame(maxWidth: .infinity)
            Button("Ohne Material – überspringen") { zutaten = []; schritt = 3 }
                .frame(maxWidth: .infinity).foregroundStyle(.secondary)
        }
    }

    // MARK: Schritt 3 — Das Werkzeug (Maschine aus dem Park)
    @ViewBuilder private var schrittGeraet: some View {
        Section("🔧 Das Werkzeug — welche Maschine aus deinem Park?") {
            if geraetePark.isEmpty {
                Text("Noch keine Maschinen in den Stammdaten. Leg deinen Maschinenpark unter „Stammdaten“ an — Satz (€/h) inklusive — dann kannst du hier auswählen.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Maschine", selection: $geraetWahl) {
                    Text("Keine").tag(Optional<Geraet>.none)
                    ForEach(geraetePark, id: \.self) { g in
                        Text("\(g.name ?? "Gerät") · \(euro(g.kostenProStunde))/h").tag(Optional(g))
                    }
                }
                if geraetWahl != nil {
                    HStack {
                        Text("Zeit je \(einheit)")
                        Spacer()
                        TextField("Std", value: $geraetStunden, format: .number)
                            .frame(width: 80).multilineTextAlignment(.trailing)
                            #if !os(macOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text("h").foregroundStyle(.secondary)
                    }
                }
            }
        }
        Section {
            Button("Weiter") { schritt = 4 }.frame(maxWidth: .infinity)
        }
    }

    // MARK: Schritt 4 — Fertig
    @ViewBuilder private var schrittFertig: some View {
        Section(leistung) {
            zeile("⏱ Arbeit", "\(fmtH(maurer)) + \(fmtH(helfer)) h", lohnEK)
            if materialEK > 0 { zeile("🧱 Material", "\(zutaten.count) Zutat\(zutaten.count == 1 ? "" : "en")", materialEK) }
            if geraetEK > 0 { zeile("🔧 Gerät", geraetWahl?.name ?? "", geraetEK) }
        }
        Section {
            HStack {
                Text("Selbstkosten je \(einheit)").font(.subheadline.weight(.semibold))
                Spacer()
                Text(euro(ekGesamt)).font(.headline.monospacedDigit())
            }
            if position.menge > 0 {
                Text("× \(fmtH(position.menge)) \(einheit) = \(euro(ekGesamt * position.menge))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("Der Firmenzuschlag (Gewinn) kommt im Verkaufspreis oben drauf — den zeigt „Mops fass\".")
                .font(.caption2).foregroundStyle(.secondary)
        }
        Section {
            Text(maurer == vorschlagMaurer && helfer == vorschlagHelfer
                 ? "ℹ️ Die Zeit ist ein Vorschlag (Schätzung), bis du ihn änderst."
                 : "✓ Die Zeit hast du selbst gesetzt (Erfahrung).")
                .font(.caption).foregroundStyle(.secondary)
            Button("Rezept speichern & merken") { speichern() }
                .frame(maxWidth: .infinity).fontWeight(.semibold).tint(.orange)
        }
    }

    // MARK: - Bausteine
    private func stundenZeile(_ titel: String, _ wert: Binding<Double>) -> some View {
        HStack {
            Text(titel)
            Spacer()
            TextField("h", value: wert, format: .number)
                .frame(width: 80).multilineTextAlignment(.trailing)
                #if !os(macOS)
                .keyboardType(.decimalPad)
                #endif
            Text("h").foregroundStyle(.secondary)
        }
    }
    private func zeile(_ titel: String, _ detail: String, _ betrag: Double) -> some View {
        HStack {
            Text(titel); Text(detail).font(.caption).foregroundStyle(.secondary)
            Spacer(); Text(euro(betrag)).monospacedDigit()
        }
    }

    private func ladeVorschlag() async {
        let helper = MopsKalkulationsHelper.shared
        if let v = await helper.aufwandswertVorschlag(leistung: leistung) {
            maurer = v.maurer; helfer = v.helfer
            vorschlagMaurer = v.maurer; vorschlagHelfer = v.helfer
            vorschlagStatus = "🟡 Vorschlag vom Prof (Schätzung) — passt das, oder ändern?"
        } else {
            vorschlagStatus = "Kein Prof-Vorschlag (offline) — trag Raphis Erfahrungswert ein."
        }
    }

    private func preisHinweis(_ name: String) -> String {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        if let p = LeistungskatalogService.materialPreis(fuer: name, in: ctx) { return "\(euro(p)) ✓" }
        return "Preis fehlt"
    }
    private func preisFarbe(_ name: String) -> Color {
        LeistungskatalogService.materialPreis(fuer: name, in: ctx) == nil ? .red : .green
    }

    private var lohnEK: Double {
        maurer * LeistungskatalogService.bruttoEK(fuer: "Maurer", in: ctx)
        + helfer * LeistungskatalogService.bruttoEK(fuer: "Helfer", in: ctx)
    }
    private var materialEK: Double {
        zutaten.reduce(0) { $0 + $1.menge * (LeistungskatalogService.materialPreis(fuer: $1.name, in: ctx) ?? 0) * (1 + $1.verschnitt / 100) }
    }
    private var geraetEK: Double {
        guard let g = geraetWahl else { return 0 }
        return g.kostenProStunde * geraetStunden
    }
    private var ekGesamt: Double { lohnEK + materialEK + geraetEK }

    private func speichern() {
        let quelle = (maurer != vorschlagMaurer || helfer != vorschlagHelfer) ? "erfahrung" : "schätzung"
        let mat = zutaten.map {
            LeistungskatalogService.RezeptMaterial(
                name: $0.name, menge: $0.menge, verschnitt: $0.verschnitt,
                einheit: $0.einheit.isEmpty ? (position.einheit ?? "") : $0.einheit)
        }
        let ger: [LeistungskatalogService.RezeptGeraet]
        if let g = geraetWahl {
            ger = [LeistungskatalogService.RezeptGeraet(name: g.name ?? "", stunden: geraetStunden, satz: g.kostenProStunde)]
        } else {
            ger = []
        }
        LeistungskatalogService.speichereRezept(auf: position, maurer: maurer, helfer: helfer,
                                                material: mat, geraet: ger, quelle: quelle, in: ctx)
        try? ctx.save()
        onFertig(); dismiss()
    }

    private func euro(_ d: Double) -> String { String(format: "%.2f €", d) }
    private func fmtH(_ d: Double) -> String { String(format: "%g", d) }
}
