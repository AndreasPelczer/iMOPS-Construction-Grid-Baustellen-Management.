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

            ForEach(blick.lagen) { l in
                Section {
                    NavigationLink { SpaeterLaden { EventDetailView(event: l.event) } } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(l.baustelle).font(.body.weight(.semibold))
                                Text(l.phase.text)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(farbe(l.phase).opacity(0.16), in: Capsule())
                                    .foregroundStyle(farbe(l.phase))
                            }
                            Text(l.satz).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    ForEach(l.anstehend) { a in
                        NavigationLink {
                            SpaeterLaden {
                                if a.insLV { AnyView(LVView(event: l.event)) }
                                else { AnyView(EventDetailView(event: l.event)) }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "circle.dashed")
                                    .foregroundStyle(.secondary)
                                Text(a.text).font(.subheadline)
                            }
                        }
                    }
                } footer: {
                    if !l.anstehend.isEmpty {
                        Text(l.phase == .planung
                             ? "Kein Alarm — hier wird noch geplant."
                             : "Das stünde noch an.")
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

            // Vor dem Anfangen kommt das Einrichten. Diese Zeile ist der FADEN
            // durch die Einricht-Arbeit: nicht "es fehlt was", sondern "hier weiter".
            if !blick.ohneAnweisung.isEmpty {
                Section {
                    ForEach(blick.ohneAnweisung.prefix(6)) { o in
                        NavigationLink { SpaeterLaden { AuftragDetailView(job: o.job) } } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "list.bullet.rectangle")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(o.auftrag).font(.body.weight(.semibold))
                                    Text(o.baustelle).font(.caption).foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    if blick.ohneAnweisung.count > 6 {
                        Text("und \(blick.ohneAnweisung.count - 6) weitere")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } header: {
                    kopf("Schritte schreiben", zahl: blick.ohneAnweisung.count)
                } footer: {
                    Text("Für diese Aufträge gibt es noch keine Arbeitsschritte. "
                         + "Einen antippen, \"Mops, wie geht das?\" drücken, durchlesen, "
                         + "abnehmen — danach bringt dich der Auftrag selbst zum nächsten.")
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

        }
        .navigationTitle("Wo war ich?")
        .refreshable { laden() }
        .onAppear { laden() }
    }

    private func farbe(_ p: Tagesblick.Phase) -> Color {
        switch p {
        case .planung: return .blue
        case .laeuft:  return .green
        case .fertig:  return .secondary
        }
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
        var alarm = false
        var lagen = ""        // "wird geplant" / "2 laufen" — der ruhige Normalfall
    }
    @State private var kurz = Kurz()

    var body: some View {
        HStack(spacing: 12) {
            // Rot nur bei echtem Alarm. Was bloss ansteht, bekommt einen Pfeil —
            // ein Zustand, der immer rot ist, ist Rauschen.
            Image(systemName: kurz.alarm ? "exclamationmark.triangle.fill"
                            : kurz.ruhig ? "checkmark.circle" : "arrow.right.circle")
                .font(.title2)
                .foregroundStyle(kurz.alarm ? Color.red : .secondary)
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
                    ruhig: b.istRuhig,
                    alarm: b.brauchtAufmerksamkeit,
                    lagen: lagenSatz(b))
    }

    /// Wie viele Baustellen in welcher Phase — der Satz für den ruhigen Fall.
    private func lagenSatz(_ b: Tagesblick.Ergebnis) -> String {
        let geplant = b.lagen.filter { $0.phase == .planung }.count
        let laufend = b.lagen.filter { $0.phase == .laeuft }.count
        var teile: [String] = []
        if laufend > 0 { teile.append(laufend == 1 ? "1 läuft" : "\(laufend) laufen") }
        if geplant > 0 { teile.append(geplant == 1 ? "1 wird geplant" : "\(geplant) werden geplant") }
        return teile.joined(separator: " · ")
    }

    /// Was WIRKLICH stört, steht zuerst. Fehlende Preise nur, wenn sonst nichts ist —
    /// und dann hinter der Lage, nicht als Vorwurf.
    private var zusammenfassung: String {
        var teile: [String] = []
        if kurz.blockiert > 0 { teile.append("\(kurz.blockiert) blockiert") }
        if kurz.ueberfaellig > 0 { teile.append("\(kurz.ueberfaellig) überfällig") }
        if !teile.isEmpty { return teile.joined(separator: " · ") }

        if !kurz.lagen.isEmpty {
            return kurz.ohnePreis > 0 ? "\(kurz.lagen) · \(kurz.ohnePreis) noch ohne Preis"
                                      : kurz.lagen
        }
        if kurz.ohnePreis > 0 { return "\(kurz.ohnePreis) noch ohne Preis" }
        return kurz.zuletzt.isEmpty ? "noch keine Baustelle" : "zuletzt: \(kurz.zuletzt)"
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
