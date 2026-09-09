//
//  VoraussetzungWaehlenView.swift
//  „Worauf soll dieser Auftrag warten?" — die Auswahl des Vorgängers.
//
//  Zeigt die Geschwister-Aufträge derselben Baustelle. Wer schon verknüpft ist
//  oder der Auftrag selbst ist, steht nicht in der Liste — die Regel dafür lebt
//  in `AuftragDetailView.moeglicheVorgaenger(fuer:)`, damit Liste und Knopf
//  („+" ist aus, wenn nichts mehr wählbar ist) nicht auseinanderlaufen können.
//
//  Ein Kreis wird hier NICHT vorab ausgefiltert: `Kausalkette.verknuepfe` prüft
//  ihn und wirft mit einer Begründung, die beide Auftragsnamen nennt. Die zeigt
//  die Detailansicht an. Einen Auftrag stumm aus der Liste zu lassen, wäre die
//  schlechtere Auskunft — der Nutzer wüsste nicht, warum er fehlt.
//

import SwiftUI
import CoreData

struct VoraussetzungWaehlenView: View {
    @Environment(\.dismiss) private var dismiss

    let auftrag: Auftrag
    let gewaehlt: (Auftrag) -> Void

    private var auswahl: [Auftrag] {
        AuftragDetailView.moeglicheVorgaenger(fuer: auftrag)
    }

    var body: some View {
        NavigationStack {
            Group {
                if auswahl.isEmpty {
                    ContentUnavailableView {
                        Label("Niemand übrig", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("Auf dieser Baustelle gibt es keinen weiteren Auftrag, "
                             + "auf den dieser noch warten könnte.")
                    }
                } else {
                    List(auswahl, id: \.objectID) { kandidat in
                        Button {
                            gewaehlt(kandidat)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Kausalkette.bezeichnung(kandidat))
                                    if let kg = kandidat.kostenGruppeNummer, !kg.isEmpty {
                                        Text("KG \(kg)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(kandidat.status.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Wartet auf …")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
