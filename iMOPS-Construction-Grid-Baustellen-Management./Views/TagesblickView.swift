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

    var body: some View {
        List {
            if let z = blick.zuletzt {
                Section {
                    NavigationLink { SpaeterLaden { EventDetailView(event: z.event) } } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("WO DU WARST")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.blue)
                            Text(z.baustelle).font(.title3.weight(.semibold))
                            Text("zuletzt \(z.wann, format: .relative(presentation: .named))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                NavigationLink { SpaeterLaden { WochenstrahlView() } } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title3).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Diese Woche").font(.body.weight(.semibold))
                            Text("alle Baustellen nebeneinander, Mo–Fr")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if blick.istRuhig && blick.fristen.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Nichts steht",
                        systemImage: "checkmark.circle",
                        description: Text("Nichts steht still, nichts ist überfällig, alles hat einen Preis. \(blick.baustellenAktiv) Baustellen."))
                }
            }

            if !blick.startklar.isEmpty {
                Section {
                    ForEach(blick.startklar) { s in
                        NavigationLink { SpaeterLaden { AuftragDetailView(job: s.job) } } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.auftrag).font(.body.weight(.semibold))
                                    Text(s.baustelle).font(.caption).foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                } header: {
                    kopf("Kann jetzt anfangen", zahl: nil)
                } footer: {
                    Text("Nichts hält diese Aufträge auf — alle Vorgänger sind fertig.")
                }
            }

            if !blick.blockaden.isEmpty {
                Section {
                    ForEach(blick.blockaden) { b in
                        NavigationLink { SpaeterLaden { AuftragDetailView(job: b.job) } } label: { zeile(b) }
                    }
                } header: {
                    kopf("Steht wirklich still", zahl: blick.blockaden.count)
                } footer: {
                    Text("Aufträge, die LAUFEN und denen etwas fehlt. Was nur auf einen "
                         + "Vorgänger wartet, steht hier bewusst nicht — das ist Plan, keine Not.")
                }
            }

            if !blick.fristen.isEmpty {
                Section {
                    ForEach(blick.fristen) { f in
                        NavigationLink { SpaeterLaden { MangelListeView(event: f.event) } } label: {
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
                    }
                } header: {
                    kopf("Hat eine Frist", zahl: blick.fristen.count)
                }
            }

            if !blick.preisluecken.isEmpty {
                Section {
                    ForEach(blick.preisluecken) { p in
                        NavigationLink { SpaeterLaden { LVView(event: p.event) } } label: {
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
                    }
                } header: {
                    kopf("Daraus wird noch kein Angebot", zahl: nil)
                } footer: {
                    Text("Gerechnet wie im LV: Angebot vor Element vor Eigenkalkulation.")
                }
            }
        }
        .navigationTitle("Wo war ich?")
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

    /// 🔴 Nur Zahlen und ein Name — KEINE Core-Data-Objekte. Diese Karte steht dauerhaft
    /// in der Baustellenliste; was sie festhält, wird bei jedem Neuzeichnen mitgeschleppt.
    private struct Kurz: Equatable {
        var blockiert = 0
        var ueberfaellig = 0
        var ohnePreis = 0
        var zuletzt = ""
        var ruhig = true
    }
    @State private var kurz = Kurz()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kurz.ruhig ? "checkmark.circle" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(kurz.blockiert == 0 ? Color.secondary : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wo war ich?").font(.body.weight(.semibold))
                Text(zusammenfassung).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .onAppear { laden() }
    }

    private func laden() {
        let b = Tagesblick.fuerHeute(in: ctx)
        kurz = Kurz(blockiert: b.blockaden.count,
                    ueberfaellig: b.fristen.filter(\.ueberfaellig).count,
                    ohnePreis: b.preisluecken.reduce(0) { $0 + $1.betroffeneMenge },
                    zuletzt: b.zuletzt?.baustelle ?? "",
                    ruhig: b.istRuhig)
    }

    private var zusammenfassung: String {
        var teile: [String] = []
        if kurz.blockiert > 0 { teile.append("\(kurz.blockiert) blockiert") }
        if kurz.ueberfaellig > 0 { teile.append("\(kurz.ueberfaellig) überfällig") }
        if kurz.ohnePreis > 0 { teile.append("\(kurz.ohnePreis) ohne Preis") }
        if teile.isEmpty {
            return kurz.zuletzt.isEmpty ? "nichts steht" : "zuletzt: \(kurz.zuletzt)"
        }
        return teile.joined(separator: " · ")
    }
}


// MARK: - Erst beim Aufschlagen bauen

/// `NavigationLink(destination:)` baut sein Ziel SOFORT mit auf — bei jedem Neuzeichnen
/// der Liste. Für eine Ansicht mit eigenem `@State` voller Core-Data-Objekte heißt das:
/// ständig anlegen und wieder wegräumen.
///
/// 🔴 Genau daran ist die App am 21.09. abgestürzt:
/// `outlined destroy of TagesblickView` → `NavigationLink.init(destination:label:)`
/// → `ContentView.swift:22`, zusammen mit `.searchable` im selben Bildschirm.
///
/// Dieser Wrapper hält nur eine Closure. Die Ansicht entsteht erst, wenn wirklich
/// hingeblättert wird.
struct SpaeterLaden<Inhalt: View>: View {
    private let bauen: () -> Inhalt
    init(@ViewBuilder _ bauen: @escaping () -> Inhalt) { self.bauen = bauen }
    var body: Inhalt { bauen() }
}
