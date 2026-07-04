import SwiftUI
import CoreData

// Welle 9 Stufe C, §5 — Ebenen-Freigabe & Voraussetzungs-Status.
// REINE STATUSANZEIGE: blockiert nichts (keine Sperre für Bestellungen/Bautagesbericht).

// MARK: - Übersicht: Baustelle → Gebäude (Rollup) → Geschoss

struct FreigabeStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var event: Event
    @State private var refreshID = UUID()

    private var gebaeude: [Gebaeude] { HierarchieHelfer.alleGebaeude(for: event) }

    var body: some View {
        NavigationStack {
            List {
                if gebaeude.isEmpty {
                    ContentUnavailableView("Keine Ebenen", systemImage: "building.2",
                        description: Text("Unter Ebenen verwalten Gebäude/Geschosse anlegen."))
                }
                ForEach(gebaeude, id: \.objectID) { geb in
                    Section {
                        ForEach(HierarchieHelfer.geschosse(of: geb), id: \.objectID) { g in
                            NavigationLink { GeschossFreigabeView(geschoss: g) } label: {
                                geschossZeile(g)
                            }
                        }
                    } header: {
                        HStack {
                            Text(geb.name ?? "Gebäude")
                            Spacer()
                            Circle().fill(geb.freigegeben ? .green : .gray)
                                .frame(width: 10, height: 10)
                            Text(geb.freigegeben ? "freigegeben" : "offen")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .id(refreshID)
            .navigationTitle("Ebenen-Freigabe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() }.tint(.orange) }
            }
            .onAppear { refreshID = UUID() }
        }
    }

    private func geschossZeile(_ g: Geschoss) -> some View {
        HStack(spacing: 12) {
            Circle().fill(GeschossStatus.farbe(g)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name ?? "Geschoss").font(.body)
                Text(GeschossStatus.text(g)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if g.freigegeben {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(g.istReif ? .green : .orange)
            }
        }
    }
}

// MARK: - Ampel-Mapping (View-Schicht, Modell bleibt UI-agnostisch)

enum GeschossStatus {
    static func farbe(_ g: Geschoss) -> Color {
        if g.freigegeben { return g.istReif ? .green : .orange }   // orange = frei trotz offener Voraussetzung
        return g.istReif ? .blue : .gray                            // blau = bereit, grau = noch offen
    }
    static func text(_ g: Geschoss) -> String {
        if g.freigegeben && !g.istReif { return "Freigegeben – Voraussetzungen offen ⚠︎" }
        if g.freigegeben { return "Freigegeben" }
        if g.istReif { return "Bereit zur Freigabe" }
        return "\(g.voraussetzungenErfuellt)/\(g.voraussetzungenGesamt) Voraussetzungen erfüllt"
    }
}

// MARK: - Detail: ein Geschoss (Voraussetzungen + Freigabe)

struct GeschossFreigabeView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var geschoss: Geschoss
    @State private var refreshID = UUID()

    var body: some View {
        List {
            Section {
                HStack {
                    Circle().fill(GeschossStatus.farbe(geschoss)).frame(width: 14, height: 14)
                    Text(GeschossStatus.text(geschoss)).font(.subheadline)
                }
            }

            Section {
                ForEach(Welle9AutoKatalog.alle) { v in
                    let ok = v.erfuellt(geschoss)
                    HStack {
                        Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(ok ? .green : .secondary)
                        Text(v.name)
                        Spacer()
                        Text("automatisch").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Automatisch (live berechnet)")
            }

            Section("Manuell (Polier hakt ab)") {
                if geschoss.manuelleVoraussetzungen.isEmpty {
                    Text("Keine manuellen Voraussetzungen.").font(.callout).foregroundStyle(.secondary)
                }
                ForEach(geschoss.manuelleVoraussetzungen, id: \.objectID) { v in
                    Toggle(isOn: Binding(get: { v.erfuellt },
                                         set: { v.erfuellt = $0; speicher() })) {
                        Text(v.name ?? "")
                    }
                    .tint(.orange)
                }
            }

            Section {
                Toggle(isOn: Binding(get: { geschoss.freigegeben },
                                     set: { setzeFreigabe($0) })) {
                    Label("Geschoss freigegeben", systemImage: "checkmark.seal")
                }
                .tint(.green)

                if geschoss.freigegeben {
                    if let am = geschoss.freigegebenAm {
                        Text("Freigegeben am \(am.formatted(date: .abbreviated, time: .shortened))"
                             + (geschoss.freigegebenVon.map { " · \($0)" } ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !geschoss.istReif {
                        Label("Freigegeben, obwohl noch Voraussetzungen offen sind.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Freigabe")
            } footer: {
                Text("Reine Statusanzeige — blockiert keine Bestellungen oder den Bautagesbericht.")
            }
        }
        .id(refreshID)
        .navigationTitle(geschoss.name ?? "Geschoss")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func speicher() { try? ctx.save(); refreshID = UUID() }

    private func setzeFreigabe(_ an: Bool) {
        geschoss.freigegeben = an
        geschoss.freigegebenAm = an ? Date() : nil
        geschoss.freigegebenVon = an ? FirmenSettings.name : nil
        speicher()
    }
}
