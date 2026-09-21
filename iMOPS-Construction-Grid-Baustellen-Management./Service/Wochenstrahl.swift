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
    }

    /// Ein fester Termin an diesem Tag — heute sind das Mängelfristen.
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
        var leer: Bool { eintraege.isEmpty && termine.isEmpty }
    }

    /// Was der Woche fehlt, damit sie überhaupt etwas zeigen kann.
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

        var hatInhalt: Bool { tage.contains { !$0.leer } }
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
                        fertig: auftrag?.status == .completed))
                }
            }
        }

        for i in e.tage.indices {
            e.tage[i].eintraege.sort {
                $0.baustelle == $1.baustelle ? $0.auftrag < $1.auftrag : $0.baustelle < $1.baustelle
            }
        }
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
