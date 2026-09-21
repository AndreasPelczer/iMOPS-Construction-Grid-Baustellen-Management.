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
    @Environment(\.horizontalSizeClass) private var breite
    private var breit: Bool { breite != .compact }

    private let zeilenHoehe: CGFloat = 44
    private let abstand: CGFloat = 4

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

            // 🔴 Andreas: „ich bin iCalender und Google und Outlook gewohnt und die
            // meisten user auch … ich finde mich auf den ersten Blick nicht zurecht."
            // Ein Kalender ist ein RASTER: Tage nebeneinander, Aufträge als Balken
            // darüber. Die Liste log obendrein — ein Auftrag über zwei Tage stand
            // zweimal da und sah aus wie zwei Aufträge.
            // Schmal (iPhone hochkant) bleibt die Liste: fünf Spalten auf 390 Punkten
            // kann niemand lesen.
            if breit {
                Section {
                    raster
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6))
            } else {
                tagesListe
            }

            if woche.hatInhalt && !woche.luecken.istVollstaendig {
                Section("Nicht alles ist hier zu sehen") { luecken }
            }
        }
        .navigationTitle("Diese Woche")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { laden() }
        .onAppear { laden() }
    }

    // MARK: - Das Raster (Mo–Fr nebeneinander)

    @ViewBuilder private var raster: some View {
        GeometryReader { geo in
            let spalte = max((geo.size.width - abstand * 4) / 5, 40)
            VStack(alignment: .leading, spacing: 8) {
                kopfzeile(spalte)
                if woche.raster.zeilen.isEmpty {
                    Text("Diese Woche steht nichts im Plan.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 6)
                } else {
                    ForEach(Array(woche.raster.zeilen.enumerated()), id: \.offset) { _, zeile in
                        balkenZeile(zeile, spalte: spalte)
                    }
                }
                terminZeile(spalte)
            }
        }
        .frame(height: hoehe)
    }

    private var hoehe: CGFloat {
        let zeilen = max(woche.raster.zeilen.count, 1)
        let termine = woche.tage.contains { !$0.termine.isEmpty } ? zeilenHoehe : 0
        return 46 + CGFloat(zeilen) * (zeilenHoehe + abstand) + termine + 12
    }

    /// Die Kopfzeile: Mo … Fr mit Datum, heute hervorgehoben.
    private func kopfzeile(_ spalte: CGFloat) -> some View {
        HStack(spacing: abstand) {
            ForEach(woche.tage) { tag in
                VStack(spacing: 1) {
                    Text(tag.kuerzel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tag.istHeute ? Color.orange : .secondary)
                    Text(tag.datum, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(width: spalte)
                .padding(.vertical, 4)
                .background(tag.istHeute ? Color.orange.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    /// Eine Zeile Balken. Jeder Balken liegt über so vielen Spalten, wie er dauert —
    /// darum geht es: ein Auftrag über zwei Tage ist EIN Balken.
    private func balkenZeile(_ zeile: [Wochenstrahl.Balken], spalte: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Das Gitter dahinter, damit man die Tage auch dort sieht, wo nichts liegt.
            HStack(spacing: abstand) {
                ForEach(woche.tage) { tag in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(tag.istHeute ? Color.orange.opacity(0.07) : Color.gray.opacity(0.07))
                        .frame(width: spalte, height: zeilenHoehe)
                }
            }
            ForEach(zeile) { b in
                balken(b, spalte: spalte)
                    .offset(x: (spalte + abstand) * CGFloat(b.vonSpalte))
            }
        }
        .frame(height: zeilenHoehe, alignment: .leading)
    }

    private func balken(_ b: Wochenstrahl.Balken, spalte: CGFloat) -> some View {
        let breite = spalte * CGFloat(b.spalten) + abstand * CGFloat(b.spalten - 1)
        return NavigationLink {
            SpaeterLaden {
                if let job = b.job { AnyView(AuftragDetailView(job: job)) }
                else { AnyView(EventDetailView(event: b.event)) }
            }
        } label: {
            HStack(spacing: 4) {
                if b.davorSchon {
                    Image(systemName: "chevron.compact.left").font(.caption2)
                }
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        if b.art == .liegezeit {
                            Image(systemName: "hourglass").font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Text(b.auftrag).font(.caption.weight(.semibold)).lineLimit(1)
                    }
                    Text(b.baustelle).font(.caption2).lineLimit(1).opacity(0.75)
                }
                Spacer(minLength: 0)
                if b.danachNoch {
                    Image(systemName: "chevron.compact.right").font(.caption2)
                }
            }
            .padding(.horizontal, 7)
            .frame(width: breite, height: zeilenHoehe - 4, alignment: .leading)
            .background {
                // Liegezeit wird schraffiert — wie in der Skizze, die Andreas
                // „sofort verstanden" hat. Da arbeitet niemand, trotzdem vergeht Zeit.
                if b.art == .liegezeit {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7).fill(Color.orange.opacity(0.10))
                        Schraffur().stroke(Color.orange.opacity(0.45), lineWidth: 1.5)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                } else {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(b.fertig ? Color.green.opacity(0.22) : Color.blue.opacity(0.22))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(b.art == .liegezeit ? Color.orange.opacity(0.55)
                        : b.fertig ? Color.green.opacity(0.5) : Color.blue.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1,
                                           dash: b.art == .liegezeit ? [4, 3] : [])))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    /// Fristen liegen auf EINEM Tag — eigene Zeile darunter, damit sie nicht mit
    /// den Arbeitsbalken verwechselt werden.
    @ViewBuilder private func terminZeile(_ spalte: CGFloat) -> some View {
        if woche.tage.contains(where: { !$0.termine.isEmpty }) {
            HStack(spacing: abstand) {
                ForEach(woche.tage) { tag in
                    VStack(spacing: 2) {
                        ForEach(tag.termine) { t in
                            NavigationLink {
                                SpaeterLaden { MangelListeView(event: t.event) }
                            } label: {
                                Text("🔴 \(t.was)")
                                    .font(.caption2).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 5).padding(.vertical, 3)
                                    .background(Color.red.opacity(0.14),
                                                in: RoundedRectangle(cornerRadius: 5))
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: spalte, alignment: .top)
                }
            }
            .frame(height: zeilenHoehe, alignment: .top)
        }
    }

    // MARK: - Die schmale Fassung (iPhone hochkant)

    @ViewBuilder private var tagesListe: some View {
        ForEach(woche.tage) { tag in
            Section {
                if tag.leer {
                    Text("—").foregroundStyle(.tertiary)
                } else {
                    ForEach(tag.termine) { t in
                        NavigationLink { SpaeterLaden { MangelListeView(event: t.event) } } label: {
                            HStack(spacing: 10) {
                                Text("🔴")
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(t.was).font(.body.weight(.semibold))
                                    Text(t.baustelle).font(.caption).foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                    ForEach(tag.eintraege) { e in
                        NavigationLink {
                            SpaeterLaden {
                                if let job = e.job { AnyView(AuftragDetailView(job: job)) }
                                else { AnyView(EventDetailView(event: e.event)) }
                            }
                        } label: { zeile(e) }
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

/// Diagonale Schraffur für Liegezeiten — das Muster aus der Ablaufplan-Skizze.
private struct Schraffur: Shape {
    var abstand: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x = -rect.height
        while x < rect.width {
            p.move(to: CGPoint(x: x, y: rect.height))
            p.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += abstand
        }
        return p
    }
}
