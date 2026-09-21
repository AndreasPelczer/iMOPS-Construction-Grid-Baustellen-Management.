//
//  WochenstrahlView.swift
//
//  „Diese Woche" aus dem Büro-Mockup (~/Desktop/iMOPS-Mockup-Buero.html):
//  alle Baustellen nebeneinander, Montag bis Freitag, echte Kalendertage.
//
//  Kein dritter Gantt. Der Gantt einer Baustelle ist `ZeitstrahlView`, die
//  Phasenschätzung `BauzeitenplanView` — hier geht es nur um die Frage, die das Büro
//  am Montag stellt: wer ist diese Woche wo?
//
//  Jede Zeile führt in die Baustelle. Ist die Woche leer, sagt der Bildschirm WARUM
//  und wo man es einträgt — statt einen hübschen leeren Kalender zu zeigen.
//

import SwiftUI
import CoreData

struct WochenstrahlView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var versatz = 0
    @State private var woche = Wochenstrahl.Ergebnis()
    @State private var ziel: Event?

    var body: some View {
        List {
            Section {
                HStack {
                    Button { blaettern(-1) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.borderless)
                    Spacer()
                    VStack(spacing: 1) {
                        Text(wochenTitel).font(.subheadline.weight(.semibold))
                        if versatz != 0 {
                            Button("zurück zu dieser Woche") { versatz = 0; laden() }
                                .font(.caption).buttonStyle(.borderless)
                        }
                    }
                    Spacer()
                    Button { blaettern(1) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.borderless)
                }
            }

            if !woche.hatInhalt {
                Section { luecken }
            }

            ForEach(woche.tage) { tag in
                Section {
                    if tag.leer {
                        Text("—").foregroundStyle(.tertiary)
                    } else {
                        ForEach(tag.termine) { t in
                            Button { ziel = t.event } label: {
                                HStack(spacing: 10) {
                                    Text("🔴")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(t.was).font(.body.weight(.semibold))
                                        Text(t.baustelle).font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(tag.eintraege) { e in
                            Button { ziel = e.event } label: { zeile(e) }
                                .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text(tag.kuerzel).fontWeight(.bold)
                        Text(tag.datum, format: .dateTime.day().month())
                        if tag.istHeute {
                            Text("heute").font(.caption2.weight(.bold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            if woche.hatInhalt && !woche.luecken.istVollstaendig {
                Section("Nicht alles ist hier zu sehen") { luecken }
            }
        }
        .navigationTitle("Diese Woche")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $ziel) { EventDetailView(event: $0) }
        .refreshable { laden() }
        .onAppear { laden() }
    }

    // MARK: - Was fehlt

    @ViewBuilder private var luecken: some View {
        let l = woche.luecken
        VStack(alignment: .leading, spacing: 10) {
            if l.auftraegeOhneDauer > 0 {
                beleg("calendar.badge.clock",
                      "\(l.auftraegeOhneDauer) Aufträge haben keine Dauer",
                      "Ohne Dauer kann kein Auftrag auf einen Tag fallen. Die Reihenfolge steht "
                      + "schon — eintragen in der Baustelle unter Terminplan — je Auftrag eine Zahl.")
                if !l.baustellenOhneDauer.isEmpty {
                    Text("Betrifft: " + l.baustellenOhneDauer.joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !l.baustellenOhneStart.isEmpty {
                beleg("calendar.badge.exclamationmark",
                      "\(l.baustellenOhneStart.count) Baustelle(n) ohne Starttermin",
                      "Ohne Baubeginn gibt es keinen Tag 1: " + l.baustellenOhneStart.joined(separator: " · "))
            }
            if l.istVollstaendig && !woche.hatInhalt {
                beleg("checkmark.circle", "Diese Woche ist nichts geplant",
                      "Alle Baustellen haben Start und Dauern — in dieser Woche läuft nur nichts.")
            }
        }
        .padding(.vertical, 2)
    }

    private func beleg(_ symbol: String, _ titel: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.orange).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Zeile

    private func zeile(_ e: Wochenstrahl.Eintrag) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(e.fertig ? "✅" : (e.beginntHeute ? "▶️" : (e.endetHeute ? "⏹️" : "▪️")))
            VStack(alignment: .leading, spacing: 1) {
                Text(e.auftrag)
                    .font(.body)
                    .strikethrough(e.fertig)
                Text(e.baustelle).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private var wochenTitel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM"
        let ende = Calendar.current.date(byAdding: .day, value: 4, to: woche.montag) ?? woche.montag
        return "\(f.string(from: woche.montag)) – \(f.string(from: ende))"
    }

    private func blaettern(_ richtung: Int) { versatz += richtung; laden() }
    private func laden() { woche = Wochenstrahl.woche(versatz: versatz, in: ctx) }
}
