#if DEBUG
import SwiftUI
import CoreData

// "Codis Augen" — DEBUG-only Host für reproduzierbare UI-Screenshots.
//   --snapshot-mode --target=AufmassSheet --state=schaetzkarte
//   --snapshot-mode --target=LVRowGallery        (5.2.1 — Zeilen-Balken geschätzt/gemessen)
//   --snapshot-mode --target=LVFortschrittSheet  (5.2.1 — R3-Override-Hinweis)
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

    @MainActor
    static func setManuell(_ prozent: Int, for pos: LVPosition) {
        let id = pos.objectID.uriRepresentation().absoluteString
        LVFortschrittStore.shared.setFortschritt(LVFortschritt(prozent: prozent), for: id)
    }
}
#endif
