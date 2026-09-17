import SwiftUI
import CoreData

/// Die kleine Gesamtrechnung unten rechts im Canvas: Material + Lohn + Gerät ergeben
/// die Selbstkosten, darauf die Aufschläge, zusammen der Netto-Gesamtpreis der ganzen
/// Baustelle. Klartext statt Abkürzungen; ein „?" erklärt, was in den Aufschlägen steckt.
struct CanvasRechnungBox: View {
    @ObservedObject var event: Event
    @State private var erklaerungOffen = false

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

            zeile("Material", s.material)
            zeile("Lohn", s.lohn)
            zeile("Gerät", s.geraet)

            Divider()
            zeile("Selbstkosten", s.selbstkosten, fett: true)
            zeile("+ Aufschläge", s.aufschlag, farbe: .orange)

            Divider()
            zeile("Gesamt (netto)", s.gesamtNetto, fett: true, farbe: .orange)
        }
        .padding(12)
        .frame(width: 230)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
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
