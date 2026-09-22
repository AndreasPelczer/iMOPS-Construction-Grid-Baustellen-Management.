//
//  Arbeitspakete.swift
//
//  Aus einem eingelesenen LV die Arbeitspakete VORSCHLAGEN — nicht anlegen.
//
//  Andreas, 21.09.2026, nachdem ich ihm gesagt hatte, er solle sechs Aufträge von Hand
//  anlegen: „Das sollte der Mops wissen und sollte es vorschlagen?!?!?!“
//  Er hat recht. Die Information liegt längst in seinen Daten.
//
//  Ein LV hat 109 Positionen — das ist die ABRECHNUNG. Eine Baustelle hat ein gutes
//  Dutzend Arbeitspakete — das ist die ARBEIT. Zwei verschiedene Dinge. Wer jede
//  LV-Position zu einem Auftrag macht (`LVCanvasBruecke.lvAufDenCanvas`), bekommt 109
//  Knoten und kann damit nichts planen.
//
//  Die Gliederung steht schon in den Positionsnummern: Raphis Angebote laufen nach
//  VOB — Titel `31.`, Positionen `31.0010`, `31.0020`. Die Titelnummer folgt der
//  DIN 276.
//
//  🔴 KORRIGIERT am 22.09.2026. Hier stand: "und die DIN 276 folgt grob dem
//  Bauablauf". Das ist falsch, und es war die Ursache eines echten Fehlers.
//  Die DIN 276 ist eine KOSTENgliederung — sie sortiert danach, wozu das Geld
//  gehoert, nicht danach, wer wann was macht. Bei Andreas landete deshalb in
//  "411 Abwasser-, Wasser-, Gasanlagen" ein Schmutzwasser-Hausanschluss in 2,60 m
//  Tiefe zusammen mit der Sanitaerinstallation im Dachgeschoss: zwei Kolonnen,
//  ein halbes Jahr Abstand, ein Paket.
//  Ein Titel ist ein guter ANFANG fuer ein Arbeitspaket, mehr nicht — deshalb
//  `teilungsVorschlag` und `PaketTeilenView`. Beim BV Setiadji: 109 Positionen
//  in 17 Titeln (31 Erdarbeiten · 32 Gründung · 33 Mauerwerk · 35 Decken · 36 Dach …).
//
//  🔴 ABER: Titelreihenfolge ist NICHT der fertige Bauablauf. Das Gerüst (39) muss vor
//  das Dach (36). Die Grundleitungen (41) liegen im Boden, also vor die Bodenplatte
//  (32). Elektro ist zweigeteilt — Rohinstallation vor Estrich, Endmontage danach.
//  Das kann kein Automat wissen.
//
//  Deshalb VORSCHLAG, nicht Automat: der Mops nimmt 90 % der Tipparbeit ab und sagt
//  ehrlich, was geschätzt ist. Der Mensch zieht es zurecht. Genau Andreas' eigenes
//  Modell („der Auto-Gantt gefällt nicht, ich will selbst einsortieren“).
//

import Foundation
import CoreData

enum Arbeitspakete {

    /// Ein vorgeschlagenes Paket — ein Titel des LV.
    struct Vorschlag: Identifiable {
        var id: String { titelNr }
        let titelNr: String            // "31"
        let name: String               // "Erdarbeiten" (aus der Kostengruppe)
        let positionen: [LVPosition]
        let mannstunden: Double
        let positionenOhneAufwand: Int
        let summe: Double

        /// Vom Menschen änderbar, bevor angelegt wird.
        var uebernehmen: Bool = true
        var dauerTage: Double

        /// Für diesen Titel gibt es schon einen Auftrag. Dann ist der Haken von
        /// vornherein raus — sonst legt ein zweiter Druck alles ein zweites Mal an.
        /// 🔴 Genau das ist am 21.09. passiert: 34 Pakete statt 17. Der Canvas-Knopf
        /// nebenan prüft das längst (`schonVerknuepft`), meiner tat es nicht.
        var schonAngelegt: Bool = false

        /// 🔴 Keine Lohnstunden hinterlegt → die Dauer ist geraten, nicht gerechnet.
        /// Muss im Vorschlag sichtbar sein, sonst ist es eine erfundene Zahl.
        var dauerIstGeschaetzt: Bool { mannstunden <= 0 }
        var anzahlPositionen: Int { positionen.count }
    }

    // MARK: - Vorschlagen

    /// Gruppiert die LV-Positionen einer Baustelle nach Titel (die ersten beiden
    /// Stellen der Positionsnummer) und schätzt je Titel die Dauer.
    ///
    /// - Parameter kolonne: wie viele Leute an einem Paket arbeiten (Default 2).
    @MainActor
    static func vorschlagen(fuer event: Event, kolonne: Int = 2) -> [Vorschlag] {
        let alle = ((event.lvPositionen?.allObjects as? [LVPosition]) ?? [])
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
        guard !alle.isEmpty else { return [] }

        var nachTitel: [String: [LVPosition]] = [:]
        for pos in alle {
            nachTitel[titelNummer(pos), default: []].append(pos)
        }

        let leute = Double(max(1, kolonne))
        let vorhanden = bereitsAngelegteTitel(event)
        return nachTitel.keys.sorted().map { nr in
            let schon = vorhanden.contains(nr)
            let gruppe = nachTitel[nr] ?? []
            let plan = BrigadePlanung.fuer(positionen: gruppe)
            let tage = plan.mannstunden > 0
                ? (plan.mannstunden / BrigadePlanung.stundenJeTag / leute)
                : Double(gruppe.count) * 0.5     // ohne Aufwandswerte: grobe Hausnummer
            return Vorschlag(
                titelNr: nr,
                name: name(fuer: gruppe, titelNr: nr),
                positionen: gruppe,
                mannstunden: plan.mannstunden,
                positionenOhneAufwand: plan.positionenOhneAufwand,
                summe: gruppe.reduce(0) { $0 + $1.menge * LVKalkulator.effektiverEP(for: $1) },
                uebernehmen: !schon,
                dauerTage: (tage * 2).rounded() / 2,     // auf halbe Tage
                schonAngelegt: schon)
        }
    }

    // MARK: - Anlegen

    /// Legt aus den gewählten Vorschlägen Aufträge an und verkettet sie in der
    /// vorgeschlagenen Reihenfolge. Gibt die angelegten Aufträge zurück.
    ///
    /// Die Kette ist ausdrücklich ein ERSTER ENTWURF — sie hängt Paket an Paket in
    /// Titelreihenfolge. Umhängen geht danach in der Auftragsansicht („Wartet auf“).
    @discardableResult @MainActor
    static func anlegen(_ vorschlaege: [Vorschlag], event: Event,
                        verketten: Bool = true,
                        in ctx: NSManagedObjectContext) -> [Auftrag] {
        var angelegt: [Auftrag] = []
        var vorheriger: Auftrag?

        let vorhanden = bereitsAngelegteTitel(event)
        for v in vorschlaege where v.uebernehmen && !vorhanden.contains(v.titelNr) {
            let a = Auftrag(context: ctx)
            a.processingDetails = "\(v.titelNr) \(v.name)"
            a.status = .pending
            a.storageNote = ""          // Pflichtfeld ohne Default — sonst wirft save()
            a.storageLocation = ""
            a.dauerTage = v.dauerTage
            a.kostenGruppeNummer = v.positionen.first?.kostenGruppeNummer
            a.event = event

            if verketten, let vor = vorheriger {
                try? Kausalkette.verknuepfe(a, brauchtVorher: vor, in: ctx)
            }
            vorheriger = a
            angelegt.append(a)
        }
        return angelegt
    }

    // MARK: - Hilfen

    /// Der Titel einer Position: die Ziffern vor dem Punkt („31.0010“ → „31“).
    /// Ohne Punkt: die ersten beiden Zeichen. Ohne Nummer: „00“ (Sammeltitel).
    /// Welche Titel hängen schon als Auftrag an dieser Baustelle?
    /// Erkannt am Namen, den `anlegen` schreibt: "31 Erdarbeiten" -> Titel "31".
    ///
    /// 🔴 Ohne diesen Riegel legt ein zweiter Druck auf den Knopf alles ein zweites
    /// Mal an — am 21.09. wurden so aus 17 Paketen 34. Der Canvas-Knopf nebenan
    /// prüft das längst (`schonVerknuepft`); ich hatte danebengebaut.
    @MainActor
    static func bereitsAngelegteTitel(_ event: Event) -> Set<String> {
        let jobs = (event.jobs?.allObjects as? [Auftrag]) ?? []
        return Set(jobs.compactMap { j -> String? in
            guard let erstes = j.processingDetails?
                .trimmingCharacters(in: .whitespaces)
                .split(separator: " ").first else { return nil }
            let kopf = String(erstes)
            return kopf.allSatisfy(\.isNumber) ? kopf : nil
        })
    }

    static func titelNummer(_ pos: LVPosition) -> String {
        let nr = (pos.posNr ?? "").trimmingCharacters(in: .whitespaces)
        guard !nr.isEmpty else { return "00" }
        if let punkt = nr.firstIndex(of: ".") {
            let kopf = String(nr[nr.startIndex..<punkt])
            return kopf.isEmpty ? "00" : kopf
        }
        return String(nr.prefix(2))
    }

    /// Ein sprechender Name für das Paket.
    ///
    /// Erste Wahl ist der **erste Positionstext** — den hat der Kalkulator geschrieben,
    /// und ein Bauleiter erkennt daran die Arbeit. Die DIN-276-Bezeichnung kommt nur
    /// zum Zug, wenn kein Text da ist.
    ///
    /// Andreas, 21.09., über einen Auftrag namens „331 Baukonstruktionen":
    /// „Das sagt dir nichts über die Arbeit." Im selben Titel stand als erste Position
    /// „Aussparungen und Wanddurchbrüche im Mauerwerk" — damit kann man etwas anfangen.
    static func name(fuer gruppe: [LVPosition], titelNr: String) -> String {
        if let erste = gruppe.first?.bezeichnung?
            .trimmingCharacters(in: .whitespacesAndNewlines), !erste.isEmpty {
            return kurz(erste)
        }
        let kgs = gruppe.compactMap { $0.kostenGruppeNummer }.filter { !$0.isEmpty }
        if let haeufigste = Dictionary(grouping: kgs, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key {
            let text = DIN276KostenGruppe.bezeichnung(fuer: haeufigste)
            if !text.isEmpty, text != haeufigste { return text }
        }
        return "Titel \(titelNr)"
    }

    /// Positionstexte sind lang und tragen ihre Angaben im Schwanz („…, verdichtet
    /// DPr >= 97 %"). Für einen Auftragsnamen reicht der Anfang bis zum ersten Komma.
    private static func kurz(_ text: String) -> String {
        let bisKomma = text.split(separator: ",", maxSplits: 1).first.map(String.init) ?? text
        let sauber = bisKomma.trimmingCharacters(in: .whitespacesAndNewlines)
        // 60 statt 44: „Aussparungen und Wanddurchbrueche im Mauerwerk" hat 45 Zeichen
        // und wurde von der ersten, zu knappen Grenze mitten im Wort abgeschnitten.
        if sauber.count > 4 && sauber.count <= 60 { return sauber }
        return String(text.prefix(58)).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - Was gehört zu diesem Auftrag?

    /// Die Titelnummer, die vorn im Auftragsnamen steht ("572 Außenanlagen…" → "572").
    ///
    /// 🔴 Das ist eine BRÜCKE ÜBER DEN NAMEN, keine echte Verbindung. Im Datenmodell
    /// ist `Auftrag.lvPosition` eine 1:1-Beziehung — ein Auftrag kann darüber genau
    /// EINE Position halten, ein Arbeitspaket fasst aber viele zusammen. Solange das
    /// so ist, wird die Zugehörigkeit gerechnet statt gespeichert.
    /// Folge: benennt jemand den Auftrag um und nimmt die Nummer weg, ist die
    /// Zuordnung weg. Deshalb steht in der Ansicht dabei, woher sie kommt.
    static func titelNummerAusName(_ auftrag: Auftrag) -> String? {
        let name = (auftrag.processingDetails ?? "").trimmingCharacters(in: .whitespaces)
        let ersterTeil = name.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        let ziffern = ersterTeil.filter(\.isNumber)
        guard !ziffern.isEmpty, ziffern.count == ersterTeil.count else { return nil }
        return ersterTeil
    }

    /// Alle LV-Positionen, die zu diesem Arbeitspaket gehören — in Positionsreihenfolge.
    @MainActor
    static func positionen(fuer auftrag: Auftrag) -> [LVPosition] {
        guard let event = auftrag.event,
              let alle = event.lvPositionen as? Set<LVPosition> else { return [] }

        // 1. Wurde das Paket geteilt, gilt die ausdrückliche Zuordnung.
        let eigene = PaketZuordnung.shared.posNummern(fuer: auftrag)
        if !eigene.isEmpty {
            let gesucht = Set(eigene)
            return alle
                .filter { gesucht.contains($0.posNr ?? "") }
                .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
        }

        // 2. Die echte 1:1-Verbindung, falls jemand sie gesetzt hat.
        if let einzelne = auftrag.lvPosition { return [einzelne] }

        // 3. Sonst über die Titelnummer — aber ohne das, was beim Teilen
        //    ausdrücklich woandershin gegeben wurde.
        guard let titelNr = titelNummerAusName(auftrag) else { return [] }
        return alle
            .filter { titelNummer($0) == titelNr }
            .filter { !PaketZuordnung.shared.gehoertWoandershin($0.posNr ?? "", ausser: auftrag) }
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
    }

    /// Was das Paket zusammenzählt: Positionen, Summe, und wie viele noch ohne Preis sind.
    struct Umfang {
        var positionen: Int = 0
        var summe: Double = 0
        var ohnePreis: Int = 0
        var einheiten: [String: Double] = [:]   // "m²" → 340, "m³" → 12
        var istGerechnet = true                 // über den Namen, nicht gespeichert
    }

    @MainActor
    static func umfang(fuer auftrag: Auftrag) -> Umfang {
        let liste = positionen(fuer: auftrag)
        var u = Umfang(positionen: liste.count, istGerechnet: auftrag.lvPosition == nil)
        for p in liste {
            let ep = LVKalkulator.effektiverEP(for: p)
            if ep <= 0 { u.ohnePreis += 1 } else { u.summe += ep * p.menge }
            let einheit = (p.einheit ?? "").trimmingCharacters(in: .whitespaces)
            if !einheit.isEmpty { u.einheiten[einheit, default: 0] += p.menge }
        }
        return u
    }

    // MARK: - Teilen

    /// Ein Vorschlag, wo die Trennlinie liegen könnte.
    struct Teilung {
        let abtrennen: [LVPosition]
        let name: String
        let begruendung: String
    }

    /// 🔴 Der erste Wurf kannte genau EINE Trennlinie — die, die Andreas' Fall
    /// brauchte. Sein Einwand: „Wenn du etwas baust, dann ist das doch allgemeingültig
    /// oder nur für diesen Fall und diese Baustelle? Das sollte nie passieren."
    /// Jetzt stehen sie in `trennlinien.yaml` und lassen sich erweitern, ohne den
    /// Code anzufassen — Raphi kann welche dazugeben.
    ///
    /// Es kann mehrere geben: ein Titel mit Gerüst UND Außenputz trennt zweimal.
    /// Der Mops schlägt alle vor, geteilt wird von Hand und einzeln.
    @MainActor
    static func teilungsVorschlaege(fuer auftrag: Auftrag) -> [Teilung] {
        let alle = positionen(fuer: auftrag)
        guard alle.count >= 3 else { return [] }

        return TrennlinienKatalog.alle.compactMap { linie in
            let getrennt = alle.filter { p in
                let t = SchrittPassung.flach(p.bezeichnung ?? "")
                return linie.stamm.contains { t.contains($0) }
            }
            // Eine Trennung, die alles oder nichts nimmt, ist keine.
            guard !getrennt.isEmpty, getrennt.count < alle.count else { return nil }

            // 🔴 Und: trägt der Auftrag die Trennlinie SCHON im Namen, ist nichts zu
            // trennen. Getestet an BV Setiadji — „311 Baugrube / Erdbau" bekam den
            // Vorschlag, die Erdarbeiten abzutrennen. Das ganze Paket IST Erdbau.
            let imNamen = SchrittPassung.flach(auftrag.processingDetails ?? "")
            guard !linie.stamm.contains(where: { imNamen.contains($0) }) else { return nil }

            return Teilung(
                abtrennen: getrennt,
                name: linie.name,
                begruendung: "\(getrennt.count) von \(alle.count) Positionen "
                           + linie.begruendung)
        }
        .sorted { $0.abtrennen.count > $1.abtrennen.count }
    }

    /// Der stärkste Vorschlag — für Stellen, die nur einen zeigen können.
    @MainActor
    static func teilungsVorschlag(fuer auftrag: Auftrag) -> Teilung? {
        teilungsVorschlaege(fuer: auftrag).first
    }
}

// MARK: - Bessere Namen für schon angelegte Pakete

extension Arbeitspakete {

    /// 🔴 Elf Arbeitspakete hiessen „Baukonstruktionen", acht „Außenanlagen und
    /// Freiflächen" — gemessen in Andreas' Datenbank am 21.09.2026.
    ///
    /// Die Namen stammen aus einer älteren Fassung von `name(fuer:titelNr:)`, die auf
    /// die DIN-276-Bezeichnung zurückfiel. Inzwischen nimmt sie den ersten
    /// Positionstext — aber die bereits angelegten Aufträge tragen noch die alten.
    ///
    /// Und die wären deutlich besser: hinter „331 Baukonstruktionen" steht
    /// „Mauerwerk Außenwand Ytong PPW 2-0,35, d = 24 cm", hinter „399 Außenanlagen"
    /// eine „Fertiggarage 6000/3500/2750". Damit kann ein Polier etwas anfangen.
    ///
    /// 🔴 Die Titelnummer bleibt VORN stehen: an ihr hängt die Zuordnung zu den
    /// LV-Positionen (`titelNummerAusName`). Nimmt man sie weg, ist die Verbindung weg.
    @MainActor
    static func bessererName(fuer auftrag: Auftrag) -> String? {
        guard let titelNr = titelNummerAusName(auftrag) else { return nil }
        let jetzt = (auftrag.processingDetails ?? "")
            .dropFirst(titelNr.count).trimmingCharacters(in: .whitespaces)

        // Nur ersetzen, was bloss eine Kostengruppe nennt — wer selbst umbenannt
        // hat, wird nicht überfahren.
        guard AnweisungsKatalog.istNurKostengruppe(jetzt) else { return nil }

        let positionen = positionen(fuer: auftrag)
        guard !positionen.isEmpty else { return nil }

        let neu = name(fuer: positionen, titelNr: titelNr)
        guard !AnweisungsKatalog.istNurKostengruppe(neu), neu != jetzt else { return nil }
        return "\(titelNr) \(neu)"
    }

    /// Alle Pakete einer Baustelle, die einen besseren Namen bekommen könnten.
    @MainActor
    static func umbenennbare(in event: Event) -> [(job: Auftrag, neu: String)] {
        ((event.jobs?.allObjects as? [Auftrag]) ?? [])
            .compactMap { j in bessererName(fuer: j).map { (j, $0) } }
            .sorted { Kausalkette.bezeichnung($0.job) < Kausalkette.bezeichnung($1.job) }
    }
}
