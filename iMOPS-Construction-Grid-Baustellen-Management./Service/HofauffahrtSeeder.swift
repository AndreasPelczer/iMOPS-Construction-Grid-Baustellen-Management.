//
//  HofauffahrtSeeder.swift
//  Demo-Baustelle Nr. 3 — das Mengengerüst.
//
//  Eine befahrbare Hofauffahrt pflastern, vier Stellplätze, rund 100 qm. Ein
//  echter Job mit **echten Mengen** — und genau das ist der Unterschied zu den
//  Vorgängern: Bauer Horst und die Sandsteinstufen tragen „1 Psch" als Deckel,
//  hier steht `menge = 100 qm`, und darunter Tonnen, Quadratmeter und laufende
//  Meter. Die Frage dieser Runde war, ob das Mengengerüst trägt.
//
//  ── Es trägt. Aber mit einer Falle, die man kennen muss ──────────────────────
//
//  **`mengeProEinheit` ist die Menge JE POSITIONSEINHEIT, nicht die Gesamtmenge.**
//  Nachgemessen in `PositionMaterial+CoreDataProperties.swift`:
//
//      kostenProEinheit = einzelpreis * mengeProEinheit * (1 + verschnittProzent)
//
//  und in `LVKalkulator.kalkuliere`: `gesamtpreis = einheitspreisVK * menge`.
//
//  Für diese Auffahrt heißt das: Es werden **57 t Mineralgemisch** gebraucht,
//  eingetragen wird aber **0,57** — nämlich 57 t ÷ 100 qm. Wer die Menge aus dem
//  Aufmaß direkt einträgt, rechnet das Hundertfache. Dasselbe gilt für Lohn
//  (`stunden` je Einheit) und Gerät (`stunden` je Einheit).
//
//  Die Gesamtmenge steht deshalb bei jeder Zeile als Kommentar daneben. Ohne den
//  ist die Zahl im Code nicht nachvollziehbar — und beim nächsten Aufmaß rechnet
//  jemand falsch.
//
//  ── Drei Modell-Lücken, die diese Demo offenlegt ─────────────────────────────
//
//  **1. Fremdleistung hat keine Kostenart** (bestätigt die Sandsteinstufen-Runde).
//     Die **Entsorgung des Aushubs** auf Deponie oder Recyclinghof ist weder
//     Material noch Lohn noch Gerät. `LVPosition` kennt nur `kalkMaterialien`,
//     `kalkLohn`, `kalkGeraete` — nachgemessen. Die Entsorgung steht deshalb im
//     Klartext am Arbeitsschritt und **nicht** getarnt in der Kalkulation. Test:
//     `entsorgungHatKeineKostenart`.
//
//  **2. NEU: Es gibt keinen Zustand „variabel / abhängig von".** Die Entsorgung
//     ist nicht nur kostenartlos, sie ist auch **nicht bezifferbar**, bevor die
//     Bodenklasse feststeht (Stammdatenblatt / Erzeugererklärung). Z0 ist fast
//     geschenkt, Z2 kostet ein Vielfaches. Das Modell kennt nur feste Preise;
//     „hängt ab von" lässt sich nicht abbilden. Vermerkt am Schritt, kein Test —
//     es gibt nichts zu prüfen, nur etwas zu wissen.
//
//  **3. Pauschale auf Gerät** (bestätigt die Sandsteinstufen-Runde). Die Fuhren
//     zum Recyclinghof fallen **pro Fahrt** an. `PositionGeraet` rechnet aber
//     `stunden × kostenProStunde`. Sechs Fuhren stehen hier als „6 × 120 €"
//     (je Einheit: 0,06) — rechnerisch richtig, begrifflich schief. Das Modell
//     kennt Zeit, keine Stückzahl.
//
//  ── Zu den Zahlen ────────────────────────────────────────────────────────────
//  `mengenQuelle = .schaetzung`. Richtangebot, verbindlich erst nach Aufmaß.
//  Preisbasis gemischt und je Zeile vermerkt: [Werbach] = Schotterwerk Werbach
//  ab Werk (über Raphael), [Netz] = Marktanker aus dem Netz, [Schätzung] = geraten.
//
//  ── Verschnitt ist ein FAKTOR, kein Prozentwert ──────────────────────────────
//  `verschnittProzent = 0.05` bedeutet 5 %. Nachgemessen an der UI
//  (`MaterialHinzufuegenView`: `(Double(text) ?? 5) / 100.0`) und am
//  `StammdatenSeeder` (0.05 / 0.03 / 0.10 / 0.15).
//  ⚠️ **`BauerHorstSeeder` trägt hier `5` und `10` ein** — das ergibt 500 % und
//  1000 % Aufschlag. Dieser Seeder spiegelt den Fehler bewusst **nicht**.
//

import Foundation
import CoreData

enum HofauffahrtSeeder {

    private static let eventNummer = "DEMO-AUFFAHRT-001"

    /// Die Bezugsmenge der Position. Steht hier einmal, damit die Mengen je
    /// Einheit unten als `gesamt / flaecheQm` lesbar bleiben statt als rohe
    /// Kommazahl.
    private static let flaecheQm: Double = 100

    /// Legt die Demo an, falls sie fehlt. Idempotent über die `eventNumber`.
    static func seedIfNeeded(context: NSManagedObjectContext) {
        let suche: NSFetchRequest<Event> = Event.fetchRequest()
        suche.fetchLimit = 1
        suche.predicate = NSPredicate(format: "eventNumber == %@", eventNummer)
        guard (try? context.fetch(suche))?.first == nil else { return }

        let baustelle = macheBaustelle(in: context)
        let schritte = macheAuftraege(fuer: baustelle, in: context)
        verketteSchritte(schritte)
        macheAuffahrtPosition(fuer: baustelle, in: context)

        do {
            try context.save()
        } catch {
            // Lieber gar keine Demo als eine halbe — die sähe aus wie ein Datenfehler.
            context.rollback()
            print("HofauffahrtSeeder: konnte nicht sichern — \(error)")
        }
    }

    // MARK: - Die Baustelle

    /// **Kein fester Termin.** Anders als bei den Sandsteinstufen steht hier kein
    /// Datum: Das Aufmaß fehlt, und ein Termin ohne Aufmaß wäre eine Zusage, die
    /// niemand gegeben hat. `eventStartTime` bleibt deshalb leer.
    private static func macheBaustelle(in context: NSManagedObjectContext) -> Event {
        let jetzt = Date()

        let event = Event(context: context)
        event.eventNumber = eventNummer
        event.title = "Privatkunde — Hofauffahrt pflastern (4 Stellplätze, ~100 qm)"
        event.location = "Hofeinfahrt, Privatgrundstück"
        event.bauherr = "Privatkunde"
        event.notes = """
            Befahrbare Hofauffahrt pflastern, Platz für vier Fahrzeuge, rund 100 qm.

            Richtangebot, verbindlich nach Aufmaß.

            Diese Demo zeigt, was die beiden Vorgänger nicht zeigen: ein echtes \
            Mengengerüst. Statt „1 Pauschal" steht hier 100 qm, darunter Tonnen, \
            Quadratmeter und laufende Meter.

            Drei Modell-Lücken sind absichtlich sichtbar: die Entsorgung des \
            Aushubs hat keine Kostenart, ihre Kosten sind bodenklassenabhängig \
            und damit gar nicht bezifferbar, und die Fuhren rechnen im \
            Zeit-Modell statt pro Fahrt.

            Alle Zahlen sind geschätzt.
            """
        event.timeStamp = jetzt
        event.setupTime = jetzt
        // Bewusst kein eventStartTime/eventEndTime: das Aufmaß steht aus.
        return event
    }

    // MARK: - Die zehn Schritte

    /// Name und Kostengruppe. Kostengruppe nur an Schritten, die ein **Bauteil**
    /// herstellen; Einrichten, Bestellen, Ausheben, Abfahren, Abrütteln und
    /// Reinigen sind Tätigkeiten und tragen `nil` — dieselbe Regel wie bei den
    /// Vorgängern.
    ///
    /// **Die Kostengruppen wurden am `DIN276BaumKatalog` gemessen, nicht geraten.**
    /// Der Auftrag nannte **520 „Befestigte Flächen"**. Im Katalog heißt 520
    /// **„Gründung / Unterbau"** — der Name aus dem Auftrag existiert dort nicht.
    /// Die befestigten Flächen liegen in der 530er-Gruppe „Oberbau / Deckschichten":
    /// 531 Wege · 532 Straßen · 533 Plätze, Höfe, Terrassen · **534 Stellplätze**.
    ///
    /// Daraus folgt eine Zweiteilung, die der Katalog selbst anlegt:
    /// - **520 „Gründung / Unterbau"** für Trennvlies und Tragschicht — das ist
    ///   der Unterbau, wörtlich.
    /// - **534 „Stellplätze"** für Randsteine und Pflasterdecke — der Oberbau,
    ///   und der Zweck der Fläche ist das Abstellen von vier Fahrzeugen.
    ///
    /// Alles auf eine Nummer zu legen wäre gröber, als der Katalog es hergibt.
    private static let schritte: [(name: String, kg: String?)] = [
        ("Baustelle einrichten, Fläche abstecken, absichern",                      nil),
        ("Material bestellen & anliefern lassen (Schotter, Pflaster, Randstein)",  nil),
        ("Erdaushub ca. 40 cm (Bagger)",                                           nil),
        ("Aushub laden, abfahren, entsorgen — Entsorgung ist Fremdleistung "
         + "(im Modell keine Kostenart). Kosten variabel, bodenklassenabhaengig: "
         + "Z0 bis Z2 nach Stammdatenblatt/Erzeugererklaerung — das Modell hat "
         + "keine Darstellung fuer 'haengt ab von'.",                              nil),
        ("Trennvlies (Geotextil) verlegen",                                      "520"),
        ("Tragschicht Mineralgemisch 0/32, 30 cm, einbauen + verdichten (95 %)", "520"),
        ("Randsteine grau in Beton setzen",                                      "534"),
        ("Bettung + Pflaster verlegen (Gefälle 1,5 %)",                          "534"),
        ("Abrütteln, Fugen füllen + einkehren",                                    nil),
        ("Reinigen, räumen, Reste abfahren",                                       nil),
    ]

    private static func macheAuftraege(fuer baustelle: Event,
                                       in context: NSManagedObjectContext) -> [Auftrag] {
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
            extras.station = "Hofeinfahrt"
            if nummer == 1 {                               // Schritt 2: bestellen
                extras.orderNumber = "AUFFAHRT-\(String(UUID().uuidString.prefix(4)))"
            }
            // Bewusst KEIN `extras.deadline`: ohne Aufmaß kein Termin.
            auftrag.extras = extras.toJSONString()
            return auftrag
        }
    }

    // MARK: - Die Kette

    /// Ein Abzweig und eine Zusammenführung. Indizes 1-basiert wie in `schritte`.
    ///
    /// **Schritt 2 (Material bestellen) hat keinen Vorgänger** — bestellt wird
    /// sofort, nicht erst wenn das Loch fertig ist. Wer 57 Tonnen Schotter erst
    /// ordert, wenn der Bagger schon weg ist, steht mit einer offenen Grube da.
    /// Dieselbe Überlegung wie beim Naturstein bei den Sandsteinstufen und beim
    /// Anmischen bei Bauer Horst.
    ///
    /// **Schritt 6 (Tragschicht) wartet auf zwei Stränge**: das Trennvlies muss
    /// liegen (5) *und* das Material muss da sein (2). Das ist die
    /// Zusammenführung — der Punkt, an dem sich zeigt, ob der Graph mehr kann
    /// als eine Perlenkette.
    ///
    /// Nach dem Seed sind **1 und 2 startklar**, die anderen acht warten.
    private static let kanten: [(vorher: Int, nachher: Int)] = [
        (1, 3),            // einrichten → ausheben
        (3, 4),            // ausheben → abfahren/entsorgen
        (3, 5),            // ausheben → Trennvlies
        (5, 6), (2, 6),    // Tragschicht braucht Vlies UND Material  ← Zusammenführung
        (6, 7),            // Tragschicht → Randsteine
        (7, 8),            // Randsteine → pflastern
        (8, 9),            // pflastern → abrütteln, Fugen
        (9, 10),           // → reinigen
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
                print("HofauffahrtSeeder: Kante \(kante) abgelehnt — \(error)")
            }
        }
    }

    // MARK: - Die eine LV-Zeile, diesmal mengenbasiert

    /// Was der Kunde im Angebot sieht: eine Zeile über 100 qm.
    ///
    /// **Die Entsorgung fehlt hier bewusst.** Sie hat keine Kostenart, und sie
    /// wäre ohne Bodenklasse ohnehin nicht bezifferbar. Sie als Material oder
    /// Gerätestunde zu verbuchen hieße, zwei Lücken mit einer Zahl zuzukleistern.
    /// Die Summe dieser Position ist damit **unvollständig** — und das soll man
    /// sehen.
    private static func macheAuffahrtPosition(fuer baustelle: Event,
                                              in context: NSManagedObjectContext) {
        let pos = LVPosition(context: context)
        pos.event = baustelle
        pos.posNr = "1.20.1"
        pos.bezeichnung = "Hofauffahrt pflastern, befahrbar, ~100 qm, "
                        + "inkl. Unterbau/Randeinfassung/Gefälle"
        pos.menge = flaecheQm
        pos.einheit = "qm"
        pos.kostenGruppeNummer = "534"      // Stellplätze (DIN276BaumKatalog)
        pos.mengenQuelle = .schaetzung

        // --- Material ---
        //
        // `menge` ist die Menge JE QUADRATMETER. Die Gesamtmenge steht daneben,
        // sonst ist „0,57" im Code nicht nachvollziehbar. Verschnitt als Faktor
        // (0.05 = 5 %), siehe Dateikopf.
        let material: [(name: String, menge: Double, einheit: String,
                        preis: Double, verschnitt: Double)] = [
            // 57 t auf 100 qm — 30 cm Tragschicht, verdichtet    [Werbach, ab Werk]
            ("Mineralgemisch 0/32 (Tragschicht)", 57.0 / flaecheQm,  "t",   7.90, 0),
            // 6,5 t auf 100 qm — 4 cm Bettung                    [Werbach, ab Werk]
            ("Splitt 2/8 (Bettung)",               6.5 / flaecheQm,  "t",   8.50, 0),
            // 100 qm auf 100 qm — 1:1, plus 5 % Verschnitt       [Netz-Anker]
            ("Betonpflaster grau, befahrbar 8 cm", 1.0,              "qm", 40.00, 0.05),
            // 30 lfm auf 100 qm — Einfassung ringsum             [Netz-Anker]
            ("Tiefbordstein grau",                30.0 / flaecheQm, "lfm",  8.00, 0),
            // 2 t auf 100 qm — Fugen einkehren                   [Werbach, ab Werk]
            ("Abdecksand/Fugensand 0/2",           2.0 / flaecheQm,  "t",   3.00, 0),
            // 110 qm auf 100 qm — mit Überlappung an den Stößen  [Schätzung]
            ("Trennvlies (Geotextil)",           110.0 / flaecheQm,  "qm",  1.50, 0),
            // 1 cbm auf 100 qm — Rückenstütze der Randsteine     [Schätzung]
            ("Beton C16/20 (Randstein-Rückenstütze)", 1.0 / flaecheQm, "cbm", 110.00, 0),
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

        // --- Lohn [Richtwert] ---
        // 70 Stunden gesamt auf 100 qm = 0,7 h/qm. Zwei Mann, drei bis vier Tage:
        // ausheben begleiten, Unterbau einbauen und verdichten, Randsteine setzen,
        // pflastern, abrütteln, verfugen.
        let lohn = PositionLohn(context: context)
        lohn.id = UUID()
        lohn.qualifikation = "Facharbeiter/Helfer (Mischsatz)"
        lohn.stunden = 70.0 / flaecheQm
        lohn.stundenBruttoEK = 74.0
        lohn.position = pos

        // --- Gerät [Schätzung] ---
        //
        // ⚠️ **Lücke 3:** Die Fuhren sind eine Stückzahl, keine Zeit. Sechs
        // Fahrten zum Recyclinghof à 120 € stehen hier als „0,06 Stunden × 120 €"
        // — rechnerisch ergibt das die richtigen 720 €, begrifflich ist es
        // falsch. `PositionGeraet` kennt nur `stunden × kostenProStunde`; eine
        // Pauschale oder einen Preis pro Stück gibt es im Modell nicht.
        // Kleine Schwester der Fremdleistungs-Lücke.
        let geraete: [(name: String, stunden: Double, satz: Double)] = [
            // 8 h Bagger auf 100 qm — Aushub 40 cm
            ("Minibagger inkl. Bediener",                  8.0 / flaecheQm, 65.00),
            // 10 h Rüttelplatte — Tragschicht lagenweise, Pflaster abrütteln
            ("Rüttelplatte / Verdichter",                 10.0 / flaecheQm, 12.00),
            // 6 Fuhren à 120 € — siehe Hinweis oben: Stückzahl im Zeit-Modell
            ("LKW-Fuhren Aushub (6 Fahrten, je 120 €)",    6.0 / flaecheQm, 120.00),
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
