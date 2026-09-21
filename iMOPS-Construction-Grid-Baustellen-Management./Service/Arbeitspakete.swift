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
//  DIN 276, und die DIN 276 folgt grob dem Bauablauf. Beim BV Setiadji: 109 Positionen
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
        return nachTitel.keys.sorted().map { nr in
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
                dauerTage: (tage * 2).rounded() / 2)     // auf halbe Tage
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

        for v in vorschlaege where v.uebernehmen {
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
    static func titelNummer(_ pos: LVPosition) -> String {
        let nr = (pos.posNr ?? "").trimmingCharacters(in: .whitespaces)
        guard !nr.isEmpty else { return "00" }
        if let punkt = nr.firstIndex(of: ".") {
            let kopf = String(nr[nr.startIndex..<punkt])
            return kopf.isEmpty ? "00" : kopf
        }
        return String(nr.prefix(2))
    }

    /// Ein sprechender Name für das Paket. Erste Wahl: die Kostengruppe im Klartext
    /// (DIN 276) — die kennt der Mops schon. Sonst der Anfang der ersten Bezeichnung.
    static func name(fuer gruppe: [LVPosition], titelNr: String) -> String {
        let kgs = gruppe.compactMap { $0.kostenGruppeNummer }.filter { !$0.isEmpty }
        // häufigste Kostengruppe der Gruppe
        if let haeufigste = Dictionary(grouping: kgs, by: { $0 })
            .max(by: { $0.value.count < $1.value.count })?.key {
            let text = DIN276KostenGruppe.bezeichnung(fuer: haeufigste)
            if !text.isEmpty, text != haeufigste { return text }
        }
        if let erste = gruppe.first?.bezeichnung, !erste.isEmpty {
            return String(erste.prefix(34))
        }
        return "Titel \(titelNr)"
    }
}
