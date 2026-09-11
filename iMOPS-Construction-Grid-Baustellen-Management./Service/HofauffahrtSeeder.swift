//
//  HofauffahrtSeeder.swift
//  Demo-Baustelle Nr. 3 — das Mengengerüst.
//
//  Eine befahrbare Hofauffahrt pflastern, vier Stellplätze, 100,31 m². Ein
//  echter Job mit **gezählten Mengen** — und genau das ist der Unterschied zu den
//  Vorgängern: Bauer Horst und die Sandsteinstufen tragen „1 Psch" als Deckel,
//  hier steht `menge = 100,31 m²`, und darunter Stückzahlen aus einer echten
//  Zeichnung. Die erste Runde fragte, ob das Mengengerüst trägt; diese Runde
//  ersetzt die geschätzten 100 qm durch die **1344 gezählten Steine**, aus denen
//  die Fläche besteht — und zieht am Ende eine XRechnung daraus.
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
//  ── Gezählte Mengen tragen KEINEN Verschnitt ─────────────────────────────────
//
//  Solange 100 qm Pflaster als Fläche dastanden, waren 5 % Verschnitt richtig:
//  eine Fläche muss man zuschneiden. Gezählte Steine nicht — der Zuschnitt an
//  den Rändern ist im DXF bereits als **50 Halbsteine** ausgewiesen. Wer auf
//  1294 gezählte Steine noch 5 % aufschlägt, zählt den Rand zweimal.
//
//  **Was damit fehlt, ist der Bruch.** Steine gehen beim Transport und beim
//  Verlegen kaputt, und dafür steht hier jetzt nichts. Das Modell hat für diesen
//  Unterschied auch keinen Platz: `verschnittProzent` ist eine Spalte für zwei
//  verschiedene Dinge — Zuschnitt (aus der Geometrie herleitbar) und Bruch
//  (Erfahrungswert). **Befund, nicht Aufgabe.** Wer eine Bruchreserve will,
//  trägt sie bewusst ein, statt sie im Verschnitt mitlaufen zu lassen.
//
//  ── Woher die Zahlen kommen ──────────────────────────────────────────────────
//
//  `Testhofeinfahrt.dxf` aus Raphaels SketchUp, 1386 Block-Instanzen über vier
//  Material-Layer. Ausgezählt, nicht überschlagen:
//
//      Pflaster          1294 Vollsteine + 50 Halbsteine  → 100,31 m²
//      Leistensteine       40 Stück à 1,00 m              →  40 lfm
//      Splittbett 8/16     Bettung 4 cm                   →   6,52 t
//      Schotter 0/32       Tragschicht 30 cm              →  57,18 t
//
//  Damit ist dies die erste Demo, deren Bezugsmenge **nicht geschätzt** ist. Die
//  Fläche ist keine eigene Angabe, sondern die Summe der gezählten Steine — der
//  Test `flaecheIstDieSummeDerSteine` rechnet sie nach.
//

import Foundation
import CoreData

enum HofauffahrtSeeder {

    private static let eventNummer = "DEMO-AUFFAHRT-001"

    // MARK: - Was im DXF gezaehlt wurde

    /// Gezaehlte Block-Instanzen aus Raphaels `Testhofeinfahrt.dxf`, Layer
    /// „Pflaster". **Gezaehlt, nicht geschaetzt** — das ist der Unterschied zu
    /// jeder Zahl, die vorher in diesem Seeder stand.
    private static let vollsteine:    Double = 1294
    private static let halbsteine:    Double = 50

    /// Layer „Leistensteine", je 1,00 m Laenge. 40 Stueck sind damit zugleich
    /// 40 lfm Randeinfassung — eine Stueckzahl, die man als Laenge lesen kann.
    private static let leistensteine: Double = 40

    /// **Die Bezugsmenge — hergeleitet aus der Zaehlung, nicht gerundet geraten.**
    ///
    ///     1294 x 0,076050  =  98,4087
    ///       50 x 0,038025  =   1,9013
    ///                        ─────────
    ///                         100,3100 m²
    ///
    /// Die 100,31 sind also keine dritte Angabe neben den Stueckzahlen, sondern
    /// deren Summe. `flaecheGegenprobe` rechnet das im Test nach — wenn jemand
    /// eine Stueckzahl aendert und die Flaeche vergisst, faellt es auf.
    ///
    /// Vorher stand hier `100` als Schaetzung. Der Unterschied ist klein, der
    /// Unterschied im Zustand ist es nicht: geschaetzt → gezaehlt.
    private static let flaecheQm: Double = 100.31

    /// Tragschicht 30 cm, verdichtet. Die Dichte steckte bisher unausgesprochen
    /// in „57 t auf 100 qm" (= 1,9 t/m³) — hier steht sie hin, damit die Zahl
    /// bei geaenderter Flaeche mitwandert statt stehenzubleiben.
    private static let tragschichtT: Double = flaecheQm * 0.30 * 1.9    // 57,18 t

    /// Bettung 4 cm. Dieselbe Rueckrechnung aus „6,5 t auf 100 qm" (1,625 t/m³).
    private static let bettungT: Double = flaecheQm * 0.04 * 1.625      //  6,52 t

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
            Befahrbare Hofauffahrt pflastern, Platz für vier Fahrzeuge, 100,31 m².

            Mengen aus der Zeichnung gezählt (Testhofeinfahrt.dxf): 1294 \
            Vollsteine + 50 Halbsteine ergeben 100,31 m², dazu 40 Leistensteine \
            à 1,00 m als Randeinfassung.

            Richtangebot. Die MENGEN stehen — was noch nicht steht, sind die \
            PREISE: die Steinpreise sind aus einem Quadratmeter-Marktanker auf \
            Stück umgerechnet, nicht bei Pasand angefragt. Verbindlich wird das \
            Angebot mit einem Lieferantenpreis, nicht mit einem Aufmaß — das \
            Aufmaß liegt bereits vor.

            Drei Modell-Lücken sind absichtlich sichtbar: die Entsorgung des \
            Aushubs hat keine Kostenart, ihre Kosten sind bodenklassenabhängig \
            und damit gar nicht bezifferbar, und die Fuhren rechnen im \
            Zeit-Modell statt pro Fahrt.
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
        pos.bezeichnung = "Hofauffahrt pflastern, befahrbar, 100,31 m², "
                        + "inkl. Unterbau/Randeinfassung/Gefälle"
        pos.menge = flaecheQm
        // `m²`, nicht `qm`: Der `XRechnungExporter` bildet Einheiten auf
        // UN/ECE Rec 20 ab und kennt `m²` → **MTK**. „qm" faellt dort in den
        // Default **C62 (Stueck)** — die Rechnung haette „100,31 Stueck
        // Hofauffahrt" gelesen. „qm" kam im ganzen Repo genau einmal vor,
        // naemlich hier; alle 16 anderen Stellen schreiben `m²`.
        pos.einheit = "m²"
        pos.kostenGruppeNummer = "534"      // Stellplätze (DIN276BaumKatalog)

        // **Gezaehlt, nicht geschaetzt — und trotzdem `.schaetzung`.**
        // `MengenQuelle` kennt vier Faelle: statik · bplan · schaetzung · manuell.
        // Einen Fall „aus der Zeichnung gezaehlt" gibt es nicht, und `istGeschaetzt`
        // ist `self != .statik` — eine DXF-Zaehlung wuerde also ohnehin als
        // Schaetzwert gelten. Der rawValue ist zudem das Wire-Format der Box
        // (`ExtractLVPosition.quelle`); ein neuer Fall waere eine Schnittstellen-
        // aenderung, kein Beiwerk. Deshalb: `.schaetzung` + Herkunft im Stempel.
        // **Befund, nicht Aufgabe** — notiert in HANDOFF-AKTUELL.
        pos.mengenQuelle = .schaetzung
        // `deckelNotiz` ist im Modell der Pruefstempel „warum/woher" —
        // `MateriallisteView` schreibt dort „N Einzel-Bauteile aus DATEI".
        // Dieselbe Verwendung, nur eine Ebene frueher: hier steht, dass die
        // Menge aus einer gezaehlten Zeichnung stammt und nicht aus dem Gefuehl.
        pos.deckelNotiz = "dxf-gezählt: \(Int(vollsteine + halbsteine)) Pflastersteine "
                        + "+ \(Int(leistensteine)) Leistensteine aus Testhofeinfahrt.dxf "
                        + "(Layer Pflaster · Leistensteine · Splittbett 8/16 · Schotter 0/32)"

        // --- Material ---
        //
        // `menge` ist die Menge JE QUADRATMETER. Die Gesamtmenge steht daneben,
        // sonst ist „0,57" im Code nicht nachvollziehbar. Verschnitt als Faktor
        // (0.05 = 5 %), siehe Dateikopf.
        let material: [(name: String, menge: Double, einheit: String,
                        preis: Double, verschnitt: Double)] = [
            // ── Gezaehlt aus dem DXF ─────────────────────────────────────────
            //
            // 1294 Stueck, Layer „Pflaster".      [Netz-Anker, auf Stueck umgerechnet]
            // Preis: der qm-Anker dieser Demo lag bei 40,00 €/m². Ein Vollstein
            // misst 0,07605 m² → 3,04 €/Stueck. **Das ist eine Folgerung aus dem
            // qm-Preis, kein Haendlerpreis fuer genau diesen Stein** — wer einen
            // Angebotspreis von Pasand hat, traegt ihn hier ein.
            ("Pasand Pflaster Vollstein Nr. 59, Fine-dunkelgrau, 39×19,5×8cm",
                                        vollsteine / flaecheQm,    "Stk",   3.04, 0),
            // 50 Stueck, dieselbe Reihe, halbe Laenge → halbe Flaeche, halber Preis.
            ("Pasand Pflaster Halbstein Nr. 59, 19,5×19,5×8cm",
                                        halbsteine / flaecheQm,    "Stk",   1.52, 0),
            // 40 Stueck a 1,00 m, Layer „Leistensteine" = 40 lfm Randeinfassung.
            // Preis vom bisherigen Tiefbordstein uebernommen.       [Netz-Anker]
            ("Leistensteine (Randeinfassung, je 1,00 m)",
                                     leistensteine / flaecheQm,    "Stk",   8.00, 0),
            //
            // ── Aus der Flaeche gerechnet ────────────────────────────────────
            //
            // 57,18 t, Layer „Schotter 0/32", 30 cm verdichtet.
            // Preis 10,00 €/to ist der **Li-Preis (EK)** aus Raphaels Stammdaten
            // (`RaphaelStammdatenSeeder`); die 15 % Materialzuschlag kommen erst
            // im `LVKalkulator` obendrauf → 11,50. Vorher standen hier 7,90
            // [Werbach] — der belegte Firmenwert schlaegt den Marktanker.
            ("Schotter 0/32 (Tragschicht)",  tragschichtT / flaecheQm,  "to", 10.00, 0),
            // 6,52 t, Layer „Splittbett 8/16", 4 cm Bettung.       [Werbach, ab Werk]
            // ⚠️ Raphaels Stammdaten fuehren **Splitt 2/8 zu 2,90 €/to** — eine
            // andere Koernung, also nicht uebertragbar. Fuer 8/16 gibt es dort
            // keinen Satz; der bisherige Wert bleibt stehen und ist damit der
            // unsicherste Preis dieser Position.
            ("Splitt 8/16 (Bettung)",            bettungT / flaecheQm,  "to",  8.50, 0),
            // 2,01 t — Fugen einkehren                           [Werbach, ab Werk]
            ("Abdecksand/Fugensand 0/2",                        0.02,   "to",  3.00, 0),
            // 110,34 m² — 10 % Ueberlappung an den Stoessen          [Schätzung]
            ("Trennvlies (Geotextil)",                          1.10,   "m²",  1.50, 0),
            // 1,00 m³ — Rueckenstuetze der Leistensteine             [Schätzung]
            ("Beton C16/20 (Randstein-Rückenstütze)", 1.0 / flaecheQm,  "m³", 110.00, 0),
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
