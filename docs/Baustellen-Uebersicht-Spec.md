# Spec: Baustellen-Übersicht aus echten Daten · Stand 7.7.2026

**Status:** Diskussionsgrundlage / Analyse. Noch nichts implementiert, kein Code geändert.
**Ziel des Dokuments:** festhalten, wie die schöne „Übersicht nach der Planung" (heute nur
für den synthetischen Haus-Planer) auch für **echte Baustellen** entsteht — gefüttert aus
den PDF-Importen und den übrigen eingelesenen/bearbeiteten Daten.

---

## 1) Wunsch (Andreas)

Die Übersicht, die der Planer nach der Hausplanung erzeugt, soll es auch für die **echten
Baustellen** geben — mit Baustellen-Infos aus den PDFs und den anderen Daten, die eingelesen
und bearbeitet werden. Aktuell: Hausplan → Übersicht. Gewünscht: echte Baustelle
(inkl. importierter Daten) → dieselbe Art Übersicht, nutzbar auf der realen Baustelle.

---

## 2) Ist-Zustand im Code (Fundstellen)

### Der Planer erzeugt die Übersicht — aus Statistik
- Tab „iMOPS Planer" = `HouseConfiguratorView` (siehe `RootTabView.swift`).
- Ablauf: Eingaben (`HouseProject`) → `HouseProjectGenerator.generate()` →
  `HouseProjectResult` → Ergebnisansicht mit 4 Reitern **Kosten / Material / Massen / Zeitplan**
  (`HouseConfiguratorView.resultContent`).
- Die Zahlen sind **synthetisch**: Wohnfläche × `Ausstattungsniveau.kostenProQm`,
  Dachfläche aus `Dachform` etc. (`HouseProjectGenerator.berechneMassen/…/berechneBaukosten`).

### Die echte Baustelle hat die echten Daten — woanders
- Baustelle = `Event` (Core Data).
- PDF-Import-Pipeline landet bereits am Event:
  `/extract-plan` → `ExtractPlanResult` → `ExtractPlanMapper.mapPositions()` → `LVPosition`-Objekte
  (`posNr`, `bezeichnung`, `menge`, `einheit`, DIN-276 `kostenGruppeNummer`, `mengenQuelleRaw`,
  optional `artikelNummer`/`lieferant` aus der Bestellliste).
- Preise: `LVKalkulator.effektiverEP()` + `AngebotsStore`.
- Weitere Event-Daten: Gelände-Ergebnisse (Welle 7), Bestellliste, Mängel, Bautagesbericht.

### Die Brücke existiert schon — zieht aber die falsche Quelle
- `EventDetailView` (~Zeile 264) hat einen Link **„Soll-Übersicht"**, der
  `HouseConfiguratorView(spezielesEvent: event)` öffnet.
- Der lädt per `loadHouseProject(from: event)` nur den in `event.extras` gespeicherten
  `houseProject` und rechnet damit wieder die **Schätzung**. Ohne gespeicherten `houseProject`
  kommt ein Platzhalter „140 m², 2 Geschosse".
- **Die importierten LV-Daten fließen NICHT in diese Übersicht ein.**

### Teile der Ist-Übersicht existieren bereits
- `KostenübersichtView(event:positionen:)` aggregiert **echte** `LVPosition`s nach
  DIN-276-Kostengruppe inkl. Netto / MwSt / Brutto und „fehlende Preise". Das ist faktisch
  schon der **Ist-Kosten-Reiter**.

**Kernaussage:** Die Übersicht existiert. Die echten Daten existieren. Sie sind nur nicht
verbunden.

---

## 3) Zu ändern (Konzept)

### 3.1 Adapter statt Statistik-Generator
Ein Builder, der die Übersicht aus `event.lvPositionen` erzeugt (analog
`HouseProjectGenerator.generate()`, aber mit echten Zahlen):
- **Kosten:** vorhanden über `KostenübersichtView` / KG-Aggregation.
- **Massen / Material:** aus `LVPosition` (bezeichnung/menge/einheit) — gruppiert nach
  DIN-276-`kostenGruppeNummer`. ⚠️ `LVPosition` hat KEIN `gewerk`-Feld (Code-verifiziert, s. §8)
  → nicht über Gewerk gruppieren.
- **Zeitplan:** offene Design-Frage (siehe §5).

### 3.2 Soll vs. Ist sauber trennen
Passt zur Projekt-Philosophie „gemessen verdrängt geschätzt" (Welle 5/9):
- **Soll-Übersicht** = Planer (Schätzung/Angebot), bleibt wie heute.
- **Ist-Übersicht** = echte, importierte Baustellen-Daten, `mengenQuelle`-getaggt.
- Gleicher Reiter-Aufbau, zwei Datenquellen.

### 3.3 Baustellen-Infos aus den PDFs persistieren
`ExtractMetadata` (`projekt`, `baustelle`, `datei`) wird geparst, aber `ExtractPlanMapper`
schreibt aktuell **nur** die LV-Positionen weg — die Metadaten landen nirgends am Event.
Für den Übersicht-Kopf („Baustelle/Projekt aus PDF") müssen sie beim Import auf das Event
persistiert werden (eigene Felder oder `extras`).

---

## 4) Zwei Umsetzungswege (Entscheidung offen)

### Weg A — Adapter auf `HouseProjectResult`
- `HouseProjectResult(fromEvent:)` gießt echte LV-Daten in die bestehenden Strukturen
  (`MassenPosition`, `MaterialPosition`, `Kostenaufstellung`, `Bauphase`).
- Bestehende `HouseConfiguratorView`-Ergebnisansicht wird 1:1 weiterverwendet.
- **Pro:** am wenigsten neue UI, „läuft in einem Nachmittag".
- **Contra:** `Kostenaufstellung` hat feste Gewerk-Töpfe (rohbau/dach/…), echte Daten sind
  DIN-276-KG-basiert → Kosten-Reiter muss gemappt oder umgebaut werden.

### Weg B — eigene „Baustellen-Übersicht"-View
- Gleiches Layout (Header-KPIs + segmentierte Reiter), jeder Reiter zieht direkt aus echten Daten:
  Kosten = KG-Aggregation (vorhanden), Massen/Material = LV nach DIN-276-KG (kein gewerk-Feld, s. §8), Zeitplan separat.
- **Pro:** saubere Trennung Soll/Ist, kein erzwungenes Mapping in fremde Strukturen.
- **Contra:** etwas mehr View-Code.

**Tendenz:** Weg B — weil die echte Welt DIN-276-KG-basiert ist und Weg A beim Kosten-Reiter
sowieso zum Umbau zwingt. Weg A ist der schnellere „Proof".

---

## 5) Offene Design-Frage: Zeitplan-Reiter
Der Planer schätzt Bauphasen aus dem Haustyp. Für die echte Baustelle ist die Quelle unklar:
- aus den LV-Gewerken abgeleitet?
- manuell gepflegt?
- vorerst die Schätzung übernehmen und später ersetzen?

Das ist die einzige echte Lücke. Muss vor der Umsetzung entschieden werden.

---

## 6) Nächste Schritte
1. Entscheidung Weg A vs. Weg B.
2. Zeitplan-Quelle klären (§5).
3. Metadaten-Persistenz beim Import ergänzen (§3.3) — kleiner, eigenständiger Schritt.
4. Builder + View umsetzen, Regressionstest (Muster: `LVJSONImportTests`).
5. Drift-Regel: `app_bedienung.yaml`-Eintrag (neue Ansicht → Bedienungshilfe mitziehen).

## 7) Rahmen / Regeln (Erinnerung)
- Vor jedem Patch `.backup_*`. Nie ohne Andreas' OK pushen/PR. Destruktives nur mit
  Bestätigung + Folgen benennen. Trailing-Dot im Projektnamen → Pfade quoten.
  Simulator: iPhone 17 Pro Max / iOS 26.2.

---

## 8) Code-Fact-Check & Entscheidung (7.7.2026, gegen den laufenden Code verifiziert)

Die Analyse (§2–§5) wurde am echten Code gegengeprüft.

**Bestätigt (stimmt wie beschrieben):**
- „Soll-Übersicht" (`EventDetailView.swift:263-270`) → `HouseConfiguratorView(spezielesEvent:)`;
  dieser lädt in `.onAppear` `loadHouseProject(from:)` + `HouseProjectGenerator.generate()` →
  rechnet die **Schätzung**, rührt `event.lvPositionen` nie an; Platzhalter „140 m², 2 Geschosse"
  bei fehlendem houseProject (`HouseConfiguratorView.swift:419-423`).
- `KostenübersichtView` aggregiert **echte** `LVPosition`s nach DIN-276-KG (Netto/MwSt/Brutto),
  Preise via `LVKalkulator.effektiverEP(...)`/`AngebotsStore` → Ist-Kosten-Reiter existiert schon.
- `Kostenaufstellung` (`HouseProject.swift:155`) hat feste Gewerk-Töpfe (rohbau/dach/…) — der
  Weg-A-Haken ist real.
- `ExtractPlanMapper.mapPositions` (`ExtractPlanMapper.swift:32-47`) schreibt nur LV-Positionen;
  `ExtractMetadata` wird nirgends persistiert (§3.3 stimmt).

**KORREKTUR (wichtig):**
- ⚠️ **`LVPosition` hat KEIN `gewerk`-Feld.** Attribute: `menge`, `einheit`, `kostenGruppeNummer`
  (DIN-276), `mengenQuelleRaw` (+ computed `mengenQuelle`), `posNr`, `bezeichnung`,
  `artikelNummer`, `lieferant`. `gewerk` existiert nur auf den *synthetischen* Planer-Structs
  (`MassenPosition`/`MaterialPosition`) und auf `Mangel`. → **Gruppierung echter LV-Daten läuft
  ausschließlich über `kostenGruppeNummer` (DIN-276)** (ersatzweise Parsen der `bezeichnung`).
  §3.1 und §4 oben sind entsprechend korrigiert.

**Empfehlung (verstärkt durch die Korrektur): Weg B.** Weg A würde zwingen, aus der KG ein
Gewerk zu *erfinden*, um in `Kostenaufstellung`/`MassenPosition` zu passen — doppelte Reibung.
Weg B ist DIN-276-nativ = deine echte Welt.

**Zeitplan-MVP (Vorschlag zu §5):** Nicht blockieren. Am Event gibt es keine echten
Bauphasen-Daten (LVPositionen haben keine Dauer). Also **MVP = 3 belastbare Reiter
(Kosten / Massen / Material)** aus echten Daten; **Zeitplan später** (manuell gepflegte
Bauphasen ODER die Planer-Schätzung als „Soll" stehen lassen). Sofort Nutzen, ohne auf ein
Zeitplan-Konzept zu warten.

**Noch von Andreas zu entscheiden:** Weg B final? · Zeitplan-MVP so? · Metadaten-Persistenz
(§3.3) als eigener erster Schritt (klein, unabhängig)?
