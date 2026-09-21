//
//  MaterialPapiereView.swift
//
//  Die Papiere zu den Materialien einer Baustelle — was da ist und was fehlt.
//
//  „Eine Baustelle ist nicht fertig geplant, wenn nicht für jedes Teil ein
//   Sicherheitsdatenblatt vorhanden ist." (Andreas, Nacht 21./22.09.2026)
//
//  🔴 Die Liste zeigt ALLE Materialien, nicht nur die Lücken — wer nachsehen will,
//  ob etwas da ist, soll es sehen und nicht aus dem Fehlen einer Meldung schliessen.
//

import SwiftUI
import CoreData

struct MaterialPapiereView: View {
    @Environment(\.managedObjectContext) private var ctx
    let event: Event

    @State private var stand = UUID()
    @State private var bearbeiten: String?

    /// Alle Materialnamen dieser Baustelle, einmal, alphabetisch.
    private var materialien: [String] {
        _ = stand
        let aus = ((event.lvPositionen as? Set<LVPosition>) ?? [])
            .flatMap { $0.materialArray }
            .compactMap { $0.materialName?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(aus)).sorted()
    }

    private var luecken: [MaterialPapierBuch.Luecke] {
        materialien.compactMap { MaterialPapierBuch.shared.luecke(fuer: $0) }
    }

    var body: some View {
        List {
            if materialien.isEmpty {
                ContentUnavailableView(
                    "Noch kein Material",
                    systemImage: "shippingbox",
                    description: Text("Materialien entstehen über die Rezepte der "
                                      + "LV-Positionen. Ohne die gibt es nichts zu belegen."))
            } else {
                Section {
                    let offen = luecken.filter { $0.sdbFehlt || $0.sdbVeraltet }.count
                    if offen == 0 {
                        Label("Für alle Gefahrstoffe liegt ein gültiges Sicherheitsdatenblatt vor.",
                              systemImage: "checkmark.seal")
                            .font(.subheadline).foregroundStyle(.green)
                    } else {
                        Label(offen == 1
                              ? "Ein Gefahrstoff ohne gültiges Sicherheitsdatenblatt."
                              : "\(offen) Gefahrstoffe ohne gültiges Sicherheitsdatenblatt.",
                              systemImage: "doc.badge.ellipsis")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                    }
                } footer: {
                    Text("Verlangt wird das Sicherheitsdatenblatt nur für Gefahrstoffe "
                         + "(Zement, Bitumen, Harze, Lösemittel …). Schotter und "
                         + "Pflastersteine brauchen keins.")
                }

                ForEach(materialien, id: \.self) { m in
                    Button { bearbeiten = m } label: { zeile(m) }
                        .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Papiere")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { bearbeiten.map { Material(name: $0) } },
            set: { if $0 == nil { bearbeiten = nil } }
        )) { m in
            PapierBlattView(material: m.name) { stand = UUID() }
        }
    }

    private struct Material: Identifiable { let name: String; var id: String { name } }

    @ViewBuilder private func zeile(_ m: String) -> some View {
        let buch = MaterialPapierBuch.shared
        let gefahr = buch.istGefahrstoff(m)
        let vorhanden = buch.papiere(fuer: m)
        let luecke = buch.luecke(fuer: m)

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: luecke == nil ? "checkmark.circle" : "doc.badge.ellipsis")
                .foregroundStyle(luecke == nil ? Color.green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(m).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if gefahr {
                        Text("Gefahrstoff")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.orange.opacity(0.16), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                }
                if vorhanden.isEmpty {
                    Text(gefahr ? "Keine Papiere hinterlegt." : "Keine Papiere — für dieses Material auch keine nötig.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(vorhanden) { p in
                        Text("\(p.art.kurz): \(p.ablage)"
                             + (p.istVeraltet ? " · älter als drei Jahre" : ""))
                            .font(.caption)
                            .foregroundStyle(p.istVeraltet ? .orange : .secondary)
                    }
                }
                if let g = GefahrstoffKatalog.erkannt(m), gefahr {
                    Text(g.warum).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Ein Papier hinterlegen

struct PapierBlattView: View {
    @Environment(\.dismiss) private var dismiss
    let material: String
    var fertig: () -> Void = {}

    @State private var art: MaterialPapier.Art = .sicherheitsdatenblatt
    @State private var ablage = ""
    @State private var stand = Date()
    @State private var wer = ""
    @State private var gefahrstoff = true
    @State private var geladen = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(material).font(.subheadline.weight(.semibold))
                    Toggle("Gefahrstoff", isOn: $gefahrstoff)
                } footer: {
                    if let g = GefahrstoffKatalog.erkannt(material) {
                        Text("Der Mops vermutet: \(g.bezeichnung). \(g.warum)\n"
                             + "Das ist aus dem Namen geraten — wenn du es besser "
                             + "weisst, stell es um.")
                    } else {
                        Text("Der Mops erkennt hier keinen Gefahrstoff. Wenn doch, "
                             + "stell es um — er rät nur am Namen.")
                    }
                }

                Section {
                    Picker("Art", selection: $art) {
                        ForEach(MaterialPapier.Art.allCases, id: \.self) {
                            Text($0.kurz).tag($0)
                        }
                    }
                    TextField("Dateiname oder wo es liegt", text: $ablage)
                    DatePicker("Stand", selection: $stand, displayedComponents: .date)
                    TextField("Dein Name", text: $wer)
                } header: {
                    Text("Papier hinterlegen")
                } footer: {
                    Text(art == .sicherheitsdatenblatt
                         ? "Pflicht nach GefStoffV. Gilt hier als zu prüfen, wenn es "
                           + "älter als drei Jahre ist."
                         : "Kein Pflichtpapier — aber hier steht die Trocknungszeit.")
                }

                let vorhanden = MaterialPapierBuch.shared.papiere(fuer: material)
                if !vorhanden.isEmpty {
                    Section("Schon hinterlegt") {
                        ForEach(vorhanden) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.art.kurz).font(.subheadline)
                                Text(p.ablage).font(.caption).foregroundStyle(.secondary)
                                if let s = p.stand {
                                    Text("Stand \(s.formatted(.dateTime.month().year()))"
                                         + (p.istVeraltet ? " · zu prüfen" : ""))
                                        .font(.caption2)
                                        .foregroundStyle(p.istVeraltet ? .orange : .secondary)
                                }
                            }
                            .swipeActions {
                                Button("Entfernen", role: .destructive) {
                                    MaterialPapierBuch.shared.entfernen(p.art, fuer: material)
                                    fertig()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Papiere")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !geladen else { return }
                geladen = true
                gefahrstoff = MaterialPapierBuch.shared.istGefahrstoff(material)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merken") {
                        MaterialPapierBuch.shared.einstufen(material, istGefahrstoff: gefahrstoff)
                        let sauber = ablage.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sauber.isEmpty {
                            MaterialPapierBuch.shared.hinterlegen(
                                MaterialPapier(art: art, ablage: sauber, stand: stand,
                                               hinterlegtVon: wer.trimmingCharacters(in: .whitespaces)),
                                fuer: material)
                        }
                        fertig()
                        dismiss()
                    }
                }
            }
        }
    }
}
