#if DEBUG
import SwiftUI
import CoreData

// "Codis Augen" — DEBUG-only Host für reproduzierbare UI-Screenshots.
//   --snapshot-mode --target=AufmassSheet --state=schaetzkarte
//   --snapshot-mode --target=LVRowGallery        (5.2.1 — Zeilen-Balken geschätzt/gemessen)
//   --snapshot-mode --target=LVFortschrittSheet  (5.2.1 — R3-Override-Hinweis)
//   --snapshot-mode --target=LVElement           (B-Element: Deckel summiert Bausteine)
//   --snapshot-mode --target=LVElementRezept     (B-Element: Rezept-Maß am Baustein)
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
            case "LVRowGallery":       SnapshotRowGallery(ctx: ctx)
            case "LVFortschrittSheet": SnapshotFortschrittHost(ctx: ctx)
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
#endif
