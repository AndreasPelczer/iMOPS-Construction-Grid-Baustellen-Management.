//
//  BauerHorstSeeder.swift
//  Die Demo-Baustelle, die BEIDE Welten hat.
//
//  Ein Pfosten auf einem Bauernhof: zwölf Handgriffe (→ Grap8-Knoten mit Kette)
//  und **eine** Leistungsverzeichnis-Zeile mit Kosten (→ Kalkulation). Beides am
//  selben `Event`, aber **ungekoppelt** — genau das ist der Punkt.
//
//  ── Warum die Lücke Absicht ist ──────────────────────────────────────────────
//  Zwischen `Auftrag` und `LVPosition` gibt es **keine** Beziehung im Modell
//  (nachgemessen: nur `Event.jobs` und die beiden `Voraussetzung`-Kanten zeigen
//  auf `Auftrag`). Wer den Pfosten setzt, arbeitet in zwölf Schritten; wer ihn
//  abrechnet, schreibt eine Zeile. Diese Demo führt beide Sichten nebeneinander
//  vor, ohne sie zu verbinden — die Verbindung ist die offene Entscheidung, und
//  sie hier heimlich zu bauen würde die Frage verstecken statt sie zu zeigen.
//
//  ── Alle Zahlen sind Schätzung ───────────────────────────────────────────────
//  Kein Wert hier ist gemessen oder von einem Kalkulator geprüft. Sie zeigen die
//  **Struktur** einer Kalkulation, nicht die Preise eines echten Angebots. Die
//  LV-Position trägt darum `mengenQuelle = .schaetzung`, damit die Ampel aus
//  Welle 9 sie andersfarbig führt. Raphi korrigiert.
//

import Foundation
import CoreData

enum BauerHorstSeeder {

    /// Kennung für die Idempotenz — wie bei `DemoSeeder` über die `eventNumber`.
    private static let eventNummer = "DEMO-PFOSTEN-001"

    /// Legt die Demo-Baustelle an, falls sie noch nicht da ist.
    ///
    /// Idempotent: Der zweite Lauf findet die `eventNumber` und tut nichts. Es wird
    /// **nichts gelöscht** und nichts überschrieben.
    static func seedIfNeeded(context: NSManagedObjectContext) {
        let suche: NSFetchRequest<Event> = Event.fetchRequest()
        suche.fetchLimit = 1
        suche.predicate = NSPredicate(format: "eventNumber == %@", eventNummer)
        guard (try? context.fetch(suche))?.first == nil else { return }

        let baustelle = macheBaustelle(in: context)
        let schritte = macheAuftraege(fuer: baustelle, in: context)
        verketteSchritte(schritte)
        machePfostenPosition(fuer: baustelle, in: context)

        do {
            try context.save()
        } catch {
            // Nicht stillschweigend scheitern: eine halb angelegte Demo ist
            // schlimmer als gar keine, weil sie aussieht wie ein Datenfehler.
            context.rollback()
            print("BauerHorstSeeder: konnte nicht sichern — \(error)")
        }
    }

    // MARK: - Die Baustelle

    private static func macheBaustelle(in context: NSManagedObjectContext) -> Event {
        let jetzt = Date()
        let event = Event(context: context)
        event.eventNumber = eventNummer
        event.title = "Bauer Horst — Pfosten setzen"
        event.location = "Hofeinfahrt, Dörlesberg"
        event.bauherr = "Horst (Landwirt)"
        event.notes = """
            Demo-Baustelle für Grap8: ein einziger Pfosten, in zwölf Handgriffen.
            Daneben liegt EINE LV-Position, die dasselbe abrechnet.

            Zweck: zeigen, wie weit die Arbeitssicht (12 Knoten) und die \
            Abrechnungssicht (1 Zeile) auseinanderliegen. Beide gehören zu dieser \
            Baustelle, sind aber nicht miteinander verbunden — diese Lücke ist \
            der eigentliche Gegenstand.

            Alle Zahlen sind geschätzt.
            """
        event.timeStamp = jetzt
        event.setupTime = jetzt
        event.eventStartTime = jetzt
        event.eventEndTime = Calendar.current.date(byAdding: .day, value: 2, to: jetzt)
        return event
    }

    // MARK: - Die zwölf Handgriffe

    /// Name und Kostengruppe je Schritt. Wo keine Kostengruppe steht, gibt DIN 276
    /// keine her, die nicht erfunden wäre — Anfahrt, Einmessen, Anmischen und
    /// Aushärten sind Tätigkeiten, keine Bauteile. Auf der Leinwand tragen sie
    /// dann das Standardsymbol; das ist ehrlicher als eine geratene Nummer.
    private static let schritte: [(name: String, kg: String?)] = [
        ("Baustelle absichern",                                   "397"),
        ("Anfahrt & abladen (LKW-Fahrt 1, von Hand)",              nil),
        ("Pfostenstelle einmessen",                                nil),
        ("Loch ausheben (Spaten + Flex)",                         "322"),
        ("Aushub lagern / abfahren",                              "397"),
        ("Kiesbett einbringen & verdichten",                      "322"),
        ("Beton anmischen (von Hand)",                             nil),
        ("Pfosten setzen, lotrecht, einbetonieren",               "534"),
        ("Aushärten (Wartezeit, keine Mannschaft)",                nil),
        ("Pflaster setzen (Bettung, Flex)",                       "523"),
        ("Fugen füllen, verdichten, säubern",                     "523"),
        ("Räumen, Absicherung zurück, Reste abfahren (LKW 2)",    "397"),
    ]

    private static func macheAuftraege(fuer baustelle: Event,
                                       in context: NSManagedObjectContext) -> [Auftrag] {
        schritte.map { schritt in
            let auftrag = Auftrag(context: context)
            auftrag.event = baustelle
            // `Auftrag` hat kein Namensfeld — der Name lebt in `processingDetails`
            // (siehe `Kausalkette.bezeichnung`).
            auftrag.processingDetails = schritt.name
            auftrag.kostenGruppeNummer = schritt.kg
            auftrag.status = .pending
            auftrag.employeeName = ""
            auftrag.storageLocation = ""
            auftrag.storageNote = ""      // im Modell nicht optional
            auftrag.deliveryTemperature = false
            auftrag.totalProcessingTime = 0
            return auftrag
        }
    }

    // MARK: - Die Kette

    /// Wer auf wen wartet. Indizes wie in `schritte` (0-basiert).
    ///
    /// **Der Punkt der Demo ist Schritt 8 (Pfosten setzen):** er wartet auf das
    /// Kiesbett *und* auf den angemischten Beton. Zwei Stränge laufen zusammen —
    /// das ist ein echter Graph, keine Perlenkette. Das Anmischen (7) hängt direkt
    /// am Abladen (2), nicht am Ausheben: Beton rührt man an, während das Loch
    /// noch offen ist.
    private static let kanten: [(vorher: Int, nachher: Int)] = [
        (1, 2), (2, 3), (3, 4), (4, 5), (5, 6),   // absichern → … → Kiesbett
        (2, 7),                                    // Abladen → Beton anmischen (Abzweig)
        (6, 8), (7, 8),                            // beide Stränge → Pfosten setzen
        (8, 9), (9, 10), (10, 11), (11, 12),       // → aushärten → pflastern → räumen
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
                // `verknuepfe` wirft bei Kreisen. Passiert hier nicht — aber wenn
                // jemand die Liste oben ändert, soll es auffallen statt zu schweigen.
                print("BauerHorstSeeder: Kante \(kante) abgelehnt — \(error)")
            }
        }
    }

    // MARK: - Die eine LV-Zeile

    /// Was der Abrechner sieht: ein Deckel über allem, 1 pauschal.
    ///
    /// Die Einzelkosten darunter sind **geschätzt** und in der Größenordnung eines
    /// halben Arbeitstags mit Kleingerät — sie zeigen, dass eine Pauschale nicht
    /// aus Luft besteht, nicht was der Pfosten kostet.
    private static func machePfostenPosition(fuer baustelle: Event,
                                             in context: NSManagedObjectContext) {
        let pos = LVPosition(context: context)
        pos.event = baustelle
        pos.posNr = "1.10.1"
        pos.bezeichnung = "Pfosten setzen inkl. Fundament, Kiesbett & Pflasterung, "
                        + "Bauernhof mit Absicherung"
        pos.menge = 1
        pos.einheit = "psch"
        pos.kostenGruppeNummer = "534"          // Stellplätze/Einfriedung — wie der Pfosten-Schritt
        // Damit die Welle-9-Ampel sie als Schätzwert führt und nicht als Messung.
        pos.mengenQuelle = .schaetzung

        // --- Lohn [Schätzung — Raphi korrigiert] ---
        // ~4,5 Mannstunden für einen Pfosten mit Pflasterung, ein Mann.
        let lohn = PositionLohn(context: context)
        lohn.id = UUID()
        lohn.qualifikation = "Bauhelfer / Facharbeiter"
        lohn.stunden = 4.5
        lohn.stundenBruttoEK = 74.0             // Brutto-EK inkl. Lohnnebenkosten
        lohn.position = pos

        // --- Material [Schätzung — Raphi korrigiert] ---
        let material: [(name: String, menge: Double, einheit: String, preis: Double, verschnitt: Double)] = [
            ("Pfosten (Holz/Metall)",  1.0,  "Stk", 45.00,  0),
            ("Kies 0/32",              0.15, "m³",  38.00,  5),
            ("Zement 25 kg",           2.0,  "Sack", 9.50,  0),
            ("Pflastersteine",         1.5,  "m²",  28.00, 10),
            ("Bettungssplitt 2/5",     0.08, "m³",  42.00,  5),
            ("Fugensand",              0.02, "m³",  35.00,  0),
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

        // --- Gerät [Schätzung — Raphi korrigiert] ---
        // Der LKW steht mit zwei kurzen Dorffahrten drin (hin, und am Ende die
        // Reste weg) — nicht mit einem Tagessatz.
        let geraete: [(name: String, stunden: Double, satz: Double)] = [
            ("LKW (2 kurze Fahrten)", 1.5,  42.00),
            ("Flex / Trennschleifer", 0.75,  6.00),
            ("Handstampfer",          0.5,   8.00),
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
