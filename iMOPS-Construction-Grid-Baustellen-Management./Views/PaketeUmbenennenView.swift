//
//  PaketeUmbenennenView.swift
//
//  „342 Baukonstruktionen" sagt nichts. „342 Mauerwerk Innenwand Ytong PP 4-0,55,
//  d = 11,5 cm" sagt alles.
//
//  🔴 Mit Vorschau und einzeln abwählbar — es sind SEINE Daten. Und die Titelnummer
//  bleibt vorn: an ihr hängt die Zuordnung zu den LV-Positionen.
//

import SwiftUI
import CoreData

struct PaketeUmbenennenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var abgewaehlt: Set<NSManagedObjectID> = []
    @State private var vorschlaege: [(job: Auftrag, neu: String)] = []
    @State private var geladen = false

    private var gewaehlt: [(job: Auftrag, neu: String)] {
        vorschlaege.filter { !abgewaehlt.contains($0.job.objectID) }
    }

    var body: some View {
        NavigationStack {
            List {
                if vorschlaege.isEmpty {
                    ContentUnavailableView(
                        "Alle Namen sind in Ordnung",
                        systemImage: "checkmark.circle",
                        description: Text("Kein Arbeitspaket heisst bloss nach seiner "
                                          + "Kostengruppe."))
                } else {
                    Section {
                        ForEach(vorschlaege, id: \.job.objectID) { v in
                            Button {
                                if abgewaehlt.contains(v.job.objectID) {
                                    abgewaehlt.remove(v.job.objectID)
                                } else {
                                    abgewaehlt.insert(v.job.objectID)
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: abgewaehlt.contains(v.job.objectID)
                                          ? "circle" : "checkmark.circle.fill")
                                        .foregroundStyle(abgewaehlt.contains(v.job.objectID)
                                                         ? AnyShapeStyle(.secondary)
                                                         : AnyShapeStyle(Color.accentColor))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(v.job.processingDetails ?? "—")
                                            .font(.caption).foregroundStyle(.secondary)
                                            .strikethrough()
                                        Text(v.neu)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(gewaehlt.count) von \(vorschlaege.count) werden umbenannt")
                    } footer: {
                        Text("Der neue Name ist der erste Positionstext des Titels — den "
                             + "hat der Kalkulator geschrieben. Die Nummer bleibt vorn "
                             + "stehen: an ihr hängt die Zuordnung zu den LV-Positionen.")
                    }
                }
            }
            .navigationTitle("Namen verbessern")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !geladen else { return }
                geladen = true
                vorschlaege = Arbeitspakete.umbenennbare(in: event)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Umbenennen") {
                        for v in gewaehlt { v.job.processingDetails = v.neu }
                        try? ctx.save()
                        dismiss()
                    }
                    .disabled(gewaehlt.isEmpty)
                }
            }
        }
    }
}
