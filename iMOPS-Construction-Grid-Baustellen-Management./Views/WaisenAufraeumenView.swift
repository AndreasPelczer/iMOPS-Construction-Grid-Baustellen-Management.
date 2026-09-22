//
//  WaisenAufraeumenView.swift
//
//  Arbeitspakete, deren Baustelle gelöscht wurde.
//
//  🔴 Sie entstanden, weil `Event.jobs` im Modell auf Nullify steht: beim Löschen
//  einer Baustelle wurde nur die Verbindung gekappt. Seit dem 22.09.2026 gehen die
//  Aufträge mit (`BaustelleLoeschen`), aber was schon liegt, liegt.
//
//  Gemessen: 965 Stück, 323 verschiedene Namen, bis zu 23-mal dasselbe — die Reste
//  von 23 gelöschten Baustellen.
//
//  Das Aufräumen ist unwiderruflich, also steht vorher da, was verschwindet.
//

import SwiftUI
import CoreData

struct WaisenAufraeumenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    var fertig: () -> Void = {}

    @State private var liste: [Auftrag] = []
    @State private var geladen = false

    /// Wie oft kommt derselbe Name vor? Das zeigt, dass es Reste sind.
    private var haeufigste: [(name: String, anzahl: Int)] {
        Dictionary(grouping: liste) { ($0.processingDetails ?? "ohne Namen")
            .split(separator: "\n").first.map(String.init) ?? "ohne Namen" }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }

    private var mitInhalt: Int {
        liste.filter { !AuftragExtrasPayload.from($0.extras).checklist.isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(liste.count) Arbeitspakete gehören zu keiner Baustelle mehr. "
                         + "Kein Bildschirm zeigt sie, sie kosten ein knappes Megabyte — "
                         + "aber sie werden bei jedem Löschen mehr.")
                        .font(.subheadline)
                    if mitInhalt > 0 {
                        Label("\(mitInhalt) davon haben noch Arbeitsschritte hinterlegt.",
                              systemImage: "list.bullet.rectangle")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Was das ist")
                } footer: {
                    Text("Sie entstanden beim Löschen von Baustellen. Seit dem 22.09. "
                         + "gehen Arbeitspakete mit ihrer Baustelle mit — das hier ist "
                         + "der Altbestand.")
                }

                Section("Die häufigsten") {
                    ForEach(haeufigste.prefix(12), id: \.name) { e in
                        HStack {
                            Text(e.name).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text("\(e.anzahl)×")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    if haeufigste.count > 12 {
                        Text("und \(haeufigste.count - 12) weitere Namen")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Ohne Baustelle")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !geladen else { return }
                geladen = true
                liste = BaustelleLoeschen.waisen(in: ctx)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Alle löschen", role: .destructive) {
                        BaustelleLoeschen.raeumeWaisenAuf(in: ctx)
                        try? ctx.save()
                        fertig()
                        dismiss()
                    }
                    .disabled(liste.isEmpty)
                }
            }
        }
    }
}
