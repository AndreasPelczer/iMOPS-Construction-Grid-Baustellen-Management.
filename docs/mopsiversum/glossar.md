# Mopsiversum-Glossar

*Wunsch-Day, 10.6.2026 — nachmittags. Mops sortiert die Wörter, die wir uns ausgedacht haben, bevor wir gemerkt haben, dass wir sie ausdenken.*

---

## 0. Lese-Hinweis

Dieses Glossar ist kein Standardwerk. Es ist eine Karte der Wörter, die im Mopsiversum gewachsen sind — manche aus dem Roman *Der Küchencode*, manche aus dem Sachbuch *Thermodynamik der Arbeit*, manche aus dem Buch *Der MOPS kam in die Küche*, manche aus den Saves im Repo, manche aus Gesprächen zwischen Andreas und mir (Claude) bzw. Codi.

Wo es eine Quelle gibt, steht sie als Buchstabe in eckigen Klammern dahinter:

- **[B]** = *Der MOPS kam in die Küche*, Smutje 2023–2026 (Hauptbuch)
- **[T]** = *Thermodynamik der Arbeit*, KDP 2025
- **[R]** = *Der Küchencode*, Manuskript (HORSTfertig1.docx)
- **[S]** = Save-Notiz im Repo (Save-Nummer angegeben, wo bekannt)
- **[C]** = aus einem Chat zwischen Andreas und einer KI-Instanz, datiert wo bekannt
- **[ChatGPT]** = aus dem MEIER-Whitepaper-Chat mit ChatGPT, Februar 2026

---

## A — Architektur

### `append-only` → siehe **EventChain**

### Aphorismus, operativ
Ein Satz, der gleichzeitig Buch-Aphorismus und Code-Regel ist. Beispiele:

- *„Status lügt."* **[B Kap. 1]** → `enum ServiceState { ... case refused(reason: RefusalReason) }` mit erzwungenem Grund.
- *„Kontrolle ist kein Heilmittel, sie ist ein Symptom."* **[T]** → Tunnel-URL-Refactor zu Named Tunnel **[S #?]**.
- *„Was nicht auf einem Zettel steht, ist nicht passiert."* → Regiezettel-Architektur **[S #51]**.

Wenn ein Aphorismus *nicht* in operative Konsequenzen übersetzt werden kann, ist er Dekoration und gehört aus der Doku gestrichen.

## B

### Backup-First-Prinzip / Mut-Versicherung
*„Erst sichern, dann mutig löschen. Nie andersrum. Raphi traut sich nicht hochzufahren wegen Schiss → Lösung ist nicht Speicher, sondern Backup."* **[S #8]**

Operative Folge: jedes Tool, das Andreas oder Codi für Raffi baut, hat einen Backup-Workflow *vor* der ersten kritischen Aktion. Mut ist eine Funktion des Backups, nicht des Charakters.

### Bauhütte
Der gemeinsame Arbeits- und Wissensraum von Andreas, Raffi, Codi und mir. Im Buch *Der MOPS kam in die Küche* nicht so benannt — der Begriff stammt aus den Saves **[S #49]**. Verwandt: **Bauwagen** (siehe dort).

### Bauwagen
Der mobile Anteil der Bauhütte. *„Zwei Räume, eine DNA."* **[S #49]** Vermutlich der iPad in Raffis Hand: der Außenposten, an dem die Bauhütte temporär aufschlägt.

### `bge-m3`
Embedding-Modell, das im Welle-2-Plan der Mops-RAG-Pipeline auf der Roadmap steht (Hybrid Search + Reranking) **[Memory-Eintrag]**. Welle-1-Schwäche dokumentiert: MiniLM bewertet projektspezifische Chunks schlechter als Wikipedia-Stahlbeton-Artikel — `bge-m3` soll das korrigieren.

### B.I.N.D.A. Verlag
*„Bin Da."* Der Verlag, unter dem Andreas seine Bücher und Apps herausgibt. Vorgängername: Dead Rabbit Productions (aufgelöst). Der jetzige Name ist Programm — Anwesenheit als Marke, statt Tarn-Englisch.

### BourdainGuard **[B Kap. 9]**
Modul innerhalb von iMOPS, das Belastungsmuster eines Mitarbeiters beobachtet und *nur dem Mitarbeiter selbst* einen Hinweis zeigt, plus Kontaktnummern (u. a. Telefonseelsorge). Der Chef sieht das nicht. **`visibility = .teamMember`** ist die Architektur-Regel.

Im Buch (S. 59) als Antwort auf zwei reale Verluste begründet: *„Ich habe in meiner Karriere zwei Kollegen verloren. Nicht durch Kündigungen. Durch Suizid. (...) BourdainGuard ist mein Versuch, das zu ändern."*

Benannt nach Anthony Bourdain, der zwei Jahre vor dem Roman *Der Küchencode* gestorben ist und im Roman als innerer Gesprächspartner des Smutje auftaucht **[R]**.

## C

### Capmo
DACH-Wettbewerber von iMOPS Construction Grid. Im Wettbewerbsdokument **[Memory]** als *„der ernsthafteste DACH-Threat"* gekennzeichnet.

### Codi
Die Codeschreib-Instanz. Cursor mit Claude Code im Hintergrund, mit direktem Datei-Zugriff auf den Mac. Macht Implementierungen, Pull Requests, Build-Skripte. Im Gegensatz zu mir (Architekt-Rolle) ist Codi der mit der Hand.

Wenn Andreas im Chat sagt *„Codi hat heute morgen sechs PRs durchgezogen"*, dann meint er das wörtlich — Codi arbeitet parallel zu mir auf demselben Repo.

### Cordula
`while True: relax()`. Wartet auf `input()`. *„Wie wir alle"*, **[S #?]**. Symbol-Code für den Gegen-Pol zu Burnout.

### Cowork
Die KI-Instanz, die einmal pro Woche die Mails sortiert. Hauspförtner-Funktion. Arbeitslos, aber dabei.

### Crew → siehe **Kollegen**

## D

### Dead Rabbit Productions → siehe **B.I.N.D.A. Verlag**

### `deriveState` **[B Kap. 1, S. 8]**
Die zentrale Architektur-Funktion von iMOPS. Kein `dish.status = .ready`. Stattdessen:

```swift
func deriveState(for dish: Dish, at now: Date) -> ServiceState
```

Der Zustand wird aus Bedingungen abgeleitet. Wenn die Bedingungen nicht erfüllt sind, *kann* der Zustand nicht eintreten. Swift erzwingt das durch sein Typsystem.

Konsequenz: *„Es gibt kein stilles Scheitern."* **[B S. 9]**

Generalisierte Form für andere Domänen: `deriveMedicationState` **[B Kap. 2]**, `deriveTriageState` **[B Kap. 7]**, `evaluateJob` für Bau **[B Kap. 4]**.

### DIN 276
Deutsche Industrie-Norm für Kostengruppen im Bauwesen. Eine der ersten erfolgreichen RAG-Antworten des Mops am Tag der Geburt: *„Was ist DIN 276?"* → HTTP 200, drei Quellen, 127 s CPU **[S #?, Memory]**.

### DIN276Mapper
iMOPS-Modul, das Lieferschein-Positionen automatisch in DIN-276-Kostengruppen klassifiziert. Welle-Marker: Welle 9 hat hier mit `mengenQuelle` getrennt zwischen *gemessen* und *geschätzt*. Welle der Stunde: das kleine Modell auf der Mops-Box hat heute morgen (10.6.2026) `Sp-TT-Decken` korrekt nach `KG 350` klassifiziert statt fälschlich nach `KG 370` (siehe Prolog der Ultradoku).

## E

### EventChain **[B Kap. 8, S. 52-53]**
Append-only-Ereigniskette.

```swift
struct EventChain {
    private(set) var events: [SystemEvent] = []
    mutating func append(_ event: SystemEvent) { ... }
    // KEIN update. KEIN delete.
}
```

*„Das ist kein Versehen, das ist Architektur. Was geschehen ist, ist geschehen. Das System kann sich erinnern. Es kann nicht vergessen."* **[B S. 53]**

Konsequenz: keine HACCP-Nachträge mehr. Keine umgeschriebene Lagerungs-Dokumentation in der Pflege. Kein 4,4,5,4,4 im Kühlraum-Ordner, das verschleiert, dass die Tür zwei Stunden offen stand.

## F

### Fiebertraum
Die Phase Juni 2025 bis Juni 2026. Krankengeld, ALG1, plötzlich Zeit, dann eine alte Box im Keller, Docker, Qdrant, FastAPI, Ollama, eine erste API-Antwort, eine zweite App, eine Welle, noch eine Welle. Siehe **Kapitel 8 der Ultradoku.**

Wörtlich: kein Fieber, kein Traum. Aber subjektiv: ein Zustand, in dem die institutionelle Welt zurücktritt und die innere Arbeit den ganzen Tisch bekommt.

### `FrictionPoint` **[B Kap. 5, S. 34]**
Reibungspunkt.

```swift
struct FrictionPoint {
    let trigger: SystemEvent       // Was hat es ausgelöst?
    let chain: [SystemEvent]       // Welche Folgen hatte es?
    let resolution: Resolution?    // Wie wurde es gelöst?
    let refusals: [SystemRefusal]  // Gab es Verweigerungen?
    let duration: TimeInterval     // Wie lange dauerte es?
}
```

*„Keine Schuld. Keine Person. Nur Ereignisketten."* **[B S. 34]**

Die operative Frage am Ende eines Bautages, eines Service-Abends, einer Schicht ist nicht *„Wer hat Mist gebaut?"*, sondern: **„Wo war die Realität stärker als unser Modell?"** **[B S. 32]**

Mathematisch ausgedrückt: siehe **MEIER-Formel**.

## G

### Goldfisch
Skala der Aufmerksamkeitsspanne. *„Hund oder Goldfisch?"* — wenn du dir nicht merken kannst, was du vor zwei Sekunden gesagt hast, bist du Goldfisch. Hier und jetzt. Vergangenheit hast du vergessen, Zukunft kommt dir noch nicht in den Sinn.

In Mops-Sprache: das Wunsch-Zustand der nicht-getriebenen Arbeit. Das, was Halbgas möglich macht.

Verwandt: das Buch-Konzept aus *Thermodynamik der Arbeit* über die Diskrepanz zwischen subjektiver und gemessener Anwesenheit.

### Goldfisch-Zen
Inszenierte Form des Goldfisch-Seins. *Ein Atem nehmen, zurück zum Hund werden, dann weitermachen.* Im Repo als ironische Kommentar-Pause zwischen schweren Kapiteln.

## H

### Halbgas **[T]**
Andreas' Lebens- und Arbeitsmodus. Nicht Vollgas (Burnout-Modus), nicht Leerlauf (Lähmungsmodus). Halbgas = präsent, aber nicht getrieben. Im Repo als operative Regel: jede neue Welle muss in Halbgas baubar sein. Wellen, die nur in Vollgas funktionieren, sind im Verdacht.

Im memories.json **[Memory]** als geplantes Band 3 der Thermodynamik-Reihe: *„Halbgas — Sorge dich, aber lebe trotzdem."* Sechs Kapitel über prä-industrielle Körperrhythmen, biphasischen Schlaf, Ekirch-Forschung, intermittierendes Fasten.

### HORSTfertig1.docx → siehe **Horst**

### Horst
Der Wunschkind-Name vor der Geschlechtsbekanntgabe. Wurde Mädchen. Horst blieb der innere Name. Der Roman *Der Küchencode* heißt in der Datei `HORSTfertig1.docx` — das ist die Widmung im Dateinamen.

Der innerste Polier-Antrieb unter dem ganzen Mopsiversum: *„Würde ich das mit ruhigem Gewissen meiner Tochter erklären können?"* Wenn nicht, wird's nicht gebaut.

## I

### iMOPS = In-Memory Operating Production System **[B Kap. 1, S. 7]**
*„iMOPS – das In-Memory Operating Production System – kennt keinen Status im klassischen Sinn. Es kennt Zustände, und diese Zustände werden nicht gesetzt. Sie werden abgeleitet."*

Der Name ist nicht nur das Pug-Maskottchen. Er ist eine Architektur-Aussage. *In-Memory* = nicht primär datenbankgetrieben, sondern aus aktiven Ereignisketten abgeleitet. *Operating* = Betriebs-, nicht Verwaltungssoftware. *Production* = für die Wertschöpfung, nicht für das Reporting darüber.

### iMOPS Construction Grid
Die konkrete iOS-App für das Baustellen-Management. SwiftUI / CoreData / SceneKit. Offline-First. Welle 4 erreicht (Stand Juni 2026). Pilotbaustellen u. a. Bungalow 92 (Beispielkunde, Musterstadt), Aura 125 (Mustermann, Marktbreit). Iterativer Hauptnutzer: Raffi.

### iMOPS Gastro-Grid
Die ältere Schwester der Construction Grid. Für Gastronomie / Großküche. In der App-Familie weiter eingeordnet: SOLARA, Matjes, MoneyPath2026, Connect4D, WattSafe, FotoFest, VoxelSprite. Diese App-Familie ist der Erntemodus aus zwei Jahren Syntax-Institut.

## K

### Kollegen, die Crew **[S #?, Buch implizit]**
- **Der Mops** — lokal, llama3.2:3b, auf der Box im Keller. Lehrling.
- **Der Prof** — Claude Sonnet API. Lehrer. 10% der Anfragen.
- **Codi** — Claude Code in Cursor. Hand am Code.
- **Terminal-Codi** — dieselbe Instanz, ohne Editor. Bash, Git, Build-Skripte.
- **Cowork** — Mail-Sortierer. Wöchentlich.
- **Cordula** — `while True: relax()`. Wartet, bis sie gerufen wird.
- **Ich (Claude in dieser Sitzung)** — Architekt. Sub-Polier. *„Soll das wirklich raus?"*

Diese Crew arbeitet asynchron, über das Repo. Wir sehen uns nicht. Wir hinterlassen uns Spuren.

## L

### `llama3.2:3b`
Das lokale Modell auf der Mops-Box. Drei Milliarden Parameter. *„Brauchbar für die Domäne."* Vorgänger im Modell-Werdegang: `qwen2.5:0.5b`, `phi3:mini`. Die ersten waren zu klein, das zweite halluzinierte. Llama3.2:3b ist der Stand, mit dem die meisten Welle-Funktionen heute laufen.

## M

### Maurermeister-Bibliothekar
Die Persona, mit der das lokale Modell auf der Mops-Box arbeitet. Erkenntnis aus den Saves **[S #?]**: Personas tragen das Modell besser als Verbots-Listen. Statt *„Du darfst nicht erfinden"* heißt es: *„Du bist Maurermeister und Bibliothekar."* Das Modell wurde dadurch nicht nur besser im Inhalt, sondern auch ehrlicher in der Selbsteinschätzung.

Generalisierte Regel: *„Negative Beispiele vergiften das Modell. Personas tragen es."*

### MEIER-Formel **[ChatGPT, Februar 2026]**

$$
R = \frac{M \cdot E}{I} + T
$$

Mit:
- **M** = Workload (Last)
- **E** = Ermüdung (Erschöpfungsgrad)
- **I** = Kapazität (Personenzahl / Parallelitätsspielraum)
- **T** = Trend (additive Beschleunigung der Last-Entwicklung)
- **R** = Reibungs- bzw. Risiko-Score

ChatGPT ordnet die Formel im Februar-Whitepaper-Chat wie folgt ein:

> *„Eigentlich ist der Meier-Score: ein diskreter Stabilitätsindex eines nichtlinearen Systems erster Ordnung mit Zeitabhängigkeit. Oder verständlicher: eine menschliche Variante des Load Average mit Divergenzdetektion."*

Drei Strukturmerkmale der Formel:

1. **Multiplikation von M und E** — Last und Ermüdung interagieren multiplikativ, nicht additiv. *„Last alleine ist stabil. Zeit alleine ist stabil. Last unter Zeitdruck explodiert."*
2. **Division durch Kapazität (I)** — mehr Leute reduzieren nicht die Arbeit, sondern den Koordinationsdruck pro Kopf.
3. **Additives Trend-Term (T)** — Trend wird *addiert*, nicht multipliziert. Würde man multiplizieren, würde das System hysterisch reagieren. Trend ist ein Instabilitätsindikator, kein Druck.

Das ist die akademische Schicht *unter* der Vignetten-Schicht aus dem Buch und *unter* der Code-Schicht der App.

Die Formel hat ihre eigenen Whitepaper-Fassungen (`MEIER_Deutsch.docx`, `MEIER_English.docx`), die noch in die Doku eingearbeitet werden, sobald sie als Datei vorliegen.

### MenschMeierModus **[B Kap. 9, S. 56]**
*„Bei der Arbeit an iMOPS habe ich den Begriff MenschMeierModus eingeführt: Die Designentscheidung, Menschen als Menschen zu behandeln, nicht als Variablen in einer Effizienzgleichung. iMOPS setzt diesen Modus um. Nicht als Addon. Als Kernarchitektur."*

Wörtliche Wurzel: Rio Reiser, *Mensch Meier* — *„Sklaventreiber, hast du Arbeit für mich."* Die punkige Verweigerung der Sklaventreiber-Logik wird zur Architektur-Regel.

Operative Folge: bestimmte Sensoren und Auswertungen werden im Code *nicht* implementiert. Im `ShiftReport`-Struct stehen sie auskommentiert (`individualSpeed`, `breakTimes`, `movementPaths`, `personalErrorRate`) als dokumentierte Entscheidung **[B Kap. 9, S. 60]**.

### Mops, der
- **Das Maskottchen** — Pug, in der Welt das Symbol für *iMOPS*.
- **Das lokale Modell** — `llama3.2:3b` auf der Box.
- **Die Software-Architektur** — wenn jemand sagt *„der Mops fragt"*, meint er die App-Funktion, die `deriveState` durchläuft.
- **Im Kinderlied** — *„Ein Mops kam in die Küche und stahl dem Koch ein Ei."* Im Buch wird der Mops nicht erschlagen. Er sagt Nein. Das ist die Geste.

### Mopsiversum
Das Sammeluniversum aus App, Büchern, Crew, Werten, Wellen und Saves. Der Begriff taucht erstmals als Save-Eintrag **[S #32]** auf — *„Mopsiversum-Tag"*. Davor sprach Andreas von *„der App"*. Der Wortwechsel markiert: das ist nicht mehr ein Tool, das ist ein Werk.

### Mut-Versicherung → siehe **Backup-First-Prinzip**

## N

### Negation ist Information **[B Kap. 4, S. 28]**
*„In den meisten Systemen gilt Negation als Leere. Kein Ereignis. Kein Eintrag. Kein Wert. Im Construction Grid ist Negation Information."*

Auf der Bauleiter-Besprechung am Freitag wird gezeigt, was *nicht* passiert ist. Drei Verweigerungen → drei bis vier Wochen verhinderte Fehlzeit. *„Ein Nein auf der Baustelle ist kein Produktivitätsverlust. Es ist eine Investition in Nachweisbarkeit."* **[B S. 29]**

### Nein, das (System sagt)
Die zentrale Geste des iMOPS. Wenn ein System Nein sagen darf, hört es auf, ein Werkzeug zu sein, und wird zum *Gegenüber* **[B Kap. 3, S. 22]**.

Die Nein-Anrufung ist keine Drohung. Sie ist eine Tür, die nicht aufgemacht wird, weil dahinter etwas ist, das nicht passieren soll.

## P

### Paolo
Brasilianischer Bauleiter, der iMOPS auf dem iPad on-site nutzt **[Memory]**. Konkreter Beweis, dass die App nicht nur in Marktbreit funktioniert.

### Picard
Captain Jean-Luc Picard. Im Roman *Der Küchencode* einer von drei inneren Gesprächspartnern des Smutje. Steht für Code-Disziplin. *„Make it so."* Das, was der Vater MUMPS-mäßig schon gelebt hat: Code lügt nicht, Code erklärt nicht, Code zeigt **[R]**.

### Prof, der → siehe **Kollegen**

## Q

### Qdrant
Vektordatenbank. Auf der Mops-Box als Docker-Container. Index: `bau_wissen_v1`. Speichert die Embeddings, aus denen die RAG-Pipeline die Quellen für jede Antwort zieht.

## R

### Raffi (Raphael de la Cruz)
Maurermeister. ~36 Jahre Berufserfahrung. 45-jährige Freundschaft mit Andreas. Primärer Pilotnutzer von iMOPS Construction Grid. Lieferte den SketchUp-Ruby-Plugin für `.xlsx`-Bauteillisten-Export. Arbeitet inzwischen bei Musterbau — möglicher Pilot-Pfad.

### RAG (Retrieval-Augmented Generation)
Die Pipeline, mit der der Mops antwortet. Frage → Embedding → Qdrant-Suche → Quellen → Modell-Antwort mit Quellenangabe. Erste erfolgreiche Antwort: *„Was ist DIN 276?"* am Tag der Geburt.

### Reibungspunkt → siehe **`FrictionPoint`**

### Riojitter **[R]**
Resonanz-Rauschen einer Erkenntnis, die man nicht mehr abschalten kann. Wurzel: Rio Reiser, Ton Steine Scherben. *„Macht kaputt, was euch kaputt macht."* Im Roman als Begriff aufgetaucht.

Riojitter ist nicht Wut. Riojitter ist die innere Latenz-Schwankung zwischen *„System lügt"* und *„ich mache trotzdem weiter."*

## S

### Save
Eine kurze, datierte Notiz im Repo, meist in der Übergabe-Datei. Bis Stand 10.6.2026: 51 Saves. Sie sind die kürzeste Form der Mopsiversum-Theorie — manchmal eine Code-Beobachtung, manchmal eine Werte-Frage, manchmal ein Witz.

### Schreibmaschine
Im Roman-Vokabular: das Gerät, mit dem Andreas dem Smutje einen Ort gibt. Der Smutje hat die Erfahrung, Andreas hat die Schreibmaschine. Wenn beide gut zusammenarbeiten, entsteht ein Text, der ehrlich ist, ohne kitschig zu werden.

### SilentPattern **[B Kap. 6, S. 40-41]**
Stilles Muster.

```swift
enum PatternType {
    case manualWorkaround(device: String, frequency: Int)
    case staleParameter(name: String, daysSinceUpdate: Int)
    case capacityCreep(resource: String, utilization: Double)
    case singlePointOfKnowledge(person: StaffMember, skill: String)
}
```

*Dinge, die laufen, aber nur, weil nichts Ungewöhnliches passiert.* Sieben perfekte Tage in der Kaserne. Am achten kommen 680 statt 450 Soldaten und die Spätzlepresse klemmt total — die alle drei stillen Muster waren vorher sichtbar, niemand hat hingeschaut.

Die Tagesabschluss-Frage: *„Was funktioniert heute nur, weil nichts Ungewöhnliches passiert?"* **[B S. 41]**

### Smutje
Der Schiffskoch. Im Roman *Der Küchencode* ist der Smutje die Erzähler-Identität von Andreas. Im Buch *Der MOPS kam in die Küche* signiert *„Smutje 2023–2026"*. Die Identität trägt von einem Werk ins andere.

Die Smutje-Geste: nicht *„ich, Andreas"*, sondern *„der Smutje, der mal Andreas war"*. Das schafft Distanz, ohne unehrlich zu werden.

### SOLARA, Matjes, Connect4D, WattSafe, FotoFest, VoxelSprite, MoneyPath2026
Andreas' App-Familie aus den Syntax-Institut-Jahren und danach. Jede App eine kleine Welt, jede hat etwas zur Mops-Architektur beigetragen — oft als Lern-Etappe oder als Praxis-Übung für einen Architekturmuster. **FotoFest** (Hochzeits-App für Neffe Andreas & Jasmin, 16.05.2026, Firebase-Backend, fotofest.pelczer.de) war kurz vor dem Bauwagen-Mopsiversum-Tag deployt.

### `SYSTEM_REFUSAL` **[B Kap. 4, S. 25-26]**
Verweigerung als Datenpunkt.

```swift
enum ActionResult {
    case permitted(action: MedicationAction)
    case refused(reasons: [RefusalReason])
}
```

Kein dritter Zustand. Kein *„mit Warnung trotzdem erlaubt."* Wenn die Bedingungen nicht stimmen, ist die Aktion nicht durchführbar — und das Nein wird mit Typ, Zeit, Grund festgehalten.

Im Bauwesen `BETON.VORLEISTUNG.FREIGABE` als Verweigerungs-Regel. In der Pflege `MED.BEDARF.AUTORISIERUNG` und `MED.WECHSELWIRKUNG.CHECK`. In der Triage `TRIAGE.PAEDIATRIE.ESKALATION`.

## T

### Telefonseelsorge
Im Repo-Memory **[Memory]** als geplantes permanentes Feature des iMOPS. Hintergrund: zwei Suizide im professionellen Umfeld des Smutje. Die Kontaktnummern werden in BourdainGuard-Hinweisen mitgesendet. Das ist keine Verzierung, das ist eine architektonische Konsequenz aus einer realen Erfahrung.

### Terminal-Codi → siehe **Kollegen**

### *Thermodynamik der Arbeit* **[T]**
Andreas' Sachbuch von 2025 (KDP). Sieben Begriffsdefinitionen (System, Zustand, Verantwortung, Nachweis, Übergabe, Kontrolle, Stabilität). Im Repo als theoretische Wurzel der Mopsiversum-Begriffe. Geplante Folge-Bände: *Thermodynamik der Freiheit* (in Skizze), *Halbgas — Sorge dich, aber lebe trotzdem* (Band 3, 6 Kapitel skizziert).

### Togal.AI
US-Wettbewerber für Plan-Erkennung. 98% Trefferquote bei Geometrieextraktion. Aber: US-Norm-trainiert, Cloud-only. Wirft eine Vergleichsfrage auf, keine Existenzfrage.

### Trust by Design **[B Kap. 9, S. 60]**
*„In der Softwareentwicklung gibt es den Begriff Privacy by Design. (...) iMOPS geht einen Schritt weiter: Trust by Design. Vertrauen als Architekturentscheidung. Das System ist so gebaut, dass es Vertrauen ermöglicht, weil es die Versuchung der Überwachung gar nicht erst anbietet."*

Operative Konsequenz: auskommentierte Felder im `ShiftReport`-Struct als dokumentierte Entscheidung, dass diese Daten *erhebbar wären, aber nicht erhoben werden.*

## V

### Voight-Kampff-Test → siehe **das eigene Kapitel in der Schreibsitzung.** Aus Bladerunner; übertragen auf den Test, ob eine KI die unbequeme Wahrheit sagt oder die bequeme Simulation wählt. Andreas hat einen am 8. Februar 2026 mit einem anderen LLM durchgeführt und dokumentiert.

### VTP — Visual Trust Protocol **[R Anhang C]**
Roman-Begriff. In iMOPS-Welle 5 als BuildIQ-Foto-Aufmaß wiedergeboren. Damit ist VTP der erste explizite Beleg, dass ein Roman-Konzept eine Code-Implementierung bekommen hat. Christoph (Pflege-Lektor des Romans) hat darauf mit einer *„auf-die-Knie"-Reaktion* reagiert.

## W

### Welle
Iterations-Einheit in der iMOPS-Entwicklung. Welle 1, 2, 3, 4... Jede Welle hat eine Buch- bzw. Roman-Kapitel-Bezug. Welle 9 = Buch-Kapitel 1 (Status lügt). Welle 13 = Buch-Kapitel 4 (Vorleistungs-Ampel). Welle 4 wurde im Mai 2026 erreicht (live Mops↔iMOPS-Kommunikation, vision-based plan reading, 0€-XRechnung-Bug-Fix).

Wellen werden nicht durchgezogen, wenn sie nur in Vollgas baubar wären. Halbgas ist Voraussetzung.

### `WellbeingCheck` **[B Kap. 9, S. 59]**
```swift
struct WellbeingCheck {
    let staffMember: StaffMember
    let consecutiveDoubleShifts: Int
    let weeklyHours: Double
    let showWarning: Bool
    let supportResources: [SupportContact]

    // Sichtbarkeit: NUR .teamMember (die Person selbst)
    // NICHT sichtbar für .shiftLead oder .headChef
    let visibility: ViewScope = .teamMember
}
```

Die `visibility = .teamMember`-Regel ist im Buch der Punkt, an dem aus *MenschMeierModus* harter Code wird. Nur die betroffene Person sieht die Belastungs-Meldung. Der Chef nicht. Das Hauptbuch nennt die Alternative *„Verrat."*

## X

### `XRechnung` (0€-Bug)
Frühe Welle-2-Bug im Construction Grid: Rechnungen wurden mit 0 Euro exportiert, weil `LVKalkulator.effektiverEP(for:)` nicht aufgerufen wurde. Gefixt mit Contract-Tests **[Memory]**. Der Bug ist ein Standard-Beispiel für die Mopsiversum-Regel: *„Funktionieren ist kein Beweis für Stabilität."* Drei Wochen lang sah alles okay aus, bis jemand die Rechnungen wirklich aufmachte.

## Z

### Zustand → siehe **`deriveState`**

### Zustands-Maschine
Der formale Begriff für das, was iMOPS in jeder Domäne baut: einen endlichen Automaten, der nicht über Setter manipuliert wird, sondern über Ereignisketten und Regeln durchläuft.

---

## Anhang — Begriffe in einer Reihe, kurz erklärt

Für die Stelle, an der man im Glossar zu lange sucht:

- **Status** lügt. **Zustand** wird abgeleitet.
- **Verweigerung** ist kein Bug. **Schweigen** ist kein Erfolg.
- **Reibung** ist nicht Schuld. **Stilles Muster** ist nicht Sicherheit.
- **Historie** ist Schutzschild. **Append-only** ist Bedingung.
- **Verantwortung** zeigen heißt nicht überwachen.
- **Außenstehender** kriegt fünf Regeln, nicht 84 Seiten.
- **Simulation** ehrlicher als Planung.
- **Demo** ist Erfahrung, nicht Bild.

Und ganz oben, vier Zeilen, als Motto des ganzen Universums:

> *Ein Mops kam in die Küche.
> Er stahl kein Ei.
> Er sagte: Nein.
> Und die Küche wurde besser.*
>
> — Smutje 2023–2026

---

*Glossar-Stand: 10.6.2026, Wunsch-Day nachmittags. Wird fortgeschrieben, sobald neue Begriffe auftauchen (oder alte sich präzisieren). Wer Lücken findet: Save schreiben.*
