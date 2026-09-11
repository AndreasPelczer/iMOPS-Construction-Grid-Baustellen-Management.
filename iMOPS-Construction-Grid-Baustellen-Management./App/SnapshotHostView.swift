#if DEBUG
import SwiftUI
import CoreData

// "Codis Augen" — DEBUG-only Host für reproduzierbare UI-Screenshots.
//   --snapshot-mode --target=AufmassSheet --state=schaetzkarte
//   --snapshot-mode --target=LVRowGallery        (5.2.1 — Zeilen-Balken geschätzt/gemessen)
//   --snapshot-mode --target=LVFortschrittSheet  (5.2.1 — R3-Override-Hinweis)
//   --snapshot-mode --target=LVElement           (B-Element: Deckel summiert Bausteine)
//   --snapshot-mode --target=LVElementRezept     (B-Element: Rezept-Maß am Baustein)
//   --snapshot-mode --target=Voraussetzungen     (Auftrag wartet auf zwei Vorgänger)
//   --snapshot-mode --target=VoraussetzungWahl   (Auswahl der möglichen Vorgänger)
//   --snapshot-mode --target=VoraussetzungZyklus (die Meldung bei einem Kreis)
//   --snapshot-mode --target=Grap8Kette          (die Leinwand mit einer echten Kante)
//   --snapshot-mode --target=Grap8Generator      (echtes Hausprojekt: Symbole je Gewerk)
//   --snapshot-mode --target=BauerHorst          (Demo: 12 Handgriffe mit Verzweigung)
//   --snapshot-mode --target=Sandsteinstufen     (Demo 2: zwei Straenge, Zusammenfuehrung)
//   --snapshot-mode --target=Hofauffahrt        (Demo 3: Mengengeruest, Abzweig + Zusammenfuehrung)
//   --snapshot-mode --target=Grap8Kalkulation    (was der Knopf „Kalkulation" oeffnet)
//   --snapshot-mode --target=Grap8Bestellung     (was der Knopf „Bestellung" oeffnet)
// scripts/snapshot.sh fängt den Screen per simctl io ab. Roman Anhang C: VTP für die UI.
struct SnapshotHostView: View {
    @State private var controller = PersistenceController(inMemory: true)

    private func arg(_ prefix: String, _ fallback: String) -> String {
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })?
            .replacingOccurrences(of: prefix, with: "") ?? fallback
    }

    var body: some View {
        let ctx = controller.container.viewContext
        let state = SnapshotState(rawValue: arg("--state=", "schaetzkarte")) ?? .schaetzkarte
        return Group {
            switch arg("--target=", "AufmassSheet") {
            case "LVElement":          SnapshotElementHost(ctx: ctx)
            case "LVElementRezept":    SnapshotRezeptHost(ctx: ctx)
            case "LVZuschlag":         SnapshotZuschlagHost(ctx: ctx, eigen: arg("--state=", "eigen") == "eigen")
            case "LVRowGallery":       SnapshotRowGallery(ctx: ctx)
            case "LVFortschrittSheet": SnapshotFortschrittHost(ctx: ctx)
            case "Voraussetzungen":    SnapshotVoraussetzungenHost(ctx: ctx)
            case "VoraussetzungWahl":  SnapshotVoraussetzungWahlHost(ctx: ctx)
            case "VoraussetzungZyklus": SnapshotZyklusHost(ctx: ctx)
            case "Grap8Kette":         SnapshotGrap8Host(ctx: ctx)
            case "Grap8Generator":     SnapshotGeneratorHost(ctx: ctx)
            case "BauerHorst":         SnapshotBauerHorstHost(ctx: ctx)
            case "Sandsteinstufen":    SnapshotStufenHost(ctx: ctx)
            case "Hofauffahrt":        SnapshotAuffahrtHost(ctx: ctx)
            case "Grap8Kalkulation":   SnapshotVerwaltungHost(ctx: ctx, ziel: .kalkulation)
            case "Grap8Bestellung":    SnapshotVerwaltungHost(ctx: ctx, ziel: .bestellung)
            case "NeuesAufmassSheet":  NeuesAufmassSheet(position: SnapshotData.position(in: ctx, state: state))
            default:                   AufmassSheet(position: SnapshotData.position(in: ctx, state: state))
            }
        }
        .environment(\.managedObjectContext, ctx)
    }
}

// 5.2.1 — Galerie der Zeilen-Balken: geschätzt (orange/Stift) vs. gemessen (blau/grün/Lineal),
// inkl. Mehrmenge > 100 %.
private struct SnapshotRowGallery: View {
    private let rows: [(String, LVPosition)]
    @MainActor init(ctx: NSManagedObjectContext) {
        rows = [
            ("geschätzt 50 % (Polier-Daumen)", SnapshotData.row(in: ctx, ist: [],           manuell: 50)),
            ("gemessen 90 %",                  SnapshotData.row(in: ctx, ist: [90, 70, 56],  manuell: nil)),
            ("gemessen 100 % (fertig)",        SnapshotData.row(in: ctx, ist: [120, 120],    manuell: nil)),
            ("Mehrmenge 125 % (ehrlich)",      SnapshotData.row(in: ctx, ist: [150, 150],    manuell: nil)),
        ]
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0).font(.caption2).foregroundStyle(.secondary)
                        LVPositionRow(position: item.1)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("LV-Zeilen · 5.2.1")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// 5.2.1 — LVFortschrittSheet mit gesetztem Polier-Schätzwert (80 %) UND Aufmaß (90 % gemessen),
// damit der R3-Override-Hinweis erscheint.
private struct SnapshotFortschrittHost: View {
    private let position: LVPosition
    @MainActor init(ctx: NSManagedObjectContext) {
        let pos = SnapshotData.position(in: ctx, state: .schaetzkarte) // 216/240 → 90 % gemessen
        SnapshotData.setManuell(80, for: pos)
        position = pos
    }
    var body: some View { LVFortschrittSheet(position: position) }
}

// B-Element — die echte LVView mit einem gedeckelten Element daneben einem
// gewöhnlichen Mengenträger-Deckel, damit der Unterschied im Bild sichtbar ist.
private struct SnapshotElementHost: View {
    private let event: Event
    @MainActor init(ctx: NSManagedObjectContext) { event = SnapshotData.pflasterBaustelle(in: ctx) }
    var body: some View {
        LVView(event: event)
            .environment(ImportedFileHandler())
    }
}

// B-Element — das Rezept-Maß-Feld am Baustein (Frostschutz, 0,35 m³ je m²).
private struct SnapshotRezeptHost: View {
    private let event: Event
    private let baustein: LVPosition
    @MainActor init(ctx: NSManagedObjectContext) {
        event = SnapshotData.pflasterBaustelle(in: ctx)
        // Der Frostschutz-Baustein — an ihm hängt das Rezept-Maß.
        baustein = (event.lvPositionen as? Set<LVPosition>)?
            .first { $0.posNr == "534.002" } ?? LVPosition(context: ctx)
    }
    var body: some View {
        AddLVPositionView(event: event, editPosition: baustein)
    }
}

// Zuschlag je Kostenart am Element — die Sätze aus dem BauSU-Bild
// (Lohn ×2,75, Material ×1,15, Gerät ×1,10) ⇒ 127,25 €/m².
// `--state=eigen` → Position weicht ab, Regler bedienbar.
// `--state=firma` → Position folgt den Firmenwerten, Regler nur zur Ansicht.
private struct SnapshotZuschlagHost: View {
    private let element: LVPosition
    @MainActor init(ctx: NSManagedObjectContext, eigen: Bool) {
        let event = SnapshotData.pflasterBaustelle(in: ctx)
        let el = (event.lvPositionen as? Set<LVPosition>)?
            .first { $0.posNr == "534.000" } ?? LVPosition(context: ctx)
        el.zuschlagEigen = eigen
        el.zuschlagJeKostenart = true
        el.zuschlagLohnProzent = 1.75
        el.zuschlagMaterialProzent = 0.15
        el.zuschlagGeraetProzent = 0.10
        element = el
    }
    var body: some View { LVTiefenkalkulationView(position: element) }
}

enum SnapshotState: String {
    case leer, gruen, rot, schaetzkarte
}

enum SnapshotData {
    @MainActor
    static func position(in ctx: NSManagedObjectContext, state: SnapshotState) -> LVPosition {
        let mengen: [Double]
        switch state {
        case .leer:         mengen = []
        case .gruen:        mengen = [120, 120]      // 240 → 0 %
        case .rot:          mengen = [60, 60]        // 120 → 50 %
        case .schaetzkarte: mengen = [90, 70, 56]    // 216 → 10 %
        }
        return row(in: ctx, ist: mengen, manuell: nil)
    }

    @MainActor
    static func row(in ctx: NSManagedObjectContext, ist: [Double], manuell: Int?) -> LVPosition {
        let notizen = ["EG", "1. OG", "DG", "KG"]
        let pos = LVPosition(context: ctx)
        pos.posNr = "3.30.1"
        pos.bezeichnung = "Außenwand 24 cm Kalksandstein"
        pos.menge = 240
        pos.einheit = "m²"
        for (i, m) in ist.enumerated() {
            let a = Aufmass(context: ctx)
            a.id = UUID()
            a.istMenge = m
            a.istEinheit = "m²"
            a.erstelltAm = Date()
            a.notiz = i < notizen.count ? notizen[i] : nil
            a.quelle = .manuell
            a.lvPosition = pos
        }
        if let m = manuell { setManuell(m, for: pos) }
        return pos
    }

    // MARK: - B-Element (Pflaster-Rezept, 87,00 €/m²)

    /// Baustelle mit ZWEI Deckeln, damit der Unterschied im Bild steht:
    ///   • „Pflasterfläche" als Element → Bausteine summieren zu 87,00 €/m²
    ///   • „Außenwand 24 cm" als Mengenträger → Belege „zählen nicht" (wie bisher)
    /// Zahlen identisch zu ElementKalkulationTests, damit Bild und Test dasselbe sagen.
    @MainActor
    static func pflasterBaustelle(in ctx: NSManagedObjectContext) -> Event {
        let event = Event(context: ctx)
        event.title = "BV Musterweg"
        event.location = "Baden-Württemberg"
        event.timeStamp = Date()

        // --- Element: Pflasterfläche, 100 m² ---
        let element = position(ctx, event, "534.000", "Pflasterfläche Hofzufahrt", 100, "m²", kg: "534")
        element.deckelTyp = .element

        let frostschutz = baustein(ctx, event, element, "534.002", "Frostschutzschicht", "m³", 0.35)
        material(ctx, frostschutz, "Schotter 0/32", preis: 50)

        let steine = baustein(ctx, event, element, "534.004", "Pflastersteine liefern", "m²", 1.0)
        material(ctx, steine, "Betonpflaster grau", preis: 25)

        let verlegen = baustein(ctx, event, element, "534.005", "Pflaster verlegen", "m²", 1.0)
        lohn(ctx, verlegen, satz: 55, stunden: 0.5)

        let abruetteln = baustein(ctx, event, element, "534.007", "Abrütteln", "h", 0.1)
        geraet(ctx, abruetteln, satz: 25, stunden: 1.0)

        // --- Mengenträger: unverändertes Verhalten daneben ---
        let wand = position(ctx, event, "331.001", "Außenwand 24 cm", 80, "m²", kg: "331")
        material(ctx, wand, "Porenbeton PP2-0,35", preis: 30)
        let beleg1 = position(ctx, event, "331.001.1", "Wand EG Nord", 30, "m²", kg: "331")
        beleg1.deckel = wand
        let beleg2 = position(ctx, event, "331.001.2", "Wand EG Süd", 50, "m²", kg: "331")
        beleg2.deckel = wand

        try? ctx.save()
        return event
    }

    @MainActor
    private static func position(_ ctx: NSManagedObjectContext, _ event: Event,
                                 _ posNr: String, _ bez: String,
                                 _ menge: Double, _ einheit: String, kg: String) -> LVPosition {
        let p = LVPosition(context: ctx)
        p.posNr = posNr
        p.bezeichnung = bez
        p.menge = menge
        p.einheit = einheit
        p.kostenGruppeNummer = kg
        p.bgkProzent = 0.12
        p.wagnisGewinnProzent = 0.08
        p.event = event
        return p
    }

    @MainActor
    private static func baustein(_ ctx: NSManagedObjectContext, _ event: Event,
                                 _ element: LVPosition, _ posNr: String, _ bez: String,
                                 _ einheit: String, _ jeElementEinheit: Double) -> LVPosition {
        let b = position(ctx, event, posNr, bez, 0, einheit, kg: element.kostenGruppeNummer ?? "534")
        b.mengeJeDeckelEinheit = jeElementEinheit
        b.deckel = element
        return b
    }

    @MainActor
    private static func material(_ ctx: NSManagedObjectContext, _ pos: LVPosition,
                                 _ name: String, preis: Double) {
        let m = PositionMaterial(context: ctx)
        m.id = UUID()
        m.materialName = name
        m.einzelpreis = preis
        m.mengeProEinheit = 1.0
        m.verschnittProzent = 0
        m.einheit = pos.einheit
        m.position = pos
    }

    @MainActor
    private static func lohn(_ ctx: NSManagedObjectContext, _ pos: LVPosition,
                             satz: Double, stunden: Double) {
        let l = PositionLohn(context: ctx)
        l.id = UUID()
        l.qualifikation = "Facharbeiter"
        l.stundenBruttoEK = satz
        l.stunden = stunden
        l.position = pos
    }

    @MainActor
    private static func geraet(_ ctx: NSManagedObjectContext, _ pos: LVPosition,
                               satz: Double, stunden: Double) {
        let g = PositionGeraet(context: ctx)
        g.id = UUID()
        g.geraetName = "Rüttelplatte"
        g.kostenProStunde = satz
        g.stunden = stunden
        g.position = pos
    }

    @MainActor
    static func setManuell(_ prozent: Int, for pos: LVPosition) {
        let id = pos.objectID.uriRepresentation().absoluteString
        LVFortschrittStore.shared.setFortschritt(LVFortschritt(prozent: prozent), for: id)
    }
}

// Voraussetzungen — ein Auftrag, der auf zwei Vorgänger wartet, einer davon fertig.
// Zeigt den „Wartet auf"-Abschnitt in `AuftragDetailView` mit beiden Zuständen.
private struct SnapshotVoraussetzungenHost: View {
    private let ziel: Auftrag
    @MainActor init(ctx: NSManagedObjectContext) {
        ziel = SnapshotKette.baue(in: ctx)
    }
    var body: some View {
        NavigationStack { AuftragDetailView(job: ziel) }
    }
}

// Die Auswahl der möglichen Vorgänger — Geschwister ohne sich selbst und ohne
// die bereits verknüpften.
private struct SnapshotVoraussetzungWahlHost: View {
    private let ziel: Auftrag
    @MainActor init(ctx: NSManagedObjectContext) {
        ziel = SnapshotKette.baue(in: ctx)
    }
    var body: some View {
        VoraussetzungWaehlenView(auftrag: ziel) { _ in }
    }
}

// Die Leinwand mit einer echten Kette: zeigt, dass ein in der App gesetztes
// „wartet auf" drüben als Pfeil ankommt. Der Weg ist derselbe wie in der App —
// `Grap8Graph.aus(event)` über die Brücke, keine gestellten Daten.
private struct SnapshotGrap8Host: View {
    private let baustelle: Event
    @MainActor init(ctx: NSManagedObjectContext) {
        baustelle = SnapshotKette.baue(in: ctx).event!
    }
    var body: some View { Grap8View(event: baustelle) }
}

// Ein echtes generiertes Hausprojekt auf der Leinwand — nicht gestellt: derselbe
// `HouseProjectGenerator`, den auch der Hausplaner ruft. Zeigt, ob die Aufträge
// Kostengruppen tragen und dadurch unterschiedliche Symbole bekommen.
private struct SnapshotGeneratorHost: View {
    private let baustelle: Event
    @MainActor init(ctx: NSManagedObjectContext) {
        var projekt = HouseProject()
        projekt.projektName = "Musterhaus — Generator"
        projekt.garage = true          // zieht das Gewerk „Aussenanlagen" mit herein
        let ergebnis = HouseProjectGenerator.generate(from: projekt)
        baustelle = HouseProjectGenerator.createEvent(from: ergebnis, into: ctx)
    }
    var body: some View { Grap8View(event: baustelle) }
}

// Die Demo-Baustelle „Bauer Horst" auf der Leinwand — echte Seeder-Daten, damit
// sichtbar wird, ob die Kette samt Verzweigung bei „Pfosten setzen" ankommt.
// Demo 2 auf der Leinwand: zwei Stränge, die sich beim Versetzen treffen.
private struct SnapshotStufenHost: View {
    private let baustelle: Event
    @MainActor init(ctx: NSManagedObjectContext) {
        SandsteinstufenSeeder.seedIfNeeded(context: ctx)
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-STUFEN-001")
        baustelle = (try? ctx.fetch(r))?.first ?? Event(context: ctx)
    }
    var body: some View { Grap8View(event: baustelle) }
}

private struct SnapshotAuffahrtHost: View {
    private let baustelle: Event
    @MainActor init(ctx: NSManagedObjectContext) {
        HofauffahrtSeeder.seedIfNeeded(context: ctx)
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-AUFFAHRT-001")
        baustelle = (try? ctx.fetch(r))?.first ?? Event(context: ctx)
    }
    var body: some View { Grap8View(event: baustelle) }
}

private struct SnapshotBauerHorstHost: View {
    private let baustelle: Event
    @MainActor init(ctx: NSManagedObjectContext) {
        BauerHorstSeeder.seedIfNeeded(context: ctx)
        let r: NSFetchRequest<Event> = Event.fetchRequest()
        r.predicate = NSPredicate(format: "eventNumber == %@", "DEMO-PFOSTEN-001")
        baustelle = (try? ctx.fetch(r))?.first ?? Event(context: ctx)
    }
    var body: some View { Grap8View(event: baustelle) }
}

// Was hinter einem „Verwaltung öffnen"-Knopf steckt: dieselbe Ansicht, die
// `Grap8View.verwaltung(_:)` präsentiert — mit der Baustelle eines generierten
// Hausprojekts, nicht mit gestellten Daten.
private struct SnapshotVerwaltungHost: View {
    private let baustelle: Event
    private let ziel: Grap8Verwaltungsziel

    @MainActor init(ctx: NSManagedObjectContext, ziel: Grap8Verwaltungsziel) {
        var projekt = HouseProject()
        projekt.projektName = "Musterhaus — Generator"
        let ergebnis = HouseProjectGenerator.generate(from: projekt)
        baustelle = HouseProjectGenerator.createEvent(from: ergebnis, into: ctx)
        self.ziel = ziel
    }

    private var positionen: [LVPosition] {
        ((baustelle.lvPositionen?.allObjects as? [LVPosition]) ?? [])
            .sorted {
                let a = $0.kostenGruppeNummer ?? "", b = $1.kostenGruppeNummer ?? ""
                return a != b ? a < b : ($0.posNr ?? "") < ($1.posNr ?? "")
            }
    }

    var body: some View {
        switch ziel {
        case .kalkulation:
            // Mit Rahmen — genau wie in `Grap8View`, weil die Ansicht selbst keinen hat.
            NavigationStack {
                // Titel kommt aus der Ansicht selbst („Kalkulation (Welle 6)") —
                // hier keinen eigenen setzen, der würde nur scheinbar wirken.
                LVKalkulationView(event: baustelle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("Fertig") {} .tint(.orange) }
                    }
            }
        case .bestellung:
            LieferantenBestelllisteView(event: baustelle, positionen: positionen)
        case .mannschaft:  CrewPlanningView()
        case .maschinen:   StammdatenPflegeView()
        }
    }
}

// Die Zyklus-Meldung. Der Text ist NICHT gestellt: hier wird wirklich versucht,
// einen Kreis zu schließen, und angezeigt wird, was `KausalketteFehler` dabei wirft —
// derselbe Weg, den `AuftragDetailView.verknuepfeMit` nimmt.
private struct SnapshotZyklusHost: View {
    private let meldung: String
    @MainActor init(ctx: NSManagedObjectContext) {
        let estrich = SnapshotKette.baue(in: ctx)
        let fundament = estrich.vorgaenger.first!
        do {
            // Fundament soll auf Estrich warten — Estrich wartet aber schon auf Fundament.
            try Kausalkette.verknuepfe(fundament, brauchtVorher: estrich, in: ctx)
            meldung = "kein Fehler — das wäre ein Befund!"
        } catch let fehler as KausalketteFehler {
            meldung = fehler.errorDescription ?? ""
        } catch {
            meldung = error.localizedDescription
        }
    }
    var body: some View {
        Color(.systemBackground)
            .alert("Geht nicht", isPresented: .constant(true)) {
                Button("Verstanden", role: .cancel) {}
            } message: {
                Text(meldung)
            }
    }
}

/// Eine kleine Baustelle mit vier Aufträgen; der Estrich wartet auf zwei davon.
private enum SnapshotKette {
    @MainActor
    static func baue(in ctx: NSManagedObjectContext) -> Auftrag {
        let baustelle = Event(context: ctx)
        baustelle.title = "Aura 125 — Marktbreit"

        func auftrag(_ name: String, _ kg: String, _ status: AuftragStatus) -> Auftrag {
            let a = Auftrag(context: ctx)
            a.processingDetails = name
            a.kostenGruppeNummer = kg
            a.status = status
            a.storageNote = ""
            a.event = baustelle
            return a
        }

        let fundament = auftrag("Fundament betonieren", "322", .completed)
        let waende    = auftrag("Wände EG mauern",      "331", .inProgress)
        _             = auftrag("Dachstuhl richten",    "361", .pending)
        let estrich   = auftrag("Estrich einbringen",   "352", .pending)

        try? Kausalkette.verknuepfe(estrich, brauchtVorher: fundament, in: ctx)
        try? Kausalkette.verknuepfe(estrich, brauchtVorher: waende, in: ctx)
        return estrich
    }
}

#endif
