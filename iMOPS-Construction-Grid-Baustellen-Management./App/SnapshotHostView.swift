#if DEBUG
import SwiftUI
import CoreData

// "Codis Augen" — DEBUG-only Host für reproduzierbare UI-Screenshots.
// Start der App mit:  --snapshot-mode --target=AufmassSheet --state=schaetzkarte
// zeigt genau diesen Screen mit frischen In-Memory-Mock-Daten (kein echter Store,
// keine Navigation nötig). `scripts/snapshot.sh` fängt ihn per simctl io ab.
// Roman Anhang C: der Snapshot ist das VTP für die UI — sichtbar beweisen, was da ist.
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
        let pos = SnapshotData.position(in: ctx, state: state)
        Group {
            switch arg("--target=", "AufmassSheet") {
            case "NeuesAufmassSheet": NeuesAufmassSheet(position: pos)
            default:                  AufmassSheet(position: pos)
            }
        }
        .environment(\.managedObjectContext, ctx)
    }
}

enum SnapshotState: String {
    case leer          // keine Aufmaße → graue Ampel
    case gruen         // Ist == Soll → grün (≤ 5 %)
    case rot           // Ist << Soll → rot (> 15 %)
    case schaetzkarte  // moderate Abweichung (orange) + geschätzt-Tooltip
}

enum SnapshotData {
    @MainActor
    static func position(in ctx: NSManagedObjectContext, state: SnapshotState) -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.posNr = "3.30.1"
        pos.bezeichnung = "Außenwand 24 cm Kalksandstein"
        pos.menge = 240
        pos.einheit = "m²"

        let mengen: [(Double, String)]
        switch state {
        case .leer:         mengen = []
        case .gruen:        mengen = [(120, "EG"), (120, "1. OG")]            // 240 → 0 %
        case .rot:          mengen = [(60,  "EG"), (60,  "1. OG")]            // 120 → 50 %
        case .schaetzkarte: mengen = [(90,  "EG"), (70, "1. OG"), (56, "DG")] // 216 → 10 %
        }
        for (m, n) in mengen {
            let a = Aufmass(context: ctx)
            a.id = UUID()
            a.istMenge = m
            a.istEinheit = "m²"
            a.erstelltAm = Date()
            a.notiz = n
            a.quelle = .manuell
            a.lvPosition = pos
        }
        return pos
    }
}
#endif
