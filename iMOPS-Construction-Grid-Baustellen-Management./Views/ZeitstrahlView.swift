import SwiftUI
import CoreData

// MARK: - ZeitstrahlView (nativer Gantt)
//
// Alle Aufträge der Baustelle auf EINER gemeinsamen Tag-Achse — der Zeitstrahl.
// Anders als die Terminplan-Karte (je Zeile eine eigene Skala) liegen hier alle
// Balken auf DERSELBEN Skala, so sieht man Überlappung und Reihenfolge auf einen
// Blick. Rein nativ (SwiftUI) auf dem Netzplan-Motor (Bauablauf.terminplan) —
// kein Eingriff in die kompilierte Grap8-Leinwand.
//
// Balken = früheste Start-/Endzeit (Tage ab Baustellenstart). Wartezeit auf den
// Kanten (Härten/Trocknen) ist schon eingerechnet: sie schiebt die Nachfolger.
struct ZeitstrahlView: View {
    let jobs: [Auftrag]

    @State private var ergebnis: AblaufErgebnis?

    var body: some View {
        Group {
            if let e = ergebnis {
                if !e.zyklus.isEmpty {
                    hinweis("Ringabhängigkeit — der Ablauf beißt sich in den Schwanz. Erst die Reihenfolge auflösen.",
                            icon: "exclamationmark.triangle.fill", farbe: .red)
                } else if e.gesamtdauerTage <= 0 {
                    hinweis("Noch keine Dauern gesetzt. Im Terminplan je Auftrag die Dauer (Tage) eintragen — dann füllt sich der Zeitstrahl.",
                            icon: "calendar.badge.clock", farbe: .secondary)
                } else {
                    gantt(e)
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .navigationTitle("Zeitstrahl")
        .navigationBarTitleDisplayMode(.inline)
        .task { ergebnis = Bauablauf.terminplan(fuer: jobs) }
    }

    // MARK: - Gantt

    private func gantt(_ e: AblaufErgebnis) -> some View {
        let gesamt = e.gesamtdauerTage
        let zeilen = e.termine.sorted {
            $0.fruehesterStartTag != $1.fruehesterStartTag
                ? $0.fruehesterStartTag < $1.fruehesterStartTag
                : $0.fruehestesEndeTag < $1.fruehestesEndeTag
        }
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Baustellenstart = Tag 0").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(zahl(gesamt)) Tage gesamt").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                VStack(spacing: 9) {
                    ForEach(zeilen) { t in zeile(t, gesamt: gesamt) }
                }
            }
            .padding()
        }
    }

    private func zeile(_ t: AblaufTermin, gesamt: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t.name).font(.caption).lineLimit(1)
            GeometryReader { geo in
                let w = geo.size.width
                let x = w * CGFloat(t.fruehesterStartTag / gesamt)
                let bw = max(6, w * CGFloat((t.fruehestesEndeTag - t.fruehesterStartTag) / gesamt))
                ZStack(alignment: .leading) {
                    // dezente Tages-Gitterlinien
                    tageRaster(gesamt: gesamt, width: w)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: bw, height: 16)
                        .offset(x: x)
                }
            }
            .frame(height: 16)
            Text("Tag \(zahl(t.fruehesterStartTag))–\(zahl(t.fruehestesEndeTag))")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    /// Dünne senkrechte Linien je Tag (oder je Schritt, wenn viele Tage), als Orientierung.
    private func tageRaster(gesamt: Double, width: CGFloat) -> some View {
        let tage = max(1, Int(gesamt.rounded(.up)))
        let schritt = tage <= 20 ? 1 : (tage <= 60 ? 5 : 10)   // nicht überfüllen
        return ZStack(alignment: .leading) {
            ForEach(Array(stride(from: 0, through: tage, by: schritt)), id: \.self) { d in
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: 16)
                    .offset(x: width * CGFloat(Double(d) / gesamt))
            }
        }
    }

    private func hinweis(_ text: String, icon: String, farbe: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.callout).foregroundStyle(farbe)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }

    private func zahl(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }
}
