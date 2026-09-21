//
//  AnweisungVorschlagView.swift
//
//  Raphis Bildschirm: Vorschlag holen, durchsehen, abnicken.
//
//  Andreas, 21.09.2026: „Raphi kommt auf die View, keine Einzelschritte angelegt,
//  drückt ‚Mops schlägt Schritte vor', lässt Schritte vorschlagen, nickt sie ab,
//  ändert, vervollständigt sie — und sie sind da?"  Genau so.
//
//  🔴 Nichts wird stillschweigend übernommen. Jeder Schritt steht mit seiner Ampel da:
//     🟡 Vorschlag, reiner Handgriff  — wer ihn liest, kann ihn abnehmen
//     🔴 Vorschlag MIT ZAHL           — da muss ein Fachmann ran
//     🟢 abgenommen oder selbst getippt
//
//  Und beim Übernehmen wandert nur das Abgenommene in den Katalog: ein Vorschlag,
//  den niemand angeschaut hat, soll sich nicht über alle Baustellen vermehren.
//

import SwiftUI
import CoreData

struct AnweisungVorschlagView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var job: Auftrag
    /// Wird mit den übernommenen Schritten gerufen.
    let uebernehmen: ([AnweisungsSchritt]) -> Void

    @State private var schritte: [AnweisungsSchritt] = []
    @State private var laeuft = false
    @State private var fehler: String?
    @State private var modell: String?
    @State private var wer = ""
    @State private var neuerText = ""

    /// Abgewählte Schritte — sie bleiben sichtbar, gehen aber nicht in den Auftrag.
    /// „Ich brauche keinen Bauzaun für einen Pfosten, den ich setze."
    @State private var abgewaehlt: Set<String> = []
    /// Schritt-ID → Sache, die im LV dieser Baustelle nicht vorkommt.
    @State private var fehltImLV: [String: String] = [:]

    private var gewaehlte: [AnweisungsSchritt] { schritte.filter { !abgewaehlt.contains($0.id) } }

    private var offeneAbnahmen: Int { gewaehlte.filter { $0.herkunft.brauchtAbnahme && !$0.istAbgenommen }.count }
    private var mitWert: Int { gewaehlte.filter { $0.traegtWert && !$0.istAbgenommen }.count }
    private var kannUebernehmen: Bool {
        !gewaehlte.isEmpty && !wer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if schritte.isEmpty { start } else { liste }
            }
            .navigationTitle("Arbeitsschritte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        uebernehmen(gewaehlte)
                        dismiss()
                    }
                    .disabled(!kannUebernehmen)
                }
            }
            .onAppear { ausDemKatalog() }
        }
    }

    // MARK: - Start

    @ViewBuilder private var start: some View {
        Section {
            Text(Kausalkette.bezeichnung(job)).font(.headline)
            Text("Für diese Arbeit gibt es noch keine Schritte. Der Mops kann welche "
                 + "vorschlagen — er kennt Leistungstext, Material und Gerät aus dem Rezept.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        Section {
            Button {
                Task { await holen() }
            } label: {
                HStack {
                    Label("Mops, wie geht das?", systemImage: "questionmark.bubble")
                        .font(.headline)
                    Spacer()
                    if laeuft { ProgressView() }
                }
            }
            .disabled(laeuft)

            Button {
                schritte = AnweisungsAssistent.ausRezept(job)
                passungPruefen()
                if schritte.isEmpty { fehler = "Zu dieser Position ist kein Rezept hinterlegt." }
            } label: {
                Label("Gerüst aus dem Rezept", systemImage: "shippingbox")
            }
        } footer: {
            Text("Der Mops fragt seinen Server. Antwortet der nicht, kommt ein ehrlicher "
                 + "Fehler — keine erfundene Liste. Das Gerüst aus dem Rezept kommt ohne "
                 + "KI aus: Material, Gerät, Aufmaß.")
        }
        if let fehler {
            Section {
                Label(fehler, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange).font(.subheadline)
            }
        }
    }

    // MARK: - Liste zum Abnicken

    @ViewBuilder private var liste: some View {
        Section {
            ForEach($schritte) { $s in
                zeile($s)
            }
            .onDelete { schritte.remove(atOffsets: $0) }
            .onMove { schritte.move(fromOffsets: $0, toOffset: $1) }

            HStack(spacing: 10) {
                TextField("Schritt ergänzen…", text: $neuerText)
                    .id("ergaenzen")
                Button {
                    let t = neuerText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    schritte.append(AnweisungsSchritt(text: t, herkunft: .selbst))
                    neuerText = ""
                } label: { Image(systemName: "plus.circle.fill") }
                .disabled(neuerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } header: {
            HStack {
                Text(abgewaehlt.isEmpty ? "\(schritte.count) Schritte"
                     : "\(gewaehlte.count) von \(schritte.count) gewählt")
                Spacer()
                if let modell { Text(modell).font(.caption2).foregroundStyle(.secondary) }
            }
        } footer: {
            Text("Wischen zum Löschen, gedrückt halten zum Verschieben. "
                 + "Was du änderst, gilt als selbst geschrieben.")
        }

        Section {
            TextField("Dein Name", text: $wer).id("abnehmer")
            Button {
                let jetzt = Date()
                for i in schritte.indices
                where !schritte[i].istAbgenommen && !schritte[i].traegtWert
                   && !abgewaehlt.contains(schritte[i].id) {
                    schritte[i].abgenommenVon = wer
                    schritte[i].abgenommenAm = jetzt
                }
            } label: {
                Label("Alle ohne Zahl abnehmen", systemImage: "checkmark.circle")
            }
            .disabled(wer.trimmingCharacters(in: .whitespaces).isEmpty)
        } header: {
            Text("Abnahme")
        } footer: {
            if mitWert > 0 {
                Text("🔴 \(mitWert) Schritt\(mitWert == 1 ? "" : "e") tragen eine Zahl. "
                     + "Die bleiben offen, bis jemand draufgeschaut hat, der den Wert "
                     + "beurteilen kann — eine Zahl sieht immer plausibel aus.")
            } else if offeneAbnahmen > 0 {
                Text("\(offeneAbnahmen) noch ohne Abnahme.")
            } else {
                Text("Alles abgenommen. Beim Übernehmen merkt sich der Mops die Anweisung "
                     + "für die nächste Baustelle.")
            }
        }
    }

    private func zeile(_ s: Binding<AnweisungsSchritt>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                // Der Griff, mit dem man einen Schritt für DIESE Baustelle wegnimmt.
                Button {
                    let id = s.wrappedValue.id
                    if abgewaehlt.contains(id) { abgewaehlt.remove(id) } else { abgewaehlt.insert(id) }
                } label: {
                    Image(systemName: abgewaehlt.contains(s.wrappedValue.id)
                          ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(abgewaehlt.contains(s.wrappedValue.id) ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                }
                .buttonStyle(.plain)

                Text(s.wrappedValue.ampel)
                TextField("Schritt", text: s.text, axis: .vertical)
                    .lineLimit(1...4)
                    .strikethrough(abgewaehlt.contains(s.wrappedValue.id))
                    .foregroundStyle(abgewaehlt.contains(s.wrappedValue.id) ? .secondary : .primary)
                    .onChange(of: s.wrappedValue.text) { _, neu in
                        // Wer den Text anfasst, übernimmt ihn.
                        s.wrappedValue.herkunft = .selbst
                        s.wrappedValue.traegtWert = Werterkennung.traegtWert(neu)
                    }
            }
            HStack(spacing: 8) {
                Text(s.wrappedValue.herkunft.kurz)
                    .font(.caption2).foregroundStyle(.secondary)
                // Eine Tatsache, kein Urteil — der Schritt ist nur vorab abgewählt.
                if let sache = fehltImLV[s.wrappedValue.id] {
                    Text("· \(sache) kommt im LV nicht vor")
                        .font(.caption2).foregroundStyle(.orange)
                }
                if let von = s.wrappedValue.abgenommenVon {
                    Text("· abgenommen von \(von)")
                        .font(.caption2).foregroundStyle(.green)
                } else if s.wrappedValue.herkunft.brauchtAbnahme {
                    Button(s.wrappedValue.traegtWert ? "Wert geprüft" : "Abnehmen") {
                        s.wrappedValue.abgenommenVon = wer.isEmpty ? "—" : wer
                        s.wrappedValue.abgenommenAm = Date()
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .disabled(wer.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Spacer()
            }
            .padding(.leading, 26)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Holen

    /// Nach jedem Befüllen: was nennt eine Sache, die es auf dieser Baustelle nicht gibt?
    /// Die wird gleich abgewählt — ein Griff, und sie ist wieder drin.
    private func passungPruefen() {
        fehltImLV = SchrittPassung.fehlende(in: schritte, auftrag: job)
        for (id, _) in fehltImLV { abgewaehlt.insert(id) }
    }

    private func ausDemKatalog() {
        guard schritte.isEmpty else { return }
        if let bekannt = AnweisungsKatalog.shared.schritte(fuer: Kausalkette.bezeichnung(job)) {
            schritte = bekannt
            modell = "aus dem Katalog — schon einmal abgenommen"
            passungPruefen()
        }
    }

    @MainActor
    private func holen() async {
        laeuft = true; fehler = nil
        defer { laeuft = false }
        do {
            let s = try await AnweisungsAssistent.hole(fuer: job)
            if s.isEmpty {
                fehler = "Der Mops hat geantwortet, aber keine Schritte geliefert."
            } else {
                schritte = s
                modell = s.first?.modell
                passungPruefen()
            }
        } catch {
            fehler = "Der Mops ist nicht erreichbar: \(error.localizedDescription) "
                   + "— du kannst die Schritte selbst schreiben oder das Gerüst aus dem Rezept nehmen."
        }
    }
}
