//
//  PaketTeilenView.swift
//
//  Ein Titel ist kein Arbeitspaket.
//
//  🔴 Der Befund vom 22.09.2026: „411 Abwasser-, Wasser-, Gasanlagen" enthielt einen
//  Schmutzwasser-Hausanschluss in 2,60 m Tiefe UND die Sanitärinstallation im
//  Dachgeschoss. Zwei Kolonnen, ein halbes Jahr Abstand, ein Paket.
//
//  Ursache: `Arbeitspakete` gruppiert nach Titelnummer, und die folgt der DIN 276.
//  Die DIN 276 ist aber eine KOSTENgliederung — sie sortiert nach „wozu gehört das
//  Geld", nicht nach „wer macht wann was". KG 410 heisst „alles mit Wasser", vom
//  Graben bis zum Waschbecken. Der Denkfehler stand wörtlich im Kommentar von
//  `Arbeitspakete.swift`: „die DIN 276 folgt grob dem Bauablauf". Tut sie nicht.
//
//  🔴 Der Mops TEILT NICHT SELBST. Er schlägt vor, woran er eine Trennlinie vermutet
//  (Erdarbeiten gegen Innenausbau), und der Mensch hakt an. Andreas' Satz vom Vortag:
//  „eine Baustelle ist immer baustellen- und situationsabhängig, es ist nie gleich."
//

import SwiftUI
import CoreData

struct PaketTeilenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let job: Auftrag

    @State private var ausgewaehlt: Set<NSManagedObjectID> = []
    @State private var neuerName = ""
    @State private var geladen = false

    private var positionen: [LVPosition] { Arbeitspakete.positionen(fuer: job) }
    private var titelNr: String { Arbeitspakete.titelNummerAusName(job) ?? "" }

    private var gewaehlte: [LVPosition] {
        positionen.filter { ausgewaehlt.contains($0.objectID) }
    }
    private var bleiben: [LVPosition] {
        positionen.filter { !ausgewaehlt.contains($0.objectID) }
    }

    private var kannTeilen: Bool {
        !gewaehlte.isEmpty && !bleiben.isEmpty
        && !neuerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if let vorschlag = Arbeitspakete.teilungsVorschlag(fuer: job), ausgewaehlt.isEmpty {
                    Section {
                        Button {
                            ausgewaehlt = Set(vorschlag.abtrennen.map(\.objectID))
                            neuerName = vorschlag.name
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Vorschlag übernehmen", systemImage: "wand.and.stars")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(vorschlag.abtrennen.count) Positionen abtrennen als: \(vorschlag.name)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Der Mops vermutet eine Trennlinie")
                    } footer: {
                        Text(vorschlag.begruendung + " Das ist geraten — sieh es dir an.")
                    }
                }

                Section {
                    ForEach(positionen, id: \.objectID) { p in
                        Button {
                            if ausgewaehlt.contains(p.objectID) { ausgewaehlt.remove(p.objectID) }
                            else { ausgewaehlt.insert(p.objectID) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: ausgewaehlt.contains(p.objectID)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(ausgewaehlt.contains(p.objectID)
                                                     ? AnyShapeStyle(Color.accentColor)
                                                     : AnyShapeStyle(.secondary))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.bezeichnung ?? "ohne Text")
                                        .font(.subheadline).lineLimit(2)
                                    Text("\(p.posNr ?? "—") · \(mengeKurz(p.menge)) \(p.einheit ?? "")")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Was soll in das neue Paket?")
                } footer: {
                    Text("Angehakte Positionen wandern in ein neues Arbeitspaket. "
                         + "Der Rest bleibt hier.")
                }

                if !gewaehlte.isEmpty {
                    Section {
                        TextField("Name des neuen Pakets", text: $neuerName)
                        Text("Heisst dann: \(titelNr)a \(neuerName)")
                            .font(.caption).foregroundStyle(.secondary)
                    } header: {
                        Text("Das neue Paket")
                    } footer: {
                        Text("🔴 Die Titelnummer bleibt vorn — an ihr hängt die Zuordnung "
                             + "zu den LV-Positionen. Das alte Paket behält \(titelNr), "
                             + "das neue bekommt \(titelNr)a.")
                    }
                }
            }
            .navigationTitle("Paket teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Teilen") { teilen() }.disabled(!kannTeilen)
                }
            }
        }
    }

    /// 🔴 Die Positionen werden NICHT verschoben — sie hängen über die Titelnummer
    /// am Paket, und die kann nur eine sein. Das neue Paket bekommt deshalb die
    /// abgetrennten Positionen fest zugewiesen (`LVPosition.auftrag`), und die
    /// Zuordnung über den Namen tritt dahinter zurück.
    private func teilen() {
        guard let event = job.event else { return }
        let neu = Auftrag(context: ctx)
        neu.processingDetails = "\(titelNr)a \(neuerName.trimmingCharacters(in: .whitespacesAndNewlines))"
        neu.status = .pending
        neu.storageNote = ""
        neu.storageLocation = ""
        neu.event = event
        neu.dauerTage = 0

        do {
            // Erst speichern — vorher hat der neue Auftrag keine feste Kennung,
            // und die braucht die Zuordnung.
            try ctx.save()
            PaketZuordnung.shared.setzen(gewaehlte.compactMap { $0.posNr }, fuer: neu)
            PaketZuordnung.shared.setzen(bleiben.compactMap { $0.posNr }, fuer: job)
            dismiss()
        } catch {
            ctx.rollback()
        }
    }

    private func mengeKurz(_ w: Double) -> String {
        w == w.rounded() ? String(format: "%.0f", w) : String(format: "%.2f", w)
    }
}
