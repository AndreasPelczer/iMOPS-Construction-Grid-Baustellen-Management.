//
//  Wochenstrahl.swift
//
//  Die Woche quer über alle Baustellen — Montag bis Freitag, echte Kalendertage.
//
//  Es gibt schon zwei Zeitstrahlen, und beide sind richtig, wo sie sitzen:
//
//    • `ZeitstrahlView`      — echter Gantt aus echten Aufträgen samt
//                              Abhängigkeitspfeilen. EINE Baustelle, Achse „Tag 0".
//    • `BauzeitenplanView`   — Phasenbalken beim Hausplaner. Schätzung in Wochen.
//
//  Was beiden fehlt, ist der **Kalender**: sie rechnen relativ („Tag 0", „Woche 1"),
//  nicht gegen den Montag, an dem jemand tatsächlich auf der Baustelle steht. Und
//  beide zeigen immer nur eine Baustelle. Das Büro jongliert alle.
//
//  Dieser Rechner erfindet deshalb NICHTS neu: er nimmt `Bauablauf.terminplan` (den
//  vorhandenen Vorwärtsrechner samt Wartezeiten) und hängt Tag 0 an den echten
//  Baustellenstart `eventStartTime`. Die Umrechnung Tag→Datum zählt Arbeitstage über
//  `BrigadePlanung.arbeitstageZwischen` — dieselbe Mo–Fr-Wahrheit wie überall sonst.
//
//  🔴 Ehrlichkeit vor Bildern: was keine Dauer hat, kann nicht auf einen Tag fallen.
//  Statt einen leeren Kalender zu zeigen, meldet das Ergebnis, WAS fehlt und wo man
//  es einträgt. (Stand 21.09.2026: 29 Aufträge, davon 0 mit Dauer.)
//

import Foundation
import CoreData

enum Wochenstrahl {

    /// Ein Auftrag, der an diesem Tag läuft.
    struct Eintrag: Identifiable {
        let id = UUID()
        let baustelle: String
        let auftrag: String
        let event: Event
        let beginntHeute: Bool
        let endetHeute: Bool
        let fertig: Bool
        /// Damit ein Balken auf SEIN Ding führen kann, nicht auf die Baustelle.
        var job: Auftrag? = nil
    }

    /// Ein fester Termin an diesem Tag — heute sind das Mängelfristen.
    /// 🔴 Ein Auftrag über mehrere Tage — EIN Balken, nicht drei Zeilen.
    ///
    /// Andreas, 21.09.2026: „ich mag die Ansicht nicht. Ich bin iCalender und Google
    /// und Outlook gewohnt und die meisten user auch … ich finde mich auf den ersten
    /// Blick auch nicht zurecht."
    /// Er hat recht, und die Liste log obendrein: „311 Baugrube / Erdbau" stand an
    /// Dienstag UND Mittwoch und sah aus wie zwei Aufträge. Es war einer über zwei
    /// Tage. Genau das kann eine Liste nicht zeigen — ein Raster schon.
    struct Balken: Identifiable {
        /// Arbeit oder Liegezeit — im Mockup der Unterschied zwischen vollem und
        /// schraffiertem Balken. „Beton härten" ist kein Auftrag, aber es kostet Tage.
        enum Art { case arbeit, liegezeit }

        let id = UUID()
        var art: Art = .arbeit
        let baustelle: String
        let auftrag: String
        let event: Event
        let job: Auftrag?
        /// Spalten 0…4 = Mo…Fr, beide Enden einschliesslich.
        let vonSpalte: Int
        let bisSpalte: Int
        let fertig: Bool
        /// Fängt der Balken vor Montag an bzw. läuft er über Freitag hinaus?
        let davorSchon: Bool
        let danachNoch: Bool

        var spalten: Int { bisSpalte - vonSpalte + 1 }
    }

    struct Termin: Identifiable {
        let id = UUID()
        let baustelle: String
        let was: String
        let event: Event
    }

    struct Tag: Identifiable {
        let id = UUID()
        let datum: Date
        var eintraege: [Eintrag] = []
        var liegezeiten: [Eintrag] = []
        var termine: [Termin] = []

        /// Fest verdrahtet statt über den DateFormatter: der liefert im Deutschen
        /// „Mo." MIT Punkt, und das hing dann an vier Tests und an der Spaltenbreite.
        /// Zwei Buchstaben, keine Überraschung.
        var kuerzel: String {
            let namen = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
            let wd = Calendar(identifier: .gregorian).component(.weekday, from: datum)
            return namen[(wd - 1) % 7]
        }
        var istHeute: Bool { Calendar.current.isDateInToday(datum) }
        var leer: Bool { eintraege.isEmpty && liegezeiten.isEmpty && termine.isEmpty }
    }

    /// Was der Woche fehlt, damit sie überhaupt etwas zeigen kann.
    /// Die Balken der Woche, in Zeilen gestapelt — jede Zeile ohne Überschneidung,
    /// wie in jedem Kalender.
    struct Raster {
        var zeilen: [[Balken]] = []
        var anzahl: Int { zeilen.reduce(0) { $0 + $1.count } }
    }

    struct Luecken {
        var auftraegeOhneDauer = 0
        var baustellenOhneDauer: [String] = []
        var baustellenOhneStart: [String] = []

        var istVollstaendig: Bool {
            auftraegeOhneDauer == 0 && baustellenOhneStart.isEmpty
        }
    }

    struct Ergebnis {
        var tage: [Tag] = []
        var luecken = Luecken()
        var montag = Date()
        /// Dieselben Daten als Balken — für die Rasteransicht.
        var raster = Raster()

        var hatInhalt: Bool { tage.contains { !$0.leer } }
    }

    // MARK: - Aus Tagen werden Balken

    /// Fasst zusammen, was zusammengehört: derselbe Auftrag an aufeinanderfolgenden
    /// Tagen ist EIN Balken. Dann werden die Balken in Zeilen gestapelt, sodass sich
    /// in einer Zeile nichts überschneidet — genau wie in iCal, Google und Outlook.
    static func rasterAus(_ tage: [Tag]) -> Raster {
        // Schlüssel: Baustelle + Auftragsname. Gleichnamige Pakete derselben Baustelle
        // laufen in der Praxis nie gleichzeitig; käme das vor, stünden sie in einer Zeile.
        var spannen: [String: (von: Int, bis: Int, e: Eintrag, art: Balken.Art)] = [:]
        for (spalte, tag) in tage.enumerated() {
            for (eintrag, art) in tag.eintraege.map({ ($0, Balken.Art.arbeit) })
                                + tag.liegezeiten.map({ ($0, Balken.Art.liegezeit) }) {
                let schluessel = "\(art)|" + eintrag.baustelle + "|" + eintrag.auftrag
                if var da = spannen[schluessel] {
                    da.bis = max(da.bis, spalte)
                    spannen[schluessel] = da
                } else {
                    spannen[schluessel] = (spalte, spalte, eintrag, art)
                }
            }
        }

        let balken = spannen.values.map { sp in
            Balken(art: sp.art,
                   baustelle: sp.e.baustelle, auftrag: sp.e.auftrag, event: sp.e.event,
                   job: sp.e.job, vonSpalte: sp.von, bisSpalte: sp.bis,
                   fertig: sp.e.fertig,
                   // Ein Balken, der am Montag ohne Anfang dasteht, kommt von letzter
                   // Woche — das muss man sehen, sonst wirkt er falsch kurz.
                   davorSchon: sp.von == 0 && !sp.e.beginntHeute,
                   danachNoch: sp.bis == max(tage.count - 1, 0) && !sp.e.endetHeute)
        }
        .sorted {
            if $0.vonSpalte != $1.vonSpalte { return $0.vonSpalte < $1.vonSpalte }
            if $0.spalten != $1.spalten { return $0.spalten > $1.spalten }
            return $0.auftrag < $1.auftrag
        }

        // Stapeln: jeder Balken in die erste Zeile, in der er Platz hat.
        var zeilen: [[Balken]] = []
        for b in balken {
            if let i = zeilen.firstIndex(where: { zeile in
                zeile.allSatisfy { b.vonSpalte > $0.bisSpalte || b.bisSpalte < $0.vonSpalte }
            }) {
                zeilen[i].append(b)
            } else {
                zeilen.append([b])
            }
        }
        return Raster(zeilen: zeilen)
    }

    // MARK: - Rechnen

    /// Die Woche, in der `anker` liegt (Montag–Freitag). `versatz` blättert:
    /// -1 = vorige Woche, +1 = nächste.
    @MainActor
    static func woche(um anker: Date = Date(), versatz: Int = 0,
                      in ctx: NSManagedObjectContext) -> Ergebnis {
        let cal = kalender()
        guard let montag = montagDerWoche(anker, versatz: versatz, cal: cal) else {
            return Ergebnis()
        }
        var e = Ergebnis()
        e.montag = montag
        e.tage = (0..<5).compactMap { cal.date(byAdding: .day, value: $0, to: montag) }
            .map { Tag(datum: $0) }

        let req: NSFetchRequest<Event> = Event.fetchRequest()
        let events = (try? ctx.fetch(req)) ?? []

        for event in events {
            let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
            let name = event.title ?? "Baustelle"

            // Fristen brauchen keinen Baustellenstart — sie tragen ihr eigenes Datum.
            for m in ((event.maengel as? Set<Mangel>) ?? []) {
                guard let frist = m.frist,
                      m.status != .behoben, m.status != .abgenommen, m.status != .abgelehnt
                else { continue }
                if let i = e.tage.firstIndex(where: { cal.isDate($0.datum, inSameDayAs: frist) }) {
                    e.tage[i].termine.append(Termin(
                        baustelle: name,
                        was: m.titel ?? m.beschreibung ?? "Mangel",
                        event: event))
                }
            }

            guard !jobs.isEmpty else { continue }

            guard let start = event.eventStartTime else {
                e.luecken.baustellenOhneStart.append(name)
                continue
            }

            let plan = Bauablauf.terminplan(fuer: jobs)
            guard plan.zyklus.isEmpty, plan.gesamtdauerTage > 0 else {
                // Ohne Dauern rechnet der Vorwärtsrechner alles auf Tag 0 — daraus
                // einen Kalender zu malen wäre gelogen.
                e.luecken.auftraegeOhneDauer += jobs.filter { $0.dauerTage <= 0 }.count
                e.luecken.baustellenOhneDauer.append(name)
                continue
            }

            let nachName = Dictionary(jobs.map { (kennung($0), $0) }, uniquingKeysWith: { a, _ in a })

            // 🔴 Die Tage, an denen niemand arbeitet, gehören in den Kalender.
            // Sie stecken auf den Kanten (`wartezeitTage`) und schoben den Plan
            // bisher unsichtbar — man sah nur, dass etwas später anfing.
            for auftrag in jobs {
                for v in ((auftrag.voraussetzungen as? Set<Voraussetzung>) ?? []) {
                    guard v.wartezeitTage > 0, let quelle = v.quelle,
                          let vorTermin = plan.termine.first(where: { $0.knotenID == kennung(quelle) })
                    else { continue }
                    let vonIdx = Int(vorTermin.fruehestesEndeTag.rounded(.up))
                    let bisIdx = vonIdx + Int(v.wartezeitTage.rounded(.up)) - 1
                    guard bisIdx >= vonIdx else { continue }

                    for (i, tag) in e.tage.enumerated() {
                        guard let idx = arbeitstagIndex(von: start, bis: tag.datum, cal: cal),
                              idx >= vonIdx, idx <= bisIdx else { continue }
                        e.tage[i].liegezeiten.append(Eintrag(
                            baustelle: name,
                            auftrag: v.name ?? "Liegezeit",
                            event: event,
                            beginntHeute: idx == vonIdx,
                            endetHeute: idx == bisIdx,
                            fertig: false,
                            job: auftrag))
                    }
                }
            }

            for termin in plan.termine {
                let vonIndex = Int(termin.fruehesterStartTag.rounded(.down))
                let bisIndex = max(vonIndex, Int(termin.fruehestesEndeTag.rounded(.up)) - 1)
                let auftrag = nachName[termin.knotenID]

                for (i, tag) in e.tage.enumerated() {
                    guard let idx = arbeitstagIndex(von: start, bis: tag.datum, cal: cal),
                          idx >= vonIndex, idx <= bisIndex else { continue }
                    e.tage[i].eintraege.append(Eintrag(
                        baustelle: name,
                        auftrag: termin.name,
                        event: event,
                        beginntHeute: idx == vonIndex,
                        endetHeute: idx == bisIndex,
                        fertig: auftrag?.status == .completed,
                        job: auftrag))
                }
            }
        }

        for i in e.tage.indices {
            e.tage[i].eintraege.sort {
                $0.baustelle == $1.baustelle ? $0.auftrag < $1.auftrag : $0.baustelle < $1.baustelle
            }
        }
        e.raster = rasterAus(e.tage)
        return e
    }

    // MARK: - Kalenderarithmetik

    /// Deutscher Kalender — die Woche fängt am Montag an, nicht am Sonntag.
    private static func kalender() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "de_DE")
        cal.firstWeekday = 2
        return cal
    }

    private static func montagDerWoche(_ datum: Date, versatz: Int, cal: Calendar) -> Date? {
        guard let woche = cal.dateInterval(of: .weekOfYear, for: datum) else { return nil }
        return cal.date(byAdding: .weekOfYear, value: versatz, to: woche.start)
    }

    /// Der nullbasierte Arbeitstag-Index von `bis` gegenüber dem Baustellenstart.
    /// nil, wenn der Tag vor dem Start liegt. Zählt Mo–Fr über
    /// `BrigadePlanung.arbeitstageZwischen` — eine Wahrheit, was ein Arbeitstag ist.
    private static func arbeitstagIndex(von start: Date, bis tag: Date, cal: Calendar) -> Int? {
        let a = cal.startOfDay(for: start)
        let b = cal.startOfDay(for: tag)
        guard b >= a else { return nil }
        let gezaehlt = BrigadePlanung.arbeitstageZwischen(a, b)
        return gezaehlt > 0 ? gezaehlt - 1 : nil
    }

    private static func kennung(_ a: Auftrag) -> String {
        a.objectID.uriRepresentation().absoluteString
    }
}
