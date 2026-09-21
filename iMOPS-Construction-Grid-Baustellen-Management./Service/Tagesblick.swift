//
//  Tagesblick.swift
//
//  Die Klammer über ALLE Baustellen — die eine Ebene, die im Mops bisher fehlte.
//
//  Befund vom 21.09.2026: Von zehn Dingen, die das Büro braucht, sind fünf fertig
//  gebaut und fünf halb. Und die fünf halben haben alle denselben Mangel — dreimal
//  stand wörtlich „je Baustelle" da:
//
//      Zeitstrahl je Baustelle · Preis-Ampel je Baustelle · Übergabe je Baustelle
//
//  Der Polier steht auf EINER Baustelle. Das Büro jongliert alle. Für diese Sicht
//  wurde nie gebaut — nicht weil sie schwer wäre, sondern weil jede Ansicht bei der
//  Baustelle anfängt, in der man gerade steckt.
//
//  Andreas über seinen Tag: „Canvas planen, bestellen, Kalender, Preise fehlen, Leute
//  einteilen, Maschinen leihen, wo sind die Pläne vom Statiker, ist Paolo nicht im
//  Urlaub wenn der Kunde kommt, wo sind die Schrauben, warum ist keiner auf Baustelle
//  xy — und dann ruft die Schwiegermutter an. Und das ist eine ruhige Stunde."
//
//  Deshalb sortiert diese Sicht NICHT nach Baustelle, sondern danach, was gerade
//  jemanden aufhält. Wer steht, kostet Geld.
//

import Foundation
import CoreData

enum Tagesblick {

    // MARK: - Was herauskommt

    /// Etwas hält jemanden auf. Die teuerste Sorte offener Punkt.
    struct Blockade: Identifiable {
        let id = UUID()
        let baustelle: String
        let auftrag: String
        let fehlt: String              // die unerfüllte Voraussetzung
        let seit: Date?
        let event: Event

        /// 🔴 Der Auftrag selbst, nicht nur sein Name. Ohne ihn landet man beim
        /// Antippen auf der Baustellenseite und darf suchen, was der Mops längst
        /// weiß. Andreas am 21.09.: „Ich muss suchen, was der Mops schon weiß?
        /// Und selbst wenn — wo? Hab schon wieder vergessen, was auf der Meldung
        /// stand." Jede Zeile führt auf IHR Ding, nicht auf den Ordner drumherum.
        let job: Auftrag
    }

    /// Eine Position ohne Preis — über ALLE Baustellen, nicht je Baustelle.
    struct Preisluecke: Identifiable {
        let id = UUID()
        let baustelle: String
        let anzahl: Int
        let betroffeneMenge: Int       // wie viele Positionen ganz ohne Preis
        let event: Event
    }

    /// Ein Mangel mit Frist. Die Fristenliste dafür gibt es längst
    /// (`FristenView`) — der Tagesblick holt sie nur nach vorn, statt sie
    /// zum zweiten Mal zu bauen.
    struct Fristsache: Identifiable {
        let id = UUID()
        let baustelle: String
        let titel: String
        let frist: Date
        let ueberfaellig: Bool
        let event: Event
    }

    /// Wo zuletzt gearbeitet wurde — der Wiedereinstieg nach der Unterbrechung.
    struct Zuletzt {
        let baustelle: String
        let wann: Date
        let event: Event
    }

    struct Ergebnis {
        var blockaden: [Blockade] = []
        var preisluecken: [Preisluecke] = []
        var fristen: [Fristsache] = []
        var zuletzt: Zuletzt?
        var baustellenAktiv = 0

        var istRuhig: Bool { blockaden.isEmpty && preisluecken.isEmpty && fristen.isEmpty }
    }

    // MARK: - Sammeln

    @MainActor
    static func fuerHeute(in ctx: NSManagedObjectContext) -> Ergebnis {
        let req: NSFetchRequest<Event> = Event.fetchRequest()
        let events = (try? ctx.fetch(req)) ?? []
        var e = Ergebnis()

        for event in events {
            let auftraege = ((event.jobs as? Set<Auftrag>) ?? [])
            let offen = auftraege.filter { $0.status != .completed }
            let positionen = ((event.lvPositionen as? Set<LVPosition>) ?? [])
            // Eine Baustelle zählt als aktiv, wenn dort überhaupt etwas läuft.
            guard !offen.isEmpty || !positionen.isEmpty else { continue }
            e.baustellenAktiv += 1
            let name = event.title ?? "Baustelle"

            // 1) Blockaden: ein laufender Auftrag, dessen Voraussetzung nicht erfüllt ist.
            //    Die Daten dafür liegen längst (523 Voraussetzungen mit Reihenfolge und
            //    Wartezeit) — sie wurden nur nie baustellenübergreifend gelesen.
            //    WICHTIG: `offeneVoraussetzungen` statt selbst zu filtern. Das rohe Feld
            //    `erfuellt` lügt bei Kanten — eine Kante ist erfüllt, wenn ihr VORGÄNGER
            //    fertig ist, das Häkchen bleibt dabei auf „nein". Wer roh filtert, meldet
            //    Blockaden, die längst keine mehr sind.
            for auftrag in offen {
                for v in auftrag.offeneVoraussetzungen {
                    e.blockaden.append(Blockade(
                        baustelle: name,
                        auftrag: Kausalkette.bezeichnung(auftrag),
                        fehlt: v.anzeigename,
                        seit: auftrag.lastStartTime,
                        event: event,
                        job: auftrag))
                }
            }

            // 2) Preislücken: Positionen, die über KEINEN Weg zu einem Preis kommen.
            //    Dieselbe Rechnung wie im LV (effektiverEP) — damit hier nicht plötzlich
            //    andere Zahlen stehen als dort.
            let zaehlbar = positionen.sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
                .zaehlbarePositionen()
            let ohnePreis = zaehlbar.filter { LVKalkulator.effektiverEP(for: $0) <= 0 }
            if !ohnePreis.isEmpty {
                e.preisluecken.append(Preisluecke(
                    baustelle: name,
                    anzahl: zaehlbar.count,
                    betroffeneMenge: ohnePreis.count,
                    event: event))
            }

            // 3) Fristen: Mängel, die überfällig sind oder in den nächsten sieben Tagen
            //    fällig werden. `istUeberfaellig` ist die vorhandene Wahrheit dafür —
            //    hier wird nicht nachgerechnet, nur eingesammelt.
            let inSiebenTagen = Calendar.current.date(byAdding: .day, value: 7, to: Date())
            for m in ((event.maengel as? Set<Mangel>) ?? []) {
                guard let frist = m.frist else { continue }
                guard m.status != .behoben, m.status != .abgenommen,
                      m.status != .abgelehnt else { continue }
                let faelligBald = inSiebenTagen.map { frist <= $0 } ?? false
                guard m.istUeberfaellig || faelligBald else { continue }
                e.fristen.append(Fristsache(
                    baustelle: name,
                    titel: m.titel ?? m.beschreibung ?? "Mangel",
                    frist: frist,
                    ueberfaellig: m.istUeberfaellig,
                    event: event))
            }

            // 4) Wiedereinstieg: die zuletzt angefasste Baustelle.
            if let wann = letzteBeruehrung(event) {
                if e.zuletzt == nil || wann > e.zuletzt!.wann {
                    e.zuletzt = Zuletzt(baustelle: name, wann: wann, event: event)
                }
            }
        }

        // Wer am längsten steht, steht oben — das ist die teuerste Blockade.
        e.blockaden.sort { ($0.seit ?? .distantFuture) < ($1.seit ?? .distantFuture) }
        e.preisluecken.sort { $0.betroffeneMenge > $1.betroffeneMenge }
        e.fristen.sort { $0.frist < $1.frist }
        return e
    }

    /// Wann wurde an dieser Baustelle zuletzt etwas getan?
    ///
    /// Es gibt kein Feld „zuletzt bearbeitet" — also wird der jüngste Zeitstempel
    /// genommen, den die Baustelle hergibt. Ehrlicher als ein neues Feld, das erst ab
    /// heute gefüllt wäre und für alle alten Baustellen leer bliebe.
    private static func letzteBeruehrung(_ event: Event) -> Date? {
        var kandidaten: [Date] = []
        if let d = event.startTime { kandidaten.append(d) }
        for a in ((event.jobs as? Set<Auftrag>) ?? []) {
            if let d = a.lastStartTime { kandidaten.append(d) }
        }
        return kandidaten.max()
    }
}
