//
//  TeilbarePaketeView.swift
//
//  Alle Pakete einer Baustelle, in denen zwei verschiedene Arbeiten stecken.
//
//  🔴 Andreas nach dem Neuanlegen von BV Setiadji: „sieht für mich nicht viel anders
//  aus und es sind wieder 34 Einträge, das ist richtig?" — Ja: der Mops teilt nicht
//  selbst, das ist Absicht. Aber ohne diese Liste findet man die Vorschläge nie,
//  und dann ist die Arbeit gebaut und ruft keiner. Genau das Muster, das wir hier
//  seit gestern jagen.
//

import SwiftUI
import CoreData

struct TeilbarePaketeView: View {
    @Environment(\.managedObjectContext) private var ctx
    let event: Event

    @State private var stand = UUID()
    @State private var teilen: Auftrag?

    private var pakete: [(job: Auftrag, vorschlaege: [Arbeitspakete.Teilung])] {
        _ = stand
        return ((event.jobs?.allObjects as? [Auftrag]) ?? [])
            .map { ($0, Arbeitspakete.teilungsVorschlaege(fuer: $0)) }
            .filter { !$0.1.isEmpty }
            .sorted { Kausalkette.bezeichnung($0.job) < Kausalkette.bezeichnung($1.job) }
    }

    var body: some View {
        List {
            Section {
                Text("Arbeitspakete entstehen nach der Titelnummer, und die folgt der "
                     + "DIN 276. Die sortiert nach Kosten, nicht nach Bauablauf — "
                     + "deshalb steckt manchmal der Graben mit dem Waschbecken in "
                     + "einem Paket.")
                    .font(.footnote).foregroundStyle(.secondary)
            } footer: {
                Text("Der Mops teilt nichts von selbst. Jeder Vorschlag ist geraten — "
                     + "du entscheidest, und nichts muss geteilt werden.")
            }

            ForEach(pakete, id: \.job.objectID) { eintrag in
                Section {
                    ForEach(Array(eintrag.vorschlaege.enumerated()), id: \.offset) { _, v in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(v.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(v.abtrennen.count)")
                                    .font(.caption.weight(.bold)).foregroundStyle(.blue)
                            }
                            Text(v.begruendung).font(.caption).foregroundStyle(.secondary)
                            ForEach(v.abtrennen.prefix(3), id: \.objectID) { p in
                                Text("· \(p.bezeichnung ?? "")")
                                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Button { teilen = eintrag.job } label: {
                        Label("Dieses Paket teilen", systemImage: "square.split.2x1")
                            .font(.subheadline)
                    }
                } header: {
                    Text(Kausalkette.bezeichnung(eintrag.job))
                }
            }
        }
        .navigationTitle("Zwei Arbeiten in einem")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $teilen) { job in
            PaketTeilenView(job: job).environment(\.managedObjectContext, ctx)
        }
        .onChange(of: teilen) { _, neu in if neu == nil { stand = UUID() } }
    }
}
