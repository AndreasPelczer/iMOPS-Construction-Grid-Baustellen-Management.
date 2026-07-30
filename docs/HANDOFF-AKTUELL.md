# HANDOFF — AKTUELL (stabiler Zeiger)

> Diese Datei wird am Ende jeder Session aktualisiert. Sie zeigt auf die letzte Vollübergabe und fasst den Delta seither. Eine neue Instanz muss nicht raten, ob 07-09, 07-08 oder sonstwas gilt — hier steht es.

## Letzte Vollübergabe

**`docs/HANDOFF-2026-07-09.md`** (Vollstand Abend) — detaillierter Repo-Stand, Commits, "die eine Tür", LV-Deckel/Dedup.

## Neuer Prüfstatiker-Bericht

**`uebergaben/2026-07-10-falbe-einstand-pruefstatik.md`** — Falbes Einstand als Prüfstatiker mit vier priorisierten Befunden:

1. Branch-Drift / kanonischer Stand
2. Doctype-/Türsteher-Confidence
3. EventDetailView/LVView zerlegen
4. Kernel-Spike-Entscheidung vorbereiten

## Delta 30./31.07.2026 — Zuschlag je Kostenart + Lohnstunden + Firmenwerte

**Branch `feature/zuschlag-je-kostenart`** (2 Commits, zweigt von
`feature/lv-element-kalkulation` ab), NICHT gepusht.

Auslöser: ein Foto aus **BauSU** (echtes LV, Position „Schotter liefern"). Darin
zwei Dinge, die mops nicht konnte — beide jetzt gebaut. Die Zeilen darin
(`B SCHOTTER03` mit `A`-Positionen darunter, bezogen auf 1,0000 m²) sind **Zeile für
Zeile unser B-Element**; die Struktur stimmte also schon.

### Zuschlag je Kostenart

Im Bild trägt der Lohn ×2,75, Material ×1,15, Gerät ×1,10 — mops hatte EINEN Satz
auf alles. Das ist die Stelle, an der auf dem Bau das Geld verdient wird.

- Vier neue Felder: `zuschlagJeKostenart` (Schalter) + je ein Satz für Lohn,
  Material, Gerät. Regler zeigen **Prozent UND Faktor** (175 % = ×2,75).
- **Die Vorgaben sind so gewählt, dass Umschalten allein KEINE Zahl bewegt**
  (je 20 % = 12 % BGK + 8 % W&G). Ein Test hält das fest.
- `LVKalkulator.zuschlaege(fuer:material:lohn:geraete:)` ist **eine** Funktion für
  beide Verfahren, benutzt von Position UND Element — bewusst, siehe unten.
- Nachgerechnet mit den Sätzen aus dem Bild: 72,50 € Selbstkosten + 54,75 Zuschlag
  = **127,25 €/m²**.

### Lohnstunden

Im Bild läuft eine `Std`-Spalte bis zur LV-Summe durch (67,599 Std).

- `Kalkulation.stundenJeEinheit` / `.stundenGesamt`; das Element summiert die
  Stunden seiner Bausteine über **dasselbe Rezept-Maß** wie die Kosten.
- `LVKalkulator.gesamtStunden(positionen:)`, sichtbar unter der Angebotssumme
  („50 Lohnstunden").
- **Nur Lohnstunden**, keine Gerätestunden — genau wie im Bild (dort sind LKW und
  Minibagger nicht in der Std-Spalte). Die Maschine steht auch, wenn niemand
  danebensteht.

### Sätze als FIRMENWERTE (`759fc8e`)

Sonst müsste man sie in jedes Element neu tippen.

- `FirmenSettings` trägt die sechs Werte, gepflegt unter **Einstellungen →
  „Kalkulation — Zuschläge"**. Vorgaben identisch zu den bisherigen Core-Data-
  Defaults, damit die Umstellung für sich genommen nichts bewegt.
- Neues Feld `LVPosition.zuschlagEigen`. Aus = Firmenwerte, an = eigene Sätze.
- **Sechs wirksame Sätze als computed properties** (`satzLohn`, `satzBGK`, …).
  Der Rechner liest NUR die, nie die rohen Felder — sonst rechnet ein Aufrufer mit
  dem Firmenwert und der nächste mit dem gespeicherten. Genau so sind an einem Tag
  schon zwei Kataloge und fünf KG-Namen auseinandergelaufen.
- Oberfläche: Schalter „Von den Firmenwerten abweichen". Aus → Regler zeigen die
  Firmenwerte **grau** (sichtbar, nicht verstellbar). Beim Einschalten werden die
  Firmenwerte übernommen, damit der Preis nicht springt.

### 🔴 Beinahe eine stille Preisänderung

Nach dem Firmenwert-Umbau fielen **drei Alt-Tests** um — und das war KEIN
Testproblem. Die **Marktbreit-Pauschalposition** steht bewusst auf **0 % Zuschlag**
(Nachunternehmer-Durchleitung) und hätte durch den Fallback 12 % BGK + 8 % W&G
bekommen: aus **1.549,21 € wären 1.858 €** geworden, ohne dass jemand etwas
geändert hat.

Zwei Konsequenzen:

- **`Models/ZuschlagMigration.swift`** (Muster: `HierarchieMigration`, aufgerufen in
  `Persistence.swift`, **nicht** im In-Memory-Store): markiert beim ersten Start
  jede Bestandsposition, deren Sätze von den Firmenwerten **abweichen**, als
  `zuschlagEigen`. Wer auf Standardwerten steht, folgt ab jetzt der Firma.
  **Dadurch ändert sich keine einzige Zahl** — die Migration konserviert den Ist-Stand.
- **Neuer Vertrag im Code: wer die Zuschlagsfelder schreibt, muss `zuschlagEigen`
  mitsetzen.** Sonst greifen stillschweigend die Firmenwerte. Umgesetzt im
  `MarktbreitSeeder` (mit Begründung im Code) und im zugehörigen Test.

### Zwei Nachzügler aus dem Simulator-Rundgang

- **`12bc67e` — Element sortiert seine Bausteine nach PosNr.** Aufgeklappt stand da
  „Abrütteln · Frostschutzschicht · Pflaster verlegen · Pflastersteine liefern", also
  der LETZTE Arbeitsschritt zuerst. Beim Element ist die Reihenfolge Information: die
  PosNr erzählt die Arbeitsfolge (534.002 vor 534.007), genau wie die A-Positionen im
  BauSU-Bild. Beim **Mengenträger** bleibt es bewusst alphabetisch — dort sind die
  Unterpunkte Belege ohne Reihenfolge-Aussage. Beide Fälle mit Test festgehalten.
- **`dc1d934` — `scripts/snapshot.sh` nahm gelegentlich das falsche App-Bundle.**
  `find` liefert ZWEI gleichnamige `.app`-Verzeichnisse: das gebaute und ein
  Indizierungs-Gerüst unter `Index.noindex/` **ohne `Info.plist`**. Welches `head -1`
  erwischte, hing an der Dateisystem-Reihenfolge — bisher reines Glück. Symptom war
  ein wenig hilfreiches `Print: Entry, "CFBundleIdentifier", Does Not Exist`.
  `Index.noindex/` wird jetzt ausgeschlossen, fehlendes Bundle sagt Klartext.
  **Latenter Fehler im Werkzeug, nicht in der App** — fällt genau dann auf, wenn man
  ihn am wenigsten gebrauchen kann.

### Stand

117 Tests grün (11 neue). Drift-Regel: `App_Zuschlag_Je_Kostenart` in
`app_bedienung.yaml` (10 Aliase), inkl. Firmenwert-Weg. Snapshot-Ziel
`scripts/snapshot.sh LVZuschlag eigen|firma`.

Im Simulator durchgesehen und für gut befunden (Andreas, 31.07.): Element klappt
auf, Rezept-Maße und Beiträge stimmen, Angebotssumme und Lohnstunden passen.
**Auf dem Gerät ist es noch nicht** — siehe Migrations-Hinweis unten.

### Offen / bewusst nicht gemacht

- Die Sätze sind **Firmenwerte, keine Zuschlagsgruppen.** BauSU kennt 30 Gruppen,
  denen Positionen zugeordnet werden. Wir haben Firma + Einzelabweichung — reicht
  fürs Erste, ist aber nicht dasselbe.
- **Was aus dem BauSU-Bild weiter fehlt** (Reihenfolge = Vorschlag):
  Variablen + Formeln (`V DI` Schichtdicke, `=DI*1,8`) · Rezept als
  wiederverwendbarer Stammdaten-Baustein · weitere Kostenarten (Fremd, Sonstiges,
  Transport, Schalung — **Fremdleistung fehlt am meisten**, Nachunternehmer sind auf
  dem Bau die Regel) · Material-/Geräte-Stammdaten mit Nummern · die Kosten-/Preis-
  Matrix je Position und LV.

## Delta 30.07.2026 — B-Element (Rezept-Kalkulation) + KG-Namen aus einer Quelle

**Zwei Branches, beide NICHT gepusht, kein PR:**
`feature/lv-element-kalkulation` (3 Commits, zweigt von `main` ab) ·
`fix/lv-kg-namen` (1 Commit, zweigt von **`fix/din276-kg-532`** ab).

### B-Element — ein Deckel, der seine Bausteine zu EINEM Einheitspreis rechnet

Andreas' Kostengruppen-Zettel: acht Arbeitsschritte unter einer KG (`541.001 … 541.008`),
jeder mit Material/Lohn/Maschine, am Ende ein Preis je m². Genau das kann mops jetzt.

- **Zwei neue Felder** (additiv + optional, leichte Migration greift):
  `LVPosition.deckelArt` (`nil`/`"mengentraeger"` = alles Bisherige | `"element"`) und
  `LVPosition.mengeJeDeckelEinheit` (Rezept-Maß des Bausteins je Element-Einheit).
- **Die Rechnung:** (€ je Baustein-Einheit) × (Baustein-Einheit je Element-Einheit).
  Die Einheiten kürzen sich heraus — ein Baustein darf in m³, lfm oder Stunden rechnen,
  das Element trotzdem in m². **Keine Division nötig.**
- **Zuschlag (BGK/W&G) kommt EINMAL oben am Element drauf** (Entscheidung Andreas).
  Bausteine rechnen zuschlagsfrei — sonst würde doppelt aufgeschlagen. Ihre eigenen
  Zuschlagsfelder bleiben ohne Wirkung, solange sie unter einem Element hängen; die
  Oberfläche sagt das ausdrücklich.
- **Oberfläche:** Deckel lange drücken → „Als Element rechnen" ⇄ „Wieder als Mengenträger".
  Element ist indigo (eigenes Symbol) und zeigt den Einheitspreis im Untertitel; Mengenträger
  bleibt orange mit „zählt einmal". Am Baustein erscheint der Abschnitt „Rezept-Maß" mit
  Live-Vorschau (0,35 × 100 m² = 35 m³). Drift-Regel erfüllt:
  `App_LV_Element_Kalkulation` in `app_bedienung.yaml` (9 Aliase).
- **Kein Rückschritt:** `deckelArt == nil` ist die Vorgabe. Jeder Deckel aus dem Excel- und
  Bestelllisten-Import bleibt Mengenträger und rechnet unverändert. Zwei Tests sichern das ab.
- **9 Tests**, u. a. das Pflaster-Rezept auf genau **87,00 €/m²** und 8.700 € Gesamt.

**🔴 Drei Fehler, die erst der Screenshot zeigte — Build und Tests waren grün:**

1. **Die Angebotssumme zeigte 2.880 € statt 11.580 €** — das Element fehlte komplett.
   Die Annahme, `LVKalkulator.effektiverEP` sei DER eine Einhängepunkt, **war falsch.**
   Vier Stellen hatten die Preis-Logik nachgebaut und kannten nur `hatKalkulation` —
   ein Element hat aber keine eigene Kalkulation, sein Preis steckt in den Bausteinen:
   `LVView.gesamtSumme`, `LVPositionRow`, **`GAEBExporter`** (Element wäre OHNE
   Einheitspreis in die Datei gegangen) und `LVKalkulator.gesamtKalkulation`.
   Alle vier element-fähig gemacht — **jeweils nur ein zusätzlicher Zweig**, bestehende
   Reihenfolgen unangetastet. Regressions-Test `gesamtsummeEnthaeltDasElement`.
2. **„Sichern" war beim Baustein ausgegraut** — `isValid` verlangte eine Menge, die kommt
   beim Baustein aber aus dem Rezept. War schlicht nicht speicherbar.
3. Das leere Mengenfeld daneben war unerklärt → Fußzeile ergänzt.

**Lehre für die nächste Instanz: Build + Tests grün ≠ es funktioniert. Anschauen.**

### KG-Namen: fünf switch-Kopien → eine Quelle

Im selben Screenshot stand „KG 534 – **Sonstige**" statt „Stellplätze", obwohl der Katalog
seit `23c0b56` stimmt. Grund: **fünf** Views/Exporter hatten je eine handgepflegte
`switch`-Kopie der KG-Namen (`LVView`, `KostenübersichtView`, `GAEBImportView`,
`LVPDFExporter`, `GAEBExporter`). Alle fünf kannten nur Hunderter und Zehner — **jede
dreistellige KG fiel in „Sonstige"**, also genau die Ebene, auf der gearbeitet wird.
Zwei Namen waren dabei falsch: 200 „Herrichten & Erschließen" (alte Fassung, heute
„Vorbereitende Maßnahmen") und 380 „Fenster & Türen" (war in *keiner* Fassung richtig,
korrekt ist „Baukonstruktive Einbauten").

Neu: `DIN276KostenGruppe.bezeichnung(fuer:)` als einzige Stelle. **122 Zeilen weniger**,
dafür 6 Tests (`DIN276KatalogTests`) — darunter einer, der für **jede** Nummer prüft, dass
flacher Katalog und Baum dasselbe sagen. Genau die Prüfung, die den 29.07.-Ärger
gefunden hätte.

**⚠️ PDF- und GAEB-Export tragen damit die aktuelle DIN-Benennung.** Wer alte Exporte
vergleicht, sieht bei 200 und 380 andere Überschriften. Richtiger, aber sichtbar — und es
geht raus zum Kunden.

### Screenshots ohne Navigations-Zirkus

„Codis Augen" (`scripts/snapshot.sh` + `App/SnapshotHostView.swift`) hat zwei neue Ziele:

```
scripts/snapshot.sh LVElement element        → LV mit Element + Mengenträger nebeneinander
scripts/snapshot.sh LVElementRezept rezept   → Rezept-Maß am Baustein
```

Die Snapshot-Daten nutzen **dieselben Zahlen wie die Tests** (87,00 €/m²), damit Bild und
Test nicht auseinanderlaufen. Nichts zu installieren, nichts zu patchen — lief auf Anhieb.

### 🟡 BauSU: A-/B-Element ist Software-Sprech, kein Fachbegriff

Andreas' Notiz „Folge ist B-Element" war in Normen und Fachliteratur nicht auffindbar
(vier Suchen). Auflösung: **BauSU** (Bausoftware). Auf bausu.de belegt: „Kalkulation … mit
A- und B-Elementen", „jeder Einzelpreis ist ein A-Element", „A-Elemente werden mit
B-Elementen verknüpft". **Unser Modell passt** — Baustein = A, Element-Deckel = B.

**Ein Unterschied:** BauSU ordnet jede Position einer von 30 **Zuschlagsgruppen** zu, der
Zuschlag sitzt dort also am **A**-Element. Wir haben ihn bewusst am **B**. Umkehrbar —
im Code ist es die Zeile `traegtZuschlag` in `LVKalkulator`.

**🔴 NICHT verifiziert und deshalb NICHT gebaut:** das 8-stellige Nummernschema aus dem
Andreas zugespielten Text (`39100001` = KG 391 + laufende Nummer, 3 + 5 Stellen), sowie
„Dialog 5121" und „Schrittweite 10". Auf bausu.de steht Dialog **4122** für B-Elemente,
Dialognummern gibt es also — 5121 war nicht auffindbar. Der Text liest sich wie
KI-Ausgabe. **Konzept belegt, konkrete Zahlen sind Folgerung** (Regel „Zitat vs.
Folgerung"). Vor dem Bau im Programm nachsehen — ein Nummernschema baut man ungern
zweimal um, und es hängt an jedem Export.

Nebenbei geklärt: gearbeitet wird in **Baden-Württemberg**, also **deutsche DIN + GAEB**.
Die ÖNORM-Erwähnung kam nur daher, dass die gefundene BauSU-Seite aus dem
österreichischen Zweig stammte (`bau-su.at`). Im Code ist kein ÖNORM-Rest — geprüft.

### Merge-Reihenfolge (wichtig)

```
main
 ├── fix/din276-kg-532                   (29.07., 4 Commits)
 │    └── fix/lv-kg-namen                (30.07., 1 Commit)  ← baut darauf auf!
 ├── feature/lv-element-kalkulation      (30.07., 3 Commits, unabhängig)
 │    └── feature/zuschlag-je-kostenart  (30./31.07., 2 Commits) ← baut darauf auf!
 └── docs/handoff-29-07                  (diese Datei)
```

Zwei Ketten, die sich nicht berühren: DIN/KG-Namen einerseits, Element/Kalkulation
andererseits. **Innerhalb** einer Kette gilt die Reihenfolge strikt — der Kind-Branch
braucht den Eltern-Branch.

`fix/lv-kg-namen` **nach** `fix/din276-kg-532` mergen — es braucht dessen abgeleiteten
Katalog. Die Element-Arbeit ist unabhängig und berührt keine gemeinsame Datei.

**Es existiert lokal ein Branch `WEGWERF/gesamttest-29-07`**, der alles zusammenführt
(konfliktfrei, 106 Tests grün) — **nur zum Ansehen, nicht mergen, nicht pushen.**
Löschen mit `git branch -D WEGWERF/gesamttest-29-07`.

### Offen aus dem 30.07.

- **Entscheidung Andreas #1 (Positionsnummer nach KG) hat neuen Input**, bleibt aber
  offen — siehe BauSU-Abschnitt: erst Quelle klären, dann bauen.
- Die zwei anderen offenen Punkte vom 29.07. (hauseigene KG-Zuordnung, flacher Rollup
  ohne Zwischensummen) stehen unverändert weiter unten.
- **Migration aufs Gerät steht noch aus.** Zwei neue Felder, und der Gerätespeicher hängt
  ohnehin auf altem Schema (ohne `ZDECKEL`) → migriert über mehrere Schritte auf einmal.
  Vorher Container ziehen, der Befehl steht im 29.07.-Abschnitt.

## Delta 29.07.2026 — DIN 276: zwei Kataloge aus zwei Fassungen zusammengeführt

**Branch `fix/din276-kg-532`, vier Commits, NICHT gepusht, kein PR.**
(Diese Übergabe liegt auf einem eigenen Branch `docs/handoff-29-07` — zwei getrennte PRs,
wie beim Delta 28.07. Beim Mergen Code zuerst, sonst steht in `main` eine Übergabe ohne den Code.)

- **Gefunden:** es gab **zwei** KG-Kataloge aus **zwei DIN-276-Ausgaben**. 37 Nummern trugen
  unterschiedliche Bezeichnungen, ~20 davon mit echter Bedeutungsverschiebung — dieselbe Nummer
  meinte in beiden Katalogen etwas anderes (325 „Bodenbeläge" ↔ „Abdichtungen und Bekleidungen",
  326 „Bauwerksabdichtungen" ↔ „Dränagen", 352 „Deckenbeläge" ↔ „Deckenöffnungen",
  533 „Stellplätze" ↔ „Plätze, Höfe, Terrassen"). `DIN276KostenGruppe` (Picker, Mängel, Automatik)
  folgte der **alten** Fassung, `DIN276BaumKatalog` (Bausteinauswahl) der **aktuellen**. Positionen
  wurden nach einer Systematik vergeben und nach der anderen beschriftet — unsichtbar bis zum
  GAEB-/XRechnung-Export.
- **`cb30b20`:** KG **532 „Straßen"** im Baum nachgezogen (fehlte; der flache Katalog kannte sie,
  und `KGZuordnungsService` ordnete „asphalt/schotter/…" darauf zu → Nummer, die der Baum nicht kannte).
- **`23c0b56` — Baum ist jetzt führend:**
  - `DIN276KostenGruppe.alle` ist eine **abgeleitete flache Sicht** auf `DIN276BaumKatalog`
    (334 statt 114 Einträge, alle 3 Ebenen). Struct-API + alle Aufrufstellen unverändert.
    **Drift ist damit strukturell unmöglich — nur noch ein Ort zum Ändern.**
  - `KGZuordnungsService`: sechs Regeln korrigiert — 326→**325** (Abdichtung), 352→**353**
    (Bodenbelag/Estrich), 353→**354** (Deckenbekleidung), 533→**534** (Stellplatz), 574→**572**
    (Rasen); Terrassen von 531 (Wege) auf **533** abgetrennt (greift über die vorhandene
    Längster-Treffer-Regel: „terrassenpflaster" schlägt „pflaster").
  - `MateriallisteView.kgFuer`: bodenplatte 324→**322**, bodenflaeche 325→**353**,
    innenwand 331→**341** (lag auf „Tragende Außenwände" — Altbug, keine Editionsdrift).
- **Bestandsdaten: keine Migration nötig.** Gemessen am Gerät (iPhone 13, Container gezogen) und in
  beiden Simulator-Stores: **0** von 24 bzw. 35 Positionen auf 324/325/326/327. Fast alles liegt auf
  Hunderter-Ebene. Nebenbefund: der **Gerätespeicher hängt auf altem Datenmodell** (`ZDECKEL`/
  `ZDECKELNOTIZ` fehlen) und `quellDatei` ist bei allen Positionen leer → auf dem Gerät lief **nie**
  ein Excel-Import. Deshalb 0 — nicht weil der Konflikt harmlos wäre.
- **Build + Unit-Tests grün** (Clean Build, iOS 26.2 Sim, iPhone 17 Pro Max). Knowledge-YAMLs nennen
  keine der betroffenen Nummern → Drift-Regel erfüllt, nichts nachzuziehen.

### ⚠️ Backups gehören NICHT in den Quellordner

Das Projekt nutzt **synchronisierte Xcode-Ordner** (`PBXFileSystemSynchronizedRootGroup`, Xcode 16+):
keine Datei ist einzeln in `project.pbxproj` gelistet, alles im Quellordner wird automatisch
übernommen — und was Xcode nicht als Quellcode erkennt (`Foo.swift.backup_2026…`) wandert als
**Ressource ins App-Bundle**. Am 29.07. lagen vier Quelldateien in der gebauten `.app`.
`.gitignore` hat `*.backup_*`, aber das Bundle ist ein anderer Kanal — gitignore schützt dort nicht.
**Ab jetzt: Patch-Backups nach `_backups/` im Repo-Root** (außerhalb der synchronisierten Gruppen).
Gegenprobe: `ls <DerivedData>/…/….app | rg backup` muss leer sein.

### Erledigt & offen aus dieser Session

Die ersten beiden Punkte standen zwischenzeitlich als „offen" hier und sind inzwischen gefixt —
sie bleiben als Spur stehen, damit nachvollziehbar ist, warum die Zuordnung sich geändert hat.

- ~~Altbug 441~~ **erledigt (`b677cc6`):** „hauptverteiler / zähler / zählerkasten /
  netzanschluss" lagen auf **441 „Hoch- und Mittelspannungsanlagen"** (= Trafostation), jetzt auf
  **443 „Niederspannungsanlagen"**. War keine Editionsdrift — 441 heißt in beiden Fassungen gleich,
  nur der Code-Kommentar behauptete „Elektrounterverteilung". `zähler` trifft als Teilstring auch
  `wasserzähler`; dort gewinnt weiterhin der längere Treffer (→ 412).
- ~~Keyword `hak`~~ **erledigt (`e80138a`):** die Abkürzung war nur 3 Zeichen lang und matchte als
  Teilstring in jedem Wort mit „hak" („Dachhaken", „Schrankhaken") — sie gewann also genau dann,
  wenn sonst nichts traf, und dann falsch. Ersetzt durch das ausgeschriebene
  **`hausanschlusskasten`**. Bewusst **nicht** das kürzere `hausanschluss`: bei „Gas-Hausanschluss"
  schlüge das den Treffer `gasanschluss` (→ 413 Gasanlagen) und zöge Gas auf Elektro.
  **Wenn in Materialnamen „HAK" als Abkürzung vorkommt, greift die Regel jetzt nicht mehr** —
  dann `hak` als Keyword bewusst wieder aufnehmen und die Nebenwirkung in Kauf nehmen.
- **Entscheidung Andreas #1 — Positionsnummer nach KG.** Zettel-Vorbild: `541.001 … 541.008`
  (KG + hauseigene laufende Nummer, jede Position mit Einheitspreis/Zeit-/Material-/Maschinenansatz,
  Rollup zur KG). Heute vergibt mops PosNr als laufende Nummer **je Importquelle** (`06.01`,
  `05.xx`, `E.1`) — KG und PosNr wissen nichts voneinander. Nicht gebaut.
- **Entscheidung Andreas #2 — hauseigene KG-Zuordnung?** Auf dem Zettel steht „Einsanden von
  Pflaster" neben **541 Einfriedungen**; nach Katalog gehören Pflasterarbeiten in die **530er**
  (531 Wege, 533 Plätze/Höfe/Terrassen, 534 Stellplätze). Frage: DIN-Nummer erzwingen, oder eigene
  Zuordnung erlauben? Betrifft GAEB-/XRechnung-Export (die KG geht mit raus).
- **Rollup ist flach.** `KostenübersichtView` gruppiert auf die exakt gesetzte Nummer; 541 rollt
  **nicht** auf 540 und nicht auf 500. Die Zwischensummen-Kaskade des Kostengruppen-Blatts
  („…-Zwischensumme" → „100 Gesamtsumme") kann mops nicht. Ebenso fehlt eine Pauschal-Schätzung
  auf Hunderter-Ebene (Zettel: 100 = 200.000 €, ohne Positionen darunter).

## Delta 28.07.2026 — LV-Gruppen bearbeitbar + Bestellliste-Import (→ main)

- **Frage 2 (PR #106, in `main`):** LV-Gruppen sind jetzt **bearbeit-/kalkulierbar.** In
  `Views/LVView.swift` bekommen **Deckel** (Swipe/Kontextmenü: Bearbeiten/Kalkulation/Fortschritt/
  Aufmaß, „Auflösen" bleibt) und **Belege** (Tap + Kontextmenü) die vorhandenen `editPosition`/
  `kalkPosition`-Einstiege (→ `AddLVPositionView`/`LVTiefenkalkulationView`). Reine UI-Verdrahtung.
  Hilfe: `App_LV_Gruppen_Bearbeiten` in `app_bedienung.yaml`.
- **Frage 1 (PR #107, in `main`):** `/materialliste` (mops-api) erkennt jetzt zusätzlich die
  **gruppierte Bestellliste-Übersicht** (.xlsx) und liefert **je Gruppe eine Deckel-Sektion**.
  iOS-Fix: `kategorieLabel` zeigt unbekannte Kategorien (= Gruppentitel) direkt statt „Nicht
  zugeordnet". → Import = Gruppen im LV, per Frage 2 kalkulierbar.
- **Backend:** mops-api `main` (Parser `bestellliste.py` + Auto-Erkennung). Box auf `main` redeployed.
- Build grün (iOS 26.2 Sim, iPhone 17 Pro Max).
- **Offen (v1-Kanten):** Bestellliste-Deckel-Reihenfolge (unbekannte Kategorien sortieren gleich →
  Gruppen nicht in Nummern-Reihenfolge); Backend: eine Gruppe im Real-Export gesplittet, Raumvolumen-
  Gruppen ohne Positionen fallen raus.

## Delta 15.07.2026 — Excel-Mengen (Materialliste) ins LV

- **Neu:** `Views/MateriallisteView.swift` — liest einen SketchUp-Mengenauszug (.xlsx) über die
  Box (`POST /materialliste`) und übernimmt ins LV. Einstieg: Card „Mengen aus Excel lesen" in
  `EventDetailView` (unter der WandLeser-Card).
- **Modell:** Pro Kategorie/Sektion EIN **Deckel** (Außenwand 24cm, Innenputz …) mit Gesamtmenge,
  darunter die Einzel-Bauteile als **aufklappbare Unterpunkte** (REB-23.003: nur Deckel zählt,
  Einzelteile sind Belege). Nutzt `LVPosition.deckel` / `unterPositionen` — dasselbe Muster wie
  `ExtractPlanMapper.legeTeilgewichteAn`. **Gesamtsumme oben** (Σ m³ · Σ m² · Stk), keine Preise.
- Alles `mengenQuelle = .schaetzung`, Herkunft in `quellDatei`, KG grob vorbelegt
  (Wände/Beton 331, Bodenplatte 324, Ringbalken 351, Sturz 334, Putz 335/345, Boden 325).
  Kalkulation/Bestellwesen dahinter **unberührt**.
- Branch: `feature/ios-materialliste-excel`. Build grün (iOS 26.2 Sim). `app_bedienung.yaml` ergänzt
  (Drift-Regel). **Backend-Gegenstück:** mops-api Branch `feature/materialliste-excel` (live auf Box).
- Offen: mit weiteren Excel-Listen testen (andere Namensschemata → evtl. mehr „unbekannt").

## Delta seit 09.07. (Stand 14.07.2026)

- Schwerpunkt: Wandleser / echte Planer-DXF. Haupt-Arbeit im **mops-api**; iOS-Seite: Geschoss-Zuordnung beim Wandleser.
- Aktiver iOS-Branch: `feature/ios-wandleser-geschoss`.
- Session-Notiz 11.07.2026: Rentus/Glanzgarage-Arbeit liegt **nicht** in diesem iOS-Repo, sondern in `/private/tmp/Glanzgarage-codex` und `/private/tmp/deadrabbit-landing-codex`; Übergaben dort: `Glanzgarage/docs/uebergaben/2026-07-11-autocheck-whatsapp.md` und `Glanzgarage/docs/uebergaben/2026-07-11-rentus-embedded-autocheck.md` (3D-AutoCheck direkt in `/rentus/`, WhatsApp-Reportbild mit Mängelliste).
- **Status der drei Aufwands-/Auswertungs-Aufträge (verifiziert 14.07.2026):**
  - **#1 `docs/HANDOFF-Aufwand-Vorschau-je-Einheit.md` → FERTIG & in `main`.** Commits `8c2a5fa` (Positions-Gesamt in der Vorschau) + `dce08d4` (Umschalter „je Einheit/gesamt"). Bausteine `AufwandVorschau`/`AufwandEingabeFeld` in `Views/LV/LVSupportViews.swift`; Drift-Regel in `Resources/Knowledge/app_bedienung.yaml` (`App_Aufwand_Eingabe`) erledigt.
  - **#2 `docs/HANDOFF-Auswertung-speichern.md` → GEBAUT.** `GespeicherteAuswertung` in `Views/EventDetailView.swift` + Test `…Tests/GespeicherteAuswertungTests.swift`. (Merge-nach-`main`-Status noch prüfen.)
  - **#3 `docs/Unterlagen-Auswerten-Routing-Spec.md` → OFFEN, nichts gebaut.** Nächster Brocken; spannt App + Box (mops-api). §4b: Klassifizierung übers vorhandene `braucht_vision`-Gate, NICHT nacktes `extract_all`. Erster Happen laut Spec: Box `/extract-auto` gegen zwei Fixtures, ohne iOS.
- Die drei Dokus liegen lokal weiterhin **ungetrackt** (in keinem Commit).
- `AGENTS.md` wurde um Pflichtspur + TAO-Hinweis ergänzt.

## Kompass

- **Woran arbeiten wir gerade?** Drei Tage Kalkulations-Tiefe: 29.07. DIN-276-Katalog
  konsolidiert · 30.07. **B-Element** (Rezept-Kalkulation, Preis je m² aus mehreren
  Arbeitsschritten) + KG-Namen auf eine Quelle · 30./31.07. **Zuschlag je Kostenart,
  Lohnstunden, Firmenwerte**. Siehe die drei Deltas oben. Drei Entscheidungen von Andreas
  stehen offen (Positionsnummer nach KG, hauseigene KG-Zuordnung, hierarchischer Rollup),
  dazu die BauSU-Lücken am Ende des 31.07.-Deltas.
  Als nächster **geplanter** Brocken weiterhin **#3 Unterlagen-Routing `/extract-auto`**
  (App + Box), erster Happen auf der Box gegen zwei Fixtures.
- **Was ist live?** Backend: Box auf **`main`** (sauberer Checkout `4ff018f`, redeployed 28.07. —
  die frühere Angabe „Box-Branch `feature/lv-seite-provenance`" war überholt). iOS-App am Gerät,
  aber auf **altem Datenmodell** (ohne `ZDECKEL`/`ZDECKELNOTIZ`, keine Importe) — die Geräte-
  Installation ist älter als Deckel/Beleg + Excel-Import, siehe Delta 29.07.
- **Was ist gebaut, aber nicht gemergt?** Alles vom 29.–31.07., **ungepusht, kein PR**:
  `fix/din276-kg-532` (4) → `fix/lv-kg-namen` (1) ·
  `feature/lv-element-kalkulation` (3) → `feature/zuschlag-je-kostenart` (2) ·
  `docs/handoff-29-07` (diese Datei). Zwei unabhängige Ketten; innerhalb einer Kette
  gilt die Reihenfolge. Merge-Baum und der Wegwerf-Branch stehen im Delta 30.07.
  Älter: #2 Auswertung-speichern (gebaut, Merge-Status prüfen); außerdem siehe
  `docs/HANDOFF-2026-07-09.md` und Falbe-Bericht. (#1 ist schon in `main`.)
- **Was ist nur Idee?** Nordstern Stufen 3–5, weitere Doctype→LV-Mappings, Kernel-Entscheidung.
- **Was darf nicht angefasst werden?** Kundendaten nicht ins Repo; `main` nicht direkt; `Kernel/` nicht mit echten Daten verdrahten.

## Zweites Repo

Backend **mops-api** immer mitdenken. Bei Backend-Arbeit dort ebenfalls zuerst die aktuelle Übergabe lesen.
