import SwiftUI
import CoreData

// MARK: - UebergangszeitenCard (Wartezeit auf der Verbindung setzen)
//
// Der fehlende Kern von „Zeit im Canvas": die Wartezeit, in der NIEMAND arbeitet
// (Beton härten, Estrich trocknen), sitzt auf der KANTE zwischen zwei Aufträgen.
// Hier wird sie eingegeben — je Abhängigkeit (Vorgänger → Nachfolger) ein Stepper.
// Ohne diese Zeiten rechnet der Terminplan/Zeitstrahl nur die reinen Arbeitsdauern;
// mit ihnen schiebt sich der Nachfolger korrekt nach hinten.
//
// Nutzt die vorhandenen Voraussetzung-Kanten (quelle → auftrag) + das Feld
// `wartezeitTage`. Kein neues Datenmodell, kein Eingriff in die Grap8-Leinwand.
struct UebergangszeitenCard: View {
    let jobs: [Auftrag]
    @Environment(\.managedObjectContext) private var ctx
    @State private var tick = 0

    private struct Kante: Identifiable {
        let id: NSManagedObjectID
        let v: Voraussetzung
        let von: String
        let zu: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Übergangszeiten", systemImage: "hourglass").font(.headline)
            Text("Wartezeit auf einer Verbindung — Zeit ohne Arbeit (Beton härten, Estrich trocknen). Schiebt den Nachfolger nach hinten.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let kanten = self.kanten
            if kanten.isEmpty {
                Text("Noch keine Abhängigkeiten zwischen Aufträgen — die entstehen über die Verbindungen im Canvas.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(kanten) { k in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(k.von)  →  \(k.zu)").font(.caption).lineLimit(2)
                        Stepper(value: bindung(k.v), in: 0...365, step: 1) {
                            Text(k.v.wartezeitTage > 0
                                 ? "\(zahl(k.v.wartezeitTage)) Tage warten"
                                 : "keine Wartezeit")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(k.v.wartezeitTage > 0 ? .orange : .secondary)
                        }

                        // 🔴 „wenn irgendwann auffallen würde, der Mops wusste das,
                        // hat aber nichts gesagt." Genau hier tippt jemand die Zahl
                        // ein — also sagt er es hier, mit beiden Werten und den Wegen.
                        // Er sperrt nicht: wer dabei bleibt, unterschreibt.
                        if let zuKurz = WartezeitKatalog.pruefe(eingetragen: k.v.wartezeitTage,
                                                                nach: k.von) {
                            VStack(alignment: .leading, spacing: 5) {
                                Label(zuKurz.satz, systemImage: "hourglass")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(zuKurz.katalog.hinweis)
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                // Was der Mops NICHT weiss, steht dabei.
                                Text(zuKurz.wasFehlt)
                                    .font(.caption2).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("\(zahl(zuKurz.katalog.tage)) Tage nehmen") {
                                    k.v.wartezeitTage = zuKurz.katalog.tage
                                    try? ctx.save()
                                    tick += 1
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bindung(_ v: Voraussetzung) -> Binding<Double> {
        Binding(
            get: { v.wartezeitTage },
            set: { neu in
                v.wartezeitTage = max(0, neu)
                try? ctx.save()
                tick += 1                 // Ansicht (Label) auffrischen
            }
        )
    }

    /// Die Abhängigkeits-Kanten innerhalb dieser Baustelle (Voraussetzung mit quelle).
    private var kanten: [Kante] {
        _ = tick                          // Neu-Berechnung nach dem Setzen anstoßen
        let ids = Set(jobs.map { $0.objectID })
        var out: [Kante] = []
        var gesehen = Set<NSManagedObjectID>()
        for j in jobs {
            let vs = (j.voraussetzungen as? Set<Voraussetzung>) ?? []
            for v in vs {
                guard let q = v.quelle, ids.contains(q.objectID), !gesehen.contains(v.objectID) else { continue }
                gesehen.insert(v.objectID)
                out.append(Kante(id: v.objectID, v: v,
                                 von: q.processingDetails ?? "—",
                                 zu: v.auftrag?.processingDetails ?? (j.processingDetails ?? "—")))
            }
        }
        return out.sorted { $0.von.localizedCompare($1.von) == .orderedAscending }
    }

    private func zahl(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }
}
