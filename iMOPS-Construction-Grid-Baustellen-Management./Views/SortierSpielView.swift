//
//  SortierSpielView.swift
//  Das 5-Minuten-Warm-up für den Lehrling: die heutigen Aufträge kommen gemischt,
//  er zieht sie in die richtige Bauablauf-Reihenfolge. Geprüft wird gegen die
//  Kausalkette des Mops (`Bauablauf`) — der Antwortschlüssel existiert schon, keine
//  zweite Wahrheit. Ist die Reihenfolge richtig, schalten sich die Tagesaufgaben frei.
//
//  Übungsraum, nicht Prüfung: hier darf man falsch liegen, ohne dass eine Mauer
//  krumm wird. Überspringen ist erlaubt (spielerischer Schubs, kein hartes Tor).
//

import SwiftUI
import CoreData

struct SortierSpielView: View {
    let event: Event
    var onFertig: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var jobs: [Auftrag] = []
    @State private var gewonnen = false
    @State private var versuche = 0
    @State private var hinweisID: NSManagedObjectID? = nil

    var body: some View {
        NavigationStack {
            Group {
                if gewonnen {
                    gewinnAnsicht
                } else {
                    spielAnsicht
                }
            }
            .navigationTitle("Reihenfolge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Überspringen") { fertig() }
                }
            }
        }
        .onAppear(perform: mischen)
    }

    // MARK: - Spiel

    private var spielAnsicht: some View {
        VStack(spacing: 0) {
            kopf
            spielListe
            fuss
        }
    }

    private var kopf: some View {
        VStack(spacing: 6) {
            Text("🧱 In welcher Reihenfolge wird gebaut?")
                .font(.headline)
            Text("Zieh die Aufgaben von oben nach unten in die richtige Reihenfolge.")
                .font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var spielListe: some View {
        List {
            ForEach(jobs, id: \.objectID) { job in
                zeile(job: job)
            }
            .onMove { from, to in
                jobs.move(fromOffsets: from, toOffset: to)
                hinweisID = nil
            }
        }
        .environment(\.editMode, .constant(.active))
        .listStyle(.insetGrouped)
    }

    private func zeile(job: Auftrag) -> some View {
        let markiert = hinweisID == job.objectID
        let nr = (jobs.firstIndex { $0.objectID == job.objectID } ?? 0) + 1
        return HStack(spacing: 12) {
            Text("\(nr)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 26)
            Text(titel(job))
                .font(.body)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .listRowBackground(markiert ? Color.orange.opacity(0.18)
                                     : Color(.secondarySystemGroupedBackground))
    }

    private var fuss: some View {
        VStack(spacing: 8) {
            if versuche > 0, hinweisID != nil {
                Text("Fast! Ein Schritt steht noch zu früh — schau die markierte Zeile an.")
                    .font(.caption).foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            Button(action: pruefen) {
                Text("Prüfen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Gewinn

    private var gewinnAnsicht: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🎉").font(.system(size: 64))
            Text("Reihenfolge sitzt!")
                .font(.title2.bold())
            Text(versuche == 0
                 ? "Auf Anhieb richtig — sauber."
                 : "Geschafft nach \(versuche) \(versuche == 1 ? "Versuch" : "Versuchen"). So wird gebaut.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Label("Tagesaufgaben freigeschaltet", systemImage: "lock.open.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.top, 4)
            Spacer()
            Button(action: fertig) {
                Text("Weiter zu den Aufgaben")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logik

    private func titel(_ job: Auftrag) -> String {
        if let d = job.processingDetails, !d.isEmpty { return d }
        return "Auftrag"
    }

    /// Offene Aufträge laden und mischen — aber nie in bereits gültiger Reihenfolge starten
    /// (sonst wäre das Spiel schon gewonnen). Bei < 2 Aufgaben ist nichts zu ordnen.
    private func mischen() {
        let offen = ((event.jobs?.allObjects as? [Auftrag]) ?? []).filter { !$0.istFertig }
        guard offen.count >= 2 else { fertig(); return }
        var gemischt = offen.shuffled()
        var schutz = 0
        while Bauablauf.istGueltigeReihenfolge(gemischt) && schutz < 12 {
            gemischt.shuffle(); schutz += 1
        }
        jobs = gemischt
        gewonnen = false
        versuche = 0
        hinweisID = nil
    }

    private func pruefen() {
        if Bauablauf.istGueltigeReihenfolge(jobs) {
            withAnimation(.snappy) { gewonnen = true }
        } else {
            versuche += 1
            withAnimation { hinweisID = Bauablauf.ersterFehler(jobs)?.objectID }
        }
    }

    /// Erledigt (gewonnen ODER übersprungen): Warm-up für heute beruhigen, Blatt zu.
    private func fertig() {
        WarmupStore.erledigen(event)
        onFertig()
        dismiss()
    }
}
