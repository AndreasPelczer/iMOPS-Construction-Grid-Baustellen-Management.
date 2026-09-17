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
    @State private var vorschlagStatus = "Ich schau kurz nach …"
    @State private var richtwert: AufwandsTreffer?   // lokaler Katalog-Treffer (echte Kolonne, Quelle)
    @State private var maschinenVorschlaege: [Maschine] = []   // passende Geräte zum Richtwert
    @State private var zutaten: [Zutat] = []
    @State private var marktpreise: [UUID: Double] = [:]   // Zutat.id → KI-Marktpreis (Orientierung)
    @State private var marktLaden: Set<UUID> = []
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
            if let lt = position.langtext?.trimmingCharacters(in: .whitespacesAndNewlines),
               !lt.isEmpty, lt != leistung {
                Text(lt).font(.caption)   // der VOLLE Auftrag: Tiefe, Boden, Verbau, Umfang
            }
            Text("LV-Eintrag: \(fmtH(position.menge)) \(einheit) · braucht Arbeit, Maschine und Material.")
                .font(.caption).foregroundStyle(.secondary)
        }
        if let t = richtwert { richtwertKarte(t) }
        Section("⏱ Die Zeit — Arbeitsstunden je 1 \(einheit)") {
            stundenZeile("Maurer", $maurer)
            stundenZeile("Helfer", $helfer)
            if maurer > 0 || helfer > 0 {
                Text(zeitBriefing).font(.footnote)
            }
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
                    }
                    #if !os(macOS)
                    .keyboardType(.decimalPad)
                    #endif
                    materialInfo(z)
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
        if !maschinenVorschlaege.isEmpty { maschinenVorschlagBlock }
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

    /// Der lokale Richtwert als GELB-Karte: echte Kolonne (richtige Rollen), Spanne, Quelle.
    /// Die Zahl unten (Maurer/Helfer) ist der übernommene Startwert zum Aufteilen — Raffi korrigiert.
    @ViewBuilder private func richtwertKarte(_ t: AufwandsTreffer) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("🟡 Richtwert · \(t.bezeichnung)").font(.subheadline.weight(.semibold))
                Text("\(fmtH(t.mittel)) h/\(t.einheit)  ·  Spanne \(fmtH(t.min))–\(fmtH(t.max))")
                    .font(.callout.monospacedDigit())
                if !t.kolonne.isEmpty {
                    Text("👷 Mannschaft: \(t.kolonne)").font(.caption)
                }
                if let h = t.hinweis, !h.isEmpty {
                    Text(h).font(.caption2).foregroundStyle(.secondary)
                }
                Text("Quelle: \(t.quelleKurz) · öffentlicher Richtwert, keine ARH-Tabelle. Deine Zahl unten zählt.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// Passende Maschinen aus dem Katalog (verzahnt über die Tätigkeit).
    /// Informativ + GELB: eigene Maschine im Park hat Vorrang, Mietpreise sind Richtwerte ±20%.
    @ViewBuilder private var maschinenVorschlagBlock: some View {
        Section("🚜 Passende Maschinen (Katalog-Vorschlag)") {
            ForEach(maschinenVorschlaege.prefix(4)) { m in
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.bezeichnung).font(.subheadline.weight(.medium))
                    HStack(spacing: 10) {
                        if let l = m.hauptLeistung {
                            Text("\(fmtH(l.wert)) \(l.einheit)").font(.caption.monospacedDigit())
                        }
                        if let tag = m.mieteTag {
                            Text("Miete ~\(euro(tag))/Tag").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let d = dauerText(m) {
                        Text(d).font(.caption2).foregroundStyle(.orange)
                    }
                    if let s = m.brauchtSchein, !s.isEmpty {
                        Text("Schein: \(s)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Richtwerte (regional ±20%). Eigene Maschine aus deinem Park hat Vorrang.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// Dauer + Mietkosten nach dem TAGE-Modell (Miete pro angefangenem Tag) für die ganze Position.
    private func dauerText(_ m: Maschine) -> String? {
        guard let mk = m.mietkostenTageModell(menge: position.menge, einheit: einheit) else { return nil }
        return "≈ \(fmtH((mk.stunden * 10).rounded() / 10)) h für \(fmtH(position.menge)) \(einheit)"
             + " → \(mk.tage) angefangene\(mk.tage == 1 ? "r" : "") Tag\(mk.tage == 1 ? "" : "e")"
             + " · Miete \(euro(mk.gesamt)) (\(euro(mk.proEinheit))/\(einheit))"
    }

    private func ladeVorschlag() async {
        // 1) Lokaler Richtwert-Katalog zuerst — deterministisch, mit echter Kolonne + Quelle.
        //    Ersetzt das nicht-deterministische KI-Raten als Startpunkt.
        // Weg über den STLB: Position → Baustein → aufwandswert_key → Richtwert (deterministisch),
        // Maschinen direkt aus den maschinen_keys des Bausteins.
        if let b = STLBKatalog.shared.finde(leistung: leistung),
           let key = b.aufwandswertKey,
           let t = AufwandswerteKatalog.shared.eintrag(key: key) {
            richtwert = t
            maurer = t.mittel; helfer = 0
            vorschlagMaurer = maurer; vorschlagHelfer = helfer
            vorschlagStatus = "🟡 STLB \(b.id) → Richtwert (\(t.quelleKurz)) — Schätzung, bitte prüfen."
            maschinenVorschlaege = MaschinenKatalog.shared.maschinen(ids: b.maschinenKeys)
            return
        }
        // Fallback: direkter Stichwort-Treffer im Aufwandswerte-Katalog.
        if let t = AufwandswerteKatalog.shared.finde(leistung: leistung, langtext: position.langtext) {
            richtwert = t
            maurer = t.mittel; helfer = 0        // Gesamt-Arbeitszeit je Einheit — Kolonne siehe Karte
            vorschlagMaurer = maurer; vorschlagHelfer = helfer
            vorschlagStatus = "🟡 Richtwert aus dem Katalog (\(t.quelleKurz)) — Schätzung, bitte prüfen."
            maschinenVorschlaege = MaschinenKatalog.shared.fuerTaetigkeit("\(t.gewerk).\(t.key)")
            return
        }
        // 2) Rückfall: den Prof fragen (nicht-deterministisch, wackelt je Anfrage).
        let helper = MopsKalkulationsHelper.shared
        if let v = await helper.aufwandswertVorschlag(leistung: leistung, langtext: position.langtext) {
            maurer = v.maurer; helfer = v.helfer
            vorschlagMaurer = v.maurer; vorschlagHelfer = v.helfer
            vorschlagStatus = "🟡 Vorschlag vom Prof (Schätzung) — passt das, oder ändern?"
        } else {
            vorschlagStatus = "Kein Vorschlag (offline) — trag Raphis Erfahrungswert ein."
        }
    }

    // Lesbare Material-Info: Katalog/dein Preis · Lager · Markt-Orientierung (KI, Büro-Vorarbeit)
    @ViewBuilder private func materialInfo(_ z: Zutat) -> some View {
        let name = z.name.trimmingCharacters(in: .whitespaces)
        let eh = z.einheit.isEmpty ? einheit : z.einheit
        if !name.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                if let p = LeistungskatalogService.materialPreis(fuer: name, in: ctx) {
                    Text("im Katalog ✓ · dein Preis: \(euro(p))/\(eh)")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Text("nicht im Katalog — dein Preis fehlt (in Stammdaten ergänzen)")
                        .font(.caption).foregroundStyle(.red)
                }
                if let bestand = LeistungskatalogService.lagerBestand(fuer: name, in: ctx) {
                    Text(bestand > 0
                         ? "auf Lager: \(fmtH(bestand)) \(eh)"
                         : "Lager: leer — muss bestellt werden")
                        .font(.caption).foregroundStyle(bestand > 0 ? Color.secondary : Color.orange)
                } else {
                    Text("nicht im Lager erfasst").font(.caption).foregroundStyle(.secondary)
                }
                if marktLaden.contains(z.id) {
                    HStack(spacing: 6) { ProgressView().scaleEffect(0.7); Text("frage Markt …").font(.caption2).foregroundStyle(.secondary) }
                } else if let mp = marktpreise[z.id] {
                    Text("🌐 Markt-Orientierung (KI-Schätzung): ~\(euro(mp))/\(eh)")
                        .font(.caption2).foregroundStyle(.blue)
                } else {
                    Button { marktFragen(z) } label: {
                        Label("🌐 Marktpreis fragen (KI)", systemImage: "globe").font(.caption2)
                    }.buttonStyle(.borderless)
                }
            }
        }
    }

    private func marktFragen(_ z: Zutat) {
        let name = z.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let eh = z.einheit.isEmpty ? einheit : z.einheit
        marktLaden.insert(z.id)
        Task {
            let p = await MopsKalkulationsHelper.shared.marktpreisVorschlag(material: name, einheit: eh)
            await MainActor.run {
                marktLaden.remove(z.id)
                if let p { marktpreise[z.id] = p }
            }
        }
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

    // Lesbarer Zeit-Briefing: zwei getrennte Arbeitsmengen, die sich zu Mannstunden summieren.
    // Bewusst KEIN „schafft X/h" — das las sich wie ein Renn-Vergleich Maurer↔Helfer.
    private var zeitBriefing: String {
        let m = position.menge
        let mStd = maurer * m, hStd = helfer * m, gesamt = mStd + hStd
        // Katalog-Startwert (nur Gesamtzahl, noch nicht auf Rollen aufgeteilt):
        // NICHT „Maurer" behaupten — die echte Kolonne steht in der Richtwert-Karte.
        if let t = richtwert, helfer == 0, maurer == vorschlagMaurer {
            return "Für \(fmtH(m)) \(einheit) ≈ \(fmtH(gesamt)) Mannstunden "
                 + "(Mannschaft: \(t.kolonne.isEmpty ? "siehe oben" : t.kolonne)). "
                 + "Auf deine Rollen aufteilen, wenn du magst."
        }
        var teile: [String] = []
        if maurer > 0 { teile.append("\(fmtH(mStd)) Std Maurer") }
        if helfer > 0 { teile.append("\(fmtH(hStd)) Std Helfer") }
        let arbeit = teile.joined(separator: " + ")
        return "Für \(fmtH(m)) \(einheit): \(arbeit) = \(fmtH(gesamt)) Mannstunden. "
             + "Sie arbeiten zusammen — die Dauer in Tagen hängt von der Kolonnengröße ab (Brigade)."
    }

    private func euro(_ d: Double) -> String { String(format: "%.2f €", d) }
    private func fmtH(_ d: Double) -> String { String(format: "%g", d) }
}
