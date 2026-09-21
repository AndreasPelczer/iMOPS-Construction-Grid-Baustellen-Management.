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

    /// Ein Auftrag, der angefangen werden KÖNNTE: alle Vorgänger sind fertig, er
    /// selbst läuft noch nicht. Das ist eine Gelegenheit, kein Alarm.
    struct Startklar: Identifiable {
        let id = UUID()
        let baustelle: String
        let auftrag: String
        let event: Event
        let job: Auftrag
    }

    /// Ein Auftrag, für den noch keine Arbeitsschritte geschrieben sind.
    ///
    /// 🔴 Das ist die Einricht-Arbeit, die zwischen "Arbeitspakete anlegen" und
    /// "draussen anfangen" liegt — und sie hatte bisher keinen Faden. Wer einen
    /// Auftrag eingerichtet hatte, ging zurück und musste sich selbst merken,
    /// welcher der nächste ist. Genau das soll der Mops wissen, nicht der Mensch.
    struct OhneAnweisung: Identifiable {
        let id = UUID()
        let baustelle: String
        let auftrag: String
        let event: Event
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

    // MARK: - Die Lage je Baustelle

    /// In welcher Phase steckt eine Baustelle? Danach richtet sich der TON.
    ///
    /// Andreas, 21.09.: „Erst wenn wirklich Alarm ist, auch Alarm rufen — denn bis
    /// jetzt haben wir doch nur eine Baustelle, die noch geplant werden muss."
    /// Eine Baustelle in Planung kann gar nicht blockiert sein. Dort gibt es keine
    /// Not, nur offene Vorbereitung — und die meldet man freundlich, nicht rot.
    enum Phase {
        case planung      // nichts angefangen
        case laeuft       // jemand arbeitet, oder es ist schon etwas fertig
        case fertig       // alles erledigt

        var text: String {
            switch self {
            case .planung: return "wird geplant"
            case .laeuft:  return "läuft"
            case .fertig:  return "fertig"
            }
        }

        /// Der geplante Endtermin ist vorbei, die Arbeit aber nicht fertig.
        ///
        /// 🔴 Andreas: "eine Baustelle dauert keine 3 Stunden. Sie dauert so lange
        /// wie sie dauert. Sie wurde geplant, dass sie eventuell x Stunden dauert,
        /// aber fertig ist sie erst wenn sie fertig ist."
        /// Deshalb ist das hier eine TATSACHE, kein Urteil: der Plan sagte einen Tag,
        /// die Arbeit sagt einen anderen. Beides steht nebeneinander, keins überschreibt
        /// das andere — und die Phase bleibt, was sie ist.
        @MainActor
        static func istUeberfaellig(_ event: Event) -> Bool {
            guard let geplant = event.eventEndTime else { return false }
            return geplant < Date() && von(event) != .fertig
        }

        /// Die Phase einer Baustelle — aus der ARBEIT, nicht aus dem Kalender.
        /// 🔴 Eine Baustelle, deren Endtermin verstrichen ist, ist nicht fertig.
        /// Sie ist überfällig. Das ist ein Unterschied, den die Liste lange nicht kannte.
        @MainActor
        static func von(_ event: Event) -> Phase {
            let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
            let fertig = jobs.filter { $0.status == .completed }.count
            let laufend = jobs.filter { $0.status == .inProgress }.count

            if !jobs.isEmpty && fertig == jobs.count { return .fertig }
            if laufend > 0 || fertig > 0             { return .laeuft }
            return .planung
        }
    }

    /// Etwas, das anstünde. Kein Mangel, kein Alarm — ein Angebot.
    struct Anstehend: Identifiable {
        let id = UUID()
        let text: String
        /// Wohin es führt: das LV oder die Baustelle selbst.
        let insLV: Bool
        /// 🔴 Wenn GENAU EIN Auftrag gemeint ist, führt die Zeile dorthin.
        ///
        /// Andreas: „dann klicke ich ihn an, komme auf die Baustelle bei der ich
        /// schon vor zwei Stunden die Dauer eingetragen habe." Er hatte 33 von 34
        /// gesetzt — die Meldung stimmte, aber sie lieferte ihn auf der Baustelle ab
        /// und liess ihn das eine suchen. Eine Zeile über ein einzelnes Ding muss
        /// auf dieses Ding führen.
        var job: Auftrag? = nil
        /// Wiedererkennbarer Schlüssel für das Sonderfall-Buch („dauer-fehlt").
        /// Leer = zu dieser Zeile kann man nichts erklären.
        var thema: String = ""
    }

    struct Lage: Identifiable {
        let id = UUID()
        let baustelle: String
        let event: Event
        let phase: Phase
        let pakete: Int
        let positionen: Int
        var anstehend: [Anstehend] = []

        /// Ein Satz, der die Lage beschreibt — ohne Wertung.
        var satz: String {
            switch phase {
            case .planung:
                if pakete == 0 && positionen > 0 {
                    return "\(positionen) Positionen eingelesen, noch keine Arbeitspakete."
                }
                if pakete == 0 { return "Noch nichts drin." }
                return "\(pakete) Arbeitspakete, \(positionen) Positionen. Noch hat keiner angefangen."
            case .laeuft:
                return "\(pakete) Arbeitspakete. Es wird gearbeitet."
            case .fertig:
                return "Alle \(pakete) Arbeitspakete sind erledigt."
            }
        }
    }

    /// Was an einer Baustelle anstünde — in der Reihenfolge, in der es Sinn ergibt.
    @MainActor
    private static func lage(_ event: Event) -> Lage {
        let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
        let positionen = ((event.lvPositionen as? Set<LVPosition>) ?? [])
        let phase = Phase.von(event)

        var l = Lage(baustelle: event.title ?? "Baustelle", event: event, phase: phase,
                     pakete: jobs.count, positionen: positionen.count)

        if event.eventStartTime == nil {
            l.anstehend.append(Anstehend(text: "Einen Baubeginn festlegen — ohne den bleibt der Kalender leer.",
                                         insLV: false, thema: "baubeginn-fehlt"))
        }
        if jobs.isEmpty && !positionen.isEmpty {
            l.anstehend.append(Anstehend(text: "Arbeitspakete vorschlagen lassen — der Mops macht aus \(positionen.count) Positionen ein gutes Dutzend Pakete.", insLV: true))
        }
        let ohneDauer = jobs.filter { $0.dauerTage <= 0 }
        if !ohneDauer.isEmpty {
            // Ein einzelnes Paket wird beim Namen genannt und direkt angesteuert.
            let text = ohneDauer.count == 1
                ? "„\(Kausalkette.bezeichnung(ohneDauer[0]))" + "\u{201C} hat keine Dauer — ohne die steht nichts im Kalender."
                : "\(ohneDauer.count) Pakete haben keine Dauer — ohne die steht nichts im Kalender."
            l.anstehend.append(Anstehend(text: text, insLV: false,
                                         job: ohneDauer.count == 1 ? ohneDauer[0] : nil,
                                         thema: "dauer-fehlt"))
        }
        let ohneMann = jobs.filter { ($0.employeeName ?? "").isEmpty }
        if !jobs.isEmpty && ohneMann.count == jobs.count {
            // Beim allerersten Paket führt die Zeile direkt dorthin — sonst zur Baustelle,
            // wo die Terminplan-Karte alle auf einmal zeigt.
            let erstes = jobs.sorted { Kausalkette.bezeichnung($0) < Kausalkette.bezeichnung($1) }.first
            l.anstehend.append(Anstehend(
                text: jobs.count == 1 ? "Niemand ist zugeteilt."
                                      : "Niemand ist zugeteilt — bei keinem der \(jobs.count) Pakete.",
                insLV: false,
                job: jobs.count == 1 ? erstes : nil,
                thema: "niemand-zugeteilt"))
        }
        let zaehlbar = positionen.sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }.zaehlbarePositionen()
        let ohnePreis = zaehlbar.filter { LVKalkulator.effektiverEP(for: $0) <= 0 }.count
        if ohnePreis > 0 {
            l.anstehend.append(Anstehend(
                text: ohnePreis == 1 ? "Eine Position hat noch keinen Preis."
                                     : "\(ohnePreis) Positionen haben noch keinen Preis.",
                insLV: true, thema: "preis-fehlt"))
        }
        // 🔴 Was erklärt wurde, wird nicht mehr gemeldet. Mit Grund, nicht stumm —
        // die Erklärung steht im Sonderfall-Buch, mit Namen und Datum.
        l.anstehend = l.anstehend.filter { a in
            guard !a.thema.isEmpty else { return true }
            return SonderfallBuch.shared.erklaerung(
                thema: a.thema,
                baustelle: l.baustelle,
                betrifft: a.job.map { Kausalkette.bezeichnung($0) } ?? l.baustelle) == nil
        }
        return l
    }

    /// Wo zuletzt gearbeitet wurde — der Wiedereinstieg nach der Unterbrechung.
    struct Zuletzt {
        let baustelle: String
        let wann: Date
        let event: Event
    }

    struct Ergebnis {
        var blockaden: [Blockade] = []
        var startklar: [Startklar] = []
        var ohneAnweisung: [OhneAnweisung] = []
        var preisluecken: [Preisluecke] = []
        var fristen: [Fristsache] = []
        var lagen: [Lage] = []
        var zuletzt: Zuletzt?
        var baustellenAktiv = 0

        /// Die Lage in einem Satz — der Rahmen, der über allem steht.
        ///
        /// 🔴 Andreas: „im Kopf der neuen Anzeige muss noch was dazu, mir fehlt da noch
        /// was, eventuell weil nur eine Baustelle drin ist." Genau deshalb: der
        /// Bildschirm fing mit einer einzelnen Karte an und sagte nie, wovon das eine
        /// von wie vielen ist. Bei einer Baustelle merkt man es kaum, bei fünf ist es
        /// das Erste, was man wissen will.
        var lageSatz: String {
            guard !lagen.isEmpty else { return "Noch keine Baustelle" }
            let laufend = lagen.filter { $0.phase == .laeuft }.count
            let geplant = lagen.filter { $0.phase == .planung }.count
            let fertig  = lagen.filter { $0.phase == .fertig }.count

            var teile = ["\(lagen.count) \(lagen.count == 1 ? "Baustelle" : "Baustellen")"]
            if laufend > 0 { teile.append(laufend == 1 ? "1 läuft" : "\(laufend) laufen") }
            if geplant > 0 { teile.append(geplant == 1 ? "1 wird geplant" : "\(geplant) werden geplant") }
            if fertig  > 0 { teile.append(fertig == 1 ? "1 fertig" : "\(fertig) fertig") }
            return teile.joined(separator: " · ")
        }

        /// Was insgesamt ansteht — die drei Zahlen, die den Tag beschreiben.
        var arbeitSatz: String {
            var teile: [String] = []
            if !blockaden.isEmpty { teile.append("\(blockaden.count) steht still") }
            if !ohneAnweisung.isEmpty { teile.append("\(ohneAnweisung.count) ohne Schritte") }
            if !startklar.isEmpty { teile.append("\(startklar.count) kann anfangen") }
            let ueberfaellig = fristen.filter(\.ueberfaellig).count
            if ueberfaellig > 0 { teile.append("\(ueberfaellig) überfällig") }
            return teile.joined(separator: " · ")
        }

        var istRuhig: Bool {
            blockaden.isEmpty && startklar.isEmpty && preisluecken.isEmpty && fristen.isEmpty
        }

        /// 🔴 Der Unterschied zwischen "es liegt was an" und "es brennt".
        /// Fehlende Preise und startklare Aufträge sind ARBEIT — in der Planung sogar
        /// der Normalzustand. Ein Warndreieck, das dabei angeht, steht dauernd auf rot
        /// und wird nach drei Tagen nicht mehr gesehen.
        /// Alarm gibt es nur, wenn jemand WIRKLICH steht oder eine Frist gerissen ist.
        var brauchtAufmerksamkeit: Bool {
            !blockaden.isEmpty || fristen.contains(where: \.ueberfaellig)
        }
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
            e.lagen.append(lage(event))

            // 1) Blockaden: ein laufender Auftrag, dessen Voraussetzung nicht erfüllt ist.
            //    Die Daten dafür liegen längst (523 Voraussetzungen mit Reihenfolge und
            //    Wartezeit) — sie wurden nur nie baustellenübergreifend gelesen.
            //    WICHTIG: `offeneVoraussetzungen` statt selbst zu filtern. Das rohe Feld
            //    `erfuellt` lügt bei Kanten — eine Kante ist erfüllt, wenn ihr VORGÄNGER
            //    fertig ist, das Häkchen bleibt dabei auf „nein". Wer roh filtert, meldet
            //    Blockaden, die längst keine mehr sind.
            //    🔴 EINE KETTE IST KEIN ALARM. Bis zum 21.09. galt jede offene
            //    Voraussetzung als Blockade — bei einem verketteten Bauablauf, der noch
            //    gar nicht begonnen hat, meldete der Mops dann 33 rote Alarme für einen
            //    völlig normalen Plan. Andreas beim Selbstversuch als Erstnutzer:
            //    „ich klick drauf, denn da ist ein Problem" — es war keins.
            //
            //    Jemand steht nur in EINEM Fall: der Auftrag LÄUFT und ihm fehlt etwas.
            //    Was auf einen noch nicht fertigen Vorgänger wartet, ist Plan, nicht Not.
            for auftrag in offen where auftrag.status == .inProgress {
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

            //    Und die Gegenseite: was könnte man ANFANGEN? Alle Vorgänger fertig,
            //    selbst noch nicht begonnen. Das ist die nützlichste Zeile des Tages —
            //    und sie ist keine Warnung, sondern ein Angebot.
            for auftrag in offen where auftrag.status != .inProgress && auftrag.istStartbar {
                e.startklar.append(Startklar(
                    baustelle: name,
                    auftrag: Kausalkette.bezeichnung(auftrag),
                    event: event,
                    job: auftrag))
            }

            //    Und davor liegt noch eine Stufe: Aufträge, für die niemand die
            //    Schritte geschrieben hat. Reihenfolge wie im Bauablauf, damit
            //    "der nächste" auch wirklich der nächste ist.
            for auftrag in offen where AuftragExtrasPayload.from(auftrag.extras).checklist.isEmpty {
                e.ohneAnweisung.append(OhneAnweisung(
                    baustelle: name,
                    auftrag: Kausalkette.bezeichnung(auftrag),
                    event: event,
                    job: auftrag))
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
            //    Nur als Rückfall — die echte Antwort steht unten in ZuletztBesucht.
            if let wann = letzteBeruehrung(event) {
                if e.zuletzt == nil || wann > e.zuletzt!.wann {
                    e.zuletzt = Zuletzt(baustelle: name, wann: wann, event: event)
                }
            }
        }

        // 🔴 „Wo war ich?" ist keine Eigenschaft der Baustelle, sondern eine des
        //    Menschen davor. Gemessen am 21.09.2026: `startTime` leer, und von 34
        //    Aufträgen hatte keiner eine `lastStartTime` — wer plant, startet nichts.
        //    Der gemerkte Besuch weiss es wirklich und schlägt deshalb die Schätzung.
        if let besuch = ZuletztBesucht.lesen(in: ctx) {
            e.zuletzt = Zuletzt(baustelle: besuch.name, wann: besuch.wann, event: besuch.event)
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
