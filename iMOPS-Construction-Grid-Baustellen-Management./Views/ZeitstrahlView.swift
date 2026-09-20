import SwiftUI
import CoreData

// MARK: - ZeitstrahlView (nativer Gantt mit Abhängigkeitspfeilen)
//
// Alle Aufträge der Baustelle auf EINER gemeinsamen Tag-Achse. Links die Namen,
// rechts die Balken (früheste Start-/Endzeit aus Bauablauf.terminplan). Ein
// Canvas-Overlay zeichnet die Abhängigkeiten: ein Pfeil vom ENDE des Vorgängers zum
// ANFANG des Nachfolgers — so sieht man die Kette. Wartezeit auf der Kante ist schon
// eingerechnet (sie schiebt den Nachfolger). Rein nativ, kein Eingriff in die
// kompilierte Grap8-Leinwand.
struct ZeitstrahlView: View {
    let jobs: [Auftrag]

    @State private var ergebnis: AblaufErgebnis?

    private let nameBreite: CGFloat = 116
    private let zeilenHoehe: CGFloat = 46
    private let balkenHoehe: CGFloat = 20

    var body: some View {
        Group {
            if let e = ergebnis {
                if !e.zyklus.isEmpty {
                    hinweis("Ringabhängigkeit — der Ablauf beißt sich in den Schwanz. Erst die Reihenfolge auflösen.",
                            icon: "exclamationmark.triangle.fill", farbe: .red)
                } else if e.gesamtdauerTage <= 0 {
                    hinweis("Noch keine Dauern gesetzt. Im Terminplan je Auftrag die Dauer eintragen (und ggf. Wartezeiten unter Übergangszeiten) — dann füllt sich der Zeitstrahl.",
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
        let indexVon = Dictionary(uniqueKeysWithValues: zeilen.enumerated().map { ($1.knotenID, $0) })
        let terminVon = Dictionary(uniqueKeysWithValues: zeilen.map { ($0.knotenID, $0) })
        let kanten = abhaengigkeiten()
        let chartHoehe = CGFloat(zeilen.count) * zeilenHoehe

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Baustellenstart = Tag 0").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(zahl(gesamt)) Tage · \(kanten.count) Abhängigkeit\(kanten.count == 1 ? "" : "en")")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 8) {
                    // Namen-Spalte
                    VStack(spacing: 0) {
                        ForEach(zeilen) { t in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.name).font(.caption).lineLimit(1)
                                Text("Tag \(zahl(t.fruehesterStartTag))–\(zahl(t.fruehestesEndeTag))")
                                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            .frame(width: nameBreite, height: zeilenHoehe, alignment: .leading)
                        }
                    }
                    // Balken + Pfeile
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .topLeading) {
                            raster(gesamt: gesamt, width: w, hoehe: chartHoehe)
                            ForEach(Array(zeilen.enumerated()), id: \.element.id) { i, t in
                                balken(t, index: i, width: w, gesamt: gesamt)
                            }
                            pfeile(kanten: kanten, indexVon: indexVon, terminVon: terminVon,
                                   width: w, gesamt: gesamt)
                                .frame(width: w, height: chartHoehe)
                        }
                    }
                    .frame(height: chartHoehe)
                }
            }
            .padding()
        }
    }

    private func balken(_ t: AblaufTermin, index: Int, width: CGFloat, gesamt: Double) -> some View {
        let x1 = width * CGFloat(t.fruehesterStartTag / gesamt)
        let bw = max(6, width * CGFloat((t.fruehestesEndeTag - t.fruehesterStartTag) / gesamt))
        let y = CGFloat(index) * zeilenHoehe + zeilenHoehe / 2
        return RoundedRectangle(cornerRadius: 5)
            .fill(Color.orange.opacity(0.85))
            .frame(width: bw, height: balkenHoehe)
            .position(x: x1 + bw / 2, y: y)
    }

    private func raster(gesamt: Double, width: CGFloat, hoehe: CGFloat) -> some View {
        let tage = max(1, Int(gesamt.rounded(.up)))
        let schritt = tage <= 20 ? 1 : (tage <= 60 ? 5 : 10)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(stride(from: 0, through: tage, by: schritt)), id: \.self) { d in
                Rectangle().fill(Color.secondary.opacity(0.12)).frame(width: 1, height: hoehe)
                    .position(x: width * CGFloat(Double(d) / gesamt), y: hoehe / 2)
            }
        }
    }

    /// Canvas-Overlay: für jede Abhängigkeit ein Pfeil vom Ende des Vorgängers zum
    /// Anfang des Nachfolgers (kleine S-Kurve + Spitze).
    private func pfeile(kanten: [(von: String, zu: String)],
                        indexVon: [String: Int], terminVon: [String: AblaufTermin],
                        width: CGFloat, gesamt: Double) -> some View {
        Canvas { ctx, _ in
            for k in kanten {
                guard let iv = indexVon[k.von], let iz = indexVon[k.zu],
                      let tv = terminVon[k.von], let tz = terminVon[k.zu] else { continue }
                let x1 = width * CGFloat(tv.fruehestesEndeTag / gesamt)
                let y1 = CGFloat(iv) * zeilenHoehe + zeilenHoehe / 2
                let x2 = width * CGFloat(tz.fruehesterStartTag / gesamt)
                let y2 = CGFloat(iz) * zeilenHoehe + zeilenHoehe / 2

                var pfad = Path()
                pfad.move(to: CGPoint(x: x1, y: y1))
                let dx = max(12, (x2 - x1) / 2)
                pfad.addCurve(to: CGPoint(x: x2, y: y2),
                              control1: CGPoint(x: x1 + dx, y: y1),
                              control2: CGPoint(x: x2 - dx, y: y2))
                ctx.stroke(pfad, with: .color(.secondary.opacity(0.7)),
                           style: StrokeStyle(lineWidth: 1.3))
                // Pfeilspitze am Nachfolger-Anfang
                var spitze = Path()
                spitze.move(to: CGPoint(x: x2, y: y2))
                spitze.addLine(to: CGPoint(x: x2 - 5, y: y2 - 3))
                spitze.addLine(to: CGPoint(x: x2 - 5, y: y2 + 3))
                spitze.closeSubpath()
                ctx.fill(spitze, with: .color(.secondary.opacity(0.7)))
            }
        }
        .allowsHitTesting(false)
    }

    /// Abhängigkeits-Kanten (Voraussetzung quelle → auftrag) innerhalb dieser Baustelle,
    /// als Schlüsselpaare (objectID-URI), passend zu den Terminen.
    private func abhaengigkeiten() -> [(von: String, zu: String)] {
        func key(_ a: Auftrag) -> String { a.objectID.uriRepresentation().absoluteString }
        let bekannt = Set(jobs.map { $0.objectID })
        var out: [(von: String, zu: String)] = []
        var gesehen = Set<NSManagedObjectID>()
        for j in jobs {
            let vs = (j.voraussetzungen as? Set<Voraussetzung>) ?? []
            for v in vs {
                guard let q = v.quelle, bekannt.contains(q.objectID), !gesehen.contains(v.objectID) else { continue }
                gesehen.insert(v.objectID)
                out.append((von: key(q), zu: key(j)))
            }
        }
        return out
    }

    private func hinweis(_ text: String, icon: String, farbe: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.callout).foregroundStyle(farbe)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }

    private func zahl(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }
}
