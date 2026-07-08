import SwiftUI
import CoreData

// Welle 9 (Stufe B) — Bau-Hierarchie verwalten: Gebäude und Geschosse anlegen,
// umbenennen, sortieren und löschen. Positionen werden über den Geschoss-Picker in
// AddLVPositionView zugeordnet; Löschen ist ungefährlich, weil die Position-Zuordnung
// per Nullify verfällt und der HierarchieHelfer beim nächsten LV-Öffnen ein
// Default-Geschoss sichert (self-healing).
struct HierarchieVerwaltenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var event: Event

    @State private var refreshID = UUID()
    @State private var nameEingabe: NameEingabe?
    @State private var loeschZiel: LoeschZiel?

    private var gebaeudeListe: [Gebaeude] { HierarchieHelfer.alleGebaeude(for: event) }

    var body: some View {
        NavigationStack {
            List {
                if gebaeudeListe.isEmpty {
                    ContentUnavailableView("Keine Ebenen", systemImage: "building.2",
                                           description: Text("Mit + ein Gebäude anlegen."))
                }
                ForEach(gebaeudeListe, id: \.objectID) { geb in
                    Section {
                        let geschosse = HierarchieHelfer.geschosse(of: geb)
                        if geschosse.isEmpty {
                            Text("Noch kein Geschoss.").font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(geschosse, id: \.objectID) { g in
                            Button { nameEingabe = .umbenennenGeschoss(g) } label: {
                                HStack {
                                    Label(g.name ?? "Geschoss", systemImage: "square.stack.3d.up")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(positionsAnzahl(g)) Pos.")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { loeschZiel = .geschoss(g) } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { indices, newOffset in
                            verschiebeGeschosse(in: geb, from: indices, to: newOffset)
                        }
                    } header: {
                        HStack {
                            Text(geb.name ?? "Gebäude")
                            Spacer()
                            Menu {
                                Button { nameEingabe = .neuesGeschoss(geb) } label: {
                                    Label("Geschoss hinzufügen", systemImage: "plus")
                                }
                                Button { nameEingabe = .umbenennenGebaeude(geb) } label: {
                                    Label("Gebäude umbenennen", systemImage: "pencil")
                                }
                                Button(role: .destructive) { loeschZiel = .gebaeude(geb) } label: {
                                    Label("Gebäude löschen", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            }
            .id(refreshID)
            .navigationTitle("Ebenen verwalten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { EditButton() }
                ToolbarItem(placement: .primaryAction) {
                    Button { nameEingabe = .neuesGebaeude } label: {
                        Label("Gebäude", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() }.tint(.orange) }
            }
            .sheet(item: $nameEingabe) { eingabe in
                NameEingabeSheet(titel: eingabe.titel, start: eingabe.startName) { name in
                    anwenden(eingabe, name: name)
                }
                .presentationSizing(.page)
            }
            .confirmationDialog("Löschen?",
                                isPresented: Binding(get: { loeschZiel != nil },
                                                     set: { if !$0 { loeschZiel = nil } }),
                                titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschen() }
                Button("Abbrechen", role: .cancel) { loeschZiel = nil }
            } message: {
                Text(loeschZiel?.warnung ?? "")
            }
        }
    }

    private func positionsAnzahl(_ g: Geschoss) -> Int {
        (g.lvPositionen as? Set<LVPosition>)?.count ?? 0
    }

    // MARK: - Mutationen

    private func speicher() {
        try? ctx.save()
        refreshID = UUID()
    }

    private func anwenden(_ eingabe: NameEingabe, name: String) {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return }
        switch eingabe {
        case .neuesGebaeude:
            HierarchieHelfer.neuesGebaeude(name: sauber, for: event, in: ctx)
        case .neuesGeschoss(let geb):
            HierarchieHelfer.neuesGeschoss(name: sauber, in: geb, context: ctx)
        case .umbenennenGebaeude(let geb):
            geb.name = sauber
        case .umbenennenGeschoss(let g):
            g.name = sauber
        }
        speicher()
    }

    private func verschiebeGeschosse(in gebaeude: Gebaeude, from: IndexSet, to: Int) {
        var arr = HierarchieHelfer.geschosse(of: gebaeude)
        arr.move(fromOffsets: from, toOffset: to)
        for (i, g) in arr.enumerated() { g.reihenfolge = Int16(i) }
        speicher()
    }

    private func loeschen() {
        switch loeschZiel {
        case .geschoss(let g):
            ctx.delete(g)              // Positionen: geschoss → nil (Nullify), self-heal beim Öffnen
        case .gebaeude(let geb):
            for g in HierarchieHelfer.geschosse(of: geb) { ctx.delete(g) }
            ctx.delete(geb)
        case .none:
            break
        }
        loeschZiel = nil
        speicher()
    }
}

// MARK: - Eingabe-Ziele

private enum NameEingabe: Identifiable {
    case neuesGebaeude
    case neuesGeschoss(Gebaeude)
    case umbenennenGebaeude(Gebaeude)
    case umbenennenGeschoss(Geschoss)

    var id: String {
        switch self {
        case .neuesGebaeude: return "neuesGebaeude"
        case .neuesGeschoss(let g): return "neuesGeschoss-\(g.objectID)"
        case .umbenennenGebaeude(let g): return "renGeb-\(g.objectID)"
        case .umbenennenGeschoss(let g): return "renGes-\(g.objectID)"
        }
    }

    var titel: String {
        switch self {
        case .neuesGebaeude: return "Neues Gebäude"
        case .neuesGeschoss: return "Neues Geschoss"
        case .umbenennenGebaeude: return "Gebäude umbenennen"
        case .umbenennenGeschoss: return "Geschoss umbenennen"
        }
    }

    var startName: String {
        switch self {
        case .neuesGebaeude, .neuesGeschoss: return ""
        case .umbenennenGebaeude(let g): return g.name ?? ""
        case .umbenennenGeschoss(let g): return g.name ?? ""
        }
    }
}

private enum LoeschZiel {
    case gebaeude(Gebaeude)
    case geschoss(Geschoss)

    var warnung: String {
        switch self {
        case .gebaeude(let g):
            let n = (g.geschosse as? Set<Geschoss>)?.count ?? 0
            return "\(g.name ?? "Gebäude") samt \(n) Geschoss(en) löschen. Zugeordnete Positionen fallen zurück aufs Default-Geschoss (beim nächsten Öffnen)."
        case .geschoss(let g):
            let n = (g.lvPositionen as? Set<LVPosition>)?.count ?? 0
            return "\(g.name ?? "Geschoss") löschen. Seine \(n) Position(en) fallen zurück aufs Default-Geschoss (beim nächsten Öffnen)."
        }
    }
}

// MARK: - Namens-Eingabe-Sheet

private struct NameEingabeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let titel: String
    @State private var text: String
    let onSave: (String) -> Void

    init(titel: String, start: String, onSave: @escaping (String) -> Void) {
        self.titel = titel
        self.onSave = onSave
        _text = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $text)
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { onSave(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                        .tint(.orange)
                }
            }
        }
        .presentationDetents([.height(180)])
    }
}
