import SwiftUI
import CoreData

/// Stammdaten-Preis-Check: zeigt, welche Materialien der Mops braucht und wo noch DEIN Preis
/// fehlt. In der Bauwelt gibt keiner Preise raus — die einzige ehrliche Quelle ist deine
/// eigene Rechnung. Diese Liste sagt dir, was einzutragen ist, sobald sie reinkommt.
struct StammdatenCheckView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    private var bilanz: MaterialPreisCheck.Bilanz { MaterialPreisCheck.pruefe(in: ctx) }

    var body: some View {
        NavigationStack {
            List {
                bilanzSection
                Section {
                    ForEach(bilanz.zeilen) { z in zeile(z) }
                } header: {
                    Text("Material · Preis-Status")
                } footer: {
                    Text("🟢 dein Preis (Stammdaten) · 🔵 nur Katalog-Richtwert · 🔴 kein Preis. "
                       + "Wo Rot oder Blau steht: Rechnung her → Stammdaten → Materialien → deinen Preis eintragen. "
                       + "Dann rechnet der Mops jede Position mit DEINER Zahl.")
                }
            }
            .navigationTitle("Preis-Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }

    private var bilanzSection: some View {
        Section {
            HStack(spacing: 12) {
                ampel("🟢", bilanz.eigen, "dein Preis")
                ampel("🔵", bilanz.richtwert, "Richtwert")
                ampel("🔴", bilanz.offen, "offen")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        } footer: {
            if bilanz.offen == 0 && bilanz.gesamt > 0 {
                Text("Alle Materialien haben einen Preis. 🐶")
            } else if bilanz.gesamt == 0 {
                Text("Noch keine Material-Links in den Bausteinen.")
            } else {
                Text("\(bilanz.offen + bilanz.richtwert) von \(bilanz.gesamt) Materialien warten noch auf DEINEN Preis.")
            }
        }
    }

    private func ampel(_ symbol: String, _ n: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(symbol).font(.title3)
            Text("\(n)").font(.title3.bold().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func zeile(_ z: MaterialPreisCheck.Zeile) -> some View {
        HStack(alignment: .top) {
            Circle().fill(farbe(z.status)).frame(width: 10, height: 10).padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(z.name).font(.subheadline)
                Text(preisText(z)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusText(z.status)).font(.caption2.weight(.semibold)).foregroundStyle(farbe(z.status))
        }
    }

    private func preisText(_ z: MaterialPreisCheck.Zeile) -> String {
        if let p = z.eigenerPreis {
            let lief = (z.lieferant?.isEmpty == false) ? " · \(z.lieferant!)" : ""
            return "\(euro(p))/\(z.einheit)\(lief)"
        }
        if let r = z.richtpreis {
            return "Richtwert \(euro(r))/\(z.einheit) — deinen Preis eintragen"
        }
        return "kein Preis — Rechnung eintragen"
    }

    private func statusText(_ s: MaterialPreisCheck.Status) -> String {
        switch s {
        case .eigen:     return "dein Wert"
        case .richtwert: return "Richtwert"
        case .offen:     return "offen"
        }
    }

    private func farbe(_ s: MaterialPreisCheck.Status) -> Color {
        switch s {
        case .eigen:     return .green
        case .richtwert: return .blue
        case .offen:     return .red
        }
    }

    private func euro(_ d: Double) -> String { d.formatted(.currency(code: "EUR")) }
}
