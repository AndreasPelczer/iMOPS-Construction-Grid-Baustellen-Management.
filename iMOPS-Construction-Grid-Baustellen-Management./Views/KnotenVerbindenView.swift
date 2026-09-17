import SwiftUI
import CoreData

/// Zwei Aufträge einer Baustelle von Hand verketten: „das eine muss vor dem anderen
/// fertig sein". Nativ, weil die Canvas-Leinwand ein kompiliertes React-Bundle ist und
/// nur liest — die Kante zeichnet sie danach von selbst (sie kommt aus `Voraussetzung`).
/// Nutzt die vorhandene `Kausalkette` (mit Zyklus-Schutz), erfindet nichts Neues.
struct KnotenVerbindenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var zuerst: Auftrag?   // Voraussetzung (quelle)
    @State private var danach: Auftrag?   // braucht die erste (ziel)
    @State private var fehler: String?
    @State private var neuZaehler = 0     // erzwingt Neuberechnung der Kanten-Liste

    private var auftraege: [Auftrag] {
        ((event.jobs?.allObjects as? [Auftrag]) ?? [])
            .sorted { Kausalkette.bezeichnung($0) < Kausalkette.bezeichnung($1) }
    }

    /// Bestehende Verbindungen (echte Graph-Kanten) — zum Anzeigen und Lösen.
    private var kanten: [Kante] {
        _ = neuZaehler
        var out: [Kante] = []
        for ziel in auftraege {
            for v in ziel.voraussetzungenArray where v.istKante {
                if let quelle = v.quelle {
                    out.append(Kante(id: v.id ?? UUID(), zuerst: quelle, danach: ziel))
                }
            }
        }
        return out
    }

    private struct Kante: Identifiable {
        let id: UUID
        let zuerst: Auftrag
        let danach: Auftrag
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    picker("Was muss zuerst fertig sein?", auswahl: $zuerst)
                    picker("Was kommt danach?", auswahl: $danach)
                    Button {
                        verbinde()
                    } label: {
                        Label("Verbinden", systemImage: "arrow.triangle.branch")
                    }
                    .disabled(zuerst == nil || danach == nil)
                } header: {
                    Text("Neue Verbindung")
                } footer: {
                    if let z = zuerst, let d = danach, z !== d {
                        Text("Zuerst „\(Kausalkette.bezeichnung(z))“, dann „\(Kausalkette.bezeichnung(d))“.")
                    } else {
                        Text("Der Pfeil zeigt vom Ersten zum Zweiten — Fundament vor Estrich.")
                    }
                }

                if kanten.isEmpty {
                    Section("Bestehende Verbindungen") {
                        Text("Noch keine Verbindung angelegt.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Bestehende Verbindungen") {
                        ForEach(kanten) { kante in
                            HStack(spacing: 8) {
                                Text(Kausalkette.bezeichnung(kante.zuerst))
                                Image(systemName: "arrow.right")
                                    .font(.caption).foregroundStyle(.orange)
                                Text(Kausalkette.bezeichnung(kante.danach))
                            }
                            .font(.subheadline)
                        }
                        .onDelete(perform: loese)
                    }
                }
            }
            .navigationTitle("Knoten verbinden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
            .alert("Geht nicht", isPresented: Binding(get: { fehler != nil },
                                                      set: { if !$0 { fehler = nil } })) {
                Button("OK") { fehler = nil }
            } message: { Text(fehler ?? "") }
        }
    }

    private func picker(_ titel: String, auswahl: Binding<Auftrag?>) -> some View {
        Picker(titel, selection: auswahl) {
            Text("— wählen —").tag(Auftrag?.none)
            ForEach(auftraege, id: \.objectID) { a in
                Text(Kausalkette.bezeichnung(a)).tag(Optional(a))
            }
        }
    }

    private func verbinde() {
        guard let quelle = zuerst, let ziel = danach else { return }
        do {
            try Kausalkette.verknuepfe(ziel, brauchtVorher: quelle, in: viewContext)
            try viewContext.save()
            zuerst = nil
            danach = nil
            neuZaehler += 1
        } catch {
            fehler = error.localizedDescription
        }
    }

    private func loese(_ indizes: IndexSet) {
        let liste = kanten
        for i in indizes {
            let kante = liste[i]
            Kausalkette.entknuepfe(kante.danach, brauchtNichtMehr: kante.zuerst, in: viewContext)
        }
        try? viewContext.save()
        neuZaehler += 1
    }
}
