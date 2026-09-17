import SwiftUI
import CoreData

/// Welche Kostenart man aufmacht, um zu sehen, woraus die Summe besteht.
enum Kostenart: String, Identifiable {
    case material = "Material"
    case lohn = "Lohn"
    case geraet = "Gerät"

    var id: String { rawValue }

    func betrag(_ b: LVKalkulator.Kostenbeitrag) -> Double {
        switch self {
        case .material: return b.material
        case .lohn:     return b.lohn
        case .geraet:   return b.geraet
        }
    }
}

/// Die kleine Gesamtrechnung unten rechts im Canvas: Material + Lohn + Gerät ergeben
/// die Selbstkosten, darauf die Aufschläge, zusammen der Netto-Gesamtpreis der ganzen
/// Baustelle. Klartext statt Abkürzungen; ein „?" erklärt, was in den Aufschlägen steckt.
/// Material/Lohn/Gerät sind antippbar → man sieht, WORAUS die Summe besteht.
struct CanvasRechnungBox: View {
    @ObservedObject var event: Event
    @State private var erklaerungOffen = false
    @State private var herkunft: Kostenart?

    /// Zählbare, nicht-alternative Positionen der Baustelle → durchkalkuliert und summiert.
    private var summe: LVKalkulator.Gesamtaufschluesselung {
        let alle = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        let base = alle.filter { !LVPositionHelper.isAlternative($0) }
        return LVKalkulator.gesamtAufschluesselung(positionen: base)
    }

    var body: some View {
        let s = summe
        VStack(alignment: .leading, spacing: 6) {

            HStack(spacing: 6) {
                Image(systemName: "eurosign.circle.fill").foregroundStyle(.orange)
                Text("Rechnung — ganze Baustelle")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 8)
                Button { erklaerungOffen = true } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            zeileTippbar("Material", s.material, art: .material)
            zeileTippbar("Lohn", s.lohn, art: .lohn)
            zeileTippbar("Gerät", s.geraet, art: .geraet)

            Divider()
            zeile("Selbstkosten", s.selbstkosten, fett: true)
            zeile("+ Aufschläge", s.aufschlag, farbe: .orange)

            Divider()
            zeile("Gesamt (netto)", s.gesamtNetto, fett: true, farbe: .orange)

            Text("Material/Lohn/Gerät antippen — woraus besteht die Summe?")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 230)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .sheet(item: $herkunft) { art in
            KostenHerkunftView(event: event, art: art)
        }
        .alert("Was heißt was?", isPresented: $erklaerungOffen) {
            Button("Alles klar") { erklaerungOffen = false }
        } message: {
            Text("""
            Selbstkosten = was die Baustelle den Betrieb wirklich kostet: Material + Lohn + Gerät.

            Aufschläge = was oben draufkommt, damit der Betrieb lebt und verdient:
            • BGK — Baustellengemeinkosten (Polier, Bauwagen, Strom vor Ort)
            • AGK — Allgemeine Geschäftskosten (Büro, Verwaltung)
            • Wagnis & Gewinn — Puffer fürs Risiko und der Verdienst

            Gesamt (netto) = Selbstkosten + Aufschläge, noch ohne Mehrwertsteuer.
            """)
        }
    }

    /// Antippbare Kostenzeile (Material/Lohn/Gerät) mit kleinem Chevron.
    private func zeileTippbar(_ label: String, _ wert: Double, art: Kostenart) -> some View {
        Button { herkunft = art } label: {
            HStack(spacing: 4) {
                Text(label).font(.caption)
                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary)
                Spacer()
                Text(wert, format: .currency(code: "EUR"))
                    .font(.caption.monospacedDigit())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func zeile(_ label: String, _ wert: Double,
                       fett: Bool = false, farbe: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(fett ? .caption.weight(.semibold) : .caption)
                .foregroundStyle(farbe == .primary ? Color.primary : farbe)
            Spacer()
            Text(wert, format: .currency(code: "EUR"))
                .font((fett ? Font.caption.weight(.bold) : Font.caption).monospacedDigit())
                .foregroundStyle(farbe == .primary ? Color.primary : farbe)
        }
    }
}

/// „Woraus besteht die Summe?" — die Positionen einer Kostenart, größte zuerst.
/// Genau das Werkzeug, um einen Ausreißer (falsche Menge/Einheit/Aufwandswert) zu finden.
struct KostenHerkunftView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event
    let art: Kostenart

    private var beitraege: [LVKalkulator.Kostenbeitrag] {
        let alle = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        let base = alle.filter { !LVPositionHelper.isAlternative($0) }
        return LVKalkulator.kostenbeitraege(positionen: base)
            .filter { art.betrag($0) > 0 }
            .sorted { art.betrag($0) > art.betrag($1) }
    }

    private var summe: Double { beitraege.reduce(0) { $0 + art.betrag($1) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(beitraege) { b in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(b.name).font(.subheadline).lineLimit(2)
                                Spacer(minLength: 8)
                                Text(art.betrag(b), format: .currency(code: "EUR"))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                            Text("\(b.menge.formatted(.number.precision(.fractionLength(0...2)))) \(b.einheit)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("\(art.rawValue) gesamt: \(summe.formatted(.currency(code: "EUR")))")
                } footer: {
                    Text("Größte zuerst. Steht hier eine unerwartet große Zahl, stimmt bei der Position meist Menge, Einheit oder Aufwandswert nicht.")
                }
            }
            .navigationTitle("Woraus besteht \(art.rawValue)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}
