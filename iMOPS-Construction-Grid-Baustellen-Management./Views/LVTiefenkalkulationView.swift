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
    @State private var quelleInfo: String?       // Herkunfts-Hinweis beim Antippen eines Quelle-Badges
    @State private var hatVorgefuellt = false     // der Mops-Vorschlag wird beim Öffnen EINMAL versucht
    @State private var kiLaeuft = false           // läuft gerade eine KI-Schätzung?
    @State private var herkunft: AutoKalkulationsService.Ergebnis?  // Befund des Vorfüllens: hat der Katalog gegriffen?

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

    /// Beim Öffnen einmal den Vorschlag des Mops einlegen — die Kalkulation ist nie leer,
    /// sie öffnet mit der besten Schätzung, du korrigierst nur. Rein lokal/deterministisch
    /// (wie „Mops fass" für diese eine Zeile), kein Netz.
    ///
    /// SCHUTZREGEL: nur füllen, wenn die Position noch NICHTS trägt. `schreibeAufwandAusKolonne`
    /// löscht vorhandenen Lohn, würde also von Hand Eingetragenes überschreiben. Elemente
    /// rechnen über ihre Bausteine — die fasst der Vorschlag nicht an.
    /// Die Quelle-Badges zeigen danach, was Richtwert (Vorschlag) ist und was Firmenwert.
    private func vorfuellen() {
        guard !hatVorgefuellt else { return }
        hatVorgefuellt = true
        // Dieselbe Schutzregel wie vorfuellenWennLeer: nur eine leere, ECHTE Position
        // (kein Element, nichts von Hand Eingetragenes) anfassen. Der Unterschied: wir
        // behalten den Befund (griff der Katalog? über Dichte? gar kein Treffer?) für die
        // Herkunfts-Zeile — sonst sieht der Nutzer nur „leer" und weiß nicht, ob überhaupt
        // etwas versucht wurde.
        guard !position.istElement,
              position.lohnArray.isEmpty,
              position.materialArray.isEmpty,
              position.geraeteArray.isEmpty else { return }
        let ergebnis = AutoKalkulationsService.bewerte(position, in: viewContext)
        try? viewContext.save()
        herkunft = ergebnis
    }

    // MARK: - Herkunfts-Zeile (hat der Katalog beim Öffnen gegriffen?)

    /// Klartext-Verdikt + Symbol + Farbe für den Befund des Vorfüllens.
    /// Preis heraus → grün „vorbepreist"; GELB ohne Preis → orange „Wert passt noch nicht"
    /// (meist die Einheit); ROT → grau „kein Treffer". Der Detailtext darunter ist die
    /// eigentliche Meldung des Mops (nennt Kolonne, Quelle und ggf. „über Dichte …").
    private func herkunftVerdikt(_ e: AutoKalkulationsService.Ergebnis)
        -> (titel: String, symbol: String, farbe: Color) {
        if e.einheitspreisVK > 0 {
            return ("Aus dem Katalog vorbepreist", "checkmark.seal.fill", .green)
        } else if e.status == .rot {
            return ("Kein Katalog-Treffer", "questionmark.circle.fill", .secondary)
        } else {
            return ("Katalog geprüft — ein Wert passt noch nicht", "exclamationmark.triangle.fill", .orange)
        }
    }

    @ViewBuilder private var herkunftSection: some View {
        // Nicht doppeln: trägt die Position eine ungeprüfte KI-Schätzung, spricht der
        // lila KI-Banner schon — dann keine zweite Herkunfts-Zeile.
        if let e = herkunft, !enthaeltKI, let detail = e.meldungen.first, !detail.isEmpty {
            let v = herkunftVerdikt(e)
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(v.titel, systemImage: v.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(v.farbe)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 2)
            } header: {
                Label("Herkunft der Zahl", systemImage: "book")
            }
        }
    }

    // MARK: - KI-Schätzung (nur wenn der Mops keinen Wert hat)

    /// Trägt die Position einen von der KI geratenen, noch nicht bestätigten Wert?
    private var enthaeltKI: Bool {
        position.materialArray.contains { Kostenquelle($0.quelle) == .ki }
            || position.lohnArray.contains { Kostenquelle($0.quelle) == .ki }
            || position.geraeteArray.contains { Kostenquelle($0.quelle) == .ki }
    }

    /// Leer und bepreisbar → der Mops hat keinen Katalogwert; hier darf die KI raten.
    private var istLeerBepreisbar: Bool {
        !position.istElement
            && position.materialArray.isEmpty
            && position.lohnArray.isEmpty
            && position.geraeteArray.isEmpty
    }

    @ViewBuilder private var kiSection: some View {
        if enthaeltKI {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("KI geraten — Startwert ohne Quelle", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.purple)
                    Text("Das hat die KI erfunden — plausibel, aber ohne Quelle. Prüfen, nicht glauben. Bis du bestätigst, geht die Position NICHT ins Angebot.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button { kiBestaetigen() } label: {
                            Label("Bestätigen", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent).tint(.green)
                        Button(role: .destructive) { kiVerwerfen() } label: {
                            Label("Verwerfen", systemImage: "trash")
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 2)
            }
        } else if istLeerBepreisbar {
            Section {
                Button { Task { await kiSchaetzen() } } label: {
                    if kiLaeuft {
                        HStack(spacing: 8) { ProgressView(); Text("Der Mops schätzt …") }
                    } else {
                        Label("Kein Wert? Vom Mops schätzen lassen (KI)", systemImage: "globe")
                    }
                }
                .disabled(kiLaeuft)
                Text("Grobe KI-Schätzung als Startwert (online, Büro). Kein gemessener Wert, keine Quelle — prüfen, nicht glauben.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func kiSchaetzen() async {
        kiLaeuft = true
        defer { kiLaeuft = false }
        let name = position.bezeichnung ?? ""
        let eh = position.einheit ?? ""
        // Ganze Leistung schätzen: Material UND Einbau (Lohn+Gerät) — je als SPANNE.
        let (material, einbau) = await MopsKalkulationsHelper.shared.leistungsSchaetzung(leistung: name, einheit: eh)
        guard material != nil || einbau != nil else {
            quelleInfo = "Der Mops hat gerade keine Schätzung — offline, oder er weiß nichts dazu. Trag den Wert von Hand ein."
            return
        }
        // „liegt etwa zwischen X und Y" sichtbar dranschreiben; Arbeitswert = Mitte.
        func spanneText(_ s: MopsKalkulationsHelper.Spanne) -> String {
            "\(zahl(s.min))–\(zahl(s.max)) €/\(eh)"
        }
        if let s = material, s.mittel > 0 {
            let pm = PositionMaterial(context: viewContext)
            pm.id = UUID()
            pm.materialName = "KI-Schätzung: \(name) (\(spanneText(s)))"
            pm.einzelpreis = s.mittel
            pm.mengeProEinheit = 1
            pm.verschnittProzent = 0
            pm.einheit = eh
            pm.quelle = "ki"
            pm.position = position
        }
        if let s = einbau, s.mittel > 0 {
            // Einbau als PAUSCHALER Geräte-Posten für die ganze Position — bewusst NICHT als
            // Stunden-Zeile (die erfände „70 Stunden" und ein Gerät, das die KI nie geschätzt
            // hat) und NICHT als Lohn (das triebe den Firmenprofil-Vergleich in die Irre).
            // Pauschal = ein ehrlicher Klumpen „Einbau, geschätzt: X € für die Position".
            // Gesamt = Mitte × Menge; kostenProEinheit rechnet das je Einheit zurück.
            let pg = PositionGeraet(context: viewContext)
            pg.id = UUID()
            pg.geraetName = "Einbau (Lohn + Gerät), geschätzt (\(spanneText(s)))"
            pg.pauschal = true
            pg.stunden = 1                                 // 1 × Gesamtbetrag
            pg.kostenProStunde = s.mittel * position.menge // Gesamt für die Position
            pg.einheit = "pauschal"
            pg.quelle = "ki"
            pg.position = position
        }
        try? viewContext.save()
    }

    private func kiBestaetigen() {
        for m in position.materialArray where Kostenquelle(m.quelle) == .ki { m.quelle = "eigen" }
        for l in position.lohnArray where Kostenquelle(l.quelle) == .ki { l.quelle = "eigen" }
        for g in position.geraeteArray where Kostenquelle(g.quelle) == .ki { g.quelle = "eigen" }
        try? viewContext.save()
    }

    private func kiVerwerfen() {
        for m in position.materialArray where Kostenquelle(m.quelle) == .ki { viewContext.delete(m) }
        for l in position.lohnArray where Kostenquelle(l.quelle) == .ki { viewContext.delete(l) }
        for g in position.geraeteArray where Kostenquelle(g.quelle) == .ki { viewContext.delete(g) }
        try? viewContext.save()
    }

    var body: some View {
        List {
            positionKopfSection
            herkunftSection
            kiSection
            materialSection
            lohnSection
            geraeteSection
            zuschlagSection
            ergebnisSection
            marktVergleichSection
            mopsBonusSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Kalkulation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: vorfuellen)
        .alert("Woher kommt die Zahl?", isPresented: Binding(
            get: { quelleInfo != nil }, set: { if !$0 { quelleInfo = nil } })) {
            Button("OK", role: .cancel) { }
        } message: { Text(quelleInfo ?? "") }
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
            // Kräftiger Kopf in Orange auf Schwarz („Industrial"): der Bau-Mann sieht auf
            // einen Blick, worum es geht (Feldforschung: „er erkennt nicht, worum es gerade
            // geht"). Der Positionsname groß und orange, Nummer/KG/Menge ruhig darunter.
            VStack(alignment: .leading, spacing: 8) {
                Text(position.bezeichnung ?? "Unbenannte Position")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Text(position.posNr ?? "–").monospacedDigit()
                    if let kg = position.kostenGruppeNummer { Text("KG \(kg)") }
                    Spacer()
                    Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            .listRowBackground(Color.clear)
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
                    HoverZeile {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pm.materialName ?? "–")
                                .font(.subheadline)
                            Text("\(pm.mengeProEinheit.formatted(.number.precision(.fractionLength(0...3)))) \(pm.einheit ?? "") × \(pm.einzelpreis.formatted(.currency(code: "EUR")))\((pm.einheit?.isEmpty == false) ? "/\(pm.einheit!)" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if pm.verschnittProzent > 0 {
                                Text("+\(Int(pm.verschnittProzent * 100))% Verschnitt")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            baustelleZeile(menge: pm.mengeProEinheit * position.menge,
                                           einheit: pm.einheit ?? "",
                                           gesamt: pm.kostenProEinheit * position.menge)
                            QuelleBadge(quelle: Kostenquelle(pm.quelle)) { quelleInfo = Kostenquelle(pm.quelle).hinweis }
                        }
                        Spacer()
                        Text("\(pm.kostenProEinheit.formatted(.currency(code: "EUR")))/\(einheitKurz)")
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
                Text("\(kalkulation.materialKosten.formatted(.currency(code: "EUR")))/\(einheitKurz)")
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
                    HoverZeile {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pl.qualifikation ?? "–")
                                .font(.subheadline)
                            // Menschlich: ZUERST die Zeit für die ganze Menge (daran kann ein
                            // Bau-Mann die Zahl nachvollziehen — Feldforschung), dann Betrag +
                            // Stundensatz. Kein „0,02 h/kg", kein „h".
                            if position.menge > 0 {
                                Label("\(menschlicheZeit(pl.stunden * position.menge)) Arbeit — für alle \(zahl(position.menge)) \(einheitKurz)", systemImage: "clock")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("= \((pl.kostenProEinheit * position.menge).formatted(.currency(code: "EUR")))  ·  \(pl.stundenBruttoEK.formatted(.currency(code: "EUR"))) je Stunde")
                                    .font(.caption2.weight(.medium)).foregroundStyle(Color.accentColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("\(menschlicheZeit(pl.stunden)) je \(einheitKurz)  ·  \(pl.stundenBruttoEK.formatted(.currency(code: "EUR"))) je Stunde")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            QuelleBadge(quelle: Kostenquelle(pl.quelle)) { quelleInfo = Kostenquelle(pl.quelle).hinweis }
                        }
                        Spacer()
                        Text("\(pl.kostenProEinheit.formatted(.currency(code: "EUR")))/\(einheitKurz)")
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
                Text("\(kalkulation.lohnKosten.formatted(.currency(code: "EUR")))/\(einheitKurz)")
                    .font(.caption.monospacedDigit())
            }
        } footer: {
            profilVergleichFuss
        }
    }

    /// Sofort-Vergleich: die Lohn-KOSTEN je Einheit (aus den gespeicherten Stunden) — beide
    /// Firmenprofile NEBENEINANDER. Kosten, nicht Verkauf: der Aufschlag kommt über die Zuschläge.
    @ViewBuilder private var profilVergleichFuss: some View {
        if !position.lohnArray.isEmpty, let ctx = position.managedObjectContext {
            let v = LeistungskatalogService.lohnVergleich(auf: position, in: ctx)
            let aktiv = Firmenprofil.aktiv
            VStack(alignment: .leading, spacing: 4) {
                Text("Lohn-KOSTEN je \(position.einheit ?? "Einheit") — beide Profile:")
                    .font(.caption2.weight(.semibold))
                HStack(spacing: 8) {
                    profilSpalte("🏢 Goldschmitt", v.goldschmitt, aktiv: aktiv == .goldschmitt)
                    profilSpalte("🐶 Mops", v.mops, aktiv: aktiv == .mops)
                }
                let delta = v.goldschmitt - v.mops
                if abs(delta) > 0.005 {
                    Text("Δ \(delta.formatted(.currency(code: "EUR").sign(strategy: .always()))) — Kosten, kein Verkauf. Gewinn/Aufschlag kommt über den Gewinn-Schieber.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func profilSpalte(_ titel: String, _ wert: Double, aktiv: Bool) -> some View {
        VStack(spacing: 2) {
            Text(titel).font(.caption2)
            Text(wert.formatted(.currency(code: "EUR")))
                .font(.caption.monospacedDigit().weight(aktiv ? .bold : .regular))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(aktiv ? Color.orange.opacity(0.15) : Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(aktiv ? RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange, lineWidth: 1) : nil)
    }

    // MARK: - Geraete

    private var geraeteSection: some View {
        Section {
            if position.geraeteArray.isEmpty {
                leerHinweis("Keine Gerätekosten hinterlegt")
            } else {
                ForEach(position.geraeteArray, id: \.objectID) { pg in
                    HoverZeile {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pg.geraetName ?? "–")
                                .font(.subheadline)
                            if pg.pauschal {
                                // Pauschal/Fahrten: Anzahl × Preis je Einheit = Gesamt (ehrlich, keine Stunden).
                                Text("\(pg.stunden.formatted(.number.precision(.fractionLength(0...2)))) \(pg.zaehlEinheit) × \(pg.kostenProStunde.formatted(.currency(code: "EUR")))/\(pg.zaehlEinheit) = \(pg.kostenGesamt.formatted(.currency(code: "EUR"))) gesamt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                baustelleZeile(menge: pg.stunden, einheit: pg.zaehlEinheit, gesamt: pg.kostenGesamt)
                            } else {
                                if position.menge > 0 {
                                    Label("\(menschlicheZeit(pg.stunden * position.menge)) Einsatz — für alle \(zahl(position.menge)) \(einheitKurz)", systemImage: "clock")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text("= \((pg.kostenProEinheit * position.menge).formatted(.currency(code: "EUR")))  ·  \(pg.kostenProStunde.formatted(.currency(code: "EUR"))) je Stunde")
                                        .font(.caption2.weight(.medium)).foregroundStyle(Color.accentColor)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("\(menschlicheZeit(pg.stunden)) je \(einheitKurz)  ·  \(pg.kostenProStunde.formatted(.currency(code: "EUR"))) je Stunde")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            QuelleBadge(quelle: Kostenquelle(pg.quelle)) { quelleInfo = Kostenquelle(pg.quelle).hinweis }
                        }
                        Spacer()
                        Text("\(pg.kostenProEinheit.formatted(.currency(code: "EUR")))/\(einheitKurz)")
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
                Text("\(kalkulation.geraeteKosten.formatted(.currency(code: "EUR")))/\(einheitKurz)")
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
                Text(menschlicheZeit(kalkulation.stundenGesamt))
                    .font(.subheadline.weight(.semibold))
                Text("je \(position.einheit ?? "Einheit"): \(menschlicheZeit(kalkulation.stundenJeEinheit))")
                    .font(.caption2)
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
                    Text("\(zahl(position.menge)) \(einheitKurz) × \(kalkulation.einheitspreisVK.formatted(.currency(code: "EUR")))/\(einheitKurz)  ·  geplant \(menschlicheZeit(kalkulation.stundenGesamt))")
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

    // Kurzform der Positionseinheit für die „/Einheit"-Suffixe (alle EK/EP-Werte sind je Einheit).
    private var einheitKurz: String { (position.einheit?.isEmpty == false) ? position.einheit! : "Einheit" }

    private func zahl(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }

    /// Die Relation zur Baustelle: was diese Zeile für die ECHTE Menge der Position bedeutet
    /// (Gesamt-Menge in ihrer Einheit + Gesamtbetrag). Macht aus dem abstrakten „je Einheit" das Konkrete.
    /// Dezimalstunden menschlich (Feldforschung 19.9.) — Logik + Tests in `Zeitformat`.
    private func menschlicheZeit(_ stunden: Double) -> String { Zeitformat.menschlich(stunden) }

    @ViewBuilder private func baustelleZeile(menge realMenge: Double, einheit mengeEinheit: String, gesamt: Double) -> some View {
        if position.menge > 0 {
            let eh = mengeEinheit.isEmpty ? "" : " \(mengeEinheit)"
            Text("→ für \(zahl(position.menge)) \(einheitKurz): \(zahl(realMenge))\(eh) = \(gesamt.formatted(.currency(code: "EUR")))")
                .font(.caption2.weight(.medium)).foregroundStyle(Color.accentColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ergebnisZeile(label: String, wert: Double, farbe: Color, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.bold() : .subheadline)
                .foregroundStyle(farbe)
            Spacer()
            Text("\(wert.formatted(.currency(code: "EUR")))/\(einheitKurz)")
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

    // MARK: - Markt-Vergleich (BKI-Orakel)

    /// BKI-Marktpreis zu dieser Position (über den STLB-Baustein) + das Markt-Mittel in der
    /// Positions-Einheit (fair vergleichbar über den MopsUmrechner), falls überbrückbar.
    private var bkiVergleich: (preis: BKIMarktpreis, mittelInEinheit: Double?)? {
        guard !position.istElement, let bez = position.bezeichnung,
              let b = STLBKatalog.shared.finde(leistung: bez),
              let bki = BKIMarktpreisKatalog.shared.eintrag(bausteinID: b.id) else { return nil }
        let normPos = EinheitenUmrechnung.normalisiere(position.einheit ?? "")
        let normBki = EinheitenUmrechnung.normalisiere(bki.einheit)
        let mittel = normPos == normBki ? bki.mittel
            : AutoKalkulationsService.preisInPositionsEinheit(bki.mittel, vonEinheit: bki.einheit, pos: position)
        return (bki, mittel)
    }

    /// Der Markt-Vergleich: BKI-Spanne (min–mittel–max) neben dem selbst gerechneten EP, mit
    /// neutraler Abweichung. Nur Orientierung — überschreibt NIE die Kalkulation.
    @ViewBuilder private var marktVergleichSection: some View {
        if let v = bkiVergleich {
            let bki = v.preis
            let eigen = kalkulation.einheitspreisVK
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    if bki.platzhalter {
                        Label("Platzhalter — echten BKI-Wert eintragen", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    }
                    HStack {
                        Text("BKI-Markt").font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text(bki.spanneText).font(.subheadline.monospacedDigit())
                    }
                    if eigen > 0 {
                        HStack {
                            Text("Dein EP").font(.subheadline)
                            Spacer()
                            Text("\(eigen.formatted(.currency(code: "EUR")))/\(einheitKurz)")
                                .font(.subheadline.monospacedDigit().bold())
                        }
                        if let mittel = v.mittelInEinheit, mittel > 0 {
                            let delta = (eigen - mittel) / mittel
                            Text(deltaText(delta))
                                .font(.caption)
                                .foregroundStyle(abs(delta) > 0.20 ? .orange : .secondary)
                        } else {
                            Text("Andere Einheit als BKI (\(bki.einheit)) — direkter Vergleich, ohne Prozent.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !bki.bkiPosition.isEmpty {
                        Text("BKI-Position: \(bki.bkiPosition)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("\(BKIMarktpreisKatalog.shared.quelle) · \(BKIMarktpreisKatalog.shared.stand)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } header: {
                Label("Markt-Vergleich (BKI)", systemImage: "chart.bar.doc.horizontal")
            } footer: {
                Text("Nur zur Orientierung — der Mops überschreibt deine Kalkulation nicht. BKI = Baupreise aus abgerechneten Objekten.")
            }
        }
    }

    private func deltaText(_ delta: Double) -> String {
        let p = Int((abs(delta) * 100).rounded())
        if p < 1 { return "Auf Markt-Mittel." }
        return delta < 0 ? "\(p)% unter Markt-Mittel." : "\(p)% über Markt-Mittel."
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

// MARK: - HoverZeile
// Mac: Maus über einer Kostenzeile → oranger Rahmen, damit klar ist, welche Zeile
// unter dem Zeiger liegt (wie in der LV-Liste). Eigene kleine View, weil per-Zeile-
// Status in einer ForEach nur über eine Sub-View geht. iPad ohne Zeiger: onHover
// feuert nicht — harmlos.
private struct HoverZeile<Inhalt: View>: View {
    @ViewBuilder var inhalt: () -> Inhalt
    @State private var isHovered = false

    var body: some View {
        inhalt()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.orange.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isHovered ? Color.orange.opacity(0.65) : Color.clear, lineWidth: 1.5)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) { isHovered = hovering }
            }
    }
}
