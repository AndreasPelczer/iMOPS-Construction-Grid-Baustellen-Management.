//
//  TagesblickView.swift
//
//  Der Büro-Bildschirm aus dem Mockup vom 21.09. (`~/Desktop/iMOPS-Mockup-Buero.html`),
//  in der Reihenfolge, die Andreas abgenommen hat:
//
//      1. Wo du warst          — Wiedereinstieg nach der Unterbrechung
//      2. Blockiert jemanden   — wer steht gerade und wartet
//      3. Hat eine Frist       — überfällige Mängel, quer über alle Baustellen
//      4. Preise fehlen        — was noch kein Angebot werden kann
//
//  Nicht nach Baustelle sortiert, sondern danach, was jemanden aufhält. Wer steht,
//  kostet Geld. Die Zahlen kommen aus `Tagesblick` — dieselbe Rechnung wie im LV,
//  damit hier keine zweite Wahrheit entsteht.
//

import SwiftUI
import CoreData

struct TagesblickView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var blick = Tagesblick.Ergebnis()
    @State private var zielBaustelle: Event?

    var body: some View {
        List {
            if let z = blick.zuletzt {
                Section {
                    Button { zielBaustelle = z.event } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("WO DU WARST")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.blue)
                            Text(z.baustelle).font(.title3.weight(.semibold))
                            Text("zuletzt \(z.wann, format: .relative(presentation: .named))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if blick.istRuhig && blick.fristen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nichts steht",
                        systemImage: "checkmark.circle",
                        description: Text("Keine Blockade, keine überfällige Frist, keine Position ohne Preis. \(blick.baustellenAktiv) Baustellen laufen."))
                }
            }

            if !blick.blockaden.isEmpty {
                Section {
                    ForEach(blick.blockaden) { b in
                        Button { zielBaustelle = b.event } label: { zeile(b) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    kopf("Blockiert gerade jemanden", zahl: blick.blockaden.count)
                } footer: {
                    Text("Wer am längsten steht, steht oben.")
                }
            }

            if !blick.fristen.isEmpty {
                Section {
                    ForEach(blick.fristen) { f in
                        Button { zielBaustelle = f.event } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(f.ueberfaellig ? "🔴" : "🟠")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.titel).font(.body.weight(.semibold))
                                    Text(f.baustelle).font(.caption).foregroundStyle(.orange)
                                    Text(f.frist, format: .dateTime.day().month().year())
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    kopf("Hat eine Frist", zahl: blick.fristen.count)
                }
            }

            if !blick.preisluecken.isEmpty {
                Section {
                    ForEach(blick.preisluecken) { p in
                        Button { zielBaustelle = p.event } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.baustelle).font(.body.weight(.semibold))
                                    Text("\(p.betroffeneMenge) von \(p.anzahl) Positionen ohne unseren Preis")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(p.betroffeneMenge)")
                                    .font(.title3.weight(.bold)).foregroundStyle(.orange)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    kopf("Daraus wird noch kein Angebot", zahl: nil)
                } footer: {
                    Text("Gerechnet wie im LV: Angebot vor Element vor Eigenkalkulation.")
                }
            }
        }
        .navigationTitle("Wo war ich?")
        .navigationDestination(item: $zielBaustelle) { EventDetailView(event: $0) }
        .refreshable { laden() }
        .onAppear { laden() }
    }

    private func kopf(_ text: String, zahl: Int?) -> some View {
        HStack {
            Text(text)
            Spacer()
            if let zahl { Text("\(zahl)").foregroundStyle(.red).fontWeight(.bold) }
        }
    }

    private func zeile(_ b: Tagesblick.Blockade) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("⛔")
            VStack(alignment: .leading, spacing: 2) {
                Text(b.fehlt).font(.body.weight(.semibold))
                Text(b.baustelle).font(.caption).foregroundStyle(.orange)
                Text("\(b.auftrag) steht").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let seit = b.seit {
                Text(seit, format: .relative(presentation: .numeric))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func laden() { blick = Tagesblick.fuerHeute(in: ctx) }
}

// MARK: - Die Karte oben in der Baustellenliste

/// Eine Zeile, kein Bildschirm: was gerade quer über alle Baustellen ansteht.
/// Sie sitzt bewusst als erste Zeile in der Baustellenliste — die Frage
/// „wo war ich?" kommt vor der Frage „welche Baustelle?".
///
/// Bewusst KEIN Toolbar-Knopf: `ContentView` ist `.searchable`, und die native
/// Suchleiste kapert am iPad die Navileiste (siehe `searchable-verdeckt-toolbar`).
struct TagesblickKarte: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var blick = Tagesblick.Ergebnis()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: blick.istRuhig ? "checkmark.circle" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(blick.blockaden.isEmpty ? Color.secondary : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wo war ich?").font(.body.weight(.semibold))
                Text(zusammenfassung).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .onAppear { blick = Tagesblick.fuerHeute(in: ctx) }
    }

    private var zusammenfassung: String {
        var teile: [String] = []
        if !blick.blockaden.isEmpty { teile.append("\(blick.blockaden.count) blockiert") }
        let ueberfaellig = blick.fristen.filter(\.ueberfaellig).count
        if ueberfaellig > 0 { teile.append("\(ueberfaellig) überfällig") }
        let ohnePreis = blick.preisluecken.reduce(0) { $0 + $1.betroffeneMenge }
        if ohnePreis > 0 { teile.append("\(ohnePreis) ohne Preis") }
        if teile.isEmpty {
            return blick.zuletzt.map { "zuletzt: \($0.baustelle)" } ?? "nichts steht"
        }
        return teile.joined(separator: " · ")
    }
}
