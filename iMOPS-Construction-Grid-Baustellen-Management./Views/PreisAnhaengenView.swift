import SwiftUI
import CoreData

// MARK: - PreisAnhaengenView
//
// Schritt 4, die Bestätigung: der Mops schlägt pro Position die passende Stammdaten-
// Material vor, der Mensch bestätigt mit ✓ (oder wählt eine andere / keine). Dann wird
// die Material-Zeile angehängt und der EP springt von „nur Lohn" auf „Lohn + Material".
// Kein Tippen von Zahlen — nur bestätigen. (Vorschlag statt Erfindung.)

struct PreisAnhaengenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \KalkMaterial.name, ascending: true)])
    private var materialien: FetchedResults<KalkMaterial>

    @State private var zeilen: [Zeile] = []
    @State private var fertig = false
    @State private var angehaengt = 0

    struct Zeile: Identifiable {
        let id: NSManagedObjectID
        let position: LVPosition
        var material: KalkMaterial?
        var an: Bool
        let epVorher: Double
        let schonDran: Bool
    }

    private var auswahlAnzahl: Int {
        zeilen.filter { $0.an && $0.material != nil && !$0.schonDran }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Der Mops schlägt pro Position die passende Material aus den Stammdaten vor. Häkchen prüfen, bei Bedarf ändern, dann unten anhängen. Der EP steigt dann auf Lohn + Material.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                ForEach($zeilen) { $z in
                    zeileView($z)
                }
            }
            .navigationTitle("Preise anhängen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anhängen (\(auswahlAnzahl))") { anwenden() }
                        .disabled(auswahlAnzahl == 0)
                        .tint(.orange)
                }
            }
            .onAppear(perform: aufbauen)
            .alert("Angehängt", isPresented: $fertig) {
                Button("Fertig") { dismiss() }
            } message: {
                Text("\(angehaengt) Material-Preise an die Positionen gehängt. Der EP zeigt jetzt Lohn + Material — sichtbar in der LV-Liste (grün, dein Wert).")
            }
        }
    }

    @ViewBuilder
    private func zeileView(_ z: Binding<Zeile>) -> some View {
        let zeile = z.wrappedValue
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(zeile.position.bezeichnung ?? "–").font(.subheadline).lineLimit(2)
                Spacer()
                Text("EP jetzt \(zeile.epVorher.formatted(.currency(code: "EUR")))")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }

            if zeile.schonDran {
                Label("Material schon dran", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(.green)
            } else {
                HStack(spacing: 10) {
                    Button {
                        z.an.wrappedValue.toggle()
                    } label: {
                        Image(systemName: zeile.an && zeile.material != nil ? "checkmark.square.fill" : "square")
                            .foregroundStyle(zeile.an && zeile.material != nil ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(zeile.material == nil)

                    Menu {
                        Button("— kein Material —") { z.material.wrappedValue = nil; z.an.wrappedValue = false }
                        ForEach(materialien, id: \.objectID) { m in
                            Button {
                                z.material.wrappedValue = m
                                z.an.wrappedValue = true
                            } label: {
                                Text("\(m.name ?? "?") · \(m.preisProEinheit.formatted(.currency(code: "EUR")))/\(m.einheit ?? "")")
                            }
                        }
                    } label: {
                        if let m = zeile.material {
                            HStack(spacing: 4) {
                                Image(systemName: "shippingbox.fill").font(.caption2)
                                Text("\(m.name ?? "?") · \(m.preisProEinheit.formatted(.currency(code: "EUR")))/\(m.einheit ?? "")")
                                    .font(.caption)
                            }
                            .foregroundStyle(.orange)
                        } else {
                            Text("Material wählen…").font(.caption).foregroundStyle(.blue)
                        }
                    }

                    Spacer()

                    if let m = zeile.material {
                        Text("+ \(m.preisProEinheit.formatted(.currency(code: "EUR")))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func aufbauen() {
        guard zeilen.isEmpty else { return }
        let alle = Array(materialien)
        let positionen = ((event.lvPositionen?.allObjects as? [LVPosition]) ?? [])
            .filter { !$0.istElement }
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }

        zeilen = positionen.map { pos in
            let vorschlag = PreisAnhaengeService.shared.besterVorschlag(fuer: pos, aus: alle)
            let schonDran = vorschlag.map { v in
                pos.materialArray.contains { ($0.materialName ?? "").lowercased() == (v.material.name ?? "").lowercased() }
            } ?? false
            let ep = LVKalkulator.kalkuliere(position: pos).einheitspreisVK
            return Zeile(id: pos.objectID,
                         position: pos,
                         material: vorschlag?.material,
                         an: vorschlag != nil && !schonDran,
                         epVorher: ep,
                         schonDran: schonDran)
        }
    }

    private func anwenden() {
        var n = 0
        for z in zeilen where z.an && !z.schonDran {
            if let m = z.material,
               PreisAnhaengeService.shared.haengeAn(material: m, an: z.position, in: ctx) {
                n += 1
            }
        }
        try? ctx.save()
        angehaengt = n
        fertig = true
    }
}
