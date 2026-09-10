//
//  SandsteinstufenSeeder.swift
//  Demo-Baustelle Nr. 2 — der frühe Lebenszyklus.
//
//  Zwei zerbrochene Sandsteinstufen austauschen. Ein kleiner, echter Job, der
//  zeigt, was „Bauer Horst" nicht zeigt: **Wartezeit auf Lieferung** und eine
//  **Fremdleistung**. Der Graph hat zwei Stränge, die unabhängig starten und
//  sich beim Versetzen treffen.
//
//  ── Zwei Modell-Lücken, die diese Demo offenlegt ─────────────────────────────
//
//  **1. Es gibt keine Kostenart für Fremdleistung.** `LVPosition` kennt genau drei
//     Töpfe: `kalkMaterialien`, `kalkLohn`, `kalkGeraete` (nachgemessen). Der
//     Steinmetz, der den Stein auf Maß schneidet, ist keins davon. Seine 100 €
//     werden hier **bewusst nicht** als getarntes Material oder als Lohnstunde
//     verbucht — das würde die Kalkulation rechnerisch richtig und inhaltlich
//     falsch machen. Sie stehen im Klartext am Arbeitsschritt. Siehe den Test
//     `fremdleistungHatKeineKostenart`.
//
//  **2. Der Termin des Auftrags liegt in JSON, nicht im Modell.** `Auftrag` hat
//     kein Core-Data-Feld dafür — wohl aber `AuftragExtrasPayload.deadline`, das
//     als JSON in `extras` liegt und von `HouseProjectGenerator` und
//     `AuftragDetailView` benutzt wird. Der Unterschied ist praktisch: **man kann
//     darauf nicht per `NSPredicate` suchen, nicht sortieren, nicht filtern.**
//     Eine Frage wie „welche Bestellung wird diese Woche fällig?" lässt sich mit
//     dem heutigen Modell nicht stellen, nur von Hand durchblättern. Der
//     Bestellzyklus (`BestellscheinAngaben`, Vorlauf-Warnung) ist mit diesem
//     Seeder **nicht** verdrahtet.
//
//  ── Alle Zahlen sind Schätzung ───────────────────────────────────────────────
//  `mengenQuelle = .schaetzung`. Sie zeigen die Struktur, nicht den Preis.
//

import Foundation
import CoreData

enum SandsteinstufenSeeder {

    private static let eventNummer = "DEMO-STUFEN-001"

    /// Legt die Demo an, falls sie fehlt. Idempotent über die `eventNumber`.
    static func seedIfNeeded(context: NSManagedObjectContext) {
        let suche: NSFetchRequest<Event> = Event.fetchRequest()
        suche.fetchLimit = 1
        suche.predicate = NSPredicate(format: "eventNumber == %@", eventNummer)
        guard (try? context.fetch(suche))?.first == nil else { return }

        let baustelle = macheBaustelle(in: context)
        let schritte = macheAuftraege(fuer: baustelle, in: context)
        verketteSchritte(schritte)
        macheStufenPosition(fuer: baustelle, in: context)

        do {
            try context.save()
        } catch {
            // Lieber gar keine Demo als eine halbe — die sähe aus wie ein Datenfehler.
            context.rollback()
            print("SandsteinstufenSeeder: konnte nicht sichern — \(error)")
        }
    }

    // MARK: - Der Termin

    /// Erster Freitag des Folgemonats, 08:00 — der Wunschtermin des Kunden.
    ///
    /// Gerechnet statt hart eingetragen, damit die Demo in jedem Monat einen
    /// plausiblen Termin in der Zukunft hat. Wird kein Freitag gefunden (kann
    /// nicht vorkommen, jeder Monat hat vier), fällt sie auf den Monatsersten
    /// zurück statt `nil` zu liefern.
    static func ersterFreitagImFolgemonat(nach heute: Date = Date(),
                                          kalender: Calendar = .current) -> Date {
        var kal = kalender
        kal.firstWeekday = 2   // Montag — beeinflusst nur Wochenrechnungen, nicht die Suche
        let monatsAnfang = kal.date(from: kal.dateComponents([.year, .month], from: heute))!
        let folgemonat = kal.date(byAdding: .month, value: 1, to: monatsAnfang)!

        for tag in 0..<7 {
            guard let kandidat = kal.date(byAdding: .day, value: tag, to: folgemonat) else { continue }
            // 6 == Freitag in Gregorian (Sonntag = 1)
            if kal.component(.weekday, from: kandidat) == 6 {
                return kal.date(bySettingHour: 8, minute: 0, second: 0, of: kandidat) ?? kandidat
            }
        }
        return kal.date(bySettingHour: 8, minute: 0, second: 0, of: folgemonat) ?? folgemonat
    }

    // MARK: - Die Baustelle

    private static func macheBaustelle(in context: NSManagedObjectContext) -> Event {
        let jetzt = Date()
        let termin = ersterFreitagImFolgemonat(nach: jetzt)

        let event = Event(context: context)
        event.eventNumber = eventNummer
        event.title = "Dr. Arzt — 2 Sandsteinstufen austauschen"
        event.location = "Hauseingang, Privatkunde"
        event.bauherr = "Dr. Arzt (Privat)"
        event.notes = """
            Zwei zerbrochene Sandsteinstufen am Hauseingang austauschen.

            Zeigt den frühen Lebenszyklus: Der Stein hat eine lange Lieferzeit, \
            und ein Steinmetz schneidet ihn auf Maß. Beide Stränge — Unterbau \
            vorbereiten und Stein beschaffen — laufen unabhängig und treffen \
            sich erst beim Versetzen.

            Zwei Modell-Lücken sind hier absichtlich sichtbar: die Fremdleistung \
            des Steinmetzes hat keine eigene Kostenart, und der Termin des \
            Auftrags liegt in JSON statt im Modell (nicht abfragbar).

            Alle Zahlen sind geschätzt.
            """
        event.timeStamp = jetzt
        event.setupTime = jetzt
        // Wunschtermin Kunde.
        event.eventStartTime = termin
        event.eventEndTime = Calendar.current.date(byAdding: .day, value: 1, to: termin)
        return event
    }

    // MARK: - Die sechs Schritte

    /// Name, Kostengruppe und — wo nötig — ein Klartext-Zusatz.
    ///
    /// Kostengruppe nur an den Schritten, die ein **Bauteil** herstellen.
    ///
    /// **544 „Rampen, Treppen, Tribünen"** — gegen `DIN276BaumKatalog` geprüft.
    /// Der Auftrag nannte 535; das ist im Katalog **„Sportplatzflächen"**. Eine
    /// Hauseingangstreppe gehört zu den Baukonstruktionen der Außenanlagen (540er),
    /// nicht zum Oberbau (530er).
    ///
    /// Bestellen, Anpassen und Reinigen sind Tätigkeiten; eine Nummer dafür wäre
    /// erfunden — dieselbe Regel wie bei Bauer Horst.
    private static let schritte: [(name: String, kg: String?)] = [
        ("Baustelle absichern, 2 zerbrochene Stufen ausbauen, Bruch entsorgen", "544"),
        ("Unterbau / Auflager prüfen & vorbereiten",                            "544"),
        ("Naturstein bestellen & liefern lassen (lange Lieferzeit!)",            nil),
        ("Steinmetz: Stein anpassen / auf Maß zuschneiden — "
         + "Fremdleistung 100 € (im Modell keine eigene Kostenart)",             nil),
        ("Stufen versetzen (Trass-/Natursteinmörtel), ausrichten, Fugen",       "544"),
        ("Reinigen, Baustelle räumen",                                           nil),
    ]

    private static func macheAuftraege(fuer baustelle: Event,
                                       in context: NSManagedObjectContext) -> [Auftrag] {
        // Der Bestellschritt bekommt den Kundentermin als Ziel — siehe Lücke 2 im
        // Dateikopf: das Feld liegt in JSON, ist also nicht abfragbar, existiert
        // aber und wird von `AuftragDetailView` angezeigt.
        let termin = baustelle.eventStartTime

        return schritte.enumerated().map { (nummer, schritt) in
            let auftrag = Auftrag(context: context)
            auftrag.event = baustelle
            auftrag.processingDetails = schritt.name       // `Auftrag` hat kein Namensfeld
            auftrag.kostenGruppeNummer = schritt.kg
            auftrag.status = .pending
            auftrag.employeeName = ""
            auftrag.storageLocation = ""
            auftrag.storageNote = ""                       // im Modell nicht optional
            auftrag.deliveryTemperature = false
            auftrag.totalProcessingTime = 0

            var extras = AuftragExtrasPayload()
            extras.station = "Hauseingang"
            if nummer == 2 {                               // Schritt 3: bestellen
                extras.deadline = termin
                extras.orderNumber = "STUFEN-\(String(UUID().uuidString.prefix(4)))"
            }
            auftrag.extras = extras.toJSONString()
            return auftrag
        }
    }

    // MARK: - Die Kette

    /// Zwei Stränge, die sich treffen. Indizes 1-basiert wie in `schritte`.
    ///
    /// **Strang A** (1→2): alte Stufen raus, Unterbau herrichten.
    /// **Strang B** (3→4): Stein bestellen, Steinmetz passt ihn an.
    /// Beide münden in **Schritt 5** (versetzen) — der wartet auf den fertigen
    /// Unterbau *und* den fertigen Stein.
    ///
    /// Schritt 3 hat **keinen** Vorgänger: bestellt wird sofort, nicht erst wenn
    /// die alten Stufen draußen sind. Bei wochenlanger Lieferzeit wäre alles
    /// andere ein Planungsfehler.
    private static let kanten: [(vorher: Int, nachher: Int)] = [
        (1, 2),           // Strang A
        (3, 4),           // Strang B, läuft parallel
        (2, 5), (4, 5),   // beide → versetzen
        (5, 6),           // → reinigen
    ]

    private static func verketteSchritte(_ auftraege: [Auftrag]) {
        guard let context = auftraege.first?.managedObjectContext else { return }
        for kante in kanten {
            let vorher = kante.vorher - 1, nachher = kante.nachher - 1
            guard auftraege.indices.contains(vorher),
                  auftraege.indices.contains(nachher) else { continue }
            do {
                try Kausalkette.verknuepfe(auftraege[nachher],
                                           brauchtVorher: auftraege[vorher],
                                           in: context)
            } catch {
                print("SandsteinstufenSeeder: Kante \(kante) abgelehnt — \(error)")
            }
        }
    }

    // MARK: - Die eine LV-Zeile

    /// Was der Kunde im Angebot sieht: eine Zeile, pauschal.
    ///
    /// **Die 100 € für den Steinmetz fehlen hier bewusst.** Es gibt keinen Topf
    /// dafür, und sie als Material oder Lohn zu verbuchen hieße, eine Lücke mit
    /// einer Lüge zu füllen. Die Summe unter dieser Position ist damit
    /// **unvollständig** — und genau das soll man sehen.
    private static func macheStufenPosition(fuer baustelle: Event,
                                            in context: NSManagedObjectContext) {
        let pos = LVPosition(context: context)
        pos.event = baustelle
        pos.posNr = "1.10.1"
        pos.bezeichnung = "Austausch 2 Sandsteinstufen weiß, ca. 30x120 cm, "
                        + "inkl. Ausbau, Unterbau, Versetzen"
        pos.menge = 1
        pos.einheit = "psch"
        pos.kostenGruppeNummer = "544"      // Rampen, Treppen, Tribünen (DIN276BaumKatalog)
        pos.mengenQuelle = .schaetzung

        // --- Material [Schätzung] ---
        let material: [(name: String, menge: Double, einheit: String, preis: Double, verschnitt: Double)] = [
            ("Sandsteinstufe weiß ca. 30x120 cm", 2.0, "Stk", 200.00, 0),
            ("Naturstein-/Trassmörtel",           1.0, "Sack", 30.00, 0),
            ("Kleinmaterial / Fugen",             1.0, "psch", 15.00, 0),
        ]
        for m in material {
            let pm = PositionMaterial(context: context)
            pm.id = UUID()
            pm.materialName = m.name
            pm.mengeProEinheit = m.menge
            pm.einheit = m.einheit
            pm.einzelpreis = m.preis
            pm.verschnittProzent = m.verschnitt
            pm.position = pos
        }

        // --- Lohn [Schätzung] — Ausbau + Versetzen, ein Mann, ein Tag ---
        let lohn = PositionLohn(context: context)
        lohn.id = UUID()
        lohn.qualifikation = "Facharbeiter"
        lohn.stunden = 8.0
        lohn.stundenBruttoEK = 74.0
        lohn.position = pos

        // --- Gerät [Schätzung] ---
        // Die Spedition ist eine Pauschale, `PositionGeraet` rechnet aber
        // `stunden × kostenProStunde`. Als 1 × 100 € eingetragen — rechnerisch
        // richtig, begrifflich schief. Eine kleine Schwester der Fremdleistungs-
        // Lücke: das Modell kennt nur Zeit, nicht Pauschalen.
        let geraete: [(name: String, stunden: Double, satz: Double)] = [
            ("Anlieferung Naturstein (Spedition, pauschal)", 1.0, 100.00),
            ("Werkzeug / Trennschneider",                    3.0,   6.00),
        ]
        for g in geraete {
            let pg = PositionGeraet(context: context)
            pg.id = UUID()
            pg.geraetName = g.name
            pg.stunden = g.stunden
            pg.kostenProStunde = g.satz
            pg.position = pos
        }
    }
}
