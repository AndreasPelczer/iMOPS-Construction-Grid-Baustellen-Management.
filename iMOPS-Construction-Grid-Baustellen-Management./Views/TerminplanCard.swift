import SwiftUI
import CoreData

// MARK: - TerminplanCard (Zeit im Canvas — Ansicht)
//
// Zeigt den zeitlichen Ablauf der Aufträge dieser Baustelle: frühester Start/Ende
// je Auftrag als Tage-Balken, gerechnet über den Abhängigkeitsgraph (Bauablauf).
// Die Dauer je Auftrag lässt sich hier direkt setzen (Stepper) — daraus fällt der
// Plan neu. Die Wartezeit auf der Kante (Härten/Trocknen) wird mitgerechnet, sobald
// sie an der Verbindung im Canvas gesetzt ist (eigener Schritt).
//
// Tage sind relativ zum Baustellenstart (Tag 0). Ein Ringschluss wird ehrlich
// gemeldet statt still falsch gerechnet.
struct TerminplanCard: View {
    let jobs: [Auftrag]
    @Environment(\.managedObjectContext) private var ctx

    @State private var ergebnis: AblaufErgebnis?
    @State private var stand = UUID()   // stößt Neuberechnung an

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Terminplan", systemImage: "calendar.badge.clock").font(.headline)
                Spacer()
                if let e = ergebnis, e.zyklus.isEmpty, e.gesamtdauerTage > 0 {
                    Text("\(zahl(e.gesamtdauerTage)) Tage").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }

            if jobs.isEmpty {
                Text("Noch keine Aufträge auf dieser Baustelle.").font(.caption).foregroundStyle(.secondary)
            } else if let e = ergebnis, !e.zyklus.isEmpty {
                Label("Ringabhängigkeit — der Ablauf beißt sich in den Schwanz. Erst die Reihenfolge auflösen.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let e = ergebnis {
                let gesamt = max(e.gesamtdauerTage, 1)
                let termine = Dictionary(uniqueKeysWithValues: e.termine.map { ($0.knotenID, $0) })
                if e.gesamtdauerTage == 0 {
                    Text("Setz je Auftrag die Dauer (Tage) — dann rechnet der Mops den Ablauf.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 8) {
                    ForEach(jobs, id: \.objectID) { j in
                        zeile(j, termin: termine[j.objectID.uriRepresentation().absoluteString], gesamt: gesamt)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: stand) { ergebnis = Bauablauf.terminplan(fuer: jobs) }
    }

    private func zeile(_ j: Auftrag, termin: AblaufTermin?, gesamt: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(j.processingDetails ?? "—").font(.subheadline).lineLimit(1)
                Spacer()
                Stepper(value: Binding(
                    get: { j.dauerTage },
                    set: { neu in j.dauerTage = max(0, neu); try? ctx.save(); stand = UUID() }
                ), in: 0...365, step: 1) {
                    Text("\(zahl(j.dauerTage)) T").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .labelsHidden()
                Text("\(zahl(j.dauerTage)) T").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let t = termin, t.fruehestesEndeTag > t.fruehesterStartTag {
                GeometryReader { geo in
                    let x = geo.size.width * CGFloat(t.fruehesterStartTag / gesamt)
                    let w = max(4, geo.size.width * CGFloat((t.fruehestesEndeTag - t.fruehesterStartTag) / gesamt))
                    RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.75))
                        .frame(width: w).offset(x: x)
                        .overlay(alignment: .leading) {
                            Text("Tag \(zahl(t.fruehesterStartTag))–\(zahl(t.fruehestesEndeTag))")
                                .font(.caption2).foregroundStyle(.secondary).offset(x: x, y: 0).hidden()
                        }
                }
                .frame(height: 14)
                Text("Tag \(zahl(t.fruehesterStartTag)) – \(zahl(t.fruehestesEndeTag))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func zahl(_ d: Double) -> String {
        d.formatted(.number.precision(.fractionLength(0...1)))
    }
}
