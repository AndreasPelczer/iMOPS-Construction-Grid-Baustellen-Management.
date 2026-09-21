# HANDOFF — AKTUELL (iMOPS)

> Zeigt den letzten Stand. Bei App-Arbeit zuerst hier lesen, dann `rg`, dann bauen.

## Delta 21.09.2026 (Abend) — 22 Commits, alles lokal, NICHTS GEPUSHT

**Branch `feature/gelaende-dxf-aushub`. 554/554 Tests grün (seriell!).**

🔴 **Tests IMMER seriell laufen lassen:** `-parallel-testing-enabled NO`.
Parallel kippt sporadisch `AngebotSchlaegtKalkulationTests` über den geteilten
`AngebotsStore`. Und: eigener `-derivedDataPath`, sonst streiten sich zwei Builds.

### Der rote Faden des Tages

**Alles da, nur nicht verkabelt.** Achtmal dasselbe Muster: gedacht ✅ gebaut ✅
getestet ✅ **nie angerufen** ❌. Werkzeug dagegen:
`~/graphs/mops-werkzeuge/ruft-keiner.py`.

### Gebaut (in dieser Reihenfolge)

| Commit | Was |
|---|---|
| `d1750ae` | **Tagesblick** — „Wo war ich?", erste Zeile der Baustellenliste |
| `67ad8b1` | **Wochenstrahl** — Mo–Fr über alle Baustellen, echte Kalendertage |
| `9796bd3` | **Der Riegel** — „wer ein Nein übergeht, unterschreibt" |
| `7c4ded0` | **Arbeitspakete vorschlagen** — aus 109 Positionen werden 17 |
| `3b11806` | Absturz-Fix: `SpaeterLaden` (NavigationLink baut sein Ziel sofort mit auf) |
| `7297910` | Jede Zeile führt auf IHR Ding, nicht in den Ordner |
| `32fb3c3` | Das Band: was ist JETZT dran, und „Zum Vorgänger" |
| `b5a747f` | Löschknopf hieß falsch · Paketnamen aus dem Positionstext |
| `eb42ffb` | **Eine Kette ist kein Alarm** — aus 33 roten Meldungen wird eine Gelegenheit |
| `6bbd947` | **Die Lage** je Baustelle: „wird geplant" / „läuft", mit „das stünde an" |
| `e27ef63` | Anweisung wird **abgearbeitet**, nicht zusammengebaut (EIN Punkt groß) |
| `1140f5b` | **„Mops, wie geht das?"** — Schritte vom eigenen Prof, abgenommen vom Menschen |
| `62b8986` | Bedienungshilfe nachgezogen (war heute vergessen — eigene Nachlässigkeit) |

### 🔴 Die vier Regeln, die Andreas gefunden hat (nicht ich)

1. **Meldungen müssen klickbar sein.**
2. **Der Klick führt zum DING, nicht in die Schublade.**
3. **Das Ding sagt, was dran ist** — ein Zustand ohne nächsten Schritt ist eine
   Meldung, keine Hilfe.
4. **Gemeldet wird nur, was wirklich etwas ist.** *Ein Zustand, der immer rot ist,
   ist keine Bewertung mehr, sondern Rauschen.*

Prüfstein für jeden neuen Bildschirm: **Muss man sich merken, WARUM man geklickt hat,
war der Klick falsch.**

### 🔴 Offene Befunde (gemessen, nicht behoben)

- **931 Aufträge ohne Baustelle** — beim Löschen einer Baustelle bleiben die Aufträge
  als Waisen zurück (Nullify statt Cascade).
- **Zwei Wahrheiten beim Firmenzuschlag** — `Lohnkalkulation` wird nirgends
  konstruiert, `GewinnSchieberView` rechnet ihn daneben nach, mit anderem Modell.
- **15 weitere „ruft keiner"-Punkte** — `~/Desktop/iMOPS-RUFT-KEINER.txt`.
- **Die Wächter** (BourdainGuard, Rio-Jitter, Privacy-Schild) sind vollständig
  geschrieben und hängen an Demo-Daten: Zähler wird nie erhöht, Schicht misst die
  App-Laufzeit, Whisper geht per `print()` ins Nichts.
- **`AuftragExtrasPayload.from()` liefert bei einem Dekodier-Fehler einen LEEREN
  Payload.** Nie ein Pflichtfeld anhängen.
- **Die „Mops fass"-Ampel gehört an den Anfang**, nicht die Fehlerliste (Andreas'
  Erstnutzer-Versuch: „die roten Meldungen erschrecken").
- **Die 91 Vorlagen-Schritte sind erfunden** — jetzt als `.vorlage` = ungeprüft
  markiert. Raphi muss Pflaster und Tragschicht einmal durchlesen.

## ▶ NÄCHSTER SCHRITT

1. **Der Mops füllt den Bautagesbericht vor.** Er ist gut gebaut (`gesperrtAm`,
   `korrigiertVonID`!), aber alles wird von Hand getippt. Blockaden → `behinderungen`
   (= Nachtragsgrundlage). Reines Verkabeln, zahlt sofort.
2. Umkehrbarkeits-YAML in `Resources/Knowledge/` — braucht 5 Nachweispunkte von Raphi.
3. Die Firma als Ding (gibt es NICHT: 18 Entities, nur `Employee`).
4. Fremdfirmen-Zugang, Link statt Login.
5. Die Wächter an echte Daten.

**Erst der Empfänger, dann der Absender.**

Übersicht (angepinnt): https://claude.ai/artifact/P7ybAevpUML9699mwDSNcZ

## Delta 21.09.2026 (Nachmittag) — drei Dinge gebaut, ein Modell geschrieben

**Branch `feature/gelaende-dxf-aushub`, weiter lokal. NICHT gepusht.**
Letzte Commits: `d1750ae`, `67ad8b1`, `9796bd3`. **530/530 Tests grün.**

### Gebaut und committet

1. **`Service/Tagesblick.swift` + `Views/TagesblickView.swift`** (`d1750ae`) — die Klammer
   über ALLE Baustellen. Erste Zeile der Baustellenliste („Wo war ich?"): wer steht ·
   was ist überfällig · wo fehlt ein Preis · wo du zuletzt warst. Preise über
   `LVKalkulator.effektiverEP` (keine zweite Wahrheit). Bewusst kein Toolbar-Knopf
   (`.searchable` kapert am iPad die Navileiste).
2. **`Service/Wochenstrahl.swift` + `Views/WochenstrahlView.swift`** (`67ad8b1`) — die Woche
   Mo–Fr über alle Baustellen auf ECHTEN Kalendertagen. Kein dritter Gantt: nutzt
   `Bauablauf.terminplan` und `BrigadePlanung.arbeitstageZwischen`. Zeigt ehrlich, was
   fehlt, statt einen leeren Kalender zu malen.
3. **`Service/Uebergehung.swift` + Riegel in `AuftragDetailView`** (`9796bd3`) —
   **„Wer ein Nein übergeht, unterschreibt."** `markJobCompleted()` fragt jetzt
   `istStartbar`. Ist etwas offen: kein Sperren, sondern ein Dialog mit Pflicht-Satz.
   Die Übernahme hängt am Auftrag, überlebt das Lösen der Kante, ist sichtbar.

### 🔴 Was dabei gefunden wurde (alles gemessen, nicht vermutet)

- **`Auftrag.istStartbar` hatte 26 Zusicherungen in den Tests und NULL Aufrufer.**
  Der Riegel war gebaut, getestet, nie angeschlossen. Der einzige Weg an einer
  Voraussetzung vorbei war, sie zu **löschen** — spurlos.
- **Werkzeug dagegen:** `~/graphs/mops-werkzeuge/ruft-keiner.py` findet
  „gebaut + getestet + ruft keiner". Befund: `~/Desktop/iMOPS-RUFT-KEINER.txt`,
  **16 getestet-aber-nie-gerufen, 77 ohne Test.** Noch offen u. a.:
  `Firmenprofil.setzeAktiv`, `BewehrungsGewichte.mattenGewicht/.stabstahlGewicht`,
  `Erdmassen.gegenFlaeche/.massenausgleich`, `BauWetterRegeln.validateArbeitsbedingungen`.
- **`Lohnkalkulation` wird nirgends konstruiert**, und `GewinnSchieberView` rechnet den
  Firmenzuschlag **daneben nach, mit einem anderen Modell** → zwei Wahrheiten.
- **`AuftragExtrasPayload.from()` schluckt Dekodier-Fehler und liefert einen LEEREN
  Payload.** Fehlt ein Pflichtfeld, ist nicht dieses Feld leer, sondern ALLE — still.
  **An diesen Payload nie ein Pflichtfeld anhängen.** Test hält das fest.
- Das Core-Data-Modell hat **zwei Versionen**; aktiv ist `test25B 2.xcdatamodel`
  (`.xccurrentversion`). Wer die falsche liest, sucht in die falsche Richtung.
- `Auftrag` hat **zwei Pflichtfelder ohne Default**: `statusRawValue`, `storageNote`.
  Tests, die sie vergessen, scheitern erst im `save()`.

### Ohne Code: das Modell dahinter (Andreas' Entscheidung)

`~/Desktop/iMOPS-Kontrolle-ohne-Ueberwachung.html` (11 Paragraphen) — Arbeitszeit ohne
Leistungsmessung, Kulanzfenster 8:00/8:10, feste Sendezeit, Totmann-Alarm, die drei
Verbote. Abgeglichen mit „Ein Mops kam in die Küche" (Kap. 4, 8, 9, 10) und
„Thermodynamik der Arbeit". Memory: `mops-zeit-und-fuersorge-modell`.

`~/Desktop/iMOPS-Nachunternehmer-fuer-Raphi.html` — Nachunternehmer im Mops, die Linie
Leistungssoll vs. Weisung. Memory: `nachunternehmer-im-mops`.

## ▶ NÄCHSTER SCHRITT (vereinbart, in dieser Reihenfolge)

1. **Der Mops füllt den Bautagesbericht vor.** Er ist gut gebaut (`gesperrtAm`,
   `korrigiertVonID`!), aber **alles wird von Hand getippt**. Blockaden aus dem
   Tagesblick → `behinderungen` (= Nachtragsgrundlage). Übernahmen → Vorkommnis.
   Maschinen, Wetter (`BauWetterRegeln` gehört hierher). Polier liest und korrigiert.
2. **Dann** die Umkehrbarkeits-YAML in `Resources/Knowledge/` — welche Regel darf
   übergangen werden, welche nie (verdeckte Arbeiten), plus der Folgetext je Regel.
   Braucht fünf Nachweispunkte von Raphi.
3. Danach: Nachunternehmer-Zugang, Link statt Login.

**Erst der Empfänger, dann der Absender** — sonst bauen wir wieder etwas, das niemand anruft.

## Delta 21.09.2026 (00:10) — BESTÄTIGT AN ECHTEN DATEN: die Rundreise schließt

Andreas hat die vier Schritte gemacht (neu gebaut 00:04, LV geleert, der fertigen X84 der laufenden Baustelle
importiert). Ergebnis in der App: **263.304,97 € Angebotssumme**, jede Position grün mit
„EP (Angebot)" — die beiden Einheiten-Funde stehen sichtbar drin (Randschalung 115,56 €/m²,
Betonstahlmatten 2,35 €/kg).

**Rundreise-Probe** (der Nachweis, der gestern fehlte): dieselbe Baustelle wieder als X84
exportiert (Mops-Export, 00:09) und gegengerechnet —
109 Items, 109 `<UP>`, DP 84, Summe **263.304,97 €**. Rein und raus identisch, keine
Position ohne Preis. Der Weg Datei → Angebotsspeicher → LV → Export ist damit an echten
Daten dicht.

Zum Vergleich der Stand davor (Mischbestand aus zwei Importen, PDF von 00:06):
162 Positionen, 92 ohne Preis, 169.876,69 € — die vier Stützwinkel-Positionen standen leer.

**🔴 Offen:** das Angebots-PDF neu exportieren (das von 00:06 hat noch die alten Zahlen).
Dabei fällt die **Titelfolge** auf: Titel 01 heißt „Baukonstruktionen" und mischt Innenwände
(341/342) mit Bauzaun, Bau-WC und Gerüst (391/392), danach erst Baugrube. Raphis Angebote
laufen nach Bauablauf — Baustelleneinrichtung, Erdbau, dann aufgehend. Kosmetik, aber einem
Bauleiter fällt es sofort auf. Ebenfalls offen: Filigranplatten-Lieferpreis (~1.900 € Lücke)
und Stützwinkel H 2050 (5.600 €, extrapoliert, rosa ⚠) beim Fertigteilwerk anfragen.

## Delta 21.09.2026 (00:xx) — Der Import meldete „fertig" und hatte nichts geliefert

**Branch `feature/gelaende-dxf-aushub`, weiter lokal, NICHT gepusht.**

**Was passiert ist.** Andreas importierte um 23:18 die fertige der fertigen X84 der laufenden Baustelle
(109 Positionen, 109 Einheitspreise, 263.304,97 €). Die App zeigte danach drei Zahlen für
dieselbe Baustelle: LV **164.788,03 €**, Canvas-Rechnung **4.076,08 €**, Datei **263.304,97 €**.

**Die Diagnose — und die Falle darin.** Ich habe von außen gemessen: Datei sauber (DP 84,
`<UP>` in jedem Item), Parser sauber (mit `swiftc` gegen die echte Datei: 109 Items, 109
Preise, Summe auf den Cent), Positionen in der Datenbank mit vollständigem Langtext
(zeichengleich mit der X84 — es war also die richtige, neueste Datei). Trotzdem im
Angebotsspeicher **kein einziger Eintrag** nach 21:18.

Die Ursache lag nicht im Code, sondern daneben: **`ps` sagt, die App läuft seit 22:00 —
der Preis-Fix `dc8b6ea` ist um 22:06 committet.** Sechs Minuten. Dahinter noch fünf
Commits: Canvas-Rechnung (22:17), die kompletten Rezepte (22:22/22:29/22:34). Das erklärt
alle drei Zahlen auf einen Schlag. Andreas' App war auf dem Stand von 22:00.
Betriebsregel dazu: Memory `laufende-app-aelter-als-der-fix.md`.

Nebenbefunde aus derselben Messung:
- **162 Positionen statt 109**, 17 Positionsnummern doppelt. Ein GAEB-Import hängt an, er
  ersetzt nicht — die Stützwinkel stehen zweimal drin (`L_995 …` alt, `L 995 … liefern und
  versetzen` neu).
- **84 Angebots-Schlüssel zeigen auf gelöschte Positionen.** Ungefährlich: `Z_PRIMARYKEY.Z_MAX`
  = höchste lebende Z_PK, Core Data recycelt die IDs nicht. Ein alter Preis kann nicht an
  einer neuen Position kleben. Aufräumen wäre trotzdem mal fällig.
- Die 140 Angebote mit Lieferant „Firma-Katalog" stammen vom **Preislisten-Import**
  (`FirmaPreisKatalog`), nicht vom GAEB-Weg. Der GAEB-Weg hat nie etwas geschrieben.

**Gebaut — Ankunfts-Nachweis für den GAEB-Import** (`Service/GAEBAnkunftsPruefung.swift`,
`Views/GAEBAnkunftsBerichtView.swift`). Der eigentliche Skandal war nicht der Bug, sondern
dass er sich wie Erfolg anfühlte: der Import zählte, was er zu tun *glaubte*. Jetzt liest er
nach dem `save()` **zurück**, über `LVKalkulator.effektiverEP` — denselben Weg, den das LV
und die Angebotssumme gehen. Was dort nicht erscheint, erscheint auch hier nicht.
Bringt eine Datei Preise mit, gibt es **kein blankes „Import fertig" mehr**, sondern immer
den Nachweis: Positionen · Preise in der Datei · davon abrufbar · Summenprobe Soll gegen Ist ·
bei Lücken jede Position einzeln, teuerste zuerst, mit Fehlbetrag. Rot bei Ausfall.
Schwester im Repo: `PreisImportBerichtView` (Preislisten-CSV) — gleiche Idee, anderer Weg herein.

**Dazu die Doppel-Import-Warnung:** hat die Baustelle schon Positionen, steht das jetzt
orange über der Auswahlliste, samt Satz „der Import hängt an, er ersetzt nicht".

**Tests:** `GAEBAnkunftsPruefungTests` (6 neu, **488/488 grün**) — der Totalausfall von heute,
der reparierte Weg, eine Datei ohne Preise (darf keinen Alarm geben), Teilausfall mit exaktem
Fehlbetrag, Bestandszähler je Baustelle. Dazu `derSchluesselMussDiePermanenteObjectIDSein`:
baut beide Reihenfolgen nebeneinander nach (Schlüssel vor dem Speichern = temporäre ID =
Preis weg / `obtainPermanentIDs` zuerst = Preis da). Ohne den wäre der Nachweis blind für
genau den Fehler, für den es ihn gibt. Drift-Regel erfüllt: `app_bedienung.yaml` +2 Einträge
(`App_GAEB_Ankunftsbericht`, `App_GAEB_Import_haengt_an`) → 51 gesamt.

**Befund am Rand, NICHT geändert (Andreas entscheidet):** eine Baustelle wird in der Liste
per **Swipe nach links ohne jede Rückfrage** gelöscht (`EventListView.swift:27`
`.onDelete(perform:)` → `EventListViewModel.swift:158-163`). `Event.lvPositionen` steht im
Modell auf **`deletionRule="Cascade"`** — ein verrutschter Daumen nimmt also das komplette
LV mit, hier wären das 162 Positionen und die ganze Kalkulation. Das widersprüche der
eigenen Regel für destruktives Löschen (kein Full-Swipe, `.alert` mit benannten Folgen —
so gelöst beim Auftrag-Löschen am 18.09.). Das LV selbst ist dagegen sauber geschützt:
Einzelposition mit Alert, Gesamt-LV nur über GOAT-PIN. Nur die Baustelle darüber nicht.

**🔴 Was Andreas tun muss, damit die Baustelle stimmt** (in dieser Reihenfolge):
1. In Xcode **Stop, dann Run** — sonst läuft weiter die 22:00-Binary und alles wiederholt sich.
2. Das alte LV leeren (162 Altpositionen): in der Baustelle **Rechtsklick / langes Drücken
   auf die LV-Karte → „Gesamtes LV löschen" → GOAT-PIN → „LV LEEREN"**
   (`Views/LVAbrissView.swift`). Die Baustelle selbst bleibt dabei stehen — Mängel,
   Bautagesberichte, Aufmaße gehen nicht verloren.
   *Nicht* der „Duplikate entfernen"-Knopf im LV: der vergleicht Bezeichnung+Einheit+Menge,
   und die alten Positionen heißen anders („Stützwinkel L_995 …" / Einheit „Stk" gegen
   „Stützwinkel L 995 … liefern und versetzen" / „Stück"). An diesem Bestand nachgemessen:
   er würde **0** Positionen entfernen, obwohl 16 Positionsnummern doppelt sind.
3. die X84 vom Desktop importieren.
4. Der Ankunfts-Bericht muss grün **„Alle 109 Preise sind da"** und **263.304,97 €** zeigen.
   Zeigt er rot, ist der Fix unvollständig — dann die Liste der vermissten Positionen lesen.

## Delta 20.09.2026 (Nacht, spät) — BKI-Ernte 2. Runde: eine Einheit war 7.400 € wert

**Branch `feature/gelaende-dxf-aushub`, weiter lokal, NICHT gepusht.** Geändert: nur
`docs/bki-ernten.md` und `Resources/Knowledge/bki_marktpreise_2026.yaml`. Kein Swift.

**Der Befund, um den es geht — BKI rechnet Winkelstützelemente je LAUFENDEM METER Wand,
nicht je Stück.** Die Reihe (LB 080, KG 543, RF 1,027): H 55 → 175 €/m · H 80 → 210 · H 130 → 398 ·
H 155 → **452** (BKI-080000421, VON 418 / BIS 526). Die L-Steine der laufenden Baustelle sind
995 mm breit, also ein Stück je Meter → **452 € statt der angesetzten 210 €/Stück.** Über alle
vier Positionen: **7.300 € → 14.713 €.** Der vorige Ansatz war nicht knapp daneben, sondern halb
so hoch. Zusätzlich nennt der BKI-Leistungstext die **Betonbettung** als enthalten — die eigene
Position „Fundamentbett unter Stützwinkel" (310,67 €) ist deshalb entfallen, sonst doppelt.

**Gegenrichtung, gleicher Tag:** Grundleitung PVC-U DN100 = **35 €/m** (LB 009) gegen 95 €/m
Richtwert → −1.800 €. Und die **Dichtheitsprüfung nach DIN EN 1610** (8,85 €/m, alternativ
566 € je Strang) fehlte im LV komplett — bei Neubau Pflicht, jetzt als 411.0035 drin.

**Nicht übernommen:** BKI „Baustelle einrichten, Geräteeinheit/Kolonne" 28.417 €/St — der
Leistungstext sagt Bohr-/Ramm-/Rüttelarbeiten, also Spezialtiefbau. Gilt nicht für ein EFH.
Brauchbar aus LB 006 dagegen: **Stundensatz Facharbeiter 79 €/h, Helfer 70 €/h** — unabhängige
Gegenprobe für den eigenen Verrechnungssatz (74 €/h liegt sauber dazwischen).

**🔴 Korrektur einer Behauptung aus der Runde davor:** In `docs/bki-ernten.md` stand, Goldschmitt
liege durchgehend bei **BKI × 0,730**, „dreifach bestätigt". **Das war falsch und ist ersetzt.**
Von den drei Belegen war nur einer ein echter Zeile-gegen-Zeile-Vergleich; bei der Bodenplatte war
der BKI-Wert selbst zusammenaddiert, bei den Mauerwerksöffnungen stand links ein eigener Richtwert
statt einer Katalogzeile (Zirkelschluss). Die Gegenprobe an einer echten Katalogzeile: Mauerwerk
GP2/0,5 d=30 cm **125,83 / 124,00 = 1,015** gegen Pflaster **0,725** — 40 % Streuung.
**Es gibt keinen einheitlichen Firmenfaktor.** Position für Position, nie hochrechnen.
Der Abschnitt in `docs/bki-ernten.md` heißt jetzt so und erklärt die Falle; Memory
`bki-ernten-verfahren.md` ebenfalls korrigiert.

**Nachgerechnet statt behauptet — Elementdecke:** die Zerlegung liegt bei **76,55 €/m²**
(Elemente + Ortbetonergänzung + Unterstützung + Randschalung + Bewehrung, 5.817,69 € auf 76 m²)
gegen BKI 102 €/m² bei nur 18 cm. Unsere Decke ist 20 cm dick, müsste also darüber liegen →
**rund 1.900 € Lücke, wahrscheinlich im Lieferpreis der Filigranplatten.** Beim Fertigteilwerk
anfragen. (Eine vorher in den Vorabzug geschriebene Zahl von „3.100 €" war ungeprüft und ist
korrigiert.)

**🔴 Ein Test war rot — nicht durch diese Änderung.** `BKIMarktpreisKatalogTests.yamlLaedtUnd
FindetProBaustein` verlangte, dass **BET-010 ein Platzhalter** ist. BET-010 wurde in der Ernte-Runde
davor (Commit 96c237d) mit einem echten Wert gefüllt → seitdem rot. Der Test hielt einen Zustand
fest, den das Ernten planmäßig auflöst. **Ein Test darf nicht rot werden, weil jemand seine Arbeit
gemacht hat.** Ersetzt durch `keinUngeernteterWertGibtSichAlsEchterMarktpreisAus` — prüft die Regel
(kein Eintrag ohne Wert darf unmarkiert bleiben) statt einer einzelnen Zeile. Dafür
`BKIMarktpreisKatalog.alle()` ergänzt. **482/482 grün, TEST SUCCEEDED.**

**`bki_marktpreise_2026.yaml`:** 13 Bausteine + **23** freie Positionen (vorher 14). Neu:
Winkelstützreihe (4 Höhen), Grundleitung, Dichtheitsprüfung, beide Stundensätze, Lagerplatz.
Lizenzlinie unverändert: Einzelwerte mit Quelle und BKI-ID, keine Tabellen.

**Sichtbare Herkunft an jeder Position** (Andreas' „deterministisches LV mit Ausnahmen"):
die Preis-CSV füllt das **Lieferanten-Feld** jetzt mit der Herkunft statt mit abgeschnittenem
Fließtext — `Goldschmitt-Katalog (eigene Kalkulation)` · `aus Goldschmitt-Katalogzeilen gerechnet` ·
`BKI Baupreise 2026, RF 1,027 (BKI-080000421)` · `Marktrichtwert - eigener Lieferant eintragen` ·
`!! ANNAHME - vor Angebotsabgabe pruefen`. Der Nutzer überschreibt es mit seinem echten
Lieferanten; die Herkunft bleibt in der Angebots-Vorschau dokumentiert. Im Vorabzug tragen diese
Positionen ein **rosa ⚠-Abzeichen** bzw. ein blaues „BKI 2026".

**Zweite Einheiten-Falle, gleiche Bauart:** die **Randschalung** führt BKI je lfm (18,49 €/m),
unser LV je m². Über die Bauteildicke umgerechnet: Bodenplatte d=16 → 115,56 €/m², Decke d=20 →
92,45 €/m². Statt der angesetzten 35 €/m². **+853 €** über beide Positionen. Ebenfalls übernommen:
Betonstahlmatten 2,35 €/kg (4×), Durchbrüche/Aussparungen 61 €/St (2×).

**Bewusst NICHT übernommen, mit Grund:** BKI „Querschnittsabdichtung Mauerwerk" 6,76 €/m ist die
reine Sperrbahn — unsere **Kimmschicht LM 21** ist eine gemauerte Ausgleichsschicht mit Mörtel,
andere Leistung. Und die **PE-Trennlage** (2,00 €/m²) steht auf Goldschmitts Katalogteilen, das ist
näher an der Firma als BKIs Marktpreis 2,99 €/m².

**Stand Rohbau:** 79 Positionen + 1 Eventual (eine raus, eine dazu), **101.871,98 € netto**
(vorher 96.311,03). Herkunft nach Geld: Goldschmitt-Katalog 38,4 % · eigener Richtwert 26,4 % ·
aus Katalog gerechnet 15,0 % · BKI 14,8 % · markierte Annahme 5,4 % (die eine Stützwinkelhöhe
H 205, die BKI nicht führt). **Belegt: 68,2 %** — vorher lag der Richtwert-Anteil bei 41 %.

- **🔴 OFFEN:** kein Push. Filigranplatten-Lieferpreis und Stützwinkel H 205 beim Werk anfragen —
  das sind die beiden letzten großen ungeprüften Zahlen. Danach Baustelle 101 im Mops löschen,
  der fertigen X84 der laufenden Baustelle neu importieren, „Mops fass".

## Delta 20.09.2026 (Nacht) — Geländebrücke offline: Aushub aus zwei DXF

**Branch `feature/gelaende-dxf-aushub` (lokal, NICHT gepusht, baut auf `chore/mops-scharfstellen`).**
Andreas' Weg: der Architekt liefert einen Geländeplan OHNE Haus und danach die Grundstücks-
zeichnung MIT Haus. Beide im selben Koordinatensystem → der Aushub ist rechenbar statt geschätzt.

**Neu — `Service/DXFGelaende.swift`:**
- `DXFGelaendeLeser.lies(dxf:)` — zeilenbasierter DXF-Leser, der den **Blockbaum rekursiv auflöst**
  (`q = R(rot)·S(scale)·(p − Blockbasis) + Einfügepunkt`, verkettet). SketchUp legt ALLES in
  verschachtelte Blöcke; der ENTITIES-Abschnitt hat nur die obersten INSERTs. Liest VERTEX,
  POINT, LINE, 3DFACE, LWPOLYLINE. POLYLINE-Köpfe bewusst NICHT (sonst Geisterpunkte im Ursprung).
- `DXFMassstab.vorschlag(fuer:)` — die **SketchUp-Zollfalle**: Exporte kommen oft als
  „Zoll-als-Meter" (1 Einheit = 39,37 m), `$INSUNITS` lügt dabei. Erkannt an der Spannweite
  (< 5 Einheiten = unplausibel), **vorgeschlagen, nie still angewendet**.
- `Gelaendemodell.ausPunktwolke(_:ausschnitt:zellgroesse:hoehenversatz:)` — unregelmäßige
  Punktwolke → Raster (nächster Nachbar über Eimer-Index). Zellen ohne Geländepunkt werden
  **gezählt und gemeldet**, nicht heimlich interpoliert.
- `Aushubvorgabe` / `Aushubrechner` — Sohle = Rohfußboden − Bodenaufbau − Plattendicke − Polster;
  Umriss + Arbeitsraum → `ErdmassenRechner.gegenEbene` (der lag schon da, Bogen 1).
- `Umriss` (Bounding Box, `erweitert(um:)`, `skaliert(_:)`) + `gebaeudeUmriss()` über Wand-Layer.

**Neu — `Views/AushubAusDXFView.swift`:** fünf Schritte (Gelände → Maßstab → Haus/Umriss →
Höhenanker + Aufbau → rechnen), Ergebniskarte, „Aushub ins LV übernehmen" mit dem **Rechenweg
im Langtext**. Eingehängt in `ErdmassenView` (Knopf „Aushub aus zwei DXF"). Rechnen läuft
auf einem Hintergrund-Thread.

**Tests:** `DXFGelaendeTests.swift`, 13 neue → **460/460 grün, TEST SUCCEEDED**
(vorher 445). Falle dabei: lange `+`-Ketten aus Tupel-Arrays lassen den Swift-Typechecker
aufgeben („unable to type-check this expression in reasonable time") — Test-DXF werden
jetzt imperativ über einen kleinen `DXFBauer` gebaut.

**Nachweis an echten Daten (nicht nur Unit-Test):** `Service/Erdmassen.swift` + `DXFGelaende.swift`
mit `swiftc` gegen Raphis echte `Raphi-Haus-Layer.dxf` (11 MB) laufen lassen — 61.319 Punkte in
1,7 s, Hausumriss 8,00 × 9,50 m automatisch erkannt, Wandfuß Z 2,30 → Versatz 193,58,
Gelände 193,02–200,96 müNN, **Abtrag 130,2 m³** bei 0,50 m Arbeitsraum. Deckt sich mit der
Handrechnung. Der Höhenanker ist dreifach geprüft (Straßenhöhe, Garagen-RFB 194,26 müNN
auf den Zentimeter, Terrassenhöhe).

**Drift-Regel erfüllt:** `app_bedienung.yaml` +1 Eintrag `App_Aushub_aus_zwei_DXF` (47 gesamt).

- **🔴 OFFEN:** kein Push (Andreas' OK abwarten). Am echten Gerät noch nicht angefasst —
  der Datei-Picker-Weg (zwei DXF nacheinander) ist ungetestet. Nicht gebaut, bewusst:
  Geländemodellierung gegen ein **geplantes** Endgelände (`ErdmassenRechner.gegenFlaeche`
  kann das schon, es fehlt nur die zweite Zeichnung) und der Fundamentgraben der Hangseite.

## Delta 20.09.2026 (Abend) — Mops SCHARFGESTELLT (Demos/Seeder/Zauberstäbe raus)

**Branch `chore/mops-scharfstellen` (lokal, Commit 6da29b7, NICHT gepusht).** Der Mops läuft ab jetzt nur auf ECHTEN Daten — frischer Mops ist leer bis zum Import.

**Entfernt (15 Dateien + Referenzen):** Demo-/Fake-Seeder (Demo, Debug, BeispielKalkulation, BauerHorst, Hofauffahrt, Sandsteinstufen, Marktbreit, StammdatenSeeder) · `RaphaelStammdatenSeeder` (echte Goldschmitt-Preise waren hardcoded → **DSGVO-Fix**, kommen jetzt per Import-CSV) · `SnapshotHostView` (+ `--snapshot-mode`-Weiche in iMOPSApp) · Zauberstab-/Demo-Knöpfe (ContentView „Demo", Grap8-Text, Hausplaner „Beispielprojekt laden", `LieferwarnungDemoFactory`) · `TheBrain.shared.seed()` beim Start.

**Bewusst BEHALTEN (echte Logik, kein Demo — Falle vermieden):** `ScharpeggeSeeder` (Lieferanten-Sortiment aus Bundle-CSV, im Onboarding/Bestellliste) · `YtongBedarf` · `TiefbauRezepte` · `HouseProjectGenerator`/`ProjektGenerator`/`HouseConfiguratorView` (**echtes Hausplaner-Feature, ist ein Tab in RootTabView!**) · `TheBrain`-Datei (KernelGuardStatusView liest sie) · Firmenprofil-`.mops`-Demo-Schalter (DSGVO-Schutz, kein Fake).

**Tests:** 5 Demo-Seeder-Testdateien entfernt; `KnotenAufwandswertTests` + `KatalogSichtenUndMasseTests` nutzen jetzt Inline-Fixture (Maurer 28,50×1,65 / Helfer 18,50×1,55) statt `StammdatenSeeder`. **445/445 grün, TEST SUCCEEDED.** Backups `_backups/20260920_170535/scharf/`.
- **🔴 OFFEN:** Andreas' OK zum Merge abwarten. Frischer Start seedet nur noch Scharpegge/Ytong/Tiefbau; Firmen-Zuschläge/Löhne kommen aus Einstellungen bzw. Import (nicht mehr aus Seeder).

## Delta 20.09.2026 — Geräte-Import + Goldschmitts ECHTER Katalog (aus Raphis Mail geborgen)

**Branch `feature/geraete-katalog-import` (lokal, NICHT gepusht).** Baut auf `feature/preise-in-einstellungen`.

**Der Fund:** Goldschmitts kompletter Kalkulations-Katalog lag als saubere PDFs in Raphis Mail „Listen und Preise RDLCT 20.09." (nicht die schlechten BauSu-Fotos). Lokal entpackt + per `pdftotext -layout` + Parser extrahiert → `~/Desktop/Lieferanten-Preise/Goldschmitt-Katalog/` (Preise bleiben LOKAL, NIE ins Repo): `Goldschmitt-Preise-komplett.csv` = **2.271 Import-Zeilen** (1.026 `leistung` B-Elemente · 1.144 `material` A-Elemente + Entsorgung · 101 `geraet` Std-Maschinen). ZG-Aufschlag-Legende dokumentiert. Details: Memory `goldschmitt-katalog-ab-elemente`. Andreas hat Raphi die Import-CSV + Klick-Anleitung gemailt.

**Geräte-Import GEBAUT (Tests grün, `TEST SUCCEEDED`):**
- **Modell:** `Geraet` neues Attribut **`stundensatz: Double`** (optional, Default 0 → leichte Migration, automatisch aktiv). `Geraet+CoreDataProperties.kostenProStunde`: wenn `stundensatz > 0` gilt DER (Miete/Fremdgerät), sonst Abschreibung Anschaffung÷Nutzungsdauer.
- **Importer:** `StammdatenPreisImportService` kennt jetzt Zeilen-Typ **`geraet`** (`geraet;name;Std;satz;quelle` → find-or-create `Geraet`, setzt `stundensatz`, idempotent). Bericht um `neuGeraet`/`aktualisiertGeraet`/`unveraendertGeraet` erweitert (Ankunfts-Bericht zeigt „(Gerät)").
- **UI:** `StammdatenPflegeView` GeraetListe zeigt `kostenProStunde €/h`; GeraetEditSheet hat Feld „Fester Stundensatz (Miete/Fremdgerät)".
- **Tests:** `StammdatenPreisImportTests` +2 (`importLegtGeraetMitStundensatzAn`, `geraetReimportAendertNichtUndVerdoppeltNicht`) → 6/6 grün.
- Backups in `_backups/20260920_155730/`.
- **🔴 OFFEN:** kein Push (Andreas' OK abwarten). Raphi importiert die komplett-CSV + schickt Sibiadji-Zeichnung → geplanter End-to-End-Durchlauf (Zeichnung→Mengen→LV→Kalk mit seinen Preisen→Angebot) als echte Demo. Stadtvergleich-Foto = Nachtschicht-Backlog. `docs/material-stammliste.csv` (untracked, leere Vorlage) sollte lokal/gitignored bleiben.

## Delta 19.09.2026 (Abend) — Goldschmitt-Katalog · Xcode-27-Fix · Firma-Preis-Katalog (Schritt 2)

**Feldforschung mit echten Goldschmitt-Angeboten (Andreas' Originale):**
- **LV-Katalog +25 generische Positionen** (`stlb_bausteine.yaml`, jetzt 133 Bausteine): Kellerabdichtung (PR #199) + kompletter Zusatzarbeiten-Fundus (PR #200) — Erdbau, Fundament, Entwässerung/Kanal (PVC DN100, Schächte, Mehrsparteneinführung), Hausanschlüsse, Terrasse/Zufahrt, Bauzaun-Monatsmiete, Kranstellplatz. **NUR Texte + Einheiten, KEINE Preise, KEIN Kunde** (Kundendaten-Riegel). Jeder `aufwandswert_key` auf echte Keys (Test `alleBausteineHabenAufloesbarenKey` grün). Raphis Angebots-Form als Wissen: [[raphi-angebot-arbeitsweise]]; Bauteil-Trennung: [[bau-positionen-immer-getrennt]].

**Xcode-27-Fix (Raphi):** Nach Xcode-Update baute Raphis Mac nicht. Ursache: 4 Dateien nutzen CoreData ohne `import CoreData` (altes Xcode ließ es durch, 27 nicht). Gefixt (PR #201): `import CoreData` in MaterialDetailView, LVPickerViews, MangelStatus, LagerStore. **Raphi-Signierung (sein Team/Bundle-ID) bleibt LOKAL, nie pushen.** Raphi noch auf altem Stand (git pull offen).

**Firma-Preis-Katalog — Schritt 2 (Nordstern, gebaut, grün):** fertiger EH-Preis je Leistung, lokal.
- **Modell:** `Leistungsbaustein` neues Attribut **`einheitspreisVK: Double`** (optional, Default 0 → leichte Migration, automatisch aktiv). Accessor in `Leistungsbaustein+CoreDataProperties.swift`.
- **Füllen:** `StammdatenPreisImportService` kennt jetzt Zeilen-Typ **`leistung`** (CSV `leistung;name;einheit;preis;quelle` → setzt `einheitspreisVK` am Baustein, Match über `LeistungskatalogService.finde`); Ankunfts-Bericht zeigt Leistung-Zeilen.
- **Nutzen:** `Service/FirmaPreisKatalog.swift` (NEU): `preis(fuer:)` Match Leistungstext+Einheit; `anwenden(auf:store:)` hängt den Firmenpreis als **Angebot** (→ `effektiverEP` nimmt Angebote ZUERST, schlägt die Schätzung). Eingehängt in **`AutoKalkulationsService.fass`** (nach der Bewertung). `Tests/FirmaPreisKatalogTests.swift` 4 grün.
- **Goldschmitt-`leistung`-CSV** gebaut (25 echte EH-Preise, lokal `~/Desktop/Lieferanten-Preise/Goldschmitt-Leistungspreise.csv`, NICHT im Repo). Namen exakt auf die Katalog-kurztexte ausgerichtet → beim Picken greift der Firma-Preis.
- **Katalog-Vorschläge beim Anlegen** (PR #204): `STLBKatalog.vorschlaege(zu:)` + Vorschlagsliste in `AddLVPositionView` (tippen → Text+Einheit picken → Firma-Preis greift). **Mouse-Hover** Baustellen-Zeile (PR #203).
- **Schritt 3 GEBAUT — Angebots-PDF auf Raphis Form** (`LVPDFExporter` umgebaut): Briefpapier-Kopf (Logo+Anschrift) + Empfänger (Bauherr) + Angebot-Nr./Datum/Objekt + Anschreiben; **Titel-Gruppierung** (nach KG, DIN-Name) mit **Titelsummen**; **Titelzusammenstellung**; LV-Gesamtsumme + MwSt + **Angebotsendsumme**; Rechtstext-Fuß (`Briefpapier.zeichneFuss`). Damit: Angebot als **PDF (Raphis Form)** UND **GAEB X84** — beides mit Angebots-Nr.
- **🔴 OFFEN:** PDF am echten Angebot visuell prüfen (Layout/Umbrüche); Titel-Namen sind DIN-276-Labels (nicht Raphis Trade-Titel) — evtl. echtes Titel-Feld später. Firma-Preis-Katalog-Menüknopf „Firma-Preise anwenden" (optional). Xcode 27: `import CoreData`-Falle im Blick behalten (weitere Dateien beim Update möglich).

## Delta 19.09.2026 (Nachmittag) — Datei-Ablage Stufe 3: Ordner je Baustelle automatisch

**Stufe 2 lebt (Andreas: „iMOPS taucht links im Finder auf").** Stufe 3 legt jetzt für JEDE Baustelle automatisch einen Ordner mit Dokument-Fächern an.

**Gebaut (5 Tests grün):**
- **`MopsAblage`** erweitert: `sichererOrdnername(_)` (Schrägstrich/Doppelpunkt → Bindestrich, leer → nil, testbar ohne iCloud), `synchronisiereBaustellen([String])` (Hintergrund, idempotent, legt nur an — löscht/benennt NIE um: umbenannte Baustelle = neuer Ordner, alter bleibt, kein Datenverlust). `ordnerFuerBaustelle` legt Fächer Architektur/Vermessung/Statik/Gutachten/Genehmigung/Sonstiges an.
- **`iMOPSApp`** Start-Task: Baustellen-Titel auf dem Main-Context einsammeln (nur Strings über Thread-Grenzen, keine Core-Data-Objekte) → `synchronisiereBaustellen`.
- **`AddEventView.saveEvent`**: neue Baustelle → gleich Ordner anlegen (Hintergrund).
- **`Tests/MopsAblageTests.swift`** (5 grün): Name-Absicherung + 6 Fächer.

**⚠️ Nicht von mir testbar (kein iCloud im Build-Env):** Andreas baut neu → in `iMOPS/Baustellen/` sollten Ordner je Baustelle (Setiadji, Bauer Horst, …) mit den 6 Fächern erscheinen.

**🔴 OFFEN — Stufe 3.1:** Dokumente automatisch ins richtige Fach einsortieren (`DateiSortierer` liefert statik/fakten/ablegen — Taxonomie auf die 6 Fächer mappen). Zuordnung Datei→Baustelle→Mops (dokuPath auf die iCloud-Datei zeigen lassen). Umbenennen/Löschen-Abgleich (bewusst offen gelassen). Geteilter iCloud-Ordner als Andreas↔Raphi-Weg.

## Delta 19.09.2026 (Mittag III) — Datei-Ablage Stufe 2: iCloud-Ordner „iMOPS" (Finder-Seitenleiste + Sync)

**iCloud-Capability aktiviert** (Andreas in Xcode, mit Führung — Hürde war „PLA update available": aktualisierte Apple-Lizenzvereinbarung erst zustimmen unter developer.apple.com/account → Vereinbarungen, dann „Try Again", Container schwarz). Xcode hat `…​.entitlements` (icloud-container/-services CloudDocuments/ubiquity) + pbxproj angelegt — **beide committet** (sonst gehen sie verloren).

**Gebaut:**
- **`Info.plist`**: `NSUbiquitousContainers` → Container `iCloud.io.imops.iMOPS-Construction-Grid-Baustellen-Management-` als **„iMOPS"** (Name), `IsDocumentScopePublic=true`, `SupportedFolderLevels=Any` → erscheint in **Finder-Seitenleiste / iCloud Drive / Dateien** als „iMOPS".
- **`Service/MopsAblage.swift`** (NEU): nil-sicherer Ablage-Service. `wurzel()` = Ubiquity-Container/Documents (nil ohne iCloud-Login → App läuft normal). `stelleGrundstrukturSicher()` legt **_Firma** + **Baustellen** an (idempotent). `ordnerFuerBaustelle(name)` legt Baustellen-Ordner + Fächer (Architektur/Vermessung/Statik/Gutachten/Genehmigung/Sonstiges) an. `url(forUbiquityContainerIdentifier:)` läuft IMMER im Hintergrund (Main-Thread-Falle).
- **`iMOPSApp.swift`**: `MopsAblage.imHintergrundVorbereiten()` im Start-`.task`.

**⚠️ Nicht von mir testbar (kein iCloud im Build-Env):** Andreas muss neu bauen + im Finder prüfen, ob „iMOPS" (Seitenleiste/iCloud Drive) mit _Firma + Baustellen erscheint. Build grün, Plist valide, Service nil-sicher.

**🔴 OFFEN — Stufe 3:** `ordnerFuerBaustelle` beim Anlegen/Öffnen einer Baustelle aufrufen (Core-Data-Events → Ordner je Baustelle), Dokumente per `DateiSortierer` in die Fächer einsortieren, Zuordnung Datei→Baustelle (Finder ODER Mops). Kanten: Umbenennen/Löschen/Konflikt. Optional: geteilter iCloud-Ordner als Andreas↔Raphi-Weg.

## Delta 19.09.2026 (Mittag II) — Datei-Ablage Stufe 1: Mops-Ordner in Dateien sichtbar (iPad/iPhone)

**Andreas' Vision (DAU-Punkt, sein Kern-Argument):** Der Mops muss einen SICHTBAREN Ablageort bieten, wo man Dateien aus Mail/Download/anderem User reinlegt — sonst steigt ein Nicht-Techniker aus („wo tu ich das hin, ich mach nix kaputt, ruf die IT"). Traumbild: ein iCloud-Ordner „iMOPS" in der Finder-Seitenleiste, darin **Unterordner pro Baustelle** mit ALLEN Dokumenten (Boden-DXF, DXF-Zeichnung, PDF/Statik, Architektenpläne, Bodengutachten, Baugenehmigung) — auch AUSSERHALB des Mops findbar. (Stammdaten/Firmeneinstellungen sind app-weit → gehören in „_Firma", nicht je Baustelle.)

**Stufe 1 gebaut (Info.plist):** `LSSupportsOpeningDocumentsInPlace` = true dazu (`UIFileSharingEnabled` war schon an). → Der App-Documents-Ordner erscheint in der **Dateien-App auf iPad/iPhone** („Auf meinem iPad → iMOPS"). Build grün, Plist valide. **Sicherheit geprüft:** Core-Data-Store liegt in **Application Support** (Persistence.swift:51, Default-URL), NICHT in Documents → per Datei-Sichtbarkeit nicht löschbar. Sichtbar werden nur `Documents/CADFiles/` + lose JSON-Arbeitsdateien (angebote.json, Lager, Fortschritt).

**⚠️ Ehrlich:** Auf dem **Mac** erscheint der Ordner damit NICHT in der Finder-Seitenleiste — das ist **Stufe 2 (iCloud)**. Stufe 1 = Fundament + Sofort-Gewinn auf iPad/iPhone.

**🔴 OFFEN — Stufe 2 (nächster Schritt, Andreas will A):** iCloud-Drive-Container „iMOPS" → Finder-Seitenleiste am Mac + Sync Mac/iPad/Handy + möglicher Andreas↔Raphi-Weg (geteilter iCloud-Ordner). **BRAUCHT iCloud-Capability** (Xcode: Signing & Capabilities → + iCloud → iCloud Documents; Ubiquity-Container; Andreas' Apple-Team) + `NSUbiquitousContainers`-Keys (Finder-Anzeigename) + Code (Container-URL, Dateien spiegeln). Kein reiner Code-Change — Andreas muss die Capability in Xcode aktivieren, ich führe. **Stufe 3:** Unterordner pro Baustelle (mit Core Data synchron) + Dokument-Kategorien; nutzt vorhandenes `DateiSortierer` (statik/fakten/ablegen) + Genehmigungs-Mappe [[genehmigungs-checkliste]]. Kanten: Umbenennen/Löschen/Konflikt → vorsichtig.

## Delta 19.09.2026 (Mittag) — Schritt 4: „Preise anhängen" (Stammdaten-Material → Position), die Kette schließt sich

**Live bewiesen:** Der CSV-Import (Vormittag III) hat die 8 Setiadji-Preise in die Stammdaten gelegt (Ankunfts-Bericht „8 Preise gelandet" — Andreas hat's am Mac gesehen). ABER: die Positionen zeigten weiter nur Lohn-Richtwerte (Betonstahl 0,71, Ytong 18,92, Beton 44,09) — der Stammdaten-Preis war noch nicht ANGEHÄNGT. Genau die als Schritt 4 angekündigte Lücke.

**Gebaut (grün, 5 Tests grün):**
- **`Service/PreisAnhaengeService.swift`** (NEU): matcht pro Position die passende `KalkMaterial` über Namens-Tokens (normalisiert: Slash/Bindestrich → Leer), Schwelle 0,6. `haengeAn(...)` legt eine `PositionMaterial`-Zeile an (einzelpreis aus Stammdaten, mengeProEinheit=1, quelle="eigen"), idempotent. → EP springt von „nur Lohn" auf „Lohn + Material".
- **`Views/PreisAnhaengenView.swift`** (NEU): Bestätigungs-Sheet — pro Position Vorschlag + ✓ + Override-Menü (für Fälle ohne Auto-Treffer, z.B. Deponie→Bodenaushub). „Anhängen (N)".
- **`Views/LVView.swift`**: ⋯-Menü-Knopf **„Preise anhängen"** (link.badge.plus) + Sheet.
- **`Tests/PreisAnhaengeTests.swift`** (5 grün): Beton→Beton · Bewehrung→Betonstahl (nicht Beton) · Ytong trotz Bindestrich/Slash · kein Falsch-Treffer bei Fremdposition · Anhängen idempotent.

**Die ganze Kette steht jetzt:** SketchUp/Plan → LV-Positionen · Preisliste-CSV → Stammdaten (Import + Ankunfts-Bericht) · **„Preise anhängen" → Material an Position** (Vorschlag+Bestätigung) · EP = Lohn+Material · Mops fass · X84. Mensch bestätigt, erfindet nie; jede Zahl trägt Herkunft.

**🔴 OFFEN:** (a) Andreas testet „Preise anhängen" an Setiadji am Mac/iPad → Summe klettert von 12.660 Richtung realistisch; Deponie von Hand zuweisen. (b) Schalsteinwand/Ringbalken haben noch keinen LOHN (waren rote „kein Rezept") — kriegen erstmal nur Beton, Raphi feilt. (c) angehängtes Material als wiederverwendbares **Rezept lernen** (nächste Baustelle automatisch). (d) SketchUp-Plugin Preis-Feld + „offen"-Schalter (Quell-Ende desselben Rohrs).

## Delta 19.09.2026 (Vormittag III) — Stammdaten-Preis-Import (CSV → Stammdaten) mit Ankunfts-Nachweis · objectID-Import-Bug gefixt

**Der Kern-Frust, ehrlich benannt (Andreas):** Er ist Koch + Coder, kein Baumann — er KANN Bau-Preise nicht validieren („3,50 bei Ringbalken? keine Ahnung, wem soll ich glauben, die KI halluziniert"). Und wiederkehrender Ärger: Preise/Stammdaten lagen wochenlang „eingebaut", waren es aber nie — weil ein Agent „getestet/fertig" MELDETE (Behauptung), ohne dass jemand die ANKUNFT an den echten Daten maß. **Diagnose:** Die Sicherungen prüfen die ÜBERGABE, nicht die ANKUNFT+WIRKUNG. Antwort = das System trägt Preise MIT Herkunft + einem Ankunfts-Nachweis; der Mensch bestätigt/überschreibt, erfindet nie. (Tao: Nachweis statt Behauptung, an den Daten statt am Code.)

**Gebaut (Schritt 1–3, alle grün, Tests grün):**
- **`Service/StammdatenPreisImportService.swift`** (NEU): CSV `typ;name;einheit;preis;lieferant` → `KalkMaterial`/`Lohnsatz`. Idempotent (Match über Namen, kein Verdoppeln), deutsches Komma, Kopfzeile erkannt. Gibt einen **`PreisImportBericht`** zurück (neu / aktualisiert alt→neu / unverändert / übersprungen+Grund).
- **`Tests/StammdatenPreisImportTests.swift`** (NEU, 4 Tests grün): Zeilen landen WIRKLICH in Core Data · Re-Import verdoppelt nicht · Preisänderung überschreibt · kaputte Zeile wird gemeldet nicht verschluckt.
- **`Views/StammdatenPflegeView.swift`**: Knopf **„Preise laden"** (fileImporter CSV) → Import → **`PreisImportBerichtView`** (Ankunfts-Bericht „N Preise gelandet", Listen). Der Beleg, den Andreas/Raphi ohne Bau-Wissen lesen.
- **`Views/GAEBImportView.swift`**: **objectID-Import-Bug GEFIXT** — bei X84-Import wurde der AngebotsStore-Key aus der TEMPORÄREN objectID vor dem `save()` gegriffen → Preis nach Speichern/Neustart „weg". Jetzt `obtainPermanentIDs` vor dem Key. (Genau die Falle, die Andreas immer wieder traf.)

**Lokal, NICHT im Repo (Kundendaten):** `~/Desktop/BV Setiadji-Artanti Retzbach/Setiadji-Preise-Stammdaten.csv` — 8 Material-Preise mit Quelle (Schotter 7,90 SHB 🟢 · Ytong 24/11,5 34/22 Xella 🟢 · Beton C25/30 130 · Betonstahl 1,20 · Matten 1,10 · Deponie BK2 17 🟠Gutachten · Baustelleneinrichtung 2500). Validiert (parst sauber).

**Andreas' Idee (nächster Bogen, sein Instinkt goldrichtig):** Das SketchUp-Plugin (`mops-scetchup`, Spike) als **Quell-Ende desselben Rohrs**: Raphi bepreist beim Malen den Bauteil-TYP (€/Einheit, einmal), Sync emittiert dieselbe CSV → mein Import lässt sie landen. Feinschliff: Preis pro Einheit (nicht pro Objekt), **nicht hart blocken** sondern „Preis offen" bewusst wählbar (→ 🔴 offen im Mops, sichtbar+gewählt), Herkunft „Raphi·SketchUp·Datum" klebt automatisch dran.

**🔴 OFFEN — Schritt 4:** Nach Import `Setiadji-Preise-Stammdaten.csv` → „Mops fass" → prüfen, welche der 12 Positionen den Preis gezogen hat und welche NICHT (Namens-/Rezept-Treffer). Rezept-Lücken (z.B. rote „Schalsteinwand-Verguss") verbinden, damit die Stammdaten-Preise an die Positionen kommen. Dann X84 neu, Gegencheck. Danach: Plugin-Preis-Feld + „offen"-Schalter.

## Delta 19.09.2026 (Vormittag II) — Canvas↔LV verdrahtet · KI-Marker ehrlich · Lohn lernt · EK/VK getrennt

**4 Sachen gebaut, alle grün, auf `main` UNCOMMITTED → Branch + PR nach Andreas' iPad-Test (kein Push ohne OK).** Backups in `_backups/20260919_*`. Verbinden statt erfinden — nichts Neues erfunden, die vorhandenen Brücken/Enums nur verdrahtet (Kühlhaus-Check gemacht, zwei Explore-Läufe mit Datei:Zeile).

- **Canvas ↔ LV Auto-Sync:** Der „+" im Canvas legt jetzt automatisch die LV-Position mit an, der „+" im LV automatisch den Canvas-Knoten — über die schon vorhandene `LVCanvasBruecke` (`erzeugeLVPosition`/`erzeugeKnoten`) + Modell-Link `Auftrag.lvPosition ↔ LVPosition.auftrag`. Eingehängt in `AddJobViewModel.saveNewJob()` und `AddLVPositionView.save()` (nur Neuanlage). **Import flutet den Canvas NICHT** (GAEB läuft nicht über diese „+"-Wege); Batch-Knöpfe bleiben für Alt-Bestand.
- **KI-Marker ehrlich:** `LVPositionRow` markierte nur `Kostenquelle==.ki` — darum blieben Katalog-**Richtwerte** (blau, z.B. Eisenflechter-Lohn) unsichtbar. Jetzt zeigt die Zeile die **schwächste Quelle** über das vorhandene `QuelleBadge` (Richtwert blau / Startwert orange / KI lila; grün/leer = dein Wert). Eine Sprache in Liste + Tiefenkalk.
- **Lohn lernt in Stammdaten:** `LohnHinzufuegenView.hinzufuegen()` legt einen `Lohnsatz`-Stammsatz an (idempotent, Brutto-EK als `stundenlohn`, `zuschlagFaktor 1,0`) — analog zu `MaterialHinzufuegenView.lerneInKatalog()`. **Gerät lernt (noch) nicht** — der `Geraet`-Stamm rechnet über Abschreibung (Anschaffung ÷ Nutzungsdauer), kein €/h-Feld → bräuchte ein Modell-Feld (`stundensatzManuell`, Migration). Bewusst NICHT mit Fake-Wert gemacht.
- **EK/VK getrennt** (Andreas' Wunsch „übersichtlicher"): Neuer Abschnitt **„Grundpreis (EK)"** in `AddLVPositionView` (EK je Einheit editierbar, bei Text/Menge; ausgeblendet beim Baustein-unter-Element). Die **LV-Liste zeigt den EK nur noch an** (read-only, `direktPreis`-TextField raus) — bearbeitet wird über Wischen→Bearbeiten. **VK bleibt in der Kalkulation.**
- **`app_bedienung.yaml` nachgezogen** (Drift-Regel): Canvas-Eintrag (Auto-Sync) + LV-Eintrag (Herkunfts-Badge, EK/VK-Trennung, Hand-Preis-Lernen).

**🔴 OFFEN aus diesem Block:** (a) Andreas testet die 4 Sachen am iPad, dann Branch + PR + merge `main` (sein „Go"). (b) **Gerät-Handpreis-Lernen** braucht Modell-Feld (Migration) — auf Wunsch. (c) X84-Gegencheck Setiadji siehe unten.

**⚠️ Setiadji-X84-Befund (`~/Downloads/Setiadji-Baustelle-X84`, 12 Pos, Gesamt 17.326,87 €):** Mehrere EPs sind **nur Lohn, Material fehlt** — Bodenplatte 44,09/m³ (Material allein wäre ~125!), Streifenfundament 23,51, **Betonstahl 0,71/kg** + Matten 0,33, **Mauerwerk Ytong 18,93/m² (Steine fehlen komplett!)**, Baustelleneinrichtung fehlt ganz. Realistisch eher **~34–36k**. Vor dem Absenden: Material-Preise in die Stammdaten (jetzt lernen sie ja), dann „Mops fass" neu → neu exportieren. Manuell bepreiste Pos (Decke 283,96 · Schalsteinwand 284,62 · Ringbalken 332,50 · Bodenaushub abfahren 31,50) sind sauber.

## Delta 19.09.2026 (Morgen) — Aufgeräumt: alles auf `main`, Raphi synchronisiert

**Alle gestrigen Branches sind GEMERGT — `main` = `537517a`.** Die „NICHT gepusht"-Sätze in den 18.09-Deltas unten sind damit ERLEDIGT (waren beim Schreiben wahr, jetzt Historie).
- **PR #186** (Hauslage): `HauslagePlatzierenView` fertig (Haus-Rechteck → `footprint` UTM → `/gelaendebruecke/calculate` → Ergebnis in der Karte; Zoom/Pan + PDF-Lageplan-Hintergrund) + Insel-Duplikate raus (`VermessungDXFLeser`/`Baugrube`/`BaugrubeRechnerView` + 2 Tests + `ErdmassenView`-Knöpfe). PR #185 (PlanAbgreifen) geschlossen.
- **PR #187** (LV): lila KI-Pille in der LV-Zeile (`LVPositionRow.enthaeltKI`) + „Duplikate entfernen"-Menüknopf in `LVView` (allgemeiner Dedup Bezeichnung+Einheit+Menge; kalkulierte bleibt; Undo).
- **PR #188** (Canvas): der „+" im Grap8-Canvas ist ein Menü — Freier Auftrag + 8 Baustein-Typen (Fundament/Wände/… = native Ketten-Starts via `AddJobView(vorgabeAufgabe:)`; die read-only Bundle-Palette bleibt Deko).
- Zusammengeführtes `main` **baut grün**. **Raphis MacBookAir gezogen** (war auf #177, 11 PRs zurück → jetzt `537517a`). **9 alte lokale Branches aufgeräumt** (Inhalt in main verifiziert), nur noch `main`.

**🔴 OFFEN / nächste Schritte:**
- **Montag: Rohbau-Angebot Setiadji.** Die Baustelle liegt in der App (LV aus `~/Desktop/BV Setiadji-Artanti Retzbach/LV-Skelett-Setiadji.x83`, 12 Positionen, „Mops fass" gelb, auf dem Canvas). Noch: **Stammdaten-Preise** eintragen (Betonstahl 3,50 €/kg fertig verlegt · SHB-Schotter ab Werk 7,90 · Ytong 24 cm PPW2/0,35 · Vath RC-Schotter), **Baustelleneinrichtung** (Pauschale) + **Boden-Deponiepreis** (BK2, ~15–20 €/m³ — **NICHT** Vath: Vath = Bauschutt-Annahme, kein sauberer Boden), dann **Angebot exportieren** (X84/PDF). Ehrlich im Angebot: „Rohbau nach Planauswertung — Rest nach fertiger Werkplanung".
- **Bepreistes LV-Skelett-Dokument** (Herkunfts-Ampel ✓belegt/~Schätzung/✗fehlt): Artifact + `~/Desktop/BV Setiadji-Artanti Retzbach/LV-Skelett-Setiadji.html`. Kern (Erdbau+Beton+Bewehrung) ~14,4k, +Mauerwerk ~16k, Restgewerke nur Grobkennwerte.
- **Hauslage-v1** am iPad im **Griff-Test** fühlen (Zoom/PDF-Ausrichten); danach evtl. 2-Punkt-Präzisions-Ausrichtung, Flurstück hervorheben, Abstandsflächen.
- **SketchUp-Brücke:** Raphi soll „Generate Report" mit **Volume + LenX/Y/Z** exportieren (seine Komponenten-/Layer-Namen tragen Geschoss+Bauteil+Dicke+Güte — top; nur die Mengen fehlten). Sein Modell hängt wegen des **163-MB-Gelände-Netzes** → Gelände in eigene Datei/gröber (1-m-Konturen, Skimp). Nächste Bögen: **Stammdaten-CSV-Import** (Lieferantenlisten en bloc), **Palette-Drop-Rückkanal** (Bundle meldet Drop → Auftrag), **Import-Upsert** (Re-Import aktualisiert statt dupliziert), SketchUp-Live-Plugin (`~/XcodeProjects/mops-scetchup`, FAKE-Modus).
- **Vath** als Lieferant: `~/Desktop/Lieferanten-Preise/Vath-Recycling-Preisliste-2026.csv` (−20 % eingerechnet), noch nicht in Stammdaten (kein Massen-Import → von Hand). [[lieferanten-landkarte-goldschmitt]]
- Fremde `docs/material-stammliste.csv` liegt unversioniert im Repo (nicht von mir; unangetastet).

## Delta 18.09.2026 (Abend II) — Geländebrücke: geparkter Schritt „Hauslage platzieren" fertig (footprint) · Insel-Duplikate raus · Batch-Doku-Extraktion durchleuchtet · Setiadji-Ordner sortiert

**Branch `feature/hauslage-footprint`, gebaut + getestet (455 Tests grün), NICHT gepusht.** Andreas testet den Griff-Feel am iPad, dann Push/PR + PR #185 schließen (sein OK). ⚠️ Diese Doku liegt auf dem **Branch**, nicht auf `main` — reitet beim Merge mit (sonst auf main cherry-picken).

**Prozessfehler zuerst (ehrlich):** Ich hab morgens Erdaushub-DXF/Baugrube/„Plan abgreifen" NEU gebaut (PR #184 gemergt, #185 offen) — **ohne Kühlhaus-Check**. Die „Geländebrücke (Welle 7)" (`EventDetailView.geländeCard`) macht DXF→Box-Cut/Fill längst. Andreas' echtes Problem war nie fehlender Code: **die Architektin liefert das Haus NIE in der DXF, nur auf dem PDF** — und der Schritt „Hauslage platzieren" (`HauslagePlatzierenView`) war ein **halbfertiger Stummel** (zeigte nur das Grundstück). Klappte genau einmal (Haus in der DXF), danach nie. Konsequenz: Insel-Duplikate raus, den echten Stummel fertig gebaut.

**Gebaut:**
- **`HauslagePlatzierenView` fertig** (Welle 7, Schritt 2b): Grundstück laden → **Haus-Rechteck** (L×B eingeben, antippen = Mitte, Winkel-Regler) → Ecken in **UTM** als `footprint` an `/gelaendebruecke/calculate` → `GelaendeResult` zurück in die Karte (Aushub/Schotter/LKW + „ins LV" + PDF-Report). Plus **Zoom/Pan** (3 Modi Ansicht/Plan/Haus) + **PDF-Lageplan als Hintergrund** (nach Augenmaß: schieben/pinchen/drehen + Transparenz) — v1; Präzisions-2-Punkt-Ausrichtung ist „später". Verdrahtet im `EventDetailView`-Sheet (`fixOkbp` durchgereicht, `onErgebnis` setzt `gelaendeResult`, löscht Fehler, schließt Sheet). `app_bedienung.yaml` `App_Hauslage_Platzieren` auf den fertigen Ablauf umgeschrieben.
- **Box kann das schon (live bewiesen):** `/gelaendebruecke/calculate` nimmt Form-Feld `footprint=[[x,y],…]` (UTM), Vorrang vor dem Haus im DXF (`mops-api api/routes/gelaendebruecke.py:176-222,312-374`). A/B an echter Setiadji-DXF: ohne footprint → 422 „kein Haus"; mit 8×9,5-Rechteck + OK-BP 196,10 → **76 m², Abtrag 72 m³, Schotter 43 t, 12 LKW**. **Kein Backend-Bau nötig.**
- **Insel-Duplikate entfernt** (aus #184): `Service/VermessungDXFLeser.swift`, `Service/Baugrube.swift`, `Views/BaugrubeRechnerView.swift` + `BaugrubeTests`/`VermessungDXFLeserTests` + die Knöpfe in `ErdmassenView` (XYZ-Weg bleibt). **PR #185 (PlanAbgreifen/PlanMass) NICHT mergen → schließen.**

**Verifiziert gegen die echten Pläne** (Grundriss EG + Schnitt): **Haus 8,00×9,50 m (76 m²), EFH=RFB=196,10 müNN, Garage RFB 194,26**. Das 3D-Artefakt/„Codi-Papier" hatte diese Werte per **Sichtkontrolle** (stimmen), aber die **Gelände-Kalibrierung dort ist Fantasie/unnötig** (rät `grundstück 35×30`, `hoehe 193,80–201,20`, `haus_position`) — die echte Vermessungs-DXF hat **UTM**, die Box kalibriert automatisch. 3D nur als **Seh-Hilfe** wert, gefüttert aus verifizierten Zahlen, nie hartkodiert. [[echte-dxf-3d-volumenmodell]]

**DXF-Falle (gemessen gegen `/grundstueck`):** `alkisdaten_utm32.dxf` = ALKIS-**Kataster**, KEINE Höhen (422). `Geländemodel …clean.dxf` = **keine Höhen** (422, normiert/rausgeputzt). Nur die **Bestands**-DXF trägt Höhen: `V4181…Bestand.dxf` = **72 Höhenpunkte** (189,5–201,2 m); Schwarz=150, Schmidt=91. **Immer die …Bestand.dxf laden, nie clean/alkis.**

**Batch-Doku-Extraktion („Ordner rein, Skripte lesen alles") — durchleuchtet, warum vor Monaten gestockt** (Sucher-Beleg): Die pragmatische Version existiert (`TuerSortierView`+`DateiSortierer`, sortiert PDFs **nach Dateiname** in statik/fakten/ablegen; `/extract-doc` kennt 4 Doctypes: Bodengutachten, Wohnfläche, B-Plan, Erschließung). **Gestockt weil:** (1) der schlaue inhaltliche Router `/extract-auto` nie gebaut („OFFEN"), (2) Klassifizierung schwach (12/15 „auto", 2 falsch), (3) Fakten hängen in der Luft — nur **Erschließung→LV** ist angeschlossen (`AuswertungLVMapper`), Rest `default: return []`, (4) **CAD läuft komplett dran vorbei** (nur PDF; DXF geht über Geländebrücke/Wandleser), (5) leeres Claude-Guthaben (lief auf gpt-4.1), (6) „Folgerung tarnt sich als Fakt". **Empfehlung: NICHT den generischen Router wiederbeleben** — jede Datei an ihren **geprüften** Leser routen (DXF→Geländebrücke, Statik→`/extract-plan`, die 4 Doctypes→`/extract-doc`) und die Fakten **anschließen** (B-Plan-Abgrabung→Geländebrücke-Check, Bodengutachten→Aushub/Verbau).

**Setiadji-Ordner sortiert** (`~/Desktop/BV Setiadji-Artanti Retzbach/`, 51 Dateien): `01_Architektur`(9) `02_Lageplan`(1, „Das Haus auf dem Grundstück.pdf" = die PDF-Draufsicht für die Hauslage) `03_Vermessung-CAD`(2) `04_Statik-Bewehrung`(18) `05_Beauftragung`(7) `06_Lieferscheine`(1) `99_NICHT-Setiadji`(13). **Der Download war ein Haufen** — 99 enthält ein **Fremdprojekt „Hofmann Waldenhausen"**, Preislisten (Stammdaten), Demo-GAEBs, Fotos. **Fehlt in DIESEM Download:** Bodengutachten, B-Plan, Erschließung (die lagen in der Voll-Mappe `~/Desktop/mopsss/BV-Setiadji-Artanti_LV`). **TCC-Falle:** Terminal kann `~/Documents` nicht lesen („Operation not permitted", Festplattenvollzugriff fehlt) — `~/Desktop` geht; iCloud-Ordner müssen erst lokal geladen sein („Jetzt herunterladen").

**🔴 OFFEN:** (a) Hauslage-v1 am iPad im **Griff-Test** (Zoom/PDF-Ausrichten fühlen; sitzt das Haus?); dann **Push + PR** (Andreas' OK) + **PR #185 schließen**. (b) **2-Punkt-Präzisions-Ausrichtung** PDF↔DXF (v2), eigenes Flurstück hervorheben, Abstandsflächen, Warnung wenn Haus aus dem Höhen-Bereich ragt. (c) Doku-Fakten **anschließen** statt nur anzeigen (der eigentliche Hebel der Ordner-Auswertung). (d) SketchUp „Steine malen", Xella/Mauerwerk verdrahten (aus Vor-Deltas).

## Delta 18.09.2026 (Abend) — Echte Preise im Mops: BKI-Orakel gefüllt · SHB-Materialpreise (dein Wert) · Preis-Check · Firma-Transfer (Stammdaten+Settings zu Raphi). Lieferanten-Landkarte geklärt

**Alles gemergt (PR #179–#182), Firma-Transfer offen als PR #183.** Riesentag: von der Dichte-Brücke früh bis echten Lieferantenpreisen abends. Die Kette schließt sich: LV → Lohn + Maschine + Material, alle Einheiten über den MopsUmrechner, Material mit ECHTEN Zahlen, BKI als Orakel daneben.

**Gebaut & gemergt heute (Reihenfolge):**
- **PR #179 Einheiten-Brücken:** Dichte m³↔t (`DichteKatalog`), Herkunfts-Zeile (Tiefenkalkulation zeigt „Aus dem Katalog vorbepreist"), Maschinen-Brücke (Bagger+Walze aus `maschinen_keys`, Park vor Miete), Material-Brücke + Lager (Schotter-Link + Richtpreis).
- **PR #180 `MopsUmrechner`:** die EINE Leiter `Länge—(Höhe)→Fläche—(Dicke)→Volumen—(Dichte)→Masse`; Lohn/Maschine/Material rechnen alle darüber; löst die Schalung (m→m²). [[einheiten-leiter-mopsumrechner]]
- **PR #181 Schalung + Bettung + BKI-Orakel:** Schalung = Vorhaltung (Gerät, €/m²·Einsatz) + Schalöl (Material), KEIN Schüttgut (`VorhaltungLink`); Bettung zeigt Splitt (Material-Link PFL-006/001); **BKI-Orakel** (`bki_marktpreise_2026.yaml`, `BKIMarktpreisKatalog`, `marktVergleichSection` — BKI-Spanne neben dem eigenen EP, `preisInPositionsEinheit` rechnet über die Leiter). Andreas hat **BKI Neubau gekauft** (RF Main-Tauber 1,027, netto) und die ersten Werte geerntet (STR-002=19, ERD-005=21, PFL-002=46, PFL-003=149, PFL-004=50 €). Loader nimmt Ø allein (Spanne optional). [[bki-orakel-marktpreise]]
- **PR #182 Preis-Check + Preisspiegel + SHB:** `StammdatenCheckView` (Ampel 🟢 dein Wert / 🔵 Richtwert / 🔴 offen; Knopf in Stammdaten-Pflege); `materialPreis` nimmt jetzt den GÜNSTIGSTEN Lieferanten (Preisspiegel); Edelsplitt-Link auf **t** + eigene Dichte (SHB rechnet in t) via `MaterialLink.dichte`. **SHB-Preise eingetragen** (lokal, NICHT im Repo): Schotter 0/32 = 7,90 · Schotter 0/45 = 10,40 · Edelsplitt 2/5 = 11,80 €/t (Lieferant SHB Werbach), Ampel grün.
- **PR #183 (offen) Firma-Transfer:** `FirmaTransfer` (Export/Import Stammdaten + Firmensettings als `.json`-Datei, Upsert über id) + `FirmaTransferView` (`.fileExporter`/`.fileImporter`, Knopf „Firma teilen" in Stammdaten). Datei läuft über **Box/Tailscale** zu Raphi (keine Cloud, kein Repo — Datenhoheit). Tests: Round-Trip zwei Apps, Settings, Upsert.

**🗺️ LIEFERANTEN-LANDKARTE (Goldschmitt, geklärt heute):**
- **Würth** = Werkstatt/Wartung (Öl, Fett, Werkzeug) — für LV-Material ~nichts (nur 3 Bestellungen/Jahr).
- **Scharpegge** (Amorbach) = Bautenschutz-Spezialist (Abstandhalter/Drunterleiste S.141, Deckenrand-/Ringanker-/Sturzschalung, Abdichtung, Dämmung) — **kein Bulk**. Preisliste 2026/27 vorhanden (Artikelnr·Gebinde·Preis, netto Richtpreise; „Nachdruck nur mit Genehmigung" → NICHT ins Repo).
- **SHB / Schotterwerk Werbach** (SHB-Schotter.de) = **Bulk** (Schotter/Splitt/Sand/Mineralgemisch/FSS), netto €/t, **ab Werk** (Transport separat). Das ist die Quelle für die Tiefbau-Material-Links.
- **Xella (Ytong/Silka)** = Mauerwerk (Porenbeton+KS), netto €/m³, franko + Kranentladung, **+4,50 €/m³ Logistik/Energie draufrechnen** (nur dieser Lieferant). ~50 Varianten (125–259 €/m³ je Güte/WD). **NOCH NICHT verdrahtet** — Mauer-Bausteine (MAU-001…006) haben keinen Material-Link; wird gemacht, wenn eine echte Mauerwerk-Position kommt (dann das eine Produkt nennen → Link + Preis lokal).
- **KERN-EINSICHT:** In der Bauwelt veröffentlicht keiner Bulk-Preise (kommen auf Anfrage). Die ehrliche Quelle ist die **eigene Rechnung**. Der Mops wird Goldschmitts privates Preisgedächtnis. Preise NIE ins Repo (Kundendaten-Falle, [[keine-kundendaten-im-rag-repo]]).

**🔴 OFFENE BÖGEN:** (a) **SketchUp „Steine malen"** (Raphi malt Pflaster-Layout → Mengen → Mops-Positionen → Preis): verbinden, nicht neu — es gibt den Malmops-Spike `~/XcodeProjects/mops-scetchup` + den Verlegeplan-Leser; erst den Spike ansehen. (b) **Xella/Mauerwerk verdrahten**, wenn gebraucht. (c) **Varianten-Frage Wand-Schalung** (System/konventionell). (d) BKI-Fähigkeiten 2+3 (GELB-statt-ROT mit BKI-Mittel; Angebotsbewertung gegen max) — lohnt, wenn mehr BKI-Werte geerntet. (e) mehr Material-Links an Bausteine (Fleiß, sobald Position auftaucht). (f) ~9 alte lokale Feature-Branches aufräumen.

## Delta 18.09.2026 (Nachmittag II) — Mops lernt Schalung (Vorhaltung + Schalöl) · Bettung zeigt Splitt · BKI-Orakel vorbereitet (Markt-Vergleich)

**Branch `feature/mops-lernt-schalung`, gebaut+getestet, Andreas mergt im Browser.** Drei Stücke, alle nach dem „Katalog vor KI"-Muster.

- **Schalung ist kein Schüttgut** (Andreas' Punkt): sie ist wiederverwendbar → Hauptkosten neben dem Lohn sind die **Vorhaltung** (Miete/Abschreibung der Schalung, €/m² je Einsatz = Gerät), verbraucht wird nur **Schalöl** (Trennmittel = Material). Neu: `STLBBaustein.VorhaltungLink` + `schreibeVorhaltung` (Schalfläche aus der Positionsmenge über den MopsUmrechner → €/m²×Einsätze als pauschale Geräte-Zeile). `schreibeGeraetPauschal` verallgemeinert (Tag/m²/…). **BET-010** trägt jetzt Vorhaltung (5 €/m²·Einsatz) + Schalöl (0,35 €/m², über die Material-Brücke). Test: 115 m → Lohn + Vorhaltung 287,50 € (57,5 m²×5) + Schalöl.
- **Bettung zeigt den Splitt** (Andreas: „Splitt ist da, wird nicht angezeigt"): dem Baustein fehlte der Material-Link. **PFL-006 + PFL-001** tragen jetzt `material: Edelsplitt 2/5` (m³, 45 €/m³ Richtwert) + `geometrie.dicke_m 0.04` (fürs Lohn-Umrechnen m²-Aufwandswert→m³-Position).
- **BKI-Orakel vorbereitet** (Markt-Vergleich, KEINE Kalkulationsgrundlage): neu `Resources/Knowledge/bki_marktpreise_2026.yaml` (5. Wissens-YAML; meta + `marktpreise:` je STLB-Baustein-ID mit min/von/mittel/bis/max, `platzhalter: true` bis echte Werte da sind), `Service/BKIMarktpreisKatalog.swift` (Loader), `AutoKalkulationsService.preisInPositionsEinheit` (rechnet BKI-Preis über die Leiter in die Positions-Einheit, fairer Vergleich), `marktVergleichSection` in `LVTiefenkalkulationView` (BKI-Spanne neben dem eigenen EP + neutrale Abweichung „X% unter/über Markt-Mittel", Quelle + Platzhalter-Warnung). Zeigt nur, wenn ein Eintrag existiert.
- Tests: `BKIMarktpreisKatalogTests` (Laden + m³→t-Umrechnung), Schalung- + Bettung-Integrationstests, voller Preis-Pfad grün.

**🧭 ANDREAS' PLAN (BKI, entschieden):** BKI Baupreise Online Neubau (~99 €/Jahr, 14.000 Positionen, Regionalfaktor **Main-Tauber-Kreis**, 4 Wochen gratis testen). Er **erntet selbst** die Preise zu unseren ~92 STLB-Bausteinen (min/von/mittel/bis/max) und gibt sie mir → ich fülle `bki_marktpreise_2026.yaml`. Legal (Abo-Lizenz), nachweisbar (jeder Preis trägt seine BKI-Position), jährlich aktualisiert. **Drei Mops-Fähigkeiten** daraus: (1) Plausibilität ✅ (Anzeige gebaut: EP vs. Markt-Mittel), (2) GELB-statt-ROT mit BKI-Mittel als Startwert bei fehlendem Wert — OFFEN, (3) Angebots-/Preisspiegel-Bewertung gegen BKI max — OFFEN.

**🔴 OFFENE BÖGEN:** (a) **Preisspiegel für Material-Einkauf** (Andreas' Idee): mehrere Lieferanten je Material `{Lieferant, Preis, Einheit, Datum}` → günstigster als Vorschlag, Vergleich sichtbar. Quellen: Scharpegge-Preisliste (angefragt, ohne Preisspalte bisher!) + eine Alternativeinkaufsliste (wird erstellt). Knackpunkt: dasselbe Material über Lieferanten hinweg zusammenführen (Name normalisiert). (b) **Varianten-Frage Wand-Schalung** (System/konventionell) — bei Fundament fix, bei Wand relevant. (c) BKI-Fähigkeiten 2+3. (d) Material-Links an weitere Bausteine (Fleiß-Sache, sobald man auf einen ohne stößt).

## Delta 18.09.2026 (Nachmittag) — MopsUmrechner: EIN Umrechner (die Leiter) räumt die verstreuten Brücken auf + löst die Schalung (Höhe). Nächster Bogen: „der Mops lernt Schalung"

**Branch `feature/mops-umrechner`, gebaut+getestet, Andreas mergt im Browser.** Antwort auf Andreas' Frage „haben wir keine Vorlage für die t↔m³/m↔m²-Umrechnungen?".

- **`Service/MopsUmrechner.swift` (neu):** die eine Leiter `Länge —(×Höhe/Breite)→ Fläche —(×Dicke)→ Volumen —(×Dichte)→ Masse`. `umrechnung(von:nach:bruecke:)` liefert proFaktor + mengeFaktor + Klartext-Hinweis; gleiche Größenart über `EinheitenUmrechnung` (kein zweites Register); fehlt eine Sprosse → nil (Aufrufer flaggt). 3 Brückenmaße statt dutzender Sonderfälle; Länge↔Volumen (Graben), Länge↔Masse (Bewehrung), Fläche↔Masse = Ketten.
- **`AutoKalkulationsService` aufgeräumt:** Lohn, Maschine UND Material rechnen jetzt über den EINEN Umrechner (die alten `mengeFuerLeistung`/`proFaktorMitDichte`-Sonderpfade raus). Brückenmaße einmal in `brueckeFuer(pos)`: Dichte (`DichteKatalog`), Dicke + Höhe aus dem Text; Text gewinnt, sonst Bauteil-Richtmaß vom Baustein.
- **Neue Höhe-Sprosse (Länge↔Fläche):** `hoeheMeter`-Parser („h= 0,50 m", `\b` vor dem Kürzel gegen Fehlgriffe), + `STLBBaustein.hoeheM`/`dickeM` aus einem `geometrie:`-Block. Neuer Baustein **`BET-010 „Schalung Fundamente"`** (m², `schalarbeiten.schalung_fundament`, Richthöhe 0,5 m) → m(lfm)→m² Schalfläche, bepreist statt KI. **Live bestätigt:** Schalung 115 m → Lohn 2 Schalungsbauer 0,25 h/m, ~1.352 € (Herkunft „über Höhe 0,5 m (Richtwert, prüfen)").
- Tests grün: `MopsUmrechnerTests` (7), `STLBKatalogTests` (Schalungs-Baustein), voller Preis-Pfad ohne Regression.

**🔴 NÄCHSTER BOGEN: „der Mops lernt Schalung" (Andreas' Punkt — Schalung ist KEIN Schüttgut).** Die Schalung ist bisher nur mit LOHN bepreist (GELB, „Material fehlt"). Gemessen, was das Bau-Wiki schon hat:
- **`scharpegge_katalog.csv` HAT Schalung**, aber (a) **KEINE Preisspalte** (Kopf: `artikelnummer;name;kategorie;beschreibung;gebinde` → überall „kein Preis — du trägst ihn ein"), (b) nur **Schalöl/Trennmittel** (Z. 68–70, das Verbrauchsmaterial JEDER Schalung) + **verlorene Schalung** LOHR für **Decke/Ringanker/Sturz** (Z. 159–180) — **KEINE Fundamentschalung**.
- **`aufwandswerte.yaml` kennt die Varianten:** `schalung_fundament`, `schalung_wand_rahmenschalung` (System, wenig h), `schalung_wand_konventionell` (Bretter, viel h).
- **`maschinenkatalog.yaml` hat das Modell „pauschal_pro_einsatz"** (Betonpumpe Z. 443) — genau die **Vorhaltungs-Mechanik**, die die (wiederverwendbare) Fundamentschalung braucht.
- **Erkenntnis:** Schalung = **Lohn** (✅) + **Vorhaltung** der Schalung (Gerät, €/m² je Einsatz — FEHLT als Katalog-Eintrag) + **Schalöl** (Material, im Katalog aber ohne Preis). Kein einzelnes Schüttgut. **Plan:** Schalung als eigener Positionstyp — Variante fragen (System/konventionell/verloren) → Aufwand-Variante + Vorhaltung-Gerät + Schalöl-Material. Allgemeiner Querschläger: **Scharpegge-Katalog braucht Preise** (Stammdaten/Richtwerte), sonst bleibt „du trägst ihn ein" bei sehr vielen Positionen.

## Delta 18.09.2026 (Mittag) — Die Einheiten-Brücken: eine Position rechnet sich VOLLSTÄNDIG (Mann + Maschine + Material + Lager). Nächster Bogen: EIN zentraler MopsUmrechner (Leiter)

**Branch `feature/dichte-bruecke-m3-tonne`, 4 Commits + HANDOFF, gebaut+getestet, Andreas mergt im Browser.** Auslöser: der Leitsatz „Katalog vor KI, Einheiten sind der Engpass" — die Auto-Bepreisung füllte nur den Lohn, Material+Maschine blieben 0, weil die Katalog-Einheiten (h/m³, m³/h, m²/h) nicht an t-Positionen kamen.

- **Dichte-Brücke m³↔t** (`7f9ef81`): `DichteKatalog.dichte(fuer:)` (Schüttgut-Text→t/m³, bewusst eng: kein „beton"/„boden"), `EinheitenUmrechnung.proFaktorMitDichte`. In `AutoKalkulationsService.gelbAusRichtwert`: erst `proFaktor` (gleiche Größenart), dann Dichte-Brücke, sonst ehrlich „Einheit prüfen". Damit greift der Katalog (Schottertragschicht m³, mit Bagger+Walze) für Stadt-LVs in t.
- **Herkunfts-Zeile** (`8369e13`): `LVTiefenkalkulationView` behält den `bewerte`-Befund und zeigt oben „Aus dem Katalog vorbepreist" (grün) / „Einheit passt nicht" (orange) / „kein Treffer" (grau) + die Mops-Meldung. Beantwortet „wo sehe ich, dass der Katalog gegriffen hat?".
- **Maschinen-Brücke** (`2190180`): `gelbAusRichtwert` hängt die Maschinen der Kolonne an (aus `STLBBaustein.maschinenKeys` → `MaschinenKatalog`). **Park vor Miete:** passt ein eigenes `Geraet` (Name) → dein Abschreibungssatz (grün „dein Wert"), sonst Katalog-Mietpreis Tage-Modell (blau „Richtwert"/leihen). Maschinen-Leistung m³/h bzw. m²/h → Positions-t umgerechnet über Dichte (t→m³) und Schichtdicke (m³→m², aus „d= 10cm"); klappt nicht → ehrlich übersprungen. `EinheitenUmrechnung.mengeUmrechnen` (absolute Menge), `schichtdickeMeter`-Parser.
- **Material-Brücke + Lager** (`7fe9261`): `STLBBaustein.MaterialLink` (text, einheit, richtpreis, verschnitt) an STR-002 (Schotter 0/32, 20 €/t) + ERD-005 (Schotter 0/45, 18). `schreibeMaterial`: Menge = Positionsmenge in Handelseinheit (t↔m³ über Dichte); Preis **Stammdaten (KalkMaterial, grün) vor Katalog-Richtpreis (blau) vor 0€ (sichtbar „ergänzen")**. Lager-Stand über vorhandene `LeistungskatalogService.lagerBestand` → auf Lager / teils / bestellen. **Live bestätigt:** Schottertragschicht 175 t rechnet sich zu 2.872,51 € (Material 10 €/t „dein Wert" aus Stammdaten, Bagger+Walze je 1 Tag, 3 Mann).
- Tests grün: `EinheitenUmrechnungTests` (11, inkl. mengeUmrechnen/Dichte/Schichtdicke), `STLBKatalogTests` (Material-Link), `MopsFassTests` + `MaschinenKatalogTests` keine Regression.

**🧭 NÄCHSTER BOGEN — der EINE `MopsUmrechner` (Andreas' Frage: „haben wir keine Vorlage?").** Die Erkenntnis: alle Einheiten hängen an EINER Leiter, jede Sprosse ist ein geometrisches Maß:
`Länge —(×Höhe/Breite)→ Fläche —(×Dicke)→ Volumen —(×Dichte)→ Masse`.
Es sind NICHT dutzende Sonderfälle, sondern **3 Brückenmaße** (Höhe, Dicke, Dichte); Länge↔Volumen (Graben), Länge↔Masse (Bewehrung), Fläche↔Masse sind Ketten daraus. **Heute halb & verstreut:** `EinheitenUmrechnung` kann gleiche Größenart + Dichte-Sprosse; die Dicke-Sprosse steckt als Parser in `AutoKalkulationsService`, die **Höhe-Sprosse fehlt ganz** → Schalung (m→m² über Fundamenthöhe) fällt durch zu KI. Plan: EIN `MopsUmrechner`, der die Leiter läuft (von-Einheit, nach-Einheit, bekannte Brückenmaße → Faktor); Brückenmaße aus `DichteKatalog` + Text/STLB-Langtext (`{{hoehe_m}}`) oder einmal fragen. Dann fällt die Schalung von selbst raus, gleicher Code wie Schotter. **Konkreter Testfall:** „Schalung Fundamente" 115 m — Katalog HAT `schalarbeiten.schalung_fundament` (0,5 h/m², 2 Schalungsbauer) und sollte matchen, aber m²≠m ohne Höhe.

## Delta 18.09.2026 — Der zweite Arbeitsplatz „Büro": Station 3 (Tiefenkalkulation vorausfüllen + KI-Startwert mit Spanne + Export-Sperre) · Leitsatz „Katalog vor KI, Einheiten sind der Engpass"

**Auf `main`, jede Änderung einzeln gebaut+committet, NOCH NICHT gepusht** (Andreas mergt selbst im Browser). Vorlauf: PR #177 (Canvas-Runde) heute früh gemergt → `origin/main` = `ffa7598`; Raphis Mac gezogen + Testbau grün.

**Richtung (Andreas):** iMOPS soll BauSU aus der Firma tragen. **Paolo** = Baustelle (Bon-Prototyp), **Raphi** = Büro/LV, überfordert von der „monströsen" App. Lösung = **ein Motor, zwei Gesichter** (Rolle): Raphi kriegt sein LV-Gesicht (Prototyp „Raphis LV-Tisch"), der Rest wird versteckt, nicht gelöscht. Zwei antippbare Prototypen als Artifacts gebaut (Bon + LV-Tisch). Der Hebel gegen BauSU: **der Mops bepreist selbst, Raphi macht nur die roten** — dafür muss die Kalkulation einer Einzelposition einfach werden = **Station 3**.

- **Tiefenkalkulation öffnet vorausgefüllt** (`LVTiefenkalkulationView.onAppear` → `AutoKalkulationsService.vorfuellenWennLeer`): beim Öffnen legt der Mops seinen Vorschlag ein (wie „Mops fass" für die eine Zeile) — **nur wenn die Position leer ist** (`schreibeAufwandAusKolonne` löscht Lohn, würde sonst Hand-Eingetragenes überschreiben). Statt den „Rezept"-Assistenten (den Andreas wegklickt) fit zu machen, kriegt die direkte Maske das Hirn. Test grün.
- **KI-Startwert für rote Positionen** (`marktpreis`/`leistungsSchaetzung` über den Prof): Knopf „🌐 Vom Mops schätzen lassen (KI)" → schätzt **Material UND Einbau (Lohn+Gerät)**. Neues Badge **`Kostenquelle.ki` = „KI geraten"** (lila): „Das hat die KI erfunden — ohne Quelle, prüfen, nicht glauben." **Export-Sperre:** `Ergebnis.enthaeltKI` + `Bilanz.kiUngeprueft` → `exportBereit` false, bis ein Mensch bestätigt (Quelle→„eigen") oder verwirft. Keine geratene Zahl geht unbemerkt an die Stadt. Tests grün.
- **Spanne statt Schein-Zahl** (Andreas' Idee): die KI würfelt sonst jedes Mal anders (Material lief 18/15/13/12) → jetzt Frage nach **MIN/MAX**, Arbeitswert = **Mitte**, Spanne sichtbar im Namen („KI-Schätzung: Schotter (10–25 €/t)"). `MopsKalkulationsHelper.Spanne`.
- **Einbau als Pauschale, nicht Schein-Stunden** (Andreas fand's beim Prüfen): die Stunden-Geräte-Zeile erfand „70 h / 1 t/h / ein Gerät", die die KI nie schätzte. Jetzt pauschaler Geräte-Posten „Einbau, geschätzt: X € für die Position".
- **Nebenfix in `bewerte`:** erkennt jetzt eine von Hand/KI bepreiste Position als bepreist (`bewerteVorhandenen`), statt sie ohne Rezept auf ROT zu werfen oder neu zu matchen.

**🧭 LEITSATZ (Andreas' wichtigste Erkenntnis heute): „Katalog vor KI, Einheiten sind der Engpass."** Der Katalog HAT Schottertragschicht (`aufwandswerte.yaml` + `stlb_bausteine.yaml` STR-002, m³, MIT Kettenbagger+Walzenzug) — aber Stadt-LVs kommen in **t**, und m³↔t ist ohne **Dichte** nicht umrechenbar → `EinheitenUmrechnung` flaggt „nicht umrechenbar" → rot → KI-Raten. Das Wissen fehlt NICHT, die **Einheiten-Brücke** fehlt.

**🔴 OFFENE BÖGEN:** (a) **Dichte-Brücke m³↔t für Schüttgüter** (Schotter ~1,9 t/m³ …, als Spanne/Richtwert) — damit der Katalog für t-Positionen greift statt KI (Memory [[dichte-bruecke-schuettgueter]], DER nächste). (b) **Ergebnis-Spanne** (Gesamt zeigt X–Y; braucht min/max als echte Daten). (c) **Umstände-Idee** (Boden/Homogenbereich, Wetter, Zugang → Spanne einengen, „geraten" → „begründet"). (d) **Raphis Büro-Gesicht** wirklich bauen (Rolle → nur LV-Ablauf, Rest verstecken; redundante Import/Export-Türen aufräumen — es gibt 4 GAEB-Import- und 2 X84-Export-Türen mit uneinheitlicher ROT-Sperre). (e) Mac-Zwei-Spalten-Layout — Andreas: „nicht umbauen", liegt still. **Parallel/persönlich:** „Wächter für Andreas" (`~/waechter/`, Totmann-Knopf, Notruf über iPhone) — mit Raphi mittags testen; Memory [[waechter-fuer-andreas]].

## Delta 17.09.2026 (Abend) — Canvas wird der zweite Arbeitsplatz: Knoten-Preise, Gesamtrechnung (aufmachbar), Markierung, Positionen bleiben, Verbinden, Einheiten-Fix, Löschschutz+Undo, Bau-Mops-Gruß

**Alles auf `main`, jede Änderung einzeln gebaut+committet.** Commits: `0634cb6` (Gesamtrechnung), `fc5365e` (Mops-Gruß), `467853a` (Knoten-Preise + Animation), `ff5474f` (Markierung), `8a36552` (Positionen), `91f6ce5` (Verbinden), `352e55b` (Rechnung aufmachen), `9ecdb3c` (Einheiten-Fix), `966f7eb` (größere Handles), `186b91a`+`0b64c1a` (Löschschutz+Undo). Auslöser: Andreas — der Canvas ist nach dem LV das meistgenutzte Stück; „langsam alles mit dem Mops verbinden". Am Gerät bestätigt („läuft sauber").

- **LVView-Knopf toggelt** (`c76b0cb`): „Auf den Canvas holen" → nach dem Anlegen „Canvas ansehen" (öffnet Grap8View direkt, spart 8 Klicks). EventDetailView-Toolbar-Knopf wieder zurückgebaut.
- **Gesamtrechnung unten rechts im Canvas** (`CanvasRechnungBox`, `Grap8View` ZStack-Overlay): Material+Lohn+Gerät = Selbstkosten, dann Aufschläge, = Netto-Gesamt der ganzen Baustelle; „?" erklärt BGK/AGK/W&G in Klartext. Motor: neu `LVKalkulator.gesamtAufschluesselung(positionen:)` (summiert `kalkulationFuer` über `zaehlbarePositionen`; Test `ElementKalkulationTests.gesamtaufschluesselungSummiertSichAuf` beweist: Teile = Ganzes).
- **Preis je Knoten** (`Grap8Graph.titelMitPreis`): jedes Kästchen trägt „Name · 8.700 €" (Preis der LV-Position dahinter) → Ausreißer auf einen Blick. Angehängt an den **Titel** (der `kg`-String speist ein Dropdown → unberührt lassen).
- **Gemeinsame Markierung** (`Grap8View.auswahlStil`, WKUserScript-`<style>`): angeklickter Knoten = oranger Ring + heller Hintergrund, sein rechtes Detail-Panel dieselbe Farbe + orange Kante → „wo arbeite ich gerade". Injiziert per CSS `!important` (Bundle ist kompiliert; Panel-`<aside>` hat keine Klasse → Element-Selektor, evtl. enger ziehen falls was Falsches färbt).
- **Positionen bleiben gespeichert** (`8a36552`): Canvas ist keine Einbahnstraße mehr. `Auftrag.posX/posY` (optional Double, additive Lightweight-Migration, Test grün); `Grap8Graph` nimmt gespeicherte Position, sonst Auto-Layout; **Rückkanal** `Grap8View.positionsRueckkanal` (WKUserScript: pointerup nach echtem Ziehen → liest Flow-Koords per DOMMatrix → `postMessage{action:'positionen'}`); Coordinator-Fall `positionen` löst je Kennung den Auftrag auf und speichert (nur bei echter Änderung). Test `Grap8PermanentIdTests.gespeichertePositionWirdBenutzt`.
- **🐶 Bau-Mops-Gruß** (`Views/MopsGruss.swift`): 1-Sek-Laufanimation aus Andreas' rigged GLB (`bau-mops … Walking.glb`), im Browser zu 28 transparenten PNG-Frames gerendert (kein Blender/ffmpeg → headless Chrome + three.js, `Resources/MopsGruss/`, ~1,1 MB). Trottet nach links (passt zur Beinbewegung). Hook `MopsGruss.winke()` (eine Zeile) + Root-Lauscher `.mopsGrussLauscht()` (RootTabView) + `.mopsGrussBeiErscheinen()` (Canvas). Verdrahtet: Canvas-Öffnen, `ImportedFileHandler` (Einlesen), `SKPConversionService` (Umwandeln). Memory [[mops-gruss-animation]].
- **Knoten von Hand verbinden** (`91f6ce5`, `Views/KnotenVerbindenView.swift`): neuer Toolbar-Knopf „Verbinden" → nativer Dialog (zwei Aufträge: „was zuerst / was danach") legt eine `Voraussetzung` an; die Kante zeichnet die Leinwand von selbst (Kanten kommen aus `Voraussetzung`). Bestehende Verbindungen gelistet + per Wisch lösbar. Nutzt `Kausalkette.verknuepfe/entknuepfe` (Zyklus-Schutz), nichts neu erfunden. Nativ, weil das Bundle read-only ist. Test `Grap8PermanentIdTests.verknuepfteAuftraegeErgebenEineKante`.
- **Rechnung aufmachen** (`352e55b`): Material/Lohn/Gerät in der Canvas-Rechnung sind antippbar → `KostenHerkunftView` listet die Positionen dieser Kostenart, größte zuerst, mit Menge+Einheit. Motor `LVKalkulator.kostenbeitraege(positionen:)`. So findet man Ausreißer. Andreas' Anlass: eine Lohnsumme von 335.887 €, nicht nachvollziehbar.
- **🔴→✅ Einheiten-Fehler gefixt** (`9ecdb3c`): der Bewehrungs-Ausreißer. Aufwandswert steht als **h/t** (`aufwandswerte.yaml` bewehrung_stabstahl/matten), Position rechnet in **kg** → `AutoKalkulationsService.gelbAusRichtwert` setzte 15 h/t als 15 h/kg an = **Faktor 1000** zu hoch (Betonstabstahl 123.441 € statt ~123 €). Neu `EinheitenUmrechnung.proFaktor(von:nach:)` (Masse/Volumen/Länge/Fläche, schreibweisentolerant) rechnet vor dem Schreiben um; passt die Größenart gar nicht → **nicht bepreisen, flaggen** („Einheit prüfen"). Tests `EinheitenUmrechnungTests` (5). **⚠️ schon importierte LVs tragen den alten Lohn noch — erneutes „Mops fass" rechnet sie neu.**
- **Verbindungspunkte 50% größer** (`966f7eb`): React-Flow-Handles 6px→9px (Andreas: zu klein). Über dieselbe Style-Injektion.
- **🛟 Löschschutz + Rückgängig** (`186b91a`+`0b64c1a`): Andreas hat mit einem Knopfdruck ein Kästchen (Auftrag) gelöscht — ohne Netz. Jetzt (1) `.alert`-Abfrage im `AuftragRowView`-Kontextmenü mit Folgenbenennung (NICHT `.confirmationDialog` — versteckt am iPad „Abbrechen", siehe [[destructive-delete-safety]]); (2) `viewContext.undoManager` (Persistence.swift, nach den Migrationen, Tiefe 30) + **„Rückgängig"-Knopf & ⌘Z** in `EventDetailView` (`rueckgaengig()`) macht jede letzte Änderung/Löschung rückgängig. Test `LoeschUndoTests`.
- **Bedienungshilfe** nachgezogen: `app_bedienung.yaml` neuer Eintrag `App_Grap8_Canvas` (Preis/Rechnung/Markierung/Positionen).

**🔴 OFFEN / als Nächstes:** (a) **Copy-Paste** — Andreas' Wunsch 17.9.: Kästchen/Positionen kopieren & einfügen (Auftrag duplizieren; evtl. auch LV-Positionen). Noch nicht gebaut. (b) **Umbenennen auf der Leinwand** bleibt noch nicht (hängt am Preis-im-Titel). (c) **Mannschaft/Maschine pro Knoten** fehlt im Modell (Auftrag↔Ressource-Beziehung; heute nur baustellenweit). (d) „Pausiert" (onHold) hat kein Canvas-Gegenstück (braucht Frontend-Neubau des Bundles). (e) Verbinden-Dialog ist eine Liste — später evtl. das Ziehen DIREKT auf der Leinwand (braucht die React-Quelle des Bundles). Bestandsaufnahme des ganzen Canvas-Stapels (DA vs. FEHLT) steckt im Session-Verlauf.

## Delta 17.09.2026 — Nordstern-Bögen gemergt: Gelände→Aushub→Bagger→Brigade + Verlegeplan-Leser + Firmenprofil-Übersicht

**Alles auf `main` (`485ec8e`), volle Suite grün (411 Tests / 69 Suiten). NOCH NICHT gepusht** (Push tippt Andreas selbst, `! git push`; Rollback-Tag `pre-merge-nordstern`).

Fünf Stücke, in einer Session gebaut, getestet, gemergt (Feature-Branches danach gelöscht):
- **A — Katalog-Miete wird echte Kostenzeile** (`MaschinenKatalog`, `RezeptAssistentView`): der Maschinen-Vorschlag ist antippbar (Häkchen) → beim Speichern schreibt `Maschine.mietAlsGeraetzeile` das Tage-Miet-Modell verlustfrei als `PositionGeraet` (stunden×satz), landet im Einheitspreis EK+VK.
- **B — Brigade über die Bauzeit** (`BrigadePlanung`, `EventDetailView.brigadeCard`): `verteilung(arbeitstage:)` + `arbeitstageZwischen(Mo–Fr)` streckt die Rollen-Manntage über `eventStartTime→eventEndTime` → „Ø N Leute/Tag, mind. M im Team nötig" je Rolle. KEINE erfundene Abfolge (das wäre Bauablauf-Topologie = Bogen 3).
- **Bogen 2 — Verlegeplan-Leser** (`Service/VerlegeplanLeser.swift`, `VerlegeplanLeserView` + Karte): OFFLINE-DXF-Leser für Pflaster-VERLEGEPLÄNE (nicht Wände): Fläche aus INSERT-Steinzählung × Maß im Blocknamen (`39x19_5x8cm`), Randsteine als Stück, Schotter/Splitt-Layer als Aufbau-Hinweis. An echter `Testhofeinfahrt.dxf`: 100,3 m². **FALLE:** Swift sieht `\r\n` als EIN Grapheme → CRLF erst normalisieren, sonst wird eine echte DXF gar nicht in Zeilen zerlegt.
- **Bogen 1 — Erdmassen Cut & Fill** (`Service/Erdmassen.swift`, `ErdmassenView` + Karte): DGM1-Höhenraster gegen Planum → Abtrag/Auftrag/Massenausgleich (mittlere Höhe = Cut=Fill) + DGM1-XYZ-Parser. Der Abtrag = Aushub → läuft durch die vorhandene Kette `MaschinenPlanung`→Bagger→A→B. Braucht echte DGM1-XYZ (Box-Fetch-Pipeline).
- **C — Firmenprofil-Übersicht** (`Views/FirmenprofilUebersichtView.swift`, NavigationLink in `SettingsView`): zwei Spalten Goldschmitt|Mops·Echtzahl, Zeilen Lohn/Material/Geräte → **Selbstkosten (fett, sichtbar gemacht)** → Rechnung. Goldschmitt-Lohn über Verrechnungssatz=Orakel (`firma_verrechnungssatz_orakel` 74), Lücke zu den Kosten (44,40) = Firmenzuschlag; Mops = Selbstkosten + FirmenSettings-Zuschläge. Editierbares Beispiel.

**Die Kette schließt sich:** aus einer Adresse/Zeichnung → Mengen (Bogen 1/2) → Preis mit echten Rollen + Maschinen-Miete (A) → Personalbedarf über die Bauzeit (B). C macht den Selbstkostenpreis sichtbar.

**🔴 OFFEN:** (a) Bogen 3 = Ablauf/Terminplan (`Bauablauf`-Topologie + `BauzeitenplanView`-Gantt auf echte Event-Daten + Brigade — alles vorhanden, nur verbinden). (b) Bogen 4 = „Mops-Spion in SketchUp" (Ruby-Extension mit Mops-Icon, redet über Tailscale mit der Box, schreibt LV-Info als Bauteil-Attribut → Zeichnung trägt die Wahrheit selbst; Memory `mops-spion-sketchup-plugin`). (c) LV-Eintrag-Kalkulation (`LVTiefenkalkulationView`) verständlicher machen — die „Rechnung mit Zahl hinten" hat für Andreas keine klare Bedeutung auf den ersten Blick (Einheiten). (d) INTENSO-Platte per macOS-TCC gesperrt → Terminal braucht Festplattenvollzugriff.

## Delta 16.09.2026 (Spätabend) — Langtext klappbar + Bausteine + Raphael pullt (PR #172); Firmenprofil GEPARKT

**Auf `main` (PR #172, `8784fa2`):**
- **📄 LV-Langtext klappbar** an jeder Position — im „Mops fass"-Review (`MopsFassReviewView`) UND in der LV-Liste (`LVPositionRow`). Volle Leistungsbeschreibung (Tiefe/Boden/Verbau) auf der Baustelle, Text markierbar. (In der Review-Zeile wandert der Rezept-Tap auf die Kopfzeile, damit er den Klapp-Klick nicht schluckt.)
- **+13 STLB-Bausteine / +6 Aufwandswerte**, an einer ECHTEN Goldschmitt-Ausschreibung geprüft (`LV-Ausenanlage.d81`, GAEB 90): Bewehrung (Betonstab/-matten, neue Sektion `bewehrung`), Abbruch (Asphalt/Pflaster/Unterbau/Einbauteile), Fundamentbeton, PE-Folie, Bettungs-/Verfugmaterial, Schnittfuge, Poller + Fahrradbügel (neue Sektion `ausstattung`). Treffer auf dem LV: **8 → 19**. Zwei Fehlgriffe gefixt (Asphalt/Betonpflaster landeten auf falschem Baustein). Stand: **115 Aufwandswerte, 107 Bausteine**, alle mit auflösbarem Key.
- **d81-Erkenntnis:** GAEB-90-Import (`GAEB90Importer`) parst `.d81` über die `sieht90Aus`-Heuristik (Endungsliste kennt nur d83/d84); Kurztext=Satzart 25, OZ/Menge=21, Langtext=26. Läuft.

**🅿️ GEPARKT — Firmenprofil (Goldschmitt ↔ Mops), NICHT auf main:** `Service/Firmenprofil.swift` liegt **lokal untracked** auf Andreas' Mac, kompiliert, aber **noch nicht verdrahtet**. Ziel: Umschalter „echte Firma (Goldschmitt, Lohnsatz-ZG1 = 74 €/h) ↔ Mops (neutrale Tarif-Defaults)", damit man an denselben Daten sofort vergleicht, „an welcher Schraube gedreht wird". `bruttoEK`/`schreibeAufwandAusKolonne` müssen noch profil-fähig werden; die Stundenlohn-Positionen „Meister/Facharbeiter" (Regie, kein Baustein) hängen genau daran. **Nächster Schritt: fertig verdrahten + Settings-Toggle + Sofort-Vergleich.**

**Raphael zieht jetzt selbst:** sein MacBook Air (Tailscale, `ssh raphis`) pullt das PRIVATE Repo über einen **read-only Deploy-Key** — Details in Memory [[raphael-mac-zugang-deploykey]]. Xcode war ok (Yams-Package war nur ungelöst); das eigentliche Problem war HTTPS-Remote ohne Login → jetzt SSH.

**Testlauf-Fallen (wichtig):** iMOPS nutzt **Swift Testing** (Ausgabe `◇`/`✔`/`✘`, NICHT „Test case") + volle Suite parallel crasht bei wenig Platte → immer `-parallel-testing-enabled NO`.

## Delta 16.09.2026 (Abend) — Text→Rezept DETERMINISTISCH: STLB-Bausteine + Kataloge + Rollenpreise (PR #171)

Der eigentliche Durchbruch: aus dem KI-Raten wird eine nachvollziehbare Kette. **An 10 echten Ausschreibungen (109 Positionen): 95% erkannt UND bepreist** (vorher 66%).

**Die Kette:** Position → **STLB-Baustein** (`STLBKatalog.finde`, Match über kurztext + `tags` die Synonyme tragen) → `aufwandswert_key` → **`AufwandswerteKatalog.eintrag(key:)` deterministisch** → `maschinen_keys` → `MaschinenKatalog.maschinen(ids:)`. Der Baustein trägt auch den **X83-Langtext** (fertig für Export).

**Drei verzahnte Wissens-YAMLs** (alle in `Resources/Knowledge/`, kein Verweis ins Leere):
- `aufwandswerte.yaml` — 109 Richtwerte (min/mittel/max h je Einheit + echte **Kolonne**), öffentliche Quellen, KEINE geschützten ARH-Tabellen; +20 von Raffi (quelle „RAFFI" = firmeneigen, Vorrang).
- `maschinenkatalog.yaml` — 45 Maschinen (Leistung + Tagesmiete), verzahnt über `einsatz_bei`.
- `stlb_bausteine.yaml` — 94 Mops-eigene Textbausteine (KEINE lizenzierten STLB-Bau-Texte), jeder mit auflösbarem `aufwandswert_key`.

**Services (neu):** `BauTextMatcher` (gemeinsame Stichwort-Logik: Einzel-Vokal-Normalisierung + leichtes Plural-Stemming + Synonyme + Flächen-Nomen-Demotion), `STLBKatalog`, `AufwandswerteKatalog`, `MaschinenKatalog`. **Matcher matcht NUR den Titel** — an echten LVs erwiesen: der Langtext ist zu verrauscht (Füllwörter „seitlich"/„entsorgen" ziehen auf falsche Einträge). Lieber ehrlich ROT als selbstsicher falsch.

**Verdrahtet:** „Mops fass" (`AutoKalkulationsService.bewerte`) + Rezept-Assistent gehen ZUERST über den STLB; ROT→GELB mit echter Kolonne + Quelle, `finde()` (fuzzy) nur Fallback.

**Rollenpreise:** Aufwandswert wird nach der Kolonne nach Kopfzahl auf die Rollen verteilt und je Rolle mit ihrem Tarif bepreist — **Baggerfahrer→Maschinist, Helfer→Helfer, Rest→Facharbeiter** (`LeistungskatalogService.parseKolonne`/`tarifgruppe`/`schreibeAufwandAusKolonne`; `bruttoEK` rollenfähig, per Lohnsatz-Stammdaten überschreibbar). Rohrgraben 0,30 h/m: statt ~14,11 €/m (alles Maurer) jetzt ~11,73 €/m. Gesamtstunden unverändert.

**Tests:** 389 / 65 Suiten grün. ⚠️ Testlauf-Fallen: iMOPS nutzt **Swift Testing** (Ausgabe `◇`/`✔`/`✘`, NICHT „Test case") + volle Suite parallel crasht bei wenig Platte → `-parallel-testing-enabled NO`.

**🔴 OFFEN:** (a) Rest-5% ROT = Matcher-Edge-Cases (Komposita „Außenwandmauerwerk", Kurz-Tokens „WC"/„NYM") — lösen sich beim Match per **STLB-Nummer**, wenn die Aufträge die IDs tragen. (b) **Maschine-pro-Tag-Preismodell** (Miete wird pro angefangenem Tag abgerechnet, nicht €/h) — Katalog schlägt vor, eigener Park hat Vorrang. (c) Rezept-Assistent zeigt die echte Kolonne, sein manueller Preis nutzt aber noch die zwei Felder Maurer/Helfer (nicht Kolonne-gesplittet) — Angleichen optional. (d) GAEB menschenlesbar bei „Pläne & Unterlagen". Repo bleibt PRIVAT.

## Delta 16.09.2026 (Nachmittag) — alles GEMERGT auf `main`, Repo ist PRIVAT

**Repo auf PRIVAT gestellt** (Andreas' Entscheidung) — DSGVO an der Wurzel gelöst (Preise/Rezepte dürfen jetzt auf `main`). Ehrlich: schützt künftig, macht die frühere öffentliche Phase nicht rückgängig.

**Gemergt (alle PRs zu, 0 offen):** PR #165 (Übergabe, Konflikt aufgelöst), PR #168 (Mops fass + Assistent + Brücke), PR #169 (Fixes + Lesbarkeit). `main` = alles.

- **Fix (PR #169):** `MopsFassReviewView` zeigte leere Ampel (0/0/0) trotz Positionen → `State(initialValue:)`-Anti-Muster; jetzt `let ergebnisse` + Overlay-Map `updates`. **Merke: keine `@State(initialValue:)` aus einem Sheet-Parameter seeden — zeigt stale leere Momentaufnahme.**
- **Rezept-Assistent lesbar:** Schritt 1 Zeit-Briefing („Für 320 lfm: 32 Std Maurer + 96 Std Helfer = 128 Mannstunden; Dauer hängt an der Kolonne (Brigade)"). Schritt 2 Material-Zeile: „im Katalog · dein Preis" (`materialPreis`), „auf Lager/bestellen" (neu `LeistungskatalogService.lagerBestand` = Name→`CDLexikonEntry.code`→`LagerStore.gesamtbestand`), „🌐 Markt-Orientierung (KI)" (neu `MopsKalkulationsHelper.marktpreisVorschlag`, über den Prof). **Regel dahinter (Andreas): offline-first ist eine BAUSTELLEN-Regel, keine BÜRO-Regel — Kalkulation/Angebot passiert online im Büro vor Baustellenbeginn; Markt-Preis klar als „KI-Schätzung", kein erfundener Marktpreis.**
- **LV-Eintrag-Kalkulation (`LVTiefenkalkulationView`):** Einheit hinter jeder Zahl (`€/lfm`) + „geplant X Std" in der Summenzeile.

**🔴 OFFEN / nächste Schritte:** (a) Andreas hat ein „da fehlt ein Knoten im Kopf, etwas stimmt noch nicht ganz"-Gefühl bei der Kalkulation/Mannstunden — noch nicht greifbar, dranbleiben. (b) generische Rollen „Maurer/Helfer" sauber benennen (bei Rohrgraben ist's Baggerfahrer/Facharbeiter). (c) „🌐 Markt-Preis übernehmen → in die Stammdaten (KalkMaterial) schreiben". (d) Assistent soll Positionen wie „Rohrgraben DN 400" ERST erklären + Tiefe/Boden fragen. (e) GAEB menschenlesbar bei „Pläne & Unterlagen". (f) mops-engine Python-Port (Codi-Auftrag) — Spec ist grün geprüft (Dateien/Formeln stimmen), ABER: Testdaten-Pfad ist Sandbox (echte Fixtures nutzen), und `mops_fass`/Katalog ist NICHT pure Mathe (braucht Store-Design). Orakel-Manifest bauen als Vorarbeit.

## Delta 16.09.2026 — „Mops fass" + Rezept-Assistent + LV↔Canvas-Brücke — Branch `feature/material-preise-zentral`

Der komplette Kalkulations-Bogen: **GAEB rein → auf den Canvas → Knoten kalkulieren (Rezept entsteht) → „Mops fass" wird grün → X84 raus.** Alles auf dem vorhandenen Motor (`LeistungskatalogService.autoMatch` + `LVKalkulator`) — KEIN neuer Rechenkern (die Opus-Spec wollte 500 Zeilen `berechneEP`/`versucheMatch`/`einheitspreis` — gibt's so nicht; Kühlhaus-Check hat's gefangen).

**Commit 1 (`97600af`):** `Service/AutoKalkulationsService.swift` (`fass` → Ampel-Diagnose GRÜN/GELB/ROT, `Bilanz`+`exportBereit`), `Views/MopsFassReviewView.swift` (Ampel + „was fehlt" + X84-Export via `GAEBExporter`, gesperrt bis ROT==0), Integration in `GAEBImportView` (X83-Import → Auto-Review). `MopsFassTests`.

**Commit 2 (dieser Batch):**
- **`Views/LVView.swift`** — „🐕 Mops fass" + „Auf den Canvas holen" als Knöpfe **oben in der LV-Liste** (Andreas' Wunsch: eine Ebene über der Einzel-Kalkulation). Review als `.fullScreenCover` (mehrere `.sheet` in LVView präsentierten nicht zuverlässig).
- **`Service/LVCanvasBruecke.swift`** — Brücke LV ↔ Grap8-Canvas, **beide Richtungen**, idempotent über die vorhandene Beziehung `Auftrag.lvPosition`. `lvAufDenCanvas` / `canvasInsLV`. Pflichtfelder gesetzt (`statusRawValue`,`storageNote` — sonst crasht `save()`). Knopf in `Grap8View` (⋯-Menü „Knoten ins LV übernehmen"). `LVCanvasBrueckeTests` (3).
- **Rezept-Assistent `Views/RezeptAssistentView.swift`** — geführt, Schritt für Schritt, Küchensprache: Mops **schlägt vor, User bestätigt/korrigiert**. Zeit (Prof-Vorschlag, offline→Erfahrungswert) · Material (Preis aus Stammdaten) · **Gerät = Auswahl aus dem Maschinenpark** (`Geraet.kostenProStunde`). Startet aus jeder 🔴/🟡-Zeile der Review; Zeile wird danach grün. Speichert über neu `LeistungskatalogService.speichereRezept(...)` (Aufwandswert + Material + Gerät → Position + Baustein gelernt). Test in `MopsFassTests`.
- **`Views/MopsVorschlagSheet.swift`** — Reiter-Umschalter raus, **eine Ansicht, nur Aufwandswert** (die einzige Frage, die echte Zahlen liefert; Material-Alt/Positionstext lieferten generischen KI-Rohtext → aus der UI raus, Helper-Methoden bleiben im Code). Zeigt **pro Einheit UND Gesamtzeit** (× Menge).

**Stand:** volle Unit-Suite grün (16.9.), App-Build SUCCEEDED. Beide Commits auf `feature/material-preise-zentral`, **lokal** — Andreas pusht + merged selbst.
**🔴 OFFEN / nächste Schritte:** (a) der Assistent soll Positionen wie „Rohrgraben DN 400" **erst erklären + die fehlenden Fragen stellen** (Tiefe/Boden aus dem Plan) statt gleich nach Stunden — Andreas' großer Wunsch, noch offen. (b) **Bei „Pläne und Unterlagen" das eingelesene GAEB menschenlesbar anzeigen** (das LV, mit dem auf der Baustelle gearbeitet wird — die Positionen als lesbare Liste, nicht das rohe XML). Andreas' Wunsch 16.9. (c) Integrationstest mit echten `.x83`. (d) vorbestehender flaky `RechnungPDFExporterTests` beachten.

## Delta 15.09.2026 (Nacht) — Rezepte für den Matcher (Ytong + Tiefbau), Goldschmitt-Fotos

**Branch `feature/ehrliche-kalkulation`** — Commits `0a8ac59` (Ytong), `f0b17cf` (Tiefbau). **LOKAL, NICHT gepusht** (Nachtschicht — Andreas entscheidet wach). Beide Suiten grün.

Damit der Auto-Match beim GAEB-Import wirklich Preise setzt, brauchen die Positionen **Rezepte** (Leistungsbausteine mit Menge Material/Gerät je Einheit). Ein Rezept hat 3 Zutaten: **Menge** (Tabelle/Foto) · **Aufwandswert** Lohn h/Einheit (Prof/KI, Folgerung) · **Preis** (gerätelokal, Stammdaten).

- **`Service/YtongBedarf.swift`** — öffentliche Ytong-Bedarfswerte je m³ (Steine Stück/m³ + DBM kg/m³ je Wanddicke 5–48 cm, aus Foto IMG_0348). `seedIfNeeded` legt je Wanddicke einen Baustein „Mauerwerk Ytong X cm" (m³) an, Material-Menge fest, **Preis 0**. Idempotent, überschreibt Lohn nicht. `YtongBedarfTests` (4).
- **`Service/TiefbauRezepte.swift`** — die 8 Hofeinfahrt-Leistungen (Oberboden/Aushub/abfahren/Schotter/Splitt/Trennvlies/Pflaster/Randstein). Material-Mengen = **Richtwerte** (Verschnitt/Verdichtung), Bagger-Stunden aus `Erdbauleistung`. **Lohn 0 + Preis 0 bewusst** (Aufwandswert steht in keiner Tabelle). `TiefbauRezepteTests` (5). `iMOPSApp` seedet beide im Start-Lauf.
- **DSGVO sauber getrennt:** Ytong-Mengen/Artikel-Nummern = öffentliche Xella-Daten (Code ok). **Goldschmitts Preise + „Gerhard Goldschmitt Bau GmbH"/Bernd Goldschmitts Telefon** (auf Fotos IMG_0350/0353) = vertraulich → nur Stammdaten, device-lokal. Fotos liegen unter `~/Desktop/goldschmitt-fotos/` (nicht im Repo).
- **🔴 OFFEN / nächster Schritt:** der **Aufwandswert** (Lohn h/Einheit) ist der Engpass bei fast jedem Rezept — kommt per Prof/KI (`MopsKalkulationsHelper`, markiert als Schätzung) oder Andreas' Erfahrung. Erst dann liefert ein Rezept einen echten Preis. Dazu: die € je Material/Stunde in den Stammdaten.
- **⚠️ FLAKY TEST (vorbestehend, NICHT durch diese Arbeit):** `RechnungPDFExporterTests/ibanOhneBanknameGenuegt` fällt im vollen Target GELEGENTLICH (Race auf geteilte `UserDefaults.standard` zwischen FirmenSettings-Tests; allein + im 2. Lauf grün). Sauber wäre, die FirmenSettings-berührenden Test-Suiten zu serialisieren/isolieren — bewusst NICHT nachts unbeaufsichtigt gemacht.

---

## Delta 15.09.2026 — GAEB, Matcher, Angebot-Button, Lehrling-Spiel (Branch gepusht)

**Branch `feature/ehrliche-kalkulation`** — bis `09c090d` **auf GitHub gepusht** (verifiziert). Volles Unit-Target grün.

- **GAEB-Import komplett:** DA XML (X83/X84) an echter Datei belegt (`GAEBImportTests`), **GAEB 90 (.d83/.d84) NEU** (`Service/GAEB90Importer.swift`, Festspalten-Zeilenformat, cp850/1252, an Andreas' echter `.d83` belegt). `GAEBImporter.parse` ist Weiche XML↔90. Erreichbar über neue Karte **„GAEB einlesen"** im Import-Katalog (EventDetailView `gaebCard`). Picker-Bug gefixt (security-scoped Zugriff schloss zu früh → betraf ALLE Mac-Importe). Commits a7d6b2c, 53e56de, 8a13633.
- **Matcher (Text→Rezept→Preis):** `LeistungskatalogService` war schon da (via graphify gefunden — Beleg für „verbinden statt erfinden"). Lücke 1 `autoMatch(position:in:)`: beim GAEB-Import findet eine Position ihr gelerntes Rezept → Preis via `LVKalkulator`; kein Treffer = bewusst OHNE Preis (keine erfundene Zahl); ehrliche Import-Bilanz. Lücke 2: `Leistungsbaustein.rezeptJSON` (neues optionales Attribut, Lightweight-Migration) trägt jetzt auch **Material + Gerät** → voller Positionspreis; Ernte in `KnotenKalkulationView`. Commits dd27780, 582506f. Tests `GAEBAutoMatchTests` (6). **Modell-Falle:** aktive Version = `test25B 2.xcdatamodel` (mit Leerzeichen!).
- **„Angebot an Kunden"-Button** im Planer (HouseConfiguratorView): Kunden-Sheet → PDF mit Logo/Briefkopf (`AngebotPDFExporter`) → per Mail (`MailComposeView`, ein Wrapper) oder Teilen-Fallback. Commits 85fdcf4, 68786ae.
- **Lehrling-Spiel IM Mops** (aus Andreas' Ausbildungsspiel „Der junge Hering"): (1) Warm-up **„Reihenfolge sortieren"** — gemischte Aufträge in Bauablauf-Reihenfolge ziehen, geprüft gegen die **Kausalkette** (`Service/Bauablauf.swift` = eine Wahrheit für Liste UND Spiel; `EventDetailView.bauablaufRang` nutzt sie jetzt); Überspringen erlaubt; `WarmupStore` pro Baustelle+Tag. (2) **Baufragen-Quiz** (`Service/Baufragen.swift`, 12 Fragen 1. Lehrjahr; `BauQuizView`). Karten in „Gewerke & Ausführung". Tests `BauablaufTests` (3) + `BaufragenTests` (3). Commits d548b09, 09c090d.
- **Nordstern-Review** (die 3 fehlenden Verbindungen): heute alle angefasst — (a) Import-Brücke durch (GAEB+WandLeser+JSON), (b) Mannstunden existieren, nur CrewPlanning-Nachfrage offen, (c) `Erdbauleistung` gebaut, nur `Geraet.leistung`-Feld + Einsatzplan offen. Memory `nordstern-zeichnung-zu-baustelle` aktualisiert.
- **🔴 DSGVO:** Commit `164fa00` (Trennvlies = Raphis realer Li 5,11) wurde **bewusst mitgepusht** — Andreas hat am 15.9. informiert so entschieden (RaphaelStammdatenSeeder ist eh schon auf origin/main). Der offene „3. Fall" bleibt seine Entscheidung.

---

## Delta 14.09.2026 — Auftrag „Material prüfen" (Wareneingang) in der Kausalkette

**Branch `feature/ehrliche-kalkulation`** (PR #166), Commit `40f4d80`. Volle Suite grün (clean).
Der Materialcheck ist jetzt ein **zugeteilter, belegter Auftrag** statt eines passiven Hakens.
- `HofauffahrtSeeder`: Schritt 11 „Material prüfen (Wareneingang)" — Kette
  **bestellen → prüfen → Tragschicht** (Einbau wartet auf die Prüfung). Checkliste =
  geplante Materialien als `AuftragLineItem` mit `vorhanden` (da/fehlt) + Nachweis
  (`geprueftVon`/`geprueftAm`); die Oberfläche dafür hat `AuftragDetailView` schon.
- **EINE Wahrheit:** `materialCard` SPIEGELT den Prüf-Auftrag (grün „geprüft"), eigener
  Toggle raus. Match über den Materialnamen (Katalog-Name = LineItem-Titel).
- Eine Material-Quelle im Seeder: `HofauffahrtSeeder.hofMaterialien` (Code/Name/Einheit/
  Bedarf) für Bedarf + Prüf-Checkliste + Pinnen. `materialPruefItems()` öffentlich.
- Bestehende Demos: `ruesteNach` legt Bedarf + Prüf-Auftrag nach (additive Kanten), kein Löschen.
- `EventExtrasPayload.materialGeprueft` ist damit ungenutzt (deprecated, harmlos).
- Tests: materialPruefenAuftragMitCheckliste, tragschichtWartetAufVliesUndPruefung; Counts 11/10.

---

## Delta 14.09.2026 — Polier-Materialliste (geplant · auf Lager · fehlt · vor Ort abhaken)

**Branch `feature/ehrliche-kalkulation`** (PR #166), Commit `5783bb3`. Build + volle Suite grün.
Korrektur nach Andreas' Bild: die „auf Lager"-Info hing an der Nebenliste (angepinnte
Katalog-Artikel). Sie gehört an DIE Liste, die der Polier vor Ort prüft — die **geplanten
Materialien** der Baustelle. `EventDetailView.materialCard` zeigt jetzt `extras.materialBedarf`
(Katalog-Code + Menge): je Zeile Name · „geplant X" · Lager-Status (auf Lager/teils/fehlt/
reicht, live) · **Haken „vor Ort da/prüfen"** (`extras.materialGeprueft`, OPTIONAL). Manuelle
Pins ohne Menge stehen als „Zusätzlich zugeordnet". `HofauffahrtSeeder` rüstet eine bereits
existierende Demo-Baustelle nach (setzt materialBedarf, wenn leer).
**Offen (Andreas' Nordstern hier):** die geplante Liste in Konfigurator/LV/Materialliste ist
noch mehrgleisig — echte Vereinheitlichung (ein Artikel-Schlüssel für LV-PositionMaterial +
Bestellung + Lager) ist die nächste Runde; Bedarf/Lager brauchen dieselbe Einheit.

---

## Delta 14.09.2026 — Materialliste bedarfsbewusst: „zu bestellen = Bedarf − Lager" (live)

**Branch `feature/ehrliche-kalkulation`** (PR #166), Commit `24c92d9`. Build + volle Suite grün.
Andreas' Wunsch: 250 Steine ins Lager → zu bestellende Menge sinkt live. Der Materialstatus
rechnet jetzt den **Bedarf** gegen den echten Lagerbestand.
- `EventExtrasPayload.materialBedarf` ([MaterialBedarf {code,menge,einheit}], **OPTIONAL**).
- `Materialstatus` (LagerStore) fünf Zustände: bestellt · **reicht** (grün, Fakt) · **teils**
  (Lager X · zu bestellen Y, orange) · **zuBestellen(Menge)** · aufLager (ohne Bedarf).
  zu bestellen = max(0, Bedarf − Lager). `materialCard` @ObservedObject LagerStore → live.
- `HofauffahrtSeeder`: Bedarf je Material (Betonpflaster PFL-VBS = **1294 Stk**).
- `DemoSeeder.seedLagerortDemoIfNeeded`: leerer Lagerort „Hof" (nur wenn keiner existiert).
- Tests: materialstatusMitBedarfRechnetZuBestellen (250→teils/1044, 1300→reicht), bedarfIstHinterlegt.

**Live-Test:** Hofeinfahrt-Demo → Materialien: „Betonpflaster · zu bestellen 1294 Stk".
Katalog → Lager → Buchen → 250 Stk PFL-VBS in „Hof" → zurück: „Lager 250 · zu bestellen 1044".
**Ehrliche Grenze:** Bedarf/Lager brauchen dieselbe Einheit (Stk gegen Stk); die LV-Position
rechnet in m² — der Bestellvorschlag ist bewusst getrennt, noch nicht verknüpft.

---

## Delta 14.09.2026 — Kleines Lagersystem (Bestand = Summe der Buchungen)

**Branch `feature/lager` → gefast-forwarded in `feature/ehrliche-kalkulation`** (PR #166),
Commit `3da01ff`. Build + LagerStoreTests (7) + volle Suite grün. Konform zu gängiger
Lagersoftware: **der Bestand ist die Summe der Buchungen, keine editierbare Zahl**
(= Tao). Migrationsfrei: Codable + JSON (`lager.json`), wie AngebotsStore — **kein
Core Data**. Artikel = Katalog-Eintrag (`CDLexikonEntry`) über den Code.
- `Service/LagerStore.swift`: `Lagerort`, `Buchungsart` (Eingang/Ausgang/Umlagerung/
  Inventur/Korrektur), `Lagerbuchung` (signierte Menge); reine `Lagerlogik` + Store
  (`init(fileURL:)` für Tests). Umlagerung = Buchungspaar, Inventur = Differenz aufs
  gezählte Ist, Meldebestand, Lagerort-Löschschutz solange Buchungen existieren.
- `Views/LagerView.swift` (Bestand · Nachbestellen · Lagerorte), `LagerBuchungSheet.swift`.
- `MaterialLexikonView`: „X auf Lager"-Badge + Einstieg „Lager" (Toolbar).
- **Materialliste (`EventDetailView.materialCard`): je Position Status-Chip — auf Lager
  (grün, echter Bestand) · bestellt (blau, tippbar) · zu bestellen (orange).**
  `bestellteCodes` in `EventExtrasPayload` **OPTIONAL** (sonst brechen die Backward-Compat-
  Blob-Tests — synthetisiertes Codable wirft keyNotFound bei nicht-optionalem neuem Feld).
- `Materialstatus.fuer(artikelCode:bestellt:store:)` kapselt die 3-Zustands-Logik.

**Bewusst offen (dockt an):** Barcode/Scan (BuildIQ), Chargen/Serien, Auto-Abbuchen bei
Bestellung/Verbrauch. Einheit kommt beim Buchen aus der letzten Buchung / Handeingabe
(CDLexikonEntry hat kein Einheit-Feld).

---

## Delta 14.09.2026 — Hofeinfahrt im Projekt-Konfigurator (2 Lücken behoben)

**Branch `feature/ehrliche-kalkulation`**, Commit `85ddb52`. Tests grün. Der Konfigurator
(`HouseConfiguratorView` → `ProjektGenerator`) KONNTE die Hofeinfahrt schon zeigen (vier
Reiter), aber:
1. `HofeinfahrtVorlage.generiere` setzte nie `wohnflaeche` → Header „0 m²" und **EUR/m² =
   Kosten ÷ 0 (NaN)**. Fix: Pflasterfläche als `wohnflaeche` + Div-Guard in der KPI.
2. „Als Baustelle anlegen" (`HouseProjectGenerator.createEvent`) pinnte nur Hochbau —
   `bekannteCodeMap` kannte kein Tiefbau → leere Materialliste. Fix: 4 Hofeinfahrt-Titel
   → Katalog-Codes (SCH-032/PFL-VBS/SPL-208/RND-TB).
Tests: `hofeinfahrtSetztDieFlaeche`, `konfiguratorHofeinfahrtPinntMaterial`.
**Offen (kosmetisch):** Ergebnis-Header zeigt für die Hofeinfahrt „0 Geschoss(e)" + Ausstattung
(Haus-Felder) — für Nicht-Haus-Typen ausblendbar.

**⚠️ BUILD-FALLE (wichtig):** Bei den **synchronisierten Xcode-Ordnern** lief der inkrementelle
`xcodebuild test` still eine ALTE Test-Bundle (nur 4 statt 6 Tests, „TEST SUCCEEDED" trotzdem).
Erst `xcodebuild clean` zog die neuen Tests. → Nach dem Anlegen NEUER Tests die Trefferzahl
gegenprüfen, nicht nur auf „SUCCEEDED" vertrauen.

---

## Delta 14.09.2026 — Hofeinfahrt-Material im Katalog + Materialliste gepinnt

**Branch `feature/ehrliche-kalkulation`**, Commit `89df575`. Build + Hofauffahrt-Tests (+3) grün.
Die Baustellen-Materialliste (`EventDetailView` → Materialien) zeigt **angepinnte
Katalog-Einträge** (`CDLexikonEntry`). Der Katalog kannte nur Hochbau → die Hofeinfahrt-Demo
konnte nichts pinnen, Liste blieb leer.
- `DemoSeeder`: 7 Tiefbau/Pflaster-Materialien (Kategorie „Tiefbau"), Codes zentral als
  `DemoSeeder.hofeinfahrtMaterialCodes`. Seeding jetzt **idempotent per Code** (nicht mehr
  „nur wenn leer") → bestehende Installs bekommen sie nach, keine Dubletten.
- `HofauffahrtSeeder.pinneMaterialliste`: pinnt die Codes ans Demo-Event.
- `EventDetailView`: Icon für Kategorie „Tiefbau".
- Tests: materiallisteIstGepinnt, katalogHatTiefbauMaterial, katalogSeedingIstIdempotent.

Merke: „Materialliste" = angepinnte `CDLexikonEntry` (Tab 4 Katalog), NICHT `PositionMaterial`
(LV) oder `AuftragLineItem` (Bestellung) — die füllte der Seeder schon.

---

## Delta 14.09.2026 — Normen-Spur: berührte DIN ambient im Baustellen-Canvas

**Branch `feature/ehrliche-kalkulation`**, Commit `4412cc9`. Build + 7 neue Tests grün.
**Nicht gepusht.** Andreas' Idee: die einschlägigen Bau-Normen einer Baustelle
blass/ausgegraut zeigen — ambient statt mahnend, zugleich Nachweis „arbeitet nach DIN".
Ehrliche Grenze: **„berührt" ≠ „erfüllt"** (UI trägt „keine Rechtsberatung").

**Gebaut:**
- `Service/Baunormen.swift` — Katalog (9 Normen) + `berührt(vonLeistungen:hatLV:)`:
  matcht Leistungstext (LV-Position ODER Checklisten-Aufgabe) per Stichwort auf die Norm,
  dedupliziert, Bauablauf-Reihenfolge. DIN 276 gilt sobald ein LV existiert. **Selbsttragend
  — braucht die YAML NICHT zur Laufzeit.**
- `Views/NormenSpurView.swift` — blasses Wasserzeichen (opacity .78, gestrichelt).
- `EventDetailView`: `normenSpurCard` im Leistungsverzeichnis.
- `…Tests/BaunormenTests.swift` (7 grün).

**✅ ERLEDIGT — YAML-Kollision aufgelöst (`din_normen.yaml`, Commit `0073544`):** Während
des Baus hatte eine zweite Instanz parallel dieselbe Datei bearbeitet (Dubletten
DIN_18299/18300, kombiniertes „18315_18318"). Andreas hat sie danach zur Kontrolle
freigegeben. Geprüft (python yaml): **25 Normen, valide, keine Duplikate**, jedes Feld
gefüllt, kein Norm-Volltext (lizenzsauber), deckt **alle 9 Spur-Normen** als Alias ab,
fachlich stimmig (18195 korrekt als zurückgezogen). Committet auf diesem Branch.

**Offen:** DIN-Nummern erforscht (Andreas = Koch) → von ihm/Raphi prüfen; Norm hängt bisher
am Leistungstext, später ggf. am LVBaustein.

---

## Delta 14.09.2026 — Ehrliche Kalkulation: Lohngruppen→Mittellohn + Aufschlag-Kette

**Branch `feature/ehrliche-kalkulation`** (von `feature/uebergabe-nachweis`). Build + die 4
neuen Tests grün. **Nicht gepusht.** Behebt den **74-Fehler**: die 74 €/h ist der
**Verrechnungssatz** (Ergebnis der Kette), NICHT der Lohn (~38 €/h Vollkosten). Saubere
Trennung Kostenseite / Angebotsseite, generisch — echte Firmenzahlen bleiben draussen.

**Gebaut:**
- `Service/Lohnkalkulation.swift` (NEU) — die Struktur:
  - `Lohngruppe.vollkosten = Brutto × Nebenkosten-Faktor` (was die Stunde KOSTET).
  - `Mittellohn.berechne(kolonne:…)` = gewichteter Vollkosten-Schnitt → der Lohnsatz je
    Mannstunde, der in die Positionen gehört (statt der 74).
  - `Aufschlagskette` (BGK·AGK·Wagnis&Gewinn·Skonto·MwSt): innen einzeln, **aussen als EIN
    vertraulicher `firmenzuschlag`** ausweisbar (Geschäftsgeheimnis). `nettoAngebot` /
    `bruttoAngebot`; `firmenzuschlag(ausVollkosten:verrechnungssatz:)` rückwärts fürs Orakel.
  - `LohnkalkulationDefaults`: nebenkostenFaktor 1,85; generische ZDB-Lohngruppen (LG1 17,00 …
    LG6 28,50, Platzhalter); Default-Kette (bgk 0,10 / agk 0,10 / w&g 0,08 / skonto 0,025).
- `Service/FirmenSettings.swift` (geändert) — Keys + Accessors `nebenkostenFaktor`, `agk`,
  `skonto` (dazu bgk/wagnisGewinn/mwst schon da) + `static var aufschlagskette` Builder.
  Die echten Firmenzahlen kommen HIER rein (UserDefaults), nie in den Code.

**Nachweis:** `…Tests/LohnkalkulationTests.swift` (4, grün):
- `vollkostenOrakel` — Brutto×1,85 = 31,45 / 38,85 / 52,73.
- `mittellohnOrakel_37_81` — Beispiel-Kolonne (1×LG6 + 4×LG4 + 3×LG1) → **37,81 €/h**.
- `ketteNettoUndBrutto` — firmenzuschlag 0,33947; netto 13.394,7 aus 10.000.
- `orakel74_istErgebnisNichtInput` — die Kette TRIFFT mit dem vertraulichen Firmenzuschlag
  exakt 74; generisch kommt ~52 raus. **Die Differenz ist Firmensache, nicht im Code.**

**Vertraulichkeit:** `.gitignore` sperrt jetzt `docs/lohnberechnung/` (Goldschmitt-Quell-Excel,
nur lesen) + `graphify-out/`. Nur Formeln + öffentliche Richtwerte im Repo.

**Gewinn-Schieber gebaut (14.9., Andreas' Idee):** `Views/GewinnSchieberView.swift` — die
EINE ehrliche Schraube „Wo verdient der Boss?". Links Vollkosten (fest), Mitte der
**Wagnis&Gewinn**-Schieber (Gewinn-only entschieden: BGK/AGK/Skonto fest, weil gemessene
Kosten), rechts der Verrechnungssatz live + die **74-Orakel-Linie** mit Lücke-Anzeige
(grün „passt" bei <0,50 €). Button **„Auf das Orakel einrasten"** rechnet den festen Teil
heraus und setzt den Gewinn so, dass der Satz das Orakel trifft → man liest den echten
Aufschlag ab (Zahl bleibt in FirmenSettings). Interne Aufschlüsselung fällt außen zu EINEM
„Firmenzuschlag" zusammen. Schreibt `Keys.wagnisGewinn`; Vollkosten + Orakel als eigene
Firmen-Config (`firma_vollkosten_referenz` / `firma_verrechnungssatz_orakel`, Default
generischer Facharbeiter / 74). Erreichbar per NavigationLink aus `SettingsView` (Zuschläge).
Build grün. Commit `a964d7f`.

**Bewusst offen:**
- **Schritt C** — den 74-Verrechnungssatz im `RaphaelStammdatenSeeder` (26,91×2,75=74) auf
  Vollkosten-Mittellohn umstellen. Hängt an der **offenen DSGVO-Leak-Bereinigung** (Raphis
  Preise im public Repo, Memo `keine-kundendaten-im-rag-repo` — Andreas entscheidet noch).
- **Integration** — den Mittellohn in die LV-Positionen ziehen; Aufschlagskette an
  `LVKalkulator` andocken.
- Deferred (Auftrag-GRENZE): Bauformeln/Auto-Menge, Maschinenpark-Sätze, Aufwandswerte.

Commits: `7dbc30d` (Kalkulation), `d58405f` (gitignore/CLAUDE.md). Backup HANDOFF: `.backup_…_ehrliche-kalk`.

---

## Delta 13.09.2026 — Leitstand Schritt 2: Auto-Menge (Größe → Menge)

**Branch `feature/auto-menge`** (von `main`). Build + Suite grün. **Nicht gepusht.**
Zweiter Leitstand-Schritt: der Katalog liefert den Aufwandswert (h/Einheit), die **Menge** kommt jetzt
aus der Baustellengröße (seit „Größe ans Event").

**Zuordnung über die EINHEIT** (nicht den Leistungsnamen): `m²/qm` → `Event.grundflaeche`, `m/lfm` →
`Event.umfang`. Alles andere (Pauschal, m³, Stück, kg …) ist nicht ableitbar → bleibt Handeingabe.
**Ehrlich:** eine so abgeleitete Menge ist eine **Schätzung** aus der groben Größe, kein Aufmaß — sie
wird als `mengenQuelle = .schaetzung` markiert (`istGeschaetzt` → in der App andersfarbig), damit sie
nie wie ein gemessener Wert aussieht.

**Gebaut:**
- `Service/MengenAbleitung.swift` — `ausGroesse(einheit:event:) -> Vorschlag?` (Menge + menschenlesbare
  Herkunft „Grundfläche"/„Umfang"). nil, wenn nicht ableitbar oder Größe fehlt.
- `KnotenKalkulationView`: beim Anlegen einer Position wird die Menge aus der Größe **vorgeschlagen**
  (Feld vorgefüllt + Hinweis „Menge aus Umfang (44 m) — geschätzt, anpassbar"); bei Einheit-Wechsel neu.
  Übernimmt man den Vorschlag unverändert → `.schaetzung`, sonst `.manuell`. Bei **Katalog-Pick** zieht
  sie die Menge zur Einheit des Bausteins nach → **Leistung + Einheit + Aufwandswert + Menge in einem
  Tipp** (der Fahrplan-Kern), für ableitbare Einheiten. Bestehende Positionen werden NICHT überschrieben.

**Nachweis:** `MengenAbleitungTests` (2, grün): Einheit bestimmt Herkunft (m²→Grundfläche, m/lfm→Umfang),
nicht-ableitbare Einheiten und fehlende Größe → nil. Build + volle Suite grün.
**Manuell:** Baustelle mit Maßen (Grundfläche/Umfang) → Grap8 → Knoten → Kalkulation → beim Anlegen steht
die Menge schon da (mit Herkunfts-Hinweis); Katalog-Baustein picken → Menge + Aufwandswert sitzen.

**Bewusst offen:** dieselbe Ableitung in `LVBausteinAuswahlView` (LV-Picker) — andockbar mit demselben
Helfer. Und m³ (Fläche × Tiefe) bräuchte ein weiteres Maß am Event.

Dateien: **neu** `Service/MengenAbleitung.swift`, `…Tests/MengenAbleitungTests.swift`; geändert
`Views/KnotenKalkulationView.swift`. Backup: keins nötig (nur additive Neu-Dateien + eine View).

---

## Delta 13.09.2026 — Leitstand Schritt 1: Knoten-Chips zeigen, was kalkuliert ist

**Branch `feature/grap8-knoten-zustand`** (von `main`). Build + Suite grün. **Nicht gepusht.**
Erster von drei Leitstand-Schritten (Chips → Auto-Menge → Rückkanal).

**Idee:** Die Leinwand soll auf einen Blick zeigen, was an einem Knoten schon steht und was fehlt.
Rein Swift, ohne die React-Quelle anzufassen — nur der Inhalt, den `Grap8Graph` schon durchreicht.

**Gemessen (aus dem React-Quelltext `~/Projekte/grap8-canvas/src/App.jsx`, nur GELESEN):** die Leinwand
rendert pro Knoten `base` (Status; startklar/wartet leitet sie selbst aus den Kanten ab — das lief schon)
und `anf` (Chips). `anf`-Contract: `{typ, erfuellt}`, `typ` ∈ {material, mensch, maschine, bestellung,
freigabe}, `erfuellt:true`=geplant (voll), `false`=offen (gestrichelt). Bisher schickte Swift `anf: []`.

**Gebaut:** `Grap8Graph.anforderungen(auftrag)` füllt jetzt drei Chips aus der EIGENEN Position des
Knotens (`Auftrag.lvPosition`): **Material** = hat `kalkMaterialien`, **Mannschaft** = hat `kalkLohn`
(der Aufwandswert!), **Maschine** = hat `kalkGeraete`. Kein eigener LVPosition → alle drei offen.
→ Auf der Leinwand sieht man: welcher Knoten schon Lohn/Material/Gerät trägt (voller Chip) und welcher
noch leer ist (gestrichelt). Der Aufwandswert-Fluss lässt den Mannschaft-Chip zugehen.

**Bewusst NICHT gefüllt:** `bestellung` + `freigabe` — dafür gibt es (noch) kein sauberes Signal am
Auftrag; lieber weglassen als raten. Andockbar, sobald Bestellliste/Abnahme am Knoten hängen.

**Nachweis:** `Grap8PermanentIdTests.chipsSpiegelnDieKalkulation` (grün): ohne Position alle Chips offen;
mit Lohn ist Mannschaft erfüllt, Material/Maschine offen. Build + volle Suite grün.
**Manuell:** Grap8 → Baustelle mit kalkulierten Aufträgen → die Knoten tragen die Chips; einen Aufwandswert
übernehmen → der Mannschaft-Chip des Knotens wird voll.

Dateien: `Service/Grap8Graph.swift`, `…Tests/Grap8PermanentIdTests.swift`. Backup in `_backups/grap8-knoten-zustand_*`.
## Delta 13.09.2026 — Nativer „+ Auftrag" im Grap8-Fenster (neuer Knoten = echter Auftrag)

**Branch `feature/grap8-neuer-auftrag-nativ`** (von `main`). Build + Suite grün. **Nicht gepusht.**

**Warum:** Ein Knoten, den man IN der Leinwand zeichnet, ist nur React — er wird nie in Core Data
gespeichert (gemessen: das Bundle sendet an Swift nur `ready` + `verwaltung`, KEINE „angelegt"-Nachricht;
die Swift-Brücke behandelt auch nur diese zwei). „Im Canvas zeichnen = Auftrag" bräuchte die React-Quelle
(Andreas sucht sie). Bis dahin: **nativ daneben** — ein echter Auftrag aus demselben Fenster.

**Gebaut:** In `Grap8View` ein Werkzeugleisten-Knopf **„+ Auftrag"** (erscheint, sobald eine Baustelle
gewählt ist). Tipp → die bestehende `AddJobView` (Name/Vorlage/Sichern) an der aktuellen Baustelle →
speichert einen echten `Auftrag`. Beim Schließen des Blatts steigt ein Zähler `aktualisierung` →
`updateUIView` schickt der schon geladenen Leinwand den Graphen **neu** (`grap8SetGraph`, kein Vollreload
→ Zoom bleibt) → der neue Knoten erscheint, mit permanenter ID, sofort kalkulierbar.

**Plumbing (klein):** `Coordinator.eltern` `let`→`var` (damit `updateUIView` den frischen Graphen
einspeist), `schickeGraph()` `private`→`fileprivate`, neuer `aktualisierung: Int` an `Grap8WebView`,
`updateUIView` schickt bei gestiegenem Zähler neu.

**Nachweis:** Build + volle Unit-Suite grün (inkl. `Grap8PermanentIdTests` — keine Regression an der Naht).
**Manuell:** Grap8 öffnen → Baustelle wählen → oben rechts **„+"** → Auftrag anlegen + „Sichern" → der
Knoten erscheint auf der Leinwand → antippen → „Kalkulation" (kein Crash) → Vorschlagsliste/Prof.

**Offen:** echtes „im Canvas zeichnen = Auftrag" (Rückkanal Leinwand→Core Data) braucht die `Grap8Web`-
React-Quelle. Der Refresh schickt den GANZEN Graphen neu — falls React Flow dabei die Ansicht zurücksetzt,
wäre ein gezielteres Nachschieben (nur neue Knoten) der nächste Feinschliff.

Dateien: `Views/Grap8View.swift`. Backup in `_backups/grap8-neuer-auftrag_*`.

---

## Delta 13.09.2026 — Katalog-Vorschlagsliste am Knoten (nativ, ohne die React-Leinwand)

**Branch `feature/knoten-katalog-vorschlaege`** (stapelt auf `fix/grap8-temp-objectid`, damit der
Flow ohne Crash testbar ist). Build + Tests grün. **Nicht gepusht.**

**Warum:** Andreas erwartete beim Tippen eines Knoten-Namens („Baustelle einrichten") eine Auswahlliste.
Die Leinwand ist ein kompiliertes React-Bundle — dort geht kein Autocomplete ohne die Web-Quelle.
Entscheidung (Andreas): **nativ daneben** bauen (er sucht die Web-Quelle separat).

**Gebaut:** In `KnotenKalkulationView` (öffnet sich vom Knoten-Tap → „Kalkulation") steht jetzt oben eine
**Auswahl-Liste „Aus dem Katalog wählen"** — die gelernten `Leistungsbaustein`, passende zum Knoten-Text
zuerst, dann die häufigsten. Ein Tipp legt die Position an (falls nötig), übernimmt Einheit + Aufwandswert
(Maurer/Helfer-Stunden) und zählt eine Verwendung — ohne Prof-Frage. Ersetzt den früheren Einzel-Treffer.
- Ranking liegt jetzt im Service (`LeistungskatalogService.vorschlaege(fuer:limit:in:)`), nicht in der View.

**Nachweis:** `LeistungskatalogTests.vorschlaegeStellenPassendeNachVorn` (grün): passender Baustein steht
vor dem häufigeren-aber-unpassenden; ohne Text häufigste zuerst; Limit greift. Build + volle Suite grün.
**Manuell:** (setzt den Crash-Fix voraus) Knoten anlegen → Kalkulation → wenn der Katalog schon Einträge
hat, steht die Liste da → tippen füllt die Kalkulation. Beim allerersten Mal ist der Katalog leer → Prof
fragen (füttert ihn).

**Grenze/offen:** Autocomplete DIREKT im Canvas-Textfeld braucht die React-Quelle von `Grap8Web`
(Andreas sucht sie). Auch die Standard-Bausteine (`LVBausteinKatalog`) könnten hier später mit rein.

Dateien: `Views/KnotenKalkulationView.swift`, `Service/LeistungskatalogService.swift`,
`…Tests/LeistungskatalogTests.swift`. Backup in `_backups/knoten-vorschlaege_*`.

---

## Delta 13.09.2026 — FIX: Grap8-Absturz auf temporärer Core-Data-ID (blockte den Test)

**Branch `fix/grap8-temp-objectid`** (von `main`, das jetzt die 5 gemergten Stücke trägt). Build +
Tests grün. **Nicht gepusht** (Freigabe abwarten).

**Symptom (am Objekt gefunden):** neuen Grap8-Knoten „Baustelle absichern" anlegen → Verwaltung/
Kalkulation öffnen → Absturz: `NSInvalidArgumentException: The specified URI is not a valid Core Data
URI: n-…`.

**Wurzel (gemessen):** `obtainPermanentIDs` wurde NIRGENDS gerufen. Ein frisch angelegter, noch nicht
gespeicherter `Auftrag` hat eine **temporäre** objectID (`n-…`); `Grap8Graph.kennungen` schickte deren
`uriRepresentation()` an die WebView, und beim Zurück-Auflösen wirft
`managedObjectID(forURIRepresentation:)` eine **ObjC-Exception**, die `guard let`/`try?` NICHT fangen →
Crash. Latenter Bug in der bestehenden JS↔Swift↔Core-Data-Brücke, nicht in Bogen 0.

**Fix (zwei Schichten):**
- **Schicht 1 — Wurzel** (`Grap8Graph.aus`): bevor die objectID-URIs zu Knoten-Kennungen werden,
  `ctx.obtainPermanentIDs(for: auftraege)`. Damit ist jede Kennung ein `x-coredata://…`-URI, kein `n-…`
  — heilt ALLE Round-Trips über die Kennung an einer Stelle.
- **Schicht 2 — Sicherheitsnetz** (`Grap8View.auftrag(zu:)`): vor dem werfenden Aufruf `url.scheme ==
  "x-coredata"` prüfen. Eine temporäre/kaputte URI gibt jetzt `nil` statt zu werfen.

**Nachweis:** `Grap8PermanentIdTests` (grün): ungespeicherter Auftrag hat temporäre ID → nach
`Grap8Graph.aus` permanent, und die Knoten-Kennung beginnt mit `x-coredata://`. Build + volle Suite grün.
**Manuell (Andreas):** neuen Knoten → Verwaltung/Kalkulation → kein Absturz; Aufwandswert-Test läuft
weiter bis zum Lohnsatz-Check.

Dateien: `Service/Grap8Graph.swift`, `Views/Grap8View.swift`, **neu** `…Tests/Grap8PermanentIdTests.swift`.
Backups in `_backups/grap8-temp-objectid_*`.

---

## Delta 13.09.2026 — Vom Haus-Generator zum Projekt-Generator (kleiner erster Schritt)

**Branch `feature/projekt-generator`** (abgezweigt von `feature/katalog-sichten-und-event-masse`).
Build grün, neue Tests grün. **Nicht gepusht, kein PR.**

### 🧭 STRUKTUR-VORSCHLAG (bitte nicken, bevor der nächste Bogen groß wird)
`ProjektTyp` sitzt **über** `Haustyp` als oberste Kategorie: ein Projekt ist entweder ein Haus (trägt
einen `Haustyp`, läuft **1:1 unverändert** über den bestehenden `HouseProjectGenerator`) oder eine kleine,
firm-typische Baustelle (erste: Hofeinfahrt). Das Dach ist `ProjektGenerator.generate(typ:haus:flaeche:)`,
das für **jeden** Typ denselben `HouseProjectResult` zurückgibt — dadurch bleiben die vier Reiter
(Kosten/Material/Massen/Zeitplan) und der Bauphasen-Plan **komplett unverändert**, nur der Inhalt skaliert.
Ein Typ „trägt seine Vorlage", indem sein Zweig Massen+Phasen(+Material+Kosten) erzeugt (heute: als Code
in `HofeinfahrtVorlage`; **nächster Bogen**: als Bündel echter `Leistungsbaustein` aus dem Katalog, plus
Maß-Herkunft je Leistung für die Auto-Menge). **Eine bewusste Schuld:** `HouseProjectResult.project` ist
noch ein `HouseProject` — die Hofeinfahrt füllt davon nur `projektName` (Rest ungenutzt, im Header/`createEvent`
unsichtbar). Ein späterer Schritt ersetzt das durch einen schlanken Projekt-Deskriptor. **Kein Abriss:**
der Haus-Generator ist unangetastet, die kleine Vorlage kam daneben.

### Gebaut (kleiner Schritt, wie beauftragt)
- **`Service/ProjektTyp.swift`** — Enum über Haus-Familie (4) + `hofeinfahrt`; `istHaus`/`hausTyp`/`anzeige`.
- **`Service/ProjektGenerator.swift`** — das Dach: Haus-Typen → `HouseProjectGenerator` (unverändert);
  `hofeinfahrt` → `HofeinfahrtVorlage`. Letztere erzeugt aus der Pflasterfläche Massen (Baustelleneinrichtung ·
  Erdarbeiten · Unterbau · Randeinfassung · Pflaster — Goldschmitts echte Titel), 4 Bauphasen, Material und
  Kosten (in `aussenanlagen`). Zahlen = Richtwerte, kein Aufmaß.
- **`Views/HouseConfiguratorView.swift`** — Projekt-Typ-Picker oben; für Häuser das volle Formular, für die
  Hofeinfahrt nur ein Flächen-Feld; „berechnen" routet über `ProjektGenerator`. Die 4 Reiter unverändert.

### Nachweis
- `ProjektGeneratorTests` (4, grün): Typ-Unterscheidung (Haus vs. Vorlage, keine erfundene Taxonomie);
  Haus läuft unverändert über den Haus-Generator (>10 Massen, Haustyp getragen); Hofeinfahrt liefert
  6 Massen / 4 Phasen / 4 Material / Kosten>0 und skaliert mit der Fläche.
- App-Build + volle Unit-Suite grün.
- **Manuell:** Haus-Konfigurator öffnen → Projekt-Typ „Hofeinfahrt pflastern" → Fläche → „berechnen" →
  alle 4 Reiter zeigen Inhalt (wenig, aber echt); Bauphasen-Plan mit 4 Phasen. Haus-Typen wie bisher.

### NICHT gebaut (bewusst, nächste Bögen — so strukturiert, dass sie leicht andocken)
- Vorlage = Bündel aus `Leistungsbaustein` (Katalog-Integration).
- Auto-Menge (Maß-Herkunft je Leistung; „Größe ans Event" ist schon da → andockbar).
- Wachsende Vorlagen (aus echten Baustellen ernten).
- Schlanker Projekt-Deskriptor statt `HouseProjectResult.project: HouseProject`.

### Dateien
**neu** `Service/ProjektTyp.swift`, `Service/ProjektGenerator.swift`,
`…Tests/ProjektGeneratorTests.swift`; geändert `Views/HouseConfiguratorView.swift`.
Backup in `_backups/projekt-generator_*`.

---

## Delta 13.09.2026 — Katalog-Sichten zusammenführen + Größe ans Event

**Branch `feature/katalog-sichten-und-event-masse`** (abgezweigt von
`feature/leistungskatalog-aufwandswert`). Build grün, neue Tests grün. **Nicht gepusht, kein PR.**
Fortsetzung der Nachtschicht (Andreas' Auftrag 13.09. mit getroffenen Entscheidungen).

**Entscheidungen (Andreas):** Katalog = die *Ansicht* zusammenführen, NICHT die Daten (zwei Quellen,
ein Picker). Größe gehört ans **Event**, nicht an den Knoten. **Anfahrt/Standort-Distanz gestrichen.**

### Gemessen zuerst
- `HouseProject` ist ein **reiner Struct** (`Service/HouseProject.swift`), NICHT am Event, keine
  Core-Data-Entity — nichts zum Anzapfen. Also Maße als Event-Felder direkt. (Fundus/qwen unscharf;
  direkter Code-Blick war die Wahrheit.)
- Event-Bearbeitung: `EditEventView` + `AddEventView`. Picker `LVBausteinAuswahlView` wird aus `LVView`
  geöffnet. `LVBausteinKatalog` = statischer Preis-Katalog; `Leistungsbaustein`/`LeistungskatalogService`
  = der gelernte Aufwandswert-Katalog (aus Bogen 1).

### Teil A — zwei Sektionen in EINEM Picker
`LVBausteinAuswahlView` zeigt jetzt zusätzlich die Sektion **„Aus deinen Baustellen"** — die gelernten
`Leistungsbaustein` (via `@FetchRequest`, häufigste zuerst). Ein Tipp legt die LV-Position an UND trägt
den Aufwandswert als Lohn ein; der Baustein zählt eine Verwendung. Menge = 1, im LV von Hand zu stellen.
Der statische „Standard"-Katalog bleibt unverändert daneben. **Keine Entity-Fusion, keine Migration** —
nur die View zeigt beide Quellen.
- **Refactor:** die Lohn-Schreib-Logik (Maurer/Helfer × Stammdaten-Satz, idempotent) liegt jetzt
  gemeinsam in `LeistungskatalogService.schreibeAufwandAlsLohn(...)`. `KnotenKalkulationView` nutzt sie
  auch (vorher privat dupliziert) — eine Wahrheit für beide Wege.

### Teil B — Größe ans Event (nur speichern, NICHT auto-rechnen)
Event hat drei neue optionale Felder: `grundflaeche` (m²), `umfang` (m, laufende Meter), `geschosse`.
Neue Attribute = leichte Migration. Eingabe als **„Maße der Baustelle"**-Sektion in `EditEventView`
UND `AddEventView`. Default 0 = „nicht gesetzt"; Kleinaufträge füllen nur ein Maß.
**Scope-Grenze eingehalten:** nur gespeichert. Die Auto-Ableitung Größe→Menge ist der NÄCHSTE Schritt,
hier NICHT gebaut. Anfahrt bleibt gestrichen.

### Nachweis
- `KatalogSichtenUndMasseTests` (3, grün): gemeinsamer Lohn-Schreiber schreibt mit Stammdaten-Satz +
  ist idempotent; Event speichert die Maße (round-trip); frisches Event trägt keine Maße (Default 0).
- App-Build + volle Unit-Suite grün — inkl. der geerbten Bogen-0/1-Tests NACH dem Refactor (kein Rückfall).
- **Manuell:** Baustelle bearbeiten → „Maße der Baustelle" eintragen/speichern. LV → „LV-Bausteine" öffnen
  → zwei Sektionen sichtbar; einen Baustein aus „Aus deinen Baustellen" tippen → Position + Lohn im LV.
  (Setzt voraus, dass vorher am Knoten ein Aufwandswert übernommen wurde — der füttert den Katalog.)

### Dateien
geändert: `Models/test25B.xcdatamodeld/test25B 2.xcdatamodel/contents` (+3 Event-Attribute),
`Models/Event+CoreDataProperties.swift`, `Service/LeistungskatalogService.swift` (+Lohn-Schreiber),
`Views/KnotenKalkulationView.swift` (nutzt Schreiber), `Views/LV/LVBausteinAuswahlView.swift`
(zweite Sektion), `Views/EditEventView.swift` + `Views/AddEventView.swift` (Maße-Block);
**neu** `…Tests/KatalogSichtenUndMasseTests.swift`. Backups in `_backups/katalog-masse_*`.

### Bewusst offen / für Andreas
- **Auto-Menge (Größe→Menge):** jetzt möglich, da die Größe einen Ort hat. `HouseProjectGenerator` hat
  die Rechenlogik (parameterbasiert) — anzapfen statt neu bauen.
- **Amts-Sicht** (EFB/Urkalkulation), **Kleinauftrags-Baustellenart**.

---

## Delta 12.09.2026 Nachtschicht — Leistungskatalog Bogen 1: „einmal fragen, für immer picken"

**Branch `feature/leistungskatalog-aufwandswert`** (abgezweigt von `feature/grap8-aufwandswert`,
das wiederum von `feature/briefpapier-und-rechnung` — **nicht** main). Build grün, neue Tests grün.
**Nicht gepusht, kein PR.** Autonome Nachtschicht am Nordstern (Andreas schlief; „zieh die
Nachtschicht durch"). Grundlage: `~/Documents/Grap8/Fahrplan - Leistungskatalog und Auto-Ableitung.md`.

### Kühlhaus-Check zuerst (gemessen, nicht geraten)
- **`LVBausteinKatalog` existiert schon** (`Models/LVBausteinKatalog.swift`) — aber ein **statischer,
  hartkodierter enum** aus Goldschmitts echtem Angebot (Titel 01/02 gefüllt, 03–99 leer), mit
  **Einzelpreis, OHNE Aufwandswert, nicht wachsend**. `Views/LV/LVBausteinAuswahlView.swift` pickt
  daraus in ein Event-LV (schreibt `einkaufspreis`, keinen Lohn).
- Es gab **keinen** persistierten Aufwandswert-Katalog. Genau das ist Bogen 1: selbst-wachsend +
  Aufwandswert. (Fundus/qwen war hier unscharf — direkter Code-Blick war die Wahrheit.)

### Was gebaut wurde (minimal-invasiv)
- **Modell:** neue Stammdaten-Entity **`Leistungsbaustein`** (Muster wie `Lohnsatz`) in `test25B 2`:
  `leistung, einheit, maurerStunden, helferStunden, kostenGruppeNummer, quelle, erstelltAm,
  verwendungen`. Neue Entity = leichte Migration, kein Mapping. + Class/Properties-Dateien.
- **`Service/LeistungskatalogService.swift`:** `merke` (ernten: anlegen ODER aktualisieren, Dedup über
  normalisierte Leistung+Einheit), `finde` (case/diakritik-tolerant), `benutzt` (Zähler hoch),
  `alle` (häufigste zuerst).
- **`KnotenKalkulationView` erweitert:**
  - **Ernten:** „In Kalkulation übernehmen" (Prof) schreibt jetzt zusätzlich einen `Leistungsbaustein`
    in den Katalog. Einmal ableiten → liegt im Katalog.
  - **Picken:** Gibt es die Leistung schon (gleiche Bezeichnung+Einheit), erscheint oben eine
    **Katalog-Sektion** — „Aus Katalog übernehmen" füllt den Lohn OHNE Prof-Frage und zählt eine
    Verwendung. Die Kühlhaus-Regel als Feature: nachschlagen statt neu ableiten.

### Nachweis
- `LeistungskatalogTests` (3, grün): Ernten+Finden (tolerant), zweites Ernten aktualisiert statt zu
  verdoppeln (Zähler bleibt), `benutzt` zählt hoch + Sortierung häufigste zuerst.
- App-Build + volle Unit-Suite grün.
- **Manuell morgen (mit dem Grap8-Bogen-0-Test zusammen):** Knoten „Baustelle absichern" → Kalkulation
  → Position anlegen → „Aufwandswert vom Prof holen" → „In Kalkulation übernehmen" (jetzt wächst der
  Katalog). Danach ein **zweiter** Knoten mit demselben Text → dort erscheint die **Katalog-Sektion**
  und füllt den Lohn ohne Prof.

### Bewusst NICHT gebaut (nächste Bögen)
- **Zusammenführung mit `LVBausteinAuswahlView`:** dort läuft der statische Preis-Katalog; der neue
  Aufwandswert-Katalog lebt vorerst nur im Knoten-Fluss. Zwei Achsen (Preis-Vorlage vs.
  Aufwandswert-Baustein) — Konvergenz ist ein eigener Schritt, absichtlich nicht nachts nebenbei.
- **Bogen 2 (Auto-Menge): gemessen, bewusst NICHT nachts gebaut — braucht deine Entscheidung.**
  - *Größe → Menge:* die Logik **existiert schon** in `Service/HouseProjectGenerator.swift`
    (`umfang = √grundfläche × 4`, Wandfläche = Umfang × Höhe, Dach-/Wohnflächen-Ableitungen). Aber
    parametergetrieben (eigener Parameter-Struct), NICHT aus `Event` gespeist.
  - *Standort → Anfahrt:* **kein Code** (kein CLLocation/CLGeocoder/Distanz irgendwo). `Event` trägt
    Adressfelder (`bauherrStrasse/PLZ/Ort`) + freien Text `location`, aber **keine Koordinaten**.
  - *`Event` speichert keine Baustellen-Größe/Geometrie.* → Bogen 2 verlangt zwei Design-Entscheidungen:
    (a) wo „Größe/Umfang" wohnt (Event-Feld? HouseProjectGenerator-Params anzapfen?), (b) ob Anfahrt
    per Geocoding der Adresse gebaut wird. Beides gehört zu dir, nicht in eine Nachtschicht.
- **Bogen 3 (Arbeitsabläufe je Baustein):** später.

### Dateien
**neu** `Models/Leistungsbaustein+CoreDataClass.swift` + `…+CoreDataProperties.swift`,
`Service/LeistungskatalogService.swift`, `…Tests/LeistungskatalogTests.swift`; geändert
`Models/test25B.xcdatamodeld/test25B 2.xcdatamodel/contents`, `Views/KnotenKalkulationView.swift`.
Backups in `_backups/leistungskatalog_*`.

---

## Delta 12.09.2026 nachts — Aufwandswert an den Grap8-Knoten (Bogen 0, 3 Drähte)

**Branch `feature/grap8-aufwandswert`** (abgezweigt von `feature/briefpapier-und-rechnung`,
**nicht** main — Andreas: „entscheide du, aber nicht auf main"). Build grün, neue Unit-Tests
grün. **Noch nicht gepusht, kein PR** (Bestätigung von Andreas steht aus).

**Ziel (Andreas' Nachtauftrag):** In Grap8 einen Knoten antippen → Aufwandswert vom Prof →
fließt als ZAHL in die Kalkulation, nicht als Text. Test-Erfolg = aus dem Knoten „Baustelle
absichern" fällt eine kalkulierte LV-Position mit Maurer-/Helfer-Stunden.

### Gemessener Ausgangsstand (Fundus + Code, bestätigt)
- Ein Grap8-Knoten **IST ein `Auftrag`** (`Grap8Graph.aus`); sein Titel = `Auftrag.processingDetails`
  (via `Kausalkette.bezeichnung`).
- Zwischen `Auftrag` und `LVPosition` gab es **keine** Beziehung — die Kalkulation hing nur an
  `Event` (Ast 1, #155: Knoten → `LVKalkulationView(event:)`, ganze Baustelle). Das war die
  geparkte **Ast-2**-Entscheidung.
- `MopsKalkulationsHelper.aufwandswertVorschlag(leistung:)` → `(maurer, helfer)` h/Einheit war
  fertig, aber nur aus `LVTiefenkalkulationView:111` (`MopsVorschlagSheet`) erreichbar, und das
  Ergebnis wurde nur als **Text** gezeigt (`mopsText`/`antwort`), nie als `kalkLohn` geschrieben.
- **Grap8Web ist ein kompiliertes Vite/React-Bundle** (`Grap8Web/assets/index-*.js`) — ein neuer
  Knopf in der Leinwand ginge nur mit der React-Quelle. Der Knoten-Tap sendet aber schon
  `{action:'verwaltung', ziel:'kalkulation', auftragId}`.

### Was gebaut wurde (minimal-invasiv, drei Drähte)
1. **Draht 1 — Modell:** neue 1:1-Relation `Auftrag.lvPosition ⇄ LVPosition.auftrag` (beide optional,
   Nullify) in **`test25B 2.xcdatamodel`** (die AKTIVE Version, nicht die schlichte `test25B`) +
   getypte Accessoren in `Auftrag`/`LVPosition+CoreDataProperties.swift`. Additiv → leichte Migration,
   kein Mapping-Modell. Der Knoten hat jetzt seine eigene Position.
2. **Draht 2 — Auslöser vom Knoten, OHNE das Bundle anzufassen:** `Grap8Verwaltungswunsch` trägt jetzt
   den `auftrag` mit; für `ziel == .kalkulation` führt der Knoten-Tap zur neuen
   **`KnotenKalkulationView(auftrag:)`** statt zur ganzen Baustelle. Der alte Baustellen-Weg bleibt
   von dort per „Ganze Baustelle" erreichbar (und als Fallback, wenn kein Auftrag mitkommt).
3. **Draht 3 — Zahl statt Text:** `KnotenKalkulationView` legt (Knopf) die eigene Position an, fragt
   den Prof mit dem Knoten-Text, und schreibt `(maurer, helfer)` als zwei `PositionLohn`
   (Muster aus `LohnHinzufuegenView`): `stunden` (h/E) × `stundenBruttoEK`. Der Lohnsatz kommt aus
   den **Stammdaten** (`Lohnsatz` „Maurer"/„Helfer", vom `StammdatenSeeder` geseedet; Rückfall auf die
   Seeder-Werte, falls die Vorlage fehlt). Menge von Hand. Lohnsumme × Menge ist in der Ansicht sichtbar.
   Ehrlich: kein Prof-Wert → nichts eingetragen, das steht dann da.

### Nachweis
- Unit-Test `KnotenAufwandswertTests` (2 Tests, grün): (a) Relation trägt in beide Richtungen;
  (b) `(0,5 Maurer + 1,5 Helfer) × Satz × Menge 4` rechnet zur erwarteten Lohnsumme (> 0, keine Null).
- App-Build + volle Unit-Suite grün (zwei Sachen unterwegs gemessen, nicht behauptet):
  - Mein Test war zuerst rot — **Test-Fehler, kein Feature-Fehler**: `Auftrag` hat Pflichtfelder ohne
    Default (`statusRawValue` + `storageNote`); der Test legte einen nackten Auftrag an. Das Feature legt
    NIE einen Auftrag an — es hängt eine Position an einen bestehenden. Helfer `neuerAuftrag` setzt die
    Felder jetzt wie die App.
  - **Ein bestehender Test fiel durch und musste angepasst werden:**
    `BauerHorstSeederTests.auftraegeUndLVZeileBleibenUngekoppelt` prüfte per Modell-Introspektion, dass
    `Auftrag` GAR KEINE LVPosition-Beziehung hat — die alte Ast-1-Regel „keine Modell-Kopplung". Draht 1
    kehrt das bewusst um. Der Test prüft jetzt den echten, weiter gültigen Sinn: der **Seeder** koppelt
    die Daten nicht (`auftrag.lvPosition == nil`). Docstring entsprechend umgeschrieben — die Umkehr ist
    beabsichtigt, nicht „nebenbei".
- **Draht 2 (Prof-Aufruf) ist Netzwerk → manuell zu prüfen:** in Grap8 Knoten „Baustelle absichern"
  antippen → „Kalkulation" → Menge setzen → „Position anlegen" → „Aufwandswert vom Prof holen" →
  „In Kalkulation übernehmen" → der Lohn steht in der Ansicht und in der Tiefenkalkulation.

### Bewusst NICHT gebaut (nächster Bogen)
- Auto-Ableitung der Menge (Standort → Anfahrt, Größe → Menge). Voraussetzung: `Event` müsste Standort +
  Geometrie tragen — nicht geprüft, nicht gebaut. Menge bleibt von Hand.
- Der wiederverwendbare **Leistungskatalog** (`~/Documents/Grap8/Fahrplan - Leistungskatalog und
  Auto-Ableitung.md`). Katalog-KOMPATIBEL vorbereitet: Leistung (bezeichnung) + Einheit + Maurer/Helfer-h
  liegen an EINEM Ort (der Position), aufgreifbar.
- Zweiter Nachtauftrag von Andreas: kommt noch, wird auf demselben/eigenem Branch abgearbeitet.

### Dateien
`Models/test25B.xcdatamodeld/test25B 2.xcdatamodel/contents`, `Models/Auftrag+CoreDataProperties.swift`,
`Models/LVPosition+CoreDataProperties.swift`, `Views/Grap8View.swift`,
**neu** `Views/KnotenKalkulationView.swift`, `Resources/Knowledge/app_bedienung.yaml`
(Eintrag `App_Grap8_Knoten_Kalkulation` — Drift-Regel), **neu**
`iMOPS-…Tests/KnotenAufwandswertTests.swift`. Backups in `_backups/grap8-aufwandswert_*`.

---

## Delta 11.09.2026 spät — Briefpapier + Rechnungsblatt: der Kreis endet auf Papier

**Branch `feature/briefpapier-und-rechnung`.** Zwei Aufträge in einem: das
Firmen-Briefpapier (Logo + Stammdaten aus `FirmenSettings`) und das lesbare
**Rechnungs-PDF**, das es benutzt.

### Was die Messung gegen den Auftrag ergeben hat

| Auftrag nahm an | Gemessen |
|---|---|
| FirmenSettings = Core Data, ggf. Migration | **UserDefaults** — keine Migration nötig |
| Bearbeiten-Ansicht fehlt | **Gibt es**: `SettingsView` mit `@AppStorage` |
| XRechnung hat „iMOPS Bauleitung" hartkodiert | Seller kam **längst** aus FirmenSettings — nur der *Default* war das Problem |
| `LVPDFExporter` rendert Kopf/Fuß | Er nutzt FirmenSettings **nur für den MwSt-Satz** |

### 🔴 Der Fund: Dokumente trugen den Namen der Software

Vier Exporter schrieben hart `"iMOPS Construction Grid"` in Kopf und Fuß:
`LVPDFExporter`, `BautagesberichtPDFExporter`, `MangelPDFExporter` und
`LieferantenAnfragePDFExporter`. **Der letzte geht nach draußen** — eine Anfrage
beim Lieferanten mit dem Namen eines Programms statt der Firma.

Deshalb **`Briefpapier.swift`**: ein Kopf, ein Fuß, für alle. Vier Stellen mit
demselben Satz laufen auseinander, sobald eine angefasst wird.
⚠️ **Umgestellt ist bisher nur das Rechnungsblatt.** Die drei anderen Exporter
tragen den Softwarenamen weiter — offener Befund, bewusst nicht nebenbei erledigt.

### 🔴 § 14 UStG: der Käufer war die Baustelle

Die XRechnung trug als `<ram:BuyerTradeParty><ram:Name>` den **`event.title`** —
„Privatkunde — Hofauffahrt pflastern (4 Stellplätze, ~100 qm)" — und als Adresse
nur `<CountryID>DE</CountryID>`. Eine Rechnung braucht Namen **und** vollständige
Anschrift des Leistungsempfängers; ohne sie zieht der Kunde keine Vorsteuer.

Die Felder gab es im Modell nicht. `location` ist die **Baustelle**, nicht der
Empfänger — meist dasselbe, aber wer für einen Bauträger baut, schickt die
Rechnung ins Büro und nicht an die Grube. Neu: `Event.bauherrStrasse/PLZ/Ort`
(optional, Version `test25B 2`, leichtgewichtig migrierbar — die vorhandenen
`ModellVersionierungTests` prüfen das), Eingabe in **`AddEventView` und
`EditEventView`**, Fallback auf den Titel bleibt (ein XML ohne Käufernamen wäre
gar nicht gültig).

### Grundsatz: keine Platzhalter auf Kundendokumenten

Fehlende Angaben werden **weggelassen**, nie gedruckt. Kein „[fehlt]", kein „–".
Ein Briefkopf ohne Faxnummer sieht normal aus; einer mit „Fax: –" sieht nach
Software aus. Ebenso: **kein Default-Firmenname mehr** — wer nichts einträgt,
bekommt nichts. Ein leerer Briefkopf fällt auf, ein falscher nicht.

### Zwei Zusagen, die nicht auseinanderlaufen dürfen

PDF und XRechnung teilen **dieselbe Rechnungsnummer**
(`RechnungPDFExporter.rechnungsnummer`) und filtern Alternativpositionen gleich.
Zwei Nummern oder zwei Beträge für einen Vorgang sind ein Buchhaltungsfehler, den
niemand bemerkt, bis er weh tut. Test: `pdfUndXRechnungTragenDieselbeNummer`.

### Logo: Datei, nicht UserDefaults

Das Bild liegt im **App-Support**, in den UserDefaults steht nur der Dateiname.
UserDefaults wird bei jedem Start vollständig in den Speicher gelesen — ein PNG
gehört da nicht hinein. Fehlt die Datei (Gerätewechsel), liefert `logoURL` `nil`:
lieber kein Logo als ein leerer Kasten.

### ⏸️ ZUGFeRD: bewusst nicht angefangen

PDF/A-3 verlangt eingebettete Schriften, XMP-Metadaten, Farbprofile und die
Anhang-Relation `/AFRelationship /Alternative`. `UIGraphicsPDFRenderer` erzeugt
kein PDF/A. **PDF und XML bleiben zwei Dateien** — der Auftrag lässt diese Tür
ausdrücklich offen. Ein halb konformes PDF/A-3 wäre schlimmer als zwei saubere
Dateien: Es sähe aus wie ZUGFeRD und fiele beim Empfänger durch.

### ⚠️ Falle beim Einbauen: `newEvent` statt `event`

In `AddEventView` heißt die Variable `newEvent`. Ein Muster-Patch setzte die
Eingabefelder und übersprang den Speicher-Teil **stillschweigend** — drei Felder,
die sich ausfüllen lassen und beim Sichern verschwinden. Gefunden durch
Nachzählen in beiden Dateien, nicht durch Hinsehen.

### Snapshot mit erfundenen Daten

`--target=RechnungPDF` setzt **Test-Stammdaten** („Musterbau GmbH", IBAN
`DE00 0000…`) und zeichnet ein Logo programmatisch. Kein echtes Logo, keine echte
IBAN: Ein Snapshot landet im Repo, und das ist öffentlich — siehe die
DSGVO-Fälle 06.06. und 31.07.

**Nachweis:** Build grün · Unit-Tests **242 bestanden, 0 gefallen** (inkl.
Migrationstests) · UITest-Snapshot grün · Modell-Diff = genau die drei bewussten
Attribute.

### 🔴 Für Andreas/Raphi, vor dem ersten echten Kunden

Jede Zahl im Briefkopf gegen die **Firmenpapiere** prüfen: USt-IdNr., IBAN, HRB,
Geschäftsführer, Anschrift. Das kann kein Programm — es sieht nur, ob ein Feld
gefüllt ist, nie ob der Wert stimmt. Unter echtem Firmennamen gibt es kein
„ungefähr". In den Einstellungen steht dazu eine Warnung, solange Name, Anschrift
und USt-IdNr./Steuernummer unvollständig sind.

---

## Delta 11.09.2026 spät — Der ƒ-Knopf im Deckel: ein Tipp statt Auflösen

**Branch `feature/kalkulation-im-deckel`.** Jede Baustein-/Beleg-Zeile in einem
aufgeklappten Deckel trägt jetzt ein sichtbares **ƒ(x)**, das mit einem Tipp die
Tiefenkalkulation genau dieses Bausteins öffnet.

**Warum das kein Schönheitsfehler war:** Der einzige Weg dorthin führte über
*lang drücken → Kontextmenü → „Kalkulation"*. Wer den nicht kennt, **löst den
Deckel auf** — und muss danach jede Position von Hand neu zusammenführen. Ein
verstecktes Menü hat also echte Zusammenführungen gekostet. Das Kontextmenü
bleibt, wer den Weg kennt, behält ihn.

`kalkKnopf(fuer:)` steht direkt neben `pdfKnopf` und ist bewusst genauso gebaut.
**`.buttonStyle(.borderless)` ist dabei keine Kosmetik:** In einer `List` färbt
der Standardstil die ganze Zeile zum Tap-Ziel — der Tipp würde die
`DisclosureGroup` zuklappen oder den `actionPosition`-Dialog öffnen.

### 🔴 Ein Snapshot allein hätte hier nichts bewiesen

**`LVView` bringt keinen eigenen `NavigationStack` mit** — den stellt in der App
`EventDetailView`. Der bestehende Snapshot-Host `LVElement` zeigt `LVView` ohne
Stack; dort läuft `.navigationDestination(item: $kalkPosition)` ins Leere. Ein
Screenshot hätte den Knopf gezeigt, und er hätte trotzdem nirgendwohin geführt.

Deshalb ein **eigenes** Ziel `--target=LVDeckelKalk` **mit** Stack.
`SnapshotElementHost` bleibt unverändert: ein Stack brächte eine Navigationsleiste
ins Bild und würde die bestehenden LVElement-Snapshots ändern, ohne dass sich an
ihrer Sache etwas geändert hätte.

Statt eines Bildes prüft **`KalkKnopfImDeckelUITests`** das eigentliche
Versprechen: Deckel aufklappen → ƒ antippen → Navigationsleiste „Kalkulation"
steht da, **kein Sheet**. Genau das, was `.borderless` leisten soll und was man
einem Bild nicht ansieht. Zwei Screenshots hängen als Anhang im Testergebnis.

### ⚠️ Falle: `@ViewBuilder` gehört zur Funktion, nicht zur Zeile davor

`pdfKnopf` trägt ein `@ViewBuilder` (es hat ein `if` ohne `else`). Ein Einschub
vor `private func pdfKnopf` landet **zwischen Attribut und Funktion** — das
Attribut klebt dann an der neuen Funktion und `pdfKnopf` bricht mit
*„opaque return type, but has no return statements"*. Beim Einfügen vor einer
Swift-Funktion immer eine Zeile höher schauen.

### Bonus war schon da

Die Beiträge je Baustein stehen bereits lesbar in der Zeile (`rezeptText` +
`bausteinBeitrag`): 17,50 · 25,00 · 27,50 · 2,50 €/m². Nichts zu tun.

**Nachweis:** Build grün · UITest 1/1 · kein Core-Data-Delta · nur `LVView.swift`
(Produktionscode), dazu DEBUG-Snapshot-Host und ein neuer UITest.

ℹ️ Randnotiz aus dem Snapshot: Der Baustein zeigt im Kalkulations-Kopf **„0 m³"**.
Das sind die Snapshot-Testdaten (`SnapshotData.pflasterBaustelle` setzt am
Baustein nur das Rezept-Maß, keine Menge) — kein Fehler der Ansicht.

---

## Delta 11.09.2026 abends — Der Kreis ist zu: Zeichnung → Rechnung

**PR #158 — gemergt am 11.09.2026 (Squash `0f99891`).**

⚠️ **Zweimal an einem Abend dieselbe Falle:** Hier stand erst „PR #157, offen“
(war gemergt), dann der Branchname eines Astes, der inzwischen ebenfalls gemergt
ist. **Der HANDOFF kann einen Merge nicht kennen — der passiert auf GitHub.**
Vor jedem PR `gh pr list --head <branch> --state all` prüfen; bei Squash-Merges
sagt `git merge-base --is-ancestor` „nein“, obwohl der Inhalt oben ist — der
verlässliche Test ist `git diff origin/main HEAD --stat` (leer = drin). Die Hofauffahrt-Demo trägt
jetzt **gezählte** Mengen aus Raphis `Testhofeinfahrt.dxf` statt geschätzter, und
aus derselben Baustelle fällt am Ende eine **XRechnung** über den bestehenden
`XRechnungExporter` — ohne eine Zeile neues Feature.

    Gespräch → Angebot → Baustelle/Kausalkette → Kalkulation → Rechnung

### Was sich geändert hat

| | vorher | jetzt |
|---|---|---|
| Bezugsmenge | `100 qm` (geschätzt) | **`100,31 m²`** (Summe der gezählten Steine) |
| Pflaster | „Betonpflaster grau", 1,0 m²/m² | **1294 Vollsteine + 50 Halbsteine** (Pasand Nr. 59) |
| Randeinfassung | „Tiefbordstein", 30 lfm | **40 Leistensteine** à 1,00 m |
| Tragschicht | „Mineralgemisch 0/32", 57 t @ 7,90 | **„Schotter 0/32"**, 57,18 t @ **10,00 (Li, Raphael)** |
| Bettung | „Splitt 2/8", 6,5 t | **„Splitt 8/16"**, 6,52 t (DXF-Layer) |
| Verschnitt Pflaster | 5 % | **0 %** — siehe unten |

### 🔴 Die Falle, die diese Runde fast verschluckt hätte: `qm` ≠ `m²`

`XRechnungExporter.xrUnit` bildet auf UN/ECE Rec 20 ab und kennt **`m²` → MTK**.
**`qm` kennt er nicht** — das fällt in den Default **`C62` (Stück)**. Die Rechnung
hätte „100,31 **Stück** Hofauffahrt" gelesen, und **dem XML sieht man das nicht an**.

Gemessen: `qm` kam im **ganzen Repo genau einmal** vor — in diesem Seeder. Alle 16
anderen Stellen schreiben `m²`. Der Ausreißer war die Position, nicht der Exporter,
deshalb ist die Position umgestellt und der Exporter unangetastet.
Test `ausDerBaustelleFaelltEineXRechnung` prüft `unitCode="MTK"` **und** dass
`C62` *nicht* vorkommt.

⚠️ **Offen, nicht behoben:** `xrUnit` kennt auch **`Pau`** nicht (4 Fundstellen im
Repo) — Pauschalen fallen dort ebenfalls auf `C62` statt `LS`. Befund, keine Aufgabe.

### Gezählte Mengen tragen keinen Verschnitt

Solange 100 qm als *Fläche* dastanden, waren 5 % Verschnitt richtig — eine Fläche
schneidet man zu. **Gezählte Steine nicht:** der Zuschnitt am Rand steht im DXF
bereits als **50 Halbsteine**. Wer auf 1294 gezählte Steine noch 5 % aufschlägt,
zählt den Rand zweimal.

**Was damit fehlt, ist der Bruch.** `verschnittProzent` ist eine Spalte für zwei
verschiedene Dinge: Zuschnitt (aus der Geometrie herleitbar) und Bruch
(Erfahrungswert). **Befund, nicht Aufgabe.**

### `MengenQuelle` kennt kein „gezählt"

Vier Fälle: `statik · bplan · schaetzung · manuell`. Eine DXF-Zählung ist keiner
davon, und `istGeschaetzt` ist `self != .statik` — sie gälte ohnehin als Schätzwert.
Der rawValue ist zudem das **Wire-Format der Box** (`ExtractLVPosition.quelle`); ein
neuer Fall wäre eine Schnittstellenänderung, kein Beiwerk.

Deshalb: `mengenQuelle = .schaetzung` **plus Herkunft in `deckelNotiz`** — dem Feld,
das im Modell schon der Prüfstempel „woher" ist (`MateriallisteView` schreibt dort
„N Einzel-Bauteile aus DATEI"). Dieselbe Verwendung, eine Ebene früher.
**Befund: dem Modell fehlt der Zustand „gezählt".**

### Was die Zahlen NICHT sind

Die **Mengen** sind gezählt. Die **Preise** sind es nicht:
- Stückpreise der Pasand-Steine sind aus dem qm-Marktanker (40,00 €/m²)
  **umgerechnet** — 0,07605 m² je Vollstein → 3,04 €/Stk. Eine Folgerung, kein
  Händlerpreis. Wer ein Pasand-Angebot hat, trägt es ein.
- **Splitt 8/16 ist der unsicherste Preis der Position.** Raphaels Stammdaten führen
  *Splitt 2/8 zu 2,90 €/to* — andere Körnung, nicht übertragbar. Für 8/16 gibt es
  dort keinen Satz, der alte Werbach-Wert (8,50) bleibt stehen.
- Schotter 0/32 **ist** belegt: 10,00 €/to Li aus `RaphaelStammdatenSeeder`; die
  15 % Materialzuschlag kommen erst im `LVKalkulator` → 11,50.

### 🔴 Unabhängiger Fund: das Repo ist öffentlich

`RaphaelStammdatenSeeder.swift` (Commit `884b2fb`) trägt Raphaels reale Lohn-,
Material- und Gerätesätze. Das Repo ist **PUBLIC** (`gh repo view --json visibility`
— ⚠️ der Repo-Name endet auf einen **Punkt**, ohne ihn findet `gh` nichts). Die
Commit-Message warnt selbst („VERTRAULICH … nirgendwo sonst hin"), nur liegt das
Werkzeug offen. Dritter Seeder-Fall nach mops-api (6.6.) und iMOPS (31.7.).
**Andreas hat entschieden: erstmal notieren, Entscheidung später.** Offen.

### Ein Test hat seinen Namen verloren: `keinTerminOhneAufmass` → `keinTerminZugesagt`

Er prüfte, dass in der Notiz „verbindlich nach Aufmaß" steht. Das stimmt nicht
mehr — **das Aufmaß liegt vor**, 1294 gezählte Steine *sind* eins. Ein Termin
steht weiterhin nicht, aber aus einem anderen Grund: es hat nie jemand einen
zugesagt. Was jetzt aussteht, ist der **Lieferantenpreis**, nicht das Maß.

Zwei weitere Tests rechneten gegen eine **hart notierte `100`** statt gegen
`pos.menge` und fielen bei der Mengenkorrektur um, ohne dass an ihrer Sache
etwas falsch war. Beide rechnen jetzt gegen die Bezugsmenge.

**Testlauf: 15 von 15 grün** (`iPhone 17 Pro Max`, iOS 26.2).

⚠️ **Falle beim Testen:** `-destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
gibt es hier nicht. xcodebuild greift dann nach dem **angeschlossenen iPhone**
(iOS 16.7 gegen Deployment-Target 26.2), bricht ab — **und liefert Exit-Code 0**.
Es sah aus wie ein grüner Lauf, in dem kein einziger Test lief. Der einzige
passende Simulator ist `id=56C7C83E-44FF-4607-AA85-B3D2E4F5D2D7`.

---

## Delta 11.09.2026 — Demo 3 „Hofauffahrt": das Mengengerüst trägt, mit einer Falle

**PR #157, offen.** Dritte Demo-Baustelle: befahrbare Hofauffahrt, vier Stellplätze,
~100 qm. Neu gegenüber den Vorgängern sind **echte Mengen** statt „1 Psch" —
57 t Schotter, 100 qm Pflaster, 30 lfm Randstein. **Kein Core-Data-Delta**,
idempotent. Snapshot: **„2 startklar · 8 wartet"**.

### 🔴 Der Fund, den die nächste Instanz kennen muss

**`mengeProEinheit` ist die Menge JE POSITIONSEINHEIT, nicht die Gesamtmenge.**
Nachgemessen in `PositionMaterial+CoreDataProperties.swift`:

```swift
kostenProEinheit = einzelpreis * mengeProEinheit * (1 + verschnittProzent)
```

und in `LVKalkulator.kalkuliere`: `gesamtpreis = einheitspreisVK * menge`.

Gebraucht werden **57 t** Mineralgemisch. Im Modell steht **0,57** — nämlich
57 t ÷ 100 qm. **Wer eine Menge aus einem Aufmaß direkt einträgt, rechnet das
Hundertfache.** Gilt genauso für `PositionLohn.stunden` und `PositionGeraet.stunden`.

Das ist gefährlich, weil die Summe plausibel *aussieht* — nur eben hundertmal zu
groß. Deshalb steht im `HofauffahrtSeeder` bei jeder Zeile die Gesamtmenge als
Kommentar daneben, und `mengenSindJeEinheitNichtGesamt` rechnet zurück.

**Merksatz: eine Menge ohne Bezugsgröße ist keine Menge.**

### 🔴 Verschnitt in `BauerHorstSeeder` ist um Faktor 100 zu hoch — nicht repariert

`verschnittProzent` ist ein **Faktor**, kein Prozentwert. Gemessen an zwei Stellen:

| Quelle | 5 % |
|---|---|
| `MaterialHinzufuegenView` (die UI) | `(Double(text) ?? 5) / 100.0` → **0.05** |
| `StammdatenSeeder` | `0.05`, `0.03`, `0.10`, `0.15` |
| **`BauerHorstSeeder`** | **`5`** und **`10`** |

Bei `einzelpreis × menge × (1 + verschnittProzent)` ergibt das **500 % und 1000 %**:

```
Pflastersteine:  1,5 × 28 € × (1+10) = 462,00 €   statt  46,20 €
Kies 0/32:      0,15 × 38 € × (1+5)  =  34,20 €   statt   5,99 €
```

Die Kalkulation von Bauer Horst ist damit um ein Vielfaches zu hoch.
**Bewusst nicht nebenbei repariert** — Befund, keine Aufgabe. Der neue Seeder
spiegelt den Fehler nicht mit; `verschnittIstEinFaktorKeinProzent` hält die
richtige Konvention fest.

### Kostengruppen: 520 heißt nicht, was der Auftrag dachte

Der Auftrag nannte **520 „Befestigte Flächen"**. Im `DIN276BaumKatalog` heißt 520
**„Gründung / Unterbau"** — den Namen aus dem Auftrag gibt es dort nicht. Die
befestigten Flächen liegen in der 530er-Gruppe: 531 Wege · 532 Straßen ·
533 Plätze, Höfe, Terrassen · **534 Stellplätze**.

Daraus die Zweiteilung, die der Katalog selbst anlegt:
- **520** für Trennvlies und Tragschicht (Unterbau, wörtlich)
- **534** für Randsteine und Pflasterdecke (Oberbau; der Zweck ist das Abstellen
  von vier Fahrzeugen)

`Grap8Graph.symbol()` um die 520er ergänzt (→ „Layers"), sonst trügen sie das
Standardsymbol — dieselbe Sache wie 541/544 in der Sandsteinstufen-Runde.
**Zweite Runde in Folge, in der die Kostengruppe aus dem Auftrag falsch war.**

### Die drei Lücken dieser Demo

1. **Fremdleistung hat keine Kostenart** *(bestätigt Runde #2)* — die
   Aushub-Entsorgung ist weder Material noch Lohn noch Gerät. Steht im Klartext
   am Schritt, nicht getarnt in der Kalkulation. Test: `entsorgungHatKeineKostenart`.
2. **NEU: kein Zustand „variabel / abhängig von".** Die Entsorgung ist nicht
   bezifferbar, bevor die Bodenklasse feststeht (Z0 bis Z2 nach
   Stammdatenblatt/Erzeugererklärung). Das Modell kennt nur feste Preise.
   Vermerkt am Schritt, kein Test — es gibt nichts zu prüfen, nur etwas zu wissen.
3. **Pauschale auf Gerät** *(bestätigt Runde #2)* — sechs Fuhren à 120 € stehen
   als `0,06 Stunden × 120 €`. Test: `fuhrenRechnenImZeitModell`.

### Nachgewiesen
- **12 eigene Tests grün**, volle Suite **0 Fehler**, `** TEST SUCCEEDED **`
- `git diff main -- '*.xcdatamodel*'` **leer**
- Snapshot `--target=Hofauffahrt`: **2 startklar · 8 wartet**
- Rechenkette von Hand gegengeprüft: Material 52,27 €/qm, Lohn 51,80 €/qm,
  Gerät 13,60 €/qm — nicht gegen das, was das Programm ausspuckt

### Falle, die hier Zeit gekostet hat
**Exakte Gleichheit bei Fließkomma.** `0,57 × 100` ergibt in `Double`
**56,99999999999999**, nicht 57 — ein `#expect(... == 57.0)` fällt dadurch durch.
Mengenprüfungen brauchen eine Toleranz. (Kostete einen Testlauf.)

Und noch einmal die bekannte: **`| grep` auf die Testausgabe verschluckt die
Fehlermeldung.** Der erste Lauf meldete nur `** TEST FAILED **` ohne Grund. Volle
Ausgabe in eine Datei schreiben, dann gezielt hineinschauen.

---

## 📋 Übergabe 10.09.2026, Feierabend — wo alles steht

**Beide Repos sind sauber:** nur `main`, keine offenen PRs, keine Branch-Leichen,
Arbeitsverzeichnisse leer, `.arbeitsplatz` frei.

### Heute gemergt
| | |
|---|---|
| **iMOPS** | #150 IFC-Nachtrag · #151 Pflichtspur-Regel · #152 Verwaltungs-Knöpfe · #153 Bauer Horst · #154 Sandsteinstufen |
| **mops-api** | #59 Wächter im Netz · #60 Namensregel · #61 Pflichtspur-Regel |

### Der rote Faden des Tages
Grap8 ist von einer Leinwand mit Beispieldaten zu einem Werkzeug geworden: echte
Aufträge, anlegbare Ketten, Knöpfe die zu den Verwaltungs-Ansichten führen, und zwei
Demo-Baustellen, an denen man beides zusammen sieht.

### 🔴 Was offen bleibt — vier Befunde, keine Aufgaben
1. **Keine Kostenart für Fremdleistung.** `LVPosition` kennt nur Material/Lohn/Gerät.
   Ein Nachunternehmer passt nirgends hinein; eine Angebotssumme mit Fremdleistung ist
   heute unvollständig. (Demo: Sandsteinstufen, Test `fremdleistungHatKeineKostenart`.)
2. **Termine sind nicht abfragbar.** `AuftragExtrasPayload.deadline` liegt als JSON in
   `extras` — kein `NSPredicate`, kein Sortieren. „Welche Bestellung wird diese Woche
   fällig?“ ist nicht stellbar. (Test `terminIstNichtAbfragbar`.)
3. **`Auftrag` und `LVPosition` sind nicht verbunden.** Die bewusst aufgeschobene
   Kapitel-Entscheidung. Zwölf Handgriffe, eine Abrechnungszeile, keine Brücke.
   (Demo: Bauer Horst, Test `auftraegeUndLVZeileBleibenUngekoppelt`.)
4. **Finger-Test auf echter Hardware** — weiterhin blockiert, kein iPad verfügbar.
   Prüfliste steht weiter unten.

### Drei Fallen, die heute Zeit gekostet haben
- **`| tail -N` schneidet Fehlermeldungen ab.** Zweimal passiert: ein `assert` schlug fehl,
  das Skript lief weiter, der Screenshot zeigte den falschen Bildschirm. Ausgaben
  vollständig lesen oder gezielt nach `error`/`FAILED` filtern — nicht blind kürzen.
- **Fremde Test-Suites, die reihenweise fallen, sind die Umgebung.** 172 von 212 Tests
  fielen durch, auch `DIN276KatalogTests`. Einzeln grün; nach `xcrun simctl shutdown all`
  alles grün. Erst Simulatoren neu, dann im eigenen Code suchen.
- **„Beide Seiten behalten“ trägt bei Konflikten nur in Listen und Kommentaren.** Bei
  Code-Blöcken, die sich eine schließende Klammer teilen, bricht der Build. Nach jedem
  Konflikt compilieren, nicht nur Konfliktmarken zählen.

### Zum Merken für morgen
- **Die Platte ist bei ~10 GB frei.** CLAUDE.md warnt davor (Simulator-Crashes). Wird eng.
- `git branch -r --merged` erkennt **keine Squash-Merges** — belastbar ist
  `gh pr list --head <branch> --state all`.
- Ein Doppel-Merge desselben Branches (#154/#155) hat keinen Schaden angerichtet; der
  zweite Commit war leer. Geprüft: keine doppelten Definitionen.

---

## Delta 10.09.2026 — Demo 2 „Sandsteinstufen": zwei Stränge und zwei Modell-Lücken

**In `main` (PR #154).** Zweite Demo-Baustelle: zwei zerbrochene
Sandsteinstufen austauschen. Zeigt, was Bauer Horst nicht zeigt — **Wartezeit auf
Lieferung** und eine **Fremdleistung**. **Kein Core-Data-Delta**, idempotent.

### 🔴 Die zwei Lücken — der eigentliche Fund
**1. Es gibt keine Kostenart für Fremdleistung.** `LVPosition` kennt genau drei Töpfe:
`kalkMaterialien`, `kalkLohn`, `kalkGeraete` (nachgemessen). Der Steinmetz (100 € fest)
ist keins davon. Die 100 € stehen deshalb **nicht in der Kalkulation**, sondern im
Klartext am Arbeitsschritt. Sie als Material oder Lohnstunde zu verbuchen wäre
rechnerisch richtig und inhaltlich falsch. **Folge: die Angebotssumme dieser Position
ist unvollständig — und das soll man sehen.** Test: `fremdleistungHatKeineKostenart`.

**2. Der Termin liegt in JSON, nicht im Modell.** Hier ist die Auftragsannahme zu
korrigieren: `Auftrag` hat zwar **kein Core-Data-Feld**, aber `AuftragExtrasPayload.deadline`
existiert und wird von `HouseProjectGenerator` und `AuftragDetailView` benutzt. Der
Unterschied ist praktisch: **man kann darauf nicht per `NSPredicate` suchen, nicht
sortieren, nicht filtern.** Die Frage „welche Bestellung wird diese Woche fällig?" ist mit
dem heutigen Modell nicht stellbar, nur von Hand durchblätterbar. Test:
`terminIstNichtAbfragbar` (prüft beides: Feld fehlt, JSON-Wert ist da).

**Kleine Schwester:** `PositionGeraet` rechnet `stunden × kostenProStunde`. Die
Spedition ist eine **Pauschale** und steht als 1 × 100 € drin — rechnerisch richtig,
begrifflich schief. Das Modell kennt Zeit, keine Pauschalen.

### 🔴 Und eine falsche Kostengruppe im Auftrag
Der Auftrag gab **535** vor. Im `DIN276BaumKatalog` ist das **„Sportplatzflächen"**.
Eine Hauseingangstreppe ist **544 „Rampen, Treppen, Tribünen"** — korrigiert, und
`Grap8Graph.symbol()` um 541/544 ergänzt, sonst trüge sie das Standardsymbol.

### Der Graph
Sechs Schritte, **5 Kanten**, zwei Stränge, die unabhängig starten: alte Stufen ausbauen
**und** Stein bestellen. Wer erst bestellt, wenn die Treppe offen ist, wartet Wochen mit
einem Loch vor der Haustür. Beide münden ins Versetzen.

### Nachgewiesen
- **Screenshot (`--target=Sandsteinstufen`): „2 startklar · 4 wartet"** — genau die zwei
  Stränge.
- 9 eigene Tests, u.a. der Termin über **alle zwölf Monate** geprüft (erster Freitag des
  Folgemonats, 08:00), nicht nur für den aktuellen.
- `** TEST SUCCEEDED **`, **212 Tests grün**, Modell bitgleich.

### Falle: der hängende Simulator
Ein Testlauf meldete **172 von 212 durchgefallen** — quer durch alle Suites, auch
`DIN276KatalogTests`, die niemand angefasst hatte. Kein Codefehler: derselbe Test lief
einzeln grün, und nach `xcrun simctl shutdown all` war alles grün. **Wenn plötzlich
fremde Suites reihenweise fallen, ist es die Umgebung, nicht der Code** — Simulatoren
herunterfahren und wiederholen, bevor man im eigenen Code sucht. (Freie Platte war dabei
bei 10 GB — knapp, siehe die Warnung in CLAUDE.md.)

### Offen
- Andreas: Baustelle öffnen, die zwei Stränge ansehen.
- Die zwei Lücken sind **Befund, keine Aufgabe** — was daraus folgt, entscheidet ihr.

---

## Delta 10.09.2026 — Demo „Bauer Horst": zwölf Handgriffe, eine LV-Zeile

**In `main` (PR #153).** Eine Demo-Baustelle mit **beiden Sichten**:
12 Aufträge als Grap8-Kette **und** eine LV-Position mit durchgerechneten Einzelkosten.
Am selben `Event`, aber **ungekoppelt** — das ist der Gegenstand, nicht ein Versäumnis.
**Kein Core-Data-Delta**, idempotent, nichts wird gelöscht.

### Warum die Lücke Absicht ist
Wer den Pfosten setzt, arbeitet in zwölf Schritten. Wer ihn abrechnet, schreibt eine Zeile.
Zwischen `Auftrag` und `LVPosition` gibt es **keine Beziehung** im Modell — die Demo führt
genau diese Lücke vor. Sie hier heimlich zu schließen würde die Frage verstecken statt sie
zu zeigen. Ein Test (`auftraegeUndLVZeileBleibenUngekoppelt`) hält das fest, damit niemand
sie „nebenbei" zumacht.

### Die Kette ist ein Graph, keine Perlenkette
Zwölf Schritte, **12 Kanten**, und bei **„Pfosten setzen" laufen zwei Stränge zusammen**:
er wartet auf das Kiesbett *und* auf den angemischten Beton. Das Anmischen hängt am
Abladen, nicht am Ausheben — Beton rührt man an, während das Loch noch offen ist.

### Alle Zahlen sind Schätzung
`mengenQuelle = .schaetzung`, im Code als `[Schätzung — Raphi korrigiert]` vermerkt.
~4,5 MA-h × 74 €/h, sechs Materialien, drei Geräte (der LKW mit **zwei kurzen Dorffahrten**,
nicht mit einem Tagessatz). Die Werte zeigen die **Struktur** einer Kalkulation, nicht die
Preise eines Angebots.

### Vier Schritte ohne Kostengruppe — bewusst
Anfahrt, Einmessen, Anmischen, Aushärten sind **Tätigkeiten, keine Bauteile**. DIN 276 gibt
dafür nichts her, das nicht erfunden wäre. Auf der Leinwand tragen sie das Standardsymbol —
ehrlicher als eine geratene Nummer.

### Nachgewiesen
- **Screenshot (`--target=BauerHorst`):** „Bauer Horst — Pfosten setzen", Zähler
  **1 startklar · 11 wartet**. Bei zwölf unverbundenen Aufträgen wären es zwölf startklar
  (so sah das Generator-Projekt gestern aus) — die Kette wirkt also.
- **7 Tests grün**, u.a. die Verzweigung, die Idempotenz und das Nicht-Ziel.
- `** TEST SUCCEEDED **`, Exit 0, Modell bitgleich.

### 🔴 Zwei Dinge aus dem Auftrag, die nicht stimmten
1. **Das Drehbuch `~/Documents/Grap8/Demo Bauer Horst - Pfosten.md` existiert nicht** —
   der Ordner ist leer, systemweit kein Treffer. Gebaut nach den Angaben im Auftrag selbst;
   die reichten, weil ohnehin alles Schätzung ist.
2. **PR #152 (Verwaltungs-Knöpfe) war beim Bauen noch offen** — und wurde währenddessen
   gemergt. Dieser Branch hat `main` darum nachträglich hereingemergt; die Konflikte in
   `SnapshotHostView` und im HANDOFF waren rein additiv (beide Seiten ergänzen nur).
   **Folge: der Weg „Knoten antippen → gefüllte Kalkulation" ist jetzt vollständig** —
   die Knöpfe aus #152 und die Demo-Daten von hier treffen sich.

### Falle beim Messen — wieder `tail`
Der erste Snapshot zeigte die falsche Ansicht. Ursache: mein Patch war mit einem Anker aus
**#152** geschrieben, den es auf `main` nicht gibt — der `assert` schlug fehl, und
`| tail -3` schnitt die Fehlermeldung ab. Das Skript lief weiter und fotografierte den
Default-Bildschirm. **Zum zweiten Mal dieselbe Falle:** die Ausgabe abschneiden, bis der
Fehler nicht mehr sichtbar ist.

### Offen
- Andreas: Bauer Horst öffnen, Kette ansehen — und nach #152 den Knopfweg zur Kalkulation.
- Raphi: die geschätzten Werte korrigieren.
## Delta 10.09.2026 — Grap8-Knoten: die Verwaltungs-Knöpfe führen irgendwohin

**In `main` (PR #152).** Die „Verwaltung öffnen"-Knöpfe im
Detailfenster der Leinwand öffnen jetzt die **bestehenden nativen Ansichten** mit der
**Baustelle des Knotens**. Nichts Neues gebaut, nur verbunden. **Kein Core-Data-Delta**,
read-only.

### Der Kontrakt (Erweiterung der Brücke aus #145)
```
Web → App:  { action: 'verwaltung', ziel: 'mannschaft'|'maschinen'|'kalkulation'|'bestellung',
              auftragId: <Core-Data-Objekt-URI> }
```
Die `ziel`-Kennungen sind der Vertrag — die **Beschriftung** drüben darf sich ändern, die
Zeichenketten nicht. Swift löst die Kennung über den Store zurück in den `Auftrag`, nimmt
`auftrag.event` und präsentiert.

### Warum die Baustelle und nicht der Auftrag
Zwischen `Auftrag` und den Ressourcen gibt es **keine Beziehung** — gemessen in der
Inventur von heute früh: nur `Event.jobs` und die beiden `Voraussetzung`-Kanten zeigen auf
`Auftrag`; die Kalkulation hängt an `LVPosition`, die an `Event`. Pro Auftrag zu filtern
hieße, eine Zuordnung zu erfinden, die es nicht gibt. **Die `Auftrag ↔ LVPosition`-Frage
bleibt die aufgeschobene Kapitel-Entscheidung.**

### 🔴 Drei Messfehler im Auftrag — gegengeprüft
| Auftrag sagte | tatsächlich |
|---|---|
| `LieferantenBestelllisteView(event:)` | **`(event:positionen:)`** — braucht die LV-Positionen dazu |
| `GeraetHinzufuegenView()` global | **`let position: LVPosition`** — vom Auftrag aus unerreichbar, darum `StammdatenPflegeView()` für „Maschinen" |
| „drei/vier Panel-Buttons" | **drei**, davon einer kombiniert („Bestellung / Kalkulation"). **Aufgeteilt**, weil es zwei verschiedene Bildschirme sind — ein Knopf für beide hieße raten |

### Die Falle: eine Ansicht ohne Ausgang
`LVKalkulationView` hat **weder `NavigationStack` noch `dismiss` noch Toolbar** — sie war
für einen `NavigationLink` in `EventDetailView` gebaut. Als Blatt ohne Rahmen wäre sie eine
Sackgasse. Sie bekommt hier einen `NavigationStack` mit „Fertig"; die anderen drei bringen
ihren Rahmen selbst mit (nachgezählt: NavigationStack/dismiss/toolbar vorhanden).

Ihren **Titel** setzt sie selbst („Kalkulation (Welle 6)") — ein eigener `navigationTitle`
wäre wirkungslos gewesen und wurde nach dem ersten Screenshot wieder entfernt.

### Coordinator → SwiftUI: warum ein ObservableObject
Eine Closure im `UIViewRepresentable` veraltet, sobald die Ansicht neu gezeichnet wird —
der Coordinator hielte die alte. `Grap8Steuerung` ist eine **Klasse**, ihre Referenz bleibt
stabil. (`import Combine` nicht vergessen, sonst kennt `@Published` niemand.)

### Nachgewiesen
- Screenshots (`Grap8Kalkulation`, `Grap8Bestellung`): beide Ansichten öffnen, **„Fertig"
  erreichbar**, und die Bestellliste zeigt **„Musterhaus — Generator"** — die Baustelle
  kommt durch.
- `** TEST SUCCEEDED **`, Exit 0, Modell bitgleich.

### Nebenbefund
**`HouseProjectGenerator` erzeugt keine `LVPosition`** (0 Treffer). Bei einem generierten
Projekt ist die Bestellliste darum leer („0 Positionen"); bei einer Baustelle mit
LV-Import ist sie gefüllt. Kein Fehler der Verdrahtung — aber wer mit Demo-Daten prüft,
sieht eine leere Liste und hält sie für kaputt.

### Offen
- iPad-Test — Andreas: Knoten antippen → Knopf → richtige Ansicht, richtige Baustelle.
- „Maschinen" öffnet die **Stammdatenpflege**, nicht einen echten Maschinenpark. Eine
  Geräte-Übersicht je Baustelle gibt es nicht — wäre ein eigener Schritt.

---

## Entscheidung 09.09.2026 — „Wo lebt der Graph?" ist beantwortet (vorerst)

**Die App bleibt die Quelle. Die Box bekommt kein Graph-Gedächtnis — noch nicht.**
Getroffen von Andreas und Falbe. Kein Code, nur Festhalten — damit die Frage nicht
alle paar Wochen neu aufgemacht wird.

### Was gegen den Box-Umbau sprach (gemessen, nicht vermutet)
- **`mops-api` hat heute überhaupt kein Gedächtnis.** Alle Endpunkte sind POST: rein,
  verarbeiten, raus (`extract`, `classify`, `wandleser`, `ifc`, `gelaendebruecke`). Keine
  Datenbank für Vorgänge, nur qdrant für den RAG. „Die Box wird die Quelle" heißt darum
  nicht „ein Endpunkt", sondern **Datenbank, Schema, Migrationen, Backup, Mehrbenutzer** —
  ein neues Stockwerk, kein Kabel.
- **Die Baustelle hat kein Netz.** Die App arbeitet draußen, die Box steht im Heim-LAN.
  Wäre die Box die einzige Wahrheit, wäre die App auf der Baustelle tot. Also braucht die
  App ohnehin eine lokale Kopie — „reines A" ist gar nicht baubar.
- Das Argument „zwei Wahrheiten wie bei `isCompleted`/`status`" **trägt hier nicht**: das
  waren zwei Felder im selben Datensatz, beide beschreibbar, ohne Schiedsrichter. Eine Kopie
  mit klarer Schreibrichtung ist keine zweite Wahrheit.

### Wann die Frage wieder aufgeht
**Sobald ein Zweiter mitschauen soll** — Raphi, ein Polier. Solange nur ein Gerät auf den
Graphen sieht, ist die App-Brücke (#145) genug. Vorher ist die Diskussion theoretisch.

### Was daraus folgt
- Zurückschreiben von der Leinwand und Positionen-Merken bleiben **liegen** — beide brauchen
  einen Schreibweg, und der hinge an dieser Entscheidung.
- Die Richtung „ein Kern, viele Sichten" bleibt richtig; nur der Zeitpunkt ist später.

---

## Offen & blockiert — Finger-Test auf echter Hardware

**Blockiert, nicht vergessen: es ist kein iPad verfügbar** (Stand 09.09.2026). Der Punkt
steht seit dem ersten Grap8-Branch und ist der einzige, den kein Simulator klären kann.

**Prüfliste für den Tag, an dem ein Gerät da ist:**
1. „⋯"-Menü → „Grap8" öffnet die Leinwand **im Vollbild**, „Fertig" oben rechts erreichbar.
2. **Kneifgriff zoomt die Leinwand** — nicht die Seite. Der Seitenzoom ist per Viewport-Skript
   abgeschaltet (`Grap8View.viewportSkript`), die Geste soll React Flow gehören. **Das ist die
   eigentliche Wette hinter Grap8** und im Simulator nicht belastbar zu prüfen.
3. Ein-Finger-Ziehen verschiebt die Fläche, Knoten lassen sich einzeln ziehen.
4. Doppeltipp auf einen Knoten öffnet das Umbenennen (Tastatur verdeckt nichts Wichtiges).

Hakt Punkt 2, ist das wichtiger als jedes Feature obendrauf — dann trägt der Web-Ansatz die
Geste nicht, und das sollte man wissen, bevor mehr daran hängt.

---

## Delta 09.09.2026 — Kostengruppen im Generator: die Leinwand wird bunt

**Branch `fix/generator-kostengruppe`.** Generierte Aufträge trugen keine
`kostenGruppeNummer` → auf jedem Knoten stand „KG —", alle mit demselben Symbol.
Jetzt setzt der Generator je Gewerk eine DIN-276-KG. **Kein Core-Data-Delta.**

### 🔴 Der Befund, der den Auftrag umgestellt hat
Der Auftrag schlug vor, die KG an `AuftragTemplate` zu hängen. **Geht nicht:**
`templateFuerGewerk` kennt nur **6 der 13** Gewerke (nachgezählt) — die übrigen 7 bekämen
keine Kostengruppe. Darum eine eigene `kostenGruppeFuerGewerk(_:)` neben dem Template.

### 🔴 Und der zweite: meine eigenen Kommentare in `Grap8Graph.symbol()` waren falsch
Die Liste stammte aus #145 — **von mir, aus dem Gedächtnis geschrieben statt gegen den
Katalog geprüft**. Gegen `DIN276BaumKatalog` gemessen stimmten drei Bezeichnungen nicht:

| Nummer | stand da | heißt im Katalog |
|---|---|---|
| 352 | „Deckenbeläge/Estrich" | **Deckenöffnungen** (Estrich ist 353) |
| 336 | „Tragende Innenwände" | **Außenwandbekleidung innen** (tragende Innenwände sind 341) |
| 534 | „Zäune/Pfosten" | **Stellplätze** |

Genau der Fehler, den die Tao-Regel verbietet — plausibel geklungen, nie nachgesehen.
Korrigiert, und die Datei **musste** entgegen dem Nicht-Ziel angefasst werden: sie kannte
keine der Nummern, die der Generator jetzt setzt, alles wäre auf „Box" gefallen.

### Die Zuordnung (jede Nummer gegen `DIN276BaumKatalog` geprüft)
| Gewerk | KG | Katalog-Bezeichnung | Symbol |
|---|---|---|---|
| Erdarbeiten | 322 | Flachgründungen und Bodenplatten | Box |
| Rohbau | 331 | Tragende Außenwände | Blocks |
| Fenster & Tueren | 334 | Außenwandöffnungen | Blocks |
| Malerarbeiten | 345 | Innenwandbekleidung | Layers |
| Trockenbau | 346 | Elementierte Innenwände | Blocks |
| Estrich & Boden | 353 | Deckenbeläge | Grid2x2 |
| Ausbau | 353 | Deckenbeläge | Grid2x2 |
| Dach | 361 | Dachkonstruktionen | Home |
| Allgemein | 397 | Zusätzliche Maßnahmen | SquarePlus |
| Sanitaer | 410 | Abwasser-, Wasser-, Gasanlagen | Route |
| Heizung | 420 | Wärmeversorgungsanlagen | Route |
| Elektro | 444 | Niederspannungsinstallationsanlagen | Zap |
| Aussenanlagen | 531 | Wege | Fence |

**Benannte Notlösungen:** Ausbau teilt sich 353 mit Estrich (Fliesen und Bodenbeläge sind
beides Deckenbeläge). Allgemein (Endreinigung, Abnahme) ist kein Bauteil — 397 ist der
ehrlichste Platz. Sanitär/Heizung bekommen die **Gruppen-KG** statt einer willkürlichen
Unterposition und teilen sich `Route`: die Palette der Leinwand hat **neun** Icons und
kein einziges für Haustechnik (nachgesehen in `ICONS`, `App.jsx`).

### Nachgewiesen
- **Screenshot iPad:** 10 Aufträge, **sechs verschiedene Symbole**, überall echte
  KG-Labels, kein „KG —" mehr.
- Drei neue Tests (`GeneratorKostengruppeTests`), `** TEST SUCCEEDED **`, Exit 0. Einer
  hält die **konkrete** Gewerk→KG→Symbol-Zuordnung fest — ein Screenshot zeigt nur, *dass*
  Symbole verschieden sind, der Test sagt *welches wohin gehört*.

### Falle beim Screenshot — für die Nachwelt
`scripts/snapshot.sh` installiert die App neu, und die Neuinstallation setzt die
Mitteilungs-Berechtigung zurück → **der Systemdialog legt sich über den Screenshot**.
`xcrun simctl privacy … deny` gibt es nicht (die Aktionen sind `grant`/`revoke`/`reset`).
Weg: einmal installieren, `grant notifications`, dann starten — oder den Shot auf einem
Simulator machen, auf dem die App schon lief.

### Offen
- iPad-Test — Andreas: Hausprojekt erzeugen → Grap8 öffnen → unterscheidbare Symbole.
- Fachliche Gegenprobe der KGs — Falbe.

---

## Delta 09.09.2026 — Aufträge verknüpfen: die Ketten bekommen eine Bedienung

**Branch `feature/auftrag-verknuepfen-ui`.** Schließt den Befund aus #145: die Kanten-
Infrastruktur aus #140 stand, aber niemand konnte sie füllen — `Kausalkette.verknuepfe`
wurde nur in Tests gerufen. Jetzt gibt es „Wartet auf" in `AuftragDetailView`.
**Kein Core-Data-Delta**, keine Leinwand-Änderung.

### Was neu ist
| Stelle | |
|---|---|
| `AuftragDetailView` | Abschnitt **„Wartet auf"** — anzeigen, hinzufügen („+"), lösen (⊖) |
| `Views/VoraussetzungWaehlenView.swift` | Auswahl der möglichen Vorgänger |
| `Kausalkette.entknuepfe(_:brauchtNichtMehr:in:)` | Gegenstück zu `verknuepfe` |
| `SnapshotHostView` | vier neue Ziele für „Codis Augen" (siehe unten) |

### 🔴 Was die Tests gefunden haben — die `delete`-Falle
`context.delete(kante)` **markiert nur**. Bis der Kontext seine Änderungen verarbeitet,
steht die gelöschte Kante **weiterhin in `auftrag.voraussetzungen`**. Die erste Fassung
von `entknuepfe` zählte sie deshalb beim Neu-Nummerieren mit und vergab die
`reihenfolge` um eins verschoben; direkt nach dem Lösen sah der Auftrag seine Kante noch.
**Drei Tests fielen durch, bevor eine Zeile Produktionscode falsch in Betrieb ging.**
Behoben mit `context.processPendingChanges()` vor dem Neu-Nummerieren.

**Merksatz:** in Core Data ist ein `delete` erst nach `processPendingChanges()` oder
`save()` in den Beziehungen sichtbar. Wer direkt danach über eine Beziehung läuft,
läuft über Leichen.

### Warum die `reihenfolge` überhaupt nachgezogen wird
`verknuepfe` zieht ihre Nummer aus `voraussetzungenArray.count`. Bliebe nach dem Lösen
aus der Mitte eine Lücke (0, 2, 3 …), vergäbe die nächste Verknüpfung eine Nummer, die
es schon gibt — zwei Kanten stritten um denselben Platz. Test: `reihenfolgeBleibtLueckenlos`.

### Entscheidungen
- **Zyklus:** wird **nicht** vorab aus der Auswahlliste gefiltert. `verknuepfe` prüft und
  wirft mit einer Begründung, die **beide Auftragsnamen nennt** — die zeigt die Ansicht als
  Meldung. Einen Auftrag stumm wegzulassen wäre die schlechtere Auskunft: der Nutzer wüsste
  nicht, warum er fehlt.
- **Bei Fehler `ctx.rollback()`**, damit keine halbe Kante im Kontext hängenbleibt.
- **`istKante`-Filter** überall: manuelle Geschoss-Häkchen (Welle 9) tauchen im Abschnitt
  nicht auf und werden von `entknuepfe` nicht angefasst. Heute hängt zwar keins an einem
  Auftrag (`HierarchieHelfer` setzt nur `v.geschoss`) — der Filter hält es auch dann
  richtig, wenn das jemand ändert. Test: `manuellesHaekchenBleibtUnberuehrt`.
- **Eine Quelle für „wer ist wählbar":** `AuftragDetailView.moeglicheVorgaenger(fuer:)`
  füttert Liste **und** „+"-Knopf (der ist aus, wenn niemand übrig ist).

### Nachgewiesen — mit „Codis Augen", nicht mit Prüfmarkern
`scripts/snapshot.sh <Ziel> <Name>`, vier neue Ziele in `SnapshotHostView`:
| Ziel | zeigt |
|---|---|
| `Voraussetzungen` | „Wartet auf" mit zwei Vorgängern: grüner Haken (fertig) / orange Uhr (läuft) |
| `VoraussetzungWahl` | die Auswahlliste |
| `VoraussetzungZyklus` | die Kreis-Meldung — Text aus einem **echten** fehlgeschlagenen Versuch |
| `Grap8Kette` | **die Leinwand mit der Kante**: grüner Pfeil vom fertigen Vorgänger, orange gestrichelt vom laufenden, Zähler „1 wartet" |

`** TEST SUCCEEDED **`, `xcodebuild`-Exit 0, alle 15 `KausalketteTests` grün.

> **Für die nächste Instanz:** UI-Nachweise gehören **nicht** in selbstgebaute Prüfmarker.
> `scripts/snapshot.sh` + `App/SnapshotHostView.swift` („Codis Augen") ist der Weg —
> Ziel eintragen, Skript rufen, PNG in `/tmp/imops-shots`. Ich habe das an einem Tag
> zweimal von Hand nachgebaut, bevor ich es gefunden habe.

### Offen
- Kostengruppen beim Erzeugen setzen (`HouseProjectGenerator`) — auf der Leinwand steht
  sonst „KG —" und alles trägt dasselbe Symbol.
- iPad-Test — Andreas: zwei Aufträge verknüpfen, auf der Leinwand die Kante sehen.
- Zurückschreiben *von* der Leinwand: weiterhin bewusst offen.

---

## Delta 09.09.2026 — Grap8 zeigt echte Aufträge (App-Brücke, nur lesen)

**Branch `feature/grap8-echte-daten`.** Die Leinwand zeigt die Aufträge einer Baustelle
aus Core Data statt der Beispieldaten. **App-intern über `WKScriptMessageHandler`** —
kein Netz, keine Box, offline-fest. **Kein Core-Data-Delta** (`git diff main` auf die
Modelldateien ist leer), **kein Zurückschreiben**.

> Zweig-Hinweis: dieser Branch kommt von `main` und kennt darum den Vollbild-Umbau aus
> PR #144 (`feature/grap8-vollbild`) noch nicht — dort wird aus dem Blatt ein Vollbild.
> Andere Dateien, kein Konflikt zu erwarten; wer zuerst gemergt wird, ist egal.

### Der Brücken-Kontrakt (beide Seiten müssen zusammenpassen)
| Richtung | |
|---|---|
| Web → App | `postMessage({action:'ready'})`, sobald `window.grap8SetGraph` steht |
| App → Web | `window.grap8SetGraph({baustelle, nodes, edges})` |

**Warum die Leinwand fragt statt die App einfach zu schicken:** `didFinish` feuert, wenn
das *Dokument* geladen ist — React kann dann noch nicht gemountet sein. Ein Aufruf zu früh
liefe ins Leere, und zwar stillschweigend. Also klingelt die Seite, wenn sie bereit ist.
Auf der Web-Seite steht darum das Aufhängen des Briefkastens **vor** dem Klingeln.

### 🔴 Zwei Befunde, die größer sind als dieser Branch
1. **Die App kann keine Kausalketten anlegen.** `Kausalkette.verknuepfe` wird
   **ausschließlich in Tests** gerufen — `grep` über das ganze Repo. Die Kanten-
   Infrastruktur aus #140 (`Voraussetzung.quelle`/`.auftrag`) steht, aber es gibt keine
   Bedienung, um zwei Aufträge zu verknüpfen. **Folge:** die Leinwand zeigt heute Kästen
   ohne Pfeile — im Simulator nachgemessen: 9 Aufträge, **0 Kanten**, alle „startklar".
   Das ist kein Fehler der Brücke, das ist die Antwort auf die Frage, die dieser Branch
   stellen sollte. **Der nächste sinnvolle Schritt ist die Verknüpfen-Bedienung, nicht
   mehr Leinwand.**
2. **`HouseProjectGenerator` setzt keine `kostenGruppeNummer`.** Darum steht auf jedem
   Kasten „KG —" und alle tragen dasselbe Symbol. Die Symbol-Zuordnung nach KG ist
   gebaut und wartet auf Daten.

### v1-Notlösungen (bewusst, alle im Code vermerkt)
| Stelle | Lösung | Warum |
|---|---|---|
| Auftragsname | `Kausalkette.bezeichnung()` → `processingDetails` | `Auftrag` hat **kein** Namensfeld; „Auftrag anlegen" schreibt `taskSummary` dorthin |
| Kennung | Core-Data-Objekt-URI | `Auftrag` hat **keine** `id` (anders als `Voraussetzung`) |
| `onHold` | → `inArbeit` | die Leinwand kennt nur offen/inArbeit/erledigt |
| `anf` (Chips) | leer | im Modell steht nicht, welcher Auftrag Material/Mensch/Maschine braucht |
| Anordnung | Ketten in Spalten nach Tiefe, **Freistehende im 4er-Raster** | erste Fassung setzte alles in Spalte 0 — neun Aufträge, neun Zeilen, endlose Kolonne (im Simulator gesehen und behoben) |
| Baustelle | Auswahlliste beim Öffnen | Grap8 kommt aus dem „⋯"-Menü der **Liste**, es gibt keine Baustelle im Kontext. „Die erste nehmen" wäre Willkür; die Liste zeigt die Auftragszahl je Baustelle. `Grap8View(event:)` nimmt eine Baustelle entgegen, falls Grap8 später aus einer Baustelle heraus geöffnet wird |

### Nur Ansicht — und das steht auch da
Klicks auf der Leinwand ändern Core Data **nicht**. Damit das niemanden überrascht,
schreibt die Leinwand im Brückenmodus „aus der App geladen · nur Ansicht" in ihre
Kopfzeile; „Beispiel"/„Leeren" sind dort ausgeblendet (sie würden die echten Aufträge
wegwerfen) und `localStorage` ist abgeschaltet — ein alter Browserstand darf die echten
Daten nicht überschreiben. **Standalone im Browser bleibt alles wie vorher.**

### Nachgewiesen
- **Screenshot iPad Pro 13" (Simulator):** neun echte Aufträge („Rohbau – Neubau
  Einfamilienhaus" usw.), echter Baustellenname in der Kopfzeile, „nur Ansicht"-Hinweis.
- `** TEST SUCCEEDED **`, `xcodebuild`-Exit 0; iPad-Build `** BUILD SUCCEEDED **`.
- Dafür standen zwei **Prüfmarker** im Code (Grap8 automatisch öffnen, größte Baustelle
  vorwählen) — **beide zurückgenommen**, per `grep` gegengeprüft.
- `app_bedienung.yaml`: Eintrag `App_Grap8_Leinwand` ergänzt (Drift-Regel aus CONTRIBUTING).

### Offen
- **Verknüpfen-Bedienung** — ohne sie bleibt Grap8 eine Kästchen-Sammlung. Siehe Befund 1.
- Kostengruppen beim Erzeugen setzen. Siehe Befund 2.
- Finger-Test auf echtem iPad — Andreas.
- Zurückschreiben, Positionen merken, Anforderungs-Chips: alles bewusst nicht in diesem Branch.
## Delta 09.09.2026 — Grap8 im Vollbild statt im Blatt

**Branch `feature/grap8-vollbild`.** Eine Zeile Präsentation, sonst nichts.
`Grap8View`, das `grap8://`-Schema und `Grap8Web/` sind **unangetastet**, kein Core-Data-Delta
(`git diff main` auf die Modelldateien ist leer).

### Was geändert ist
`ContentView.swift`: `.sheet(isPresented: $showingGrap8)` → **`.fullScreenCover`**,
`.presentationSizing(.page)` entfällt. Der Menüpunkt „Grap8" im „⋯"-Menü bleibt, wo er war.

### Warum kein zweiter Schließen-Knopf nötig war
`Grap8View` bringt seit Schritt 1 einen eigenen `NavigationStack` mit „Fertig" in
`.confirmationAction` mit, der über `@Environment(\.dismiss)` schließt. Das wirkt bei
`fullScreenCover` genauso wie beim Blatt, und die Navigationsleiste sitzt im sicheren Bereich.
**Wichtig für später:** ein Vollbild lässt sich **nicht wegwischen** — dieser Knopf ist die
einzige Tür zurück. Wer die Werkzeugleiste aus `Grap8View` entfernt, sperrt den Nutzer ein.

### Nachgewiesen (nicht vermutet)
- **Sicht-Nachweis auf dem iPad Pro 13" (Simulator):** Screenshot zeigt die Leinwand ganzflächig,
  keinen Blatt-Rand, „Fertig" oben rechts unterhalb der Statusleiste. Dafür stand `showingGrap8`
  vorübergehend auf `true` — **zurückgenommen**, per `rg` gegengeprüft.
- `** TEST SUCCEEDED **`, `xcodebuild`-Exit **0**, iPad-Build `** BUILD SUCCEEDED **`.

### Falle beim Messen — für die Nachwelt
Der erste Testlauf lief durch `| tail -40`. Das meldete Exit 0 — aber das war der Exit-Code von
`tail`, nicht von `xcodebuild`, und `** TEST SUCCEEDED **` stand weiter oben im Log und wurde
vom `tail` abgeschnitten. **Ein grüner Exit-Code hinter einer Pipe ist kein Nachweis.**
Zweiter Lauf ohne Pipe, Ausgabe in eine Datei, Exit-Code direkt gelesen.

### Offen
- **Finger-Test auf echtem iPad** (Kneifzoom + Ziehen) — Andreas. Unverändert offen.
- Datenbrücke bleibt Nicht-Ziel bis zum Design-Gate „wo lebt der Graph".

---

## Delta 08.09.2026 — Grap8 als Fenster in der App (WKWebView, Schritt 1)

**Branch `feature/grap8-webview`.** Die Web-Leinwand läuft **gebündelt** in der App.
Kein SwiftUI-Nachbau, **keine** Datenbrücke, **kein** Core-Data-Delta. Die Leinwand zeigt
ihre eigenen Beispieldaten.

### Was neu ist
| Stelle | |
|---|---|
| `Grap8Web/` (Repo-Wurzel) | gebaute Leinwand, als **Folder Reference** im Bundle |
| `Views/Grap8View.swift` | `UIViewRepresentable` um eine `WKWebView` + Auslieferung aus dem Bundle |
| `ContentView` | Toolbar-Knopf „Grap8" → Blatt, gleiches Muster wie der Hausplaner daneben |
| `scripts/grap8-bauen.sh` | baut `~/Projekte/grap8-canvas` neu nach `Grap8Web/` |
| `~/Projekte/grap8-canvas/vite.config.js` | `base: './'` (liegt außerhalb des Repos) |

### Zwei Fallen — beide im Simulator nachgemessen, nicht vermutet
**1. Die synchronisierte Xcode-Gruppe klopft Unterordner flach.** Belegt am bestehenden
Bundle: `Resources/scharpegge_katalog.csv` liegt darin im Wurzelverzeichnis, es gibt kein
`Resources/` und kein `Knowledge/`. `ExactMatchKnowledge.locateYAML` fängt das mit einem
zweiten Versuch ab — für die Leinwand geht das nicht, `index.html` sucht `./assets/…` als
echten Unterordner. Darum liegt `Grap8Web` **außerhalb** des Quellordners und ist von Hand
als Folder Reference (`lastKnownFileType = folder`) in `project.pbxproj` eingetragen.

**2. `loadFileURL` ergibt einen weißen Schirm — und meldet nichts.** Vite baut
`<script type="module">`. Ein Modul hat über `file://` die Herkunft `null`, die CORS-Prüfung
verwirft es **stillschweigend**: das Hauptdokument lädt sauber durch (im Log
`ProgressTracker::progressCompleted … isMainLoad 1`), `didFail` feuert nie, die Seite bleibt
leer. Der Auftrag sah `loadFileURL` vor — das trägt nicht.
**Ersetzt durch ein eigenes Schema:** `Grap8BundleHandler` (`WKURLSchemeHandler`) liefert
den Bundle-Ordner unter `grap8://leinwand/` aus. Damit hat die Leinwand eine echte Herkunft,
Module laden normal, und es geht **kein Byte ins Netz** — geprüft: in `Grap8Web` stehen nur
XML-Namensräume und ein Attributionslink, nichts wird nachgeladen.

### Nachgewiesen
- Bundle-Struktur erhalten: `…app/Grap8Web/assets/index-*.js` liegt als Unterordner drin.
- Leinwand läuft im iPad-Simulator: Knoten, Kanten, Bausteine-Palette, Detail-Seitenleiste,
  Zoom-Steuerung, Minikarte. Screenshot beim Auftrag.
- `** TEST SUCCEEDED **` (Unit-Suite), Build grün.

### Offen
- **Fingertipp-Weg ungeprüft.** Der Simulator lief hier headless, der Menüpunkt wurde nicht
  angetippt — das Blatt wurde zum Prüfen vorübergehend automatisch geöffnet (zurückgenommen).
  Auf dem iPad rutscht „Grap8" wie Demo/Hausplaner/+ ins „⋯"-Überlaufmenü. **Andreas testet.**
- **Kneifgriff auf echter Hardware.** Seitenzoom ist per Viewport-Skript abgeschaltet, die
  Geste gehört React Flow. Im Simulator nicht belastbar zu prüfen.
- **Datenbrücke** bleibt Nicht-Ziel: erst Design-Gate „wo lebt der Graph", dann entweder
  `WKScriptMessageHandler` oder — bevorzugt — beide Seiten über die Box-Graph-API.
- `Grap8Web/` ist **Bauergebnis im Repo**. Bewusst so: sonst baut die App nicht ohne das
  Web-Projekt daneben. Nach jeder Änderung `scripts/grap8-bauen.sh` laufen lassen.

---

## Delta 08.09.2026 — eine Quelle für „fertig" (`status` schlägt `isCompleted`)

**Branch `refactor/auftrag-status-eine-quelle`.** Löst die Grap8-Krücke ab.
**Kein Schema-Delta** — `.xcdatamodel` bitgleich gegen `main` (belegt per `git diff`).

### Was auseinanderlief — vollständig, nicht wie beim ersten Anlauf
| Stelle | setzte |
|---|---|
| `addStep` · `toggleStep` · `deleteStep` · `applyTemplate` · Checkliste leeren | **nur `isCompleted`**, nie `status` |
| `resetCompletion()` | `isCompleted = false`, **`status` blieb `.completed`** — „geöffnet" und gleichzeitig fertig |
| `EditJobView` | Status **und** Häkchen als **getrennte Eingabefelder** — der Nutzer konnte sie widersprüchlich setzen |
| `AuftragRowView.setStatus` | `isCompleted = true` **nur beim Fertigsetzen, nie zurück** — ein Auftrag, der wieder auf `.pending` ging, blieb im Flag „fertig" |
| `markJobCompleted` · `JobViewModel` · `AddJobViewModel` · `DemoSeeder` | beide, konsistent |

**`AuftragRowView` ist mir beim ersten Durchgang entgangen** — mein eigener `grep`-Filter
(`grep -v "== "`) hat die Zeile weggeworfen, weil sie zufällig ein `==` enthielt. Gefunden
erst bei der Abschluss-Gegenprobe **ohne** selbstgebauten Filter. Merksatz: der Filter, der
die Suche übersichtlich macht, ist der, der den Fund versteckt.

**`EditJobView` war die schlimmste Quelle:** zwei Bedienelemente für einen Zustand.

### Wie es jetzt aussieht
- **`Auftrag.istFertig`** (`status == .completed`) ist **die eine Stelle**, die die Frage
  beantwortet. Alle Leser darauf umgestellt — 24 Fundstellen in 7 Dateien, plus Grap8.
- **Der `status`-Setter zieht `isCompleted` mit.** `statusRawValue` wird nirgends sonst
  geschrieben (geprüft) — damit ist der Setter die einzige Tür, und *jeder* bestehende
  `job.status = …`-Pfad wird automatisch konsistent, ohne ihn anzufassen.
- **`setzeFertig(_:)`** für Pfade, die „fertig/nicht fertig" ausdrücken. „Nicht fertig"
  stuft **nur herab, was fertig war**: ein Auftrag auf `.pending` bleibt `.pending`, wenn
  jemand einen Checklistenpunkt anlegt. Ziel beim Öffnen ist `.inProgress` — so hat es
  `KausalbauketteView` beim Umschalten schon immer gemacht.
- **`isCompleted` bleibt** als Legacy-Feld (Schema unverändert), wird aber von keinem Pfad
  mehr direkt geschrieben. Rauswerfen braucht V3 → eigener Branch.
- **Drei NSPredicates** (`EmployeeDetailView`, `CrewPlanningView` ×2) mussten auf
  `statusRawValue` statt `isCompleted` — **ein Prädikat kann keine computed property sehen.**
  Wer `istFertig` in einen Fetch schreibt, bekommt einen Laufzeitfehler.

### Backfill
`Models/AuftragFertigMigration.swift`, im Boot-Pfad neben `HierarchieMigration`.
**Konfliktregel konservativ:** fertig ⇔ `status == .completed` **ODER** `isCompleted == true`.
Nimmt also niemandem einen Haken weg.

Kein `UserDefaults`-Flag wie bei `ZuschlagMigration`, mit Absicht: das **Prädikat holt nur
die widersprüchlichen Datensätze** — im Normalfall werden gar keine Objekte geladen. Damit
ist der Lauf billig, idempotent *by design* und selbstheilend, falls doch je wieder etwas
auseinanderläuft. Anzahl wird geloggt.

### Offen
- **`isCompleted` wirklich entfernen** — braucht eine neue Modellversion (V3) und damit
  PR #141 als Basis. Eigener Branch, ausdrücklich nicht hier.
- **`EditJobView` zeigt weiter ein Fertig-Häkchen.** Es schreibt jetzt über `setzeFertig`
  auf den Status, ist also nicht mehr widersprüchlich — aber ein zweites Bedienelement für
  etwas, das der Status-Picker daneben schon sagt. UI-Frage, kein Datenproblem.

---

## Delta 08.09.2026 — Grap8 Branch 1: die Kausalkette bekommt einen Datenkern

**PR #140, in `main`.** Reiner Datenkern + Logik + Tests. **Keine UI** — die Leinwand
kommt in einem späteren Branch (Nicht-Ziel des Auftrags).

> ⚠️ **Wer nach `Voraussetzung.quelle` im Modell sucht: die steht in `test25B 2.xcdatamodel`,
> nicht in `test25B.xcdatamodel`.** Seit der Versionierung (nächster Abschnitt) ist V2 die
> aktuelle Version; V1 ist bewusst der Stand davor.

### Der Befund, der vorher stand
`Views/KausalbauketteView.swift` **gibt es schon** — aber die Kette darin ist **fest
verdrahtet**: drei Glieder, und die Zuordnung läuft über Textsuche in `processingDetails`
(`"bauzaun"`, `"baustrom"`, `"bauwasser"`). Das ist keine Graph-Struktur, sondern eine
Annahme über Auftragsnamen. Branch 1 legt darunter die echten Kanten — die View bleibt
vorerst unangetastet.

Ebenso vorher geprüft: **eine eigene `Schritt`-Entity gibt es nicht.** Der `Auftrag` *ist*
der Schritt. Es wurde keine neue Entity erfunden.

### Modell (additiv, in-place wie im Repo üblich)
| Relation | | |
|---|---|---|
| `Voraussetzung.quelle -> Auftrag` | optional, maxCount 1 | der Schritt, der zuerst fertig sein muss |
| `Voraussetzung.auftrag -> Auftrag` | optional, maxCount 1 | der abhängige Schritt |
| `Auftrag.istVoraussetzungFuer` | to-many, **Cascade** | Kanten, in denen er die Quelle ist |
| `Auftrag.voraussetzungen` | to-many, **Cascade** | Kanten, auf die er wartet |

`geschoss -> Geschoss` **bleibt unberührt**: eine Voraussetzung ohne `quelle` ist weiter
das manuelle Welle-9-Häkchen und richtet sich nach dem gespeicherten `erfuellt`.

**Warum Cascade und nicht Nullify:** eine Kante, deren Auftrag gelöscht wurde, fiele auf
`erfuellt` (Default NO) zurück und blockierte den Nachfolger **für immer** — ein Geist,
den niemand mehr abhaken kann. Ein Test hält das fest.

### Logik: `Service/Kausalkette.swift`
Nichts davon wird persistiert — Startbarkeit ist immer live gerechnet, wie beim
Welle-9-Rollup in `Hierarchie+Status.swift`. Kein zweiter Zustand, der veralten kann.

- `Voraussetzung.istErfuellt` — mit `quelle`: ist der Vorgänger fertig? Ohne: `erfuellt`.
- `Auftrag.istStartbar` / `.offeneVoraussetzungen` / `.vorgaenger`
- `Kausalkette.verknuepfe(_:brauchtVorher:in:)` — legt die Kante an und **wirft**, wenn
  ein Kreis entstünde (Tiefensuche rückwärts über die `quelle`-Kanten).

### Die Entscheidung, die man kennen muss: was heißt „fertig"?
`isCompleted` und `status` sind **zwei Felder für dieselbe Aussage** und liefen im Bestand
auseinander. Darum zählte hier **jedes von beiden** als fertig — eine Krücke.

> **✏️ Korrektur (08.09., beim Aufräumen).** Hier stand: „`JobViewModel` setzt beide,
> `AuftragDetailView:367` setzt nur `status`". **Das war falsch herum.**
> `markJobCompleted()` setzte sehr wohl beide. Die echte Divergenz saß in den
> Checklisten-Aktionen (`addStep`, `toggleStep`, `deleteStep`, `applyTemplate`), die
> **nur `isCompleted`** setzten und nie `status` — und in `resetCompletion()`, das den
> Auftrag öffnete, `status` aber auf `.completed` stehen ließ. Dazu bot `EditJobView`
> beides als **getrennte Eingabefelder** an.
> Die Krücke war also nötig, nur die Begründung war vertauscht. Aufgefallen erst, als
> für die Ablösung wirklich jede Fundstelle durchgegangen wurde.

**Abgelöst am 08.09.** durch `Auftrag.istFertig` — siehe eigenen Eintrag unten.

### Nachweis
**11 Tests** in `KausalketteTests.swift`, alle namentlich grün (Nudel-Test, direkter und
transitiver Zyklus, Selbstbezug, Kompatibilität der Geschoss-Voraussetzung, Löschregel).
Build grün, ganze Unit-Suite `TEST SUCCEEDED`. Der gezielte Einzellauf war Absicht: die
Sammelmeldung sagt nicht, ob ein Test **gelaufen** oder nur nicht fehlgeschlagen ist.

### Offen / für den Statik-Blick
- **Migration.** Das Modell hat weiterhin **nur eine Version** (kein `.xccurrentversion`),
  wie bei allen bisherigen Modelländerungen im Repo (zuletzt Entity `Bautagesbericht`).
  Lightweight Migration ist im `PersistenceController` eingeschaltet, aber für ein
  *inferiertes* Mapping braucht Core Data das **Quellmodell** — das es ohne Versionierung
  nicht mehr gibt. Auf einem Gerät mit Altbestand kann das erste Öffnen deshalb scheitern
  (`fatalError` in `loadPersistentStores`). Im Simulator/Neubau fällt das nicht auf.
  **Nicht eigenmächtig geändert** — eine zweite Modellversion einzuführen ist eine
  strukturelle Entscheidung für Andreas, kein Nebenbei-Commit.
- **Doppelte Kanten** werden nicht verhindert (zweimal dieselbe Verknüpfung ist erlaubt).
  Harmlos für die Rechnung, unsauber in der Liste. Bewusst außerhalb des Auftrags gelassen.
- **Keine Ableitung aus Statik/Geometrie** — nur der Kanten-Mechanismus, wie beauftragt.
## Delta 08.09.2026 — Fundament: das Datenmodell ist jetzt versioniert

**Branch `fix/coredata-model-versioning` (PR #141).** Aufgesetzt **nach** dem Merge von
PR #140 — und dadurch schärfer geworden als geplant (siehe „Die Reihenfolge").

### Warum das nötig war
Core Data kann eine Migration nur **inferieren**, wenn das alte Modell noch als eigene
Version im Bundle liegt. `test25B.xcdatamodeld` enthielt **genau eine** Version und keine
`.xccurrentversion` — es gab kein „von-Modell". Auf einem Gerät mit Altdaten kann das erste
Öffnen nach einem Update deshalb hart scheitern (`fatalError` in `loadPersistentStores`).
**Im Simulator fällt das nie auf**, weil dort neu installiert wird. Das galt für *alle*
bisherigen Modelländerungen, zuletzt Entity `Bautagesbericht` — kein Grap8-Problem.

### Wie die zwei Versionen belegt sind
| Version | Inhalt | |
|---|---|---|
| `test25B.xcdatamodel` (V1) | Stand **vor** Grap8 (`42f4e32`) | das Modell, das auf einem Gerät mit Altdaten liegt |
| `test25B 2.xcdatamodel` (V2) | Stand **mit** Grap8 (= `main`) | **current** |

Beides bitgleich gegen die jeweiligen git-Stände geprüft. **Kein Schema-Inhalt erfunden** —
V2 ist exakt `main`, V1 exakt der Vorgänger.

### Die Reihenfolge — was passiert ist und warum es besser wurde
Geplant war: erst versionieren (V1 == V2 bitgleich), dann PR #140 mergen und dessen
Relationen nach V2 schieben. Gemergt wurde **#140 zuerst**. Statt einer Nacharbeit ergibt
das denselben Zielzustand in einem Zug — mit einem Gewinn: weil V1 und V2 sich jetzt **echt
unterscheiden**, ist die Migration nicht nur strukturell vorbereitet, sondern **nachweisbar**.

⚠️ **Die Falle dabei war real:** nach dem Merge von `main` in diesen Branch stand Grap8 in
**V1**, während **V2** (current) es nicht hatte. Die App hätte ein Modell ohne die neuen
Relationen geladen — `@NSManaged var quelle` ins Leere, bei grünem Build und grünem Merge.
Genau dagegen steht jetzt ein Test.

### Nachweis
`ModellVersionierungTests.swift`:

| Test | prüft |
|---|---|
| `momdEnthaeltMehrAlsEineVersion` | es gibt überhaupt ein von-Modell |
| `geladenesModellIstDieAktuelleVersion` | `Persistence.swift` lädt per `.momd`-URL die *current*-Version |
| `migrationVonDerAltenZurAktuellenVersionIstInferierbar` | **der eigentliche Nachweis:** `NSMappingModel.inferredMappingModel` von V1 nach V2 gelingt |
| `aktuelleVersionTraegtDieKausalketteAusPR140` | die Grap8-Relationen stehen in der **current**-Version, nicht in der alten |

**Der Migrationstest kommt ohne Store aus** — `inferredMappingModel` arbeitet rein auf
Modellebene, kein Coordinator, keine Objekte.

Alle vier namentlich grün, ganze Unit-Suite `TEST SUCCEEDED`. Der Migrationstest ist
**scharf**, weil V1 und V2 sich echt unterscheiden — bei bitgleichen Versionen hätte er
nichts geprüft.

### Ein Test wurde gebaut und wieder entfernt
Ein Test, der einen echten SQLite-Store mit V1 anlegt und mit dem aktuellen Modell öffnet,
lief **isoliert grün** und hat in der vollen Suite **reihenweise fremde Tests umgeworfen**,
mit wechselnden Opfern. Crash-Report:

```
-[NSManagedObject initWithEntity:insertIntoManagedObjectContext:]
Event.init(entity:insertInto:)
```

Genau das, wovor `Persistence.swift` warnt: das Modell wird dort **absichtlich genau einmal**
geladen, weil zwei Modelle im selben Prozess doppelte `NSEntityDescription`s für dieselbe
Subklasse ergeben — und **Swift Testing fährt Suites parallel**. Die Entities der Kopien auf
`NSManagedObject` umzubiegen hat **nicht** gereicht. Sauber ginge es nur in einem eigenen
Test-Target. Begründung steht in der Testdatei, damit der Nächste nicht dieselbe Runde dreht.

### Offen — ehrlich, kein stilles „erledigt"
**Das Öffnen eines echten, gewachsenen Altbestands ist nicht getestet.** Der Test zeigt, dass
die Migration *inferierbar* ist; ob sie auf einem Gerät mit Jahresdaten auch durchläuft, sagt
er nicht. **Manuell zu prüfen:** App mit Datenbestand installieren, Update einspielen, prüfen
dass sie **ohne Reset** startet.


## Delta 07.09.2026 (nachmittags) — IFC-Leser in der App (PR #138, in `main`)

Gegenstück zu **mops-api #52**. Der Endpunkt `POST /ifc/analyse` lag auf der Box, die App wusste
nichts von ihm — damit war es ein Werkzeug für den Server und keins für die Baustelle.

**Neu `Views/IFCLeserView.swift`** — Datei wählen, auswerten, Ergebnis. Upload nach demselben
Muster wie der Wand-Leser (`MopsConfig.host`, multipart, `ServerFehlertext`). Einstieg als
**„IFC auswerten (SketchUp)"** im Baustellen-Menü.

### Die Reihenfolge in der Ansicht ist eine Entscheidung
| | |
|---|---|
| **Volumen zuoberst** | Mauerwerk wird nach m³ bestellt, nicht nach m² |
| **Herkunft unter jeder Menge** | grün „aus dem Modell" (Qto) gegen orange „gerechnet" (aus Maßen geschätzt) |
| **`KG offen` in Orange** | damit ungeklärte Kostengruppen nicht als erledigt durchgehen |
| **Warnung bei fehlender Einheit** | dann sind die Werte Rohwerte, keine Meter — wie `$INSUNITS` beim DXF |
| **„Nicht als Bauteil gewertet"** | Beschriftungen werden ausgewiesen, nicht verschluckt |

**Die Herkunftszeile ist wichtiger als die Zahl daneben.** SketchUp exportiert meist keine Base
Quantities — dann steht überall „gerechnet", und das muss man sehen, bevor man danach bestellt.

Alle Felder der Antwort sind **optional dekodiert**: Der Server ist ehrlich, wenn er etwas nicht
weiß (`einheit_bekannt: false`, `kg: "offen"`). Ein Decoder, der auf Vollständigkeit besteht,
würde genau diese Ehrlichkeit in einen Parse-Fehler verwandeln.

Bedienungshilfe mitgezogen (Drift-Regel), 6 Aliase.

### Offen
- **Keine Übernahme ins LV.** Die Ansicht zeigt die Mengen, schreibt sie nicht in Positionen.
  Das braucht eine Entscheidung, wie Kostengruppe und LV-Position zusammenfinden.
- **Noch kein Lauf gegen die echte Box:** `/ifc/analyse` ist dort erst nach
  `sudo systemctl restart mops-api` erreichbar. Bis dahin bekäme die App einen 404.

---

## Delta 07.09.2026 — Bautagesbericht wird zum Tagebuch (PR #137, in `main`)

**In `main` (PR #137).** Vier Commits, Build und Unit-Suite grün.

### Was vorher war
Der Bautagesbericht war ein **Generator**, kein Tagebuch: alle Felder lagen in `@State`,
nach dem PDF war der Bericht weg. Es gab keinen Datensatz, nur ein Dokument. Und der
Exporter zog Aufträge, LV und Mängel **live** aus dem Event — ein Bericht vom Juli hätte
beim Nachdrucken die Mängelzahlen von heute gezeigt.

### Was jetzt steht

| | |
|---|---|
| **Entity `Bautagesbericht`** | im Modell, Relation zu `Event` exakt wie `Mangel`; `@objc(Bautagesbericht)` + Category-Files, Codegen bleibt Manual/None |
| **Speichern** | Button heißt „Speichern & PDF" — erst Datensatz, dann PDF **daraus**, damit beide nicht auseinanderlaufen |
| **Snapshot** | Aufträge, LV-Positionen und Mängel werden beim Speichern **eingefroren** |
| **Historie** | `BautagesberichtListeView`, neuester zuerst, Leseansicht + „Als PDF" mit den Zahlen von damals |
| **Freigabe** | setzt `gesperrtAm`/`freigegebenVon` aus `FirmenSettings.name` — dieselbe Quelle wie die Welle-9-Ampel |
| **Korrektur** | neuer Bericht mit `korrigiertVonID`, Original bleibt unberührt |

### Der Kern in einem Satz
Ein Bautagesbericht weist einen bestimmten Tag nach. Zöge er seine Zahlen beim Drucken
frisch aus der Baustelle, schriebe die App still die Vergangenheit um. **Deshalb wird
einmal gezählt, beim Speichern** — und ein Test beweist es:

```
Bericht speichern            → snapMaengel == 2
danach neuen Mangel anlegen  → Baustelle hat 3
alter Bericht                → zeigt weiter 2
```

7 Tests in `BautagesberichtTests.swift`, eigener In-Memory-Stack je Test wie in
`AufmassTests`. Mit dabei: die Inverse greift in beide Richtungen (stimmte sie nicht,
bliebe die Liste stumm leer und der Zähler stünde auf 0), und die Zahl überlebt
`refreshAllObjects` samt Neuladen.

### Über den Auftrag hinaus
Der Exporter listete nicht nur Zahlen, sondern auch die **einzelnen** Aufträge und Mängel —
live. Bei einem gespeicherten Bericht zeigt er jetzt nur die eingefrorenen Zahlen mit dem
Satz „Diese Zahlen wurden beim Speichern festgehalten und ändern sich nicht mehr."
Eine Mängelliste von heute in einem Bericht vom Juli wäre derselbe Fehler eine Ebene tiefer.

### Drift-Regel eingehalten
`Resources/Knowledge/app_bedienung.yaml` hat einen eigenen Eintrag bekommen (10 Aliase):
Ablauf, warum der Knopf „Speichern & PDF" heißt, Historie, Freigabe, Korrektur — samt der
Begründung, warum das Bearbeiten dort **nicht** geht.

### Offen
- **Gemergt (PR #137).** Der Falbe-Blick auf Snapshot-Korrektheit und Sperr-Logik steht weiterhin aus —
  er war als Bedingung gedacht, der Merge kam vorher.
- **Inhaltlich fehlt noch** (VOB-typisch, war nicht im Auftrag): Materiallieferungen/Wareneingang
  als eigenes Feld, Personalstärke je Gewerk statt einer Gesamtzahl, Fotodokumentation am Bericht.
- **Hash-Ketten-Manipulationssicherheit** (HACCP-Muster) bleibt der optionale Ausbau danach —
  bewusstes Nicht-Ziel für v1.
- Die Freigabe nutzt `FirmenSettings.name`. Ist der leer, sagt der Dialog das ausdrücklich,
  gibt aber trotzdem frei. Ob das reicht, muss die Praxis zeigen.

---

## Delta 26.08.2026 (abends) — Lernliste im Import (PR #134, in `main`)

Gegenstück zu mops-api PR #46. Der Server meldet jetzt, wo Raphis Zeichnung eine
Güte führt, die es beim Lieferanten nicht gibt — die App zeigte das bisher nicht an,
die Position bekam einfach keine Material-Nummer.

**Neu im Import-Bildschirm** (`Views/MateriallisteView.swift`), über den Hinweisen:

```
Bezeichnungen, die der Bestellschein nicht kennt

17,5 cm    Zeichnung: PPW 4-0,50     Vordruck: PPW 4-0,60 · PPW 6-0,65
24 cm      Zeichnung: PPW 4-0,55     Vordruck: PPW 2-0,35 · 2-0,40 · 4-0,50 · 6-0,65
36,5 cm    Zeichnung: PPW 4-0,55     Vordruck: PPW 2-0,35 · 2-0,40 · 4-0,50 · 6-0,65

[Als Text kopieren]
```

### Entscheidungen

- **Kein Fehler-Rot.** Der Import ist gelungen; nur diese Positionen bekommen keine
  Nummer, weil die Bezeichnung beim Lieferanten nicht existiert. Orange = Rückfrage.
- **Kopieren statt Mail.** Der Text geht an den, der die Zeichnung gebaut hat —
  über welchen Kanal, entscheidet der Nutzer.
- **`lernliste` optional dekodiert.** Gegen einen Server ohne den Fix verhält sich der
  Bildschirm exakt wie vorher, statt den ganzen Import mit einem Decoding-Fehler zu killen.

⚠️ Der Vordruck schlägt die Zeichnungsdatei — **umgelenkt wird nichts.** Von `4-0,55`
auf `4-0,50` zu raten läge nahe und stimmte meistens; im Ausnahmefall kommt der falsche
Stein auf die Baustelle. Details im mops-api-HANDOFF.


### Aufgeräumt am 26.08. abends

`main` ist der einzige Branch. **13 gemergte Branches gelöscht** — es lag nichts
Unfertiges darin, alle Inhalte waren in `main`. Wer hier eine alte Branch-Referenz in
einem Dokument findet: sie ist Geschichte, nicht Arbeitsvorrat.

DSGVO-Prüfung vor dem Klonen durch Raphi: sauber. Die `aura125`-Fundstellen in `docs/`
sind **Dateinamen mit ausdrücklichem Hinweis**, dass die echten Dateien außerhalb des
Repos liegen — das gute Muster. Die Adresse in `baustellen-grid.html` gehört dem
Lieferanten Scharpegge samt öffentlicher Website, kein Leck.

---

## Letzte Vollübergabe

**`docs/HANDOFF-2026-07-09.md`** (Vollstand Abend) — detaillierter Repo-Stand, Commits, "die eine Tür", LV-Deckel/Dedup.

## Neuer Prüfstatiker-Bericht

**`uebergaben/2026-07-10-falbe-einstand-pruefstatik.md`** — Falbes Einstand als Prüfstatiker mit vier priorisierten Befunden:

1. Branch-Drift / kanonischer Stand — **🟢 erledigt 31.07.**, siehe unten
2. Doctype-/Türsteher-Confidence — 🔴 offen
3. EventDetailView/LVView zerlegen — 🔴 offen (`EventDetailView` ist seither eher gewachsen)
4. Kernel-Spike-Entscheidung vorbereiten — 🔴 offen

## Bestandsaufnahme SketchUp → LV (26.08.2026)

**`docs/2026-08-26-bestandsaufnahme-sketchup-ins-lv.md`** — erhoben, bevor Raphis neue
Datei da war. Drei Import-Wege und welcher der aktuelle ist, die drei Bruchstellen des
Parsers (zwei davon brechen still), die **zwei KG-Systeme, die nichts voneinander wissen**,
der Zuordnungsservice samt belegtem Kollisionsrisiko, die Deckel-Mechanik und der offene
Umbau zur benennbaren Gruppe. Mit Datei- und Zeilenangaben.

**Wenn eine SketchUp-Datei Ärger macht, zuerst dort Abschnitt 8 lesen** — zwei Blicke
(Kopfzeile, Bauteilnamen) entscheiden in einer Minute, ob es ein Parser- oder ein LV-Thema ist.

## Delta 06.08.2026 — Server-Neustart sah aus wie ein kaputtes CSV

**Branch `fix/serverfehler-lesbare-meldung`, ein Commit `a600e55`, NICHT gepusht.**
Build grün, komplette Unit-Suite grün.

### Der Vorfall

Raffi lud eine Mengen-CSV hoch und bekam 40 Zeilen rohes HTML ins Fehlerfeld — DOCTYPE,
IE7-Kommentare, Cloudflare-Markup. Sah nach kaputter Datei aus. War es nicht:

    15:14:43   Serverprozess gestartet, lädt RAG-Modell …
    15:14:53 ← Raffis Request → Cloudflare: 502 Bad Gateway
    15:14:54   "Application startup complete"

**Eine Sekunde zu früh.** Der Mops lädt beim Start ein Embedding-Modell und ist dabei
~11 s nicht ansprechbar; in dem Loch antwortet Cloudflare statt seiner. Dieselbe Datei
lief Minuten später zweimal mit `200 OK` durch. Weder CSV noch Server waren defekt.

**Zwei Fallen für die nächste Instanz:** Die Box loggt **UTC** (2 h Versatz zu CEST) — ohne
den Abgleich sucht man am falschen Zeitpunkt. Und ein 502 erzeugt **keine Log-Zeile und
keinen Traceback**, weil der Request die App nie erreicht. „Nichts im Log" ist hier der
Befund, keine Sackgasse. Der Zeitstempel steht unten in der HTML-Seite selbst.

### Was gebaut wurde

`Service/ServerFehlertext.swift` (neu) — eine Wahrheit für alle Upload-Wege. Statuscode
wird ausgewertet statt weggeworfen; 502/503/504 erklären den Neustart; HTML wird auch bei
Status 200 erkannt (Proxy/Tunnel-Panne); eigene Mops-Meldungen (`{"detail": …}`) werden
weiter durchgereicht. **Nie wieder roher Antwort-Body in der Oberfläche.**

`MateriallisteView` und `WandLeserView` nutzen sie — beide hatten dieselbe Zeile
(`String(data: data, encoding: .utf8)`) doppelt. 8 Regressionstests in
`ServerFehlertextTests.swift`, mit der echten 502-Seite aus Raffis Upload als Fixture.

Der Hinweistext endet mit **„An der Datei liegt es nicht."** — das ist die erste Frage,
die sich draußen stellt, und sie hat einen Nachmittag Suche gekostet. Bei unlesbarer
Antwort *ohne* HTML kommt bewusst **nicht** der Neustart-Hinweis, sondern „ließ sich nicht
lesen" (eigener Test) — ein beruhigender Satz, der nicht stimmt, wäre schlimmer als keiner.

### 🔴 Fund: der Erdaushub geht nur mit EINER DXF — und das ist kein Bug

`/gelaendebruecke/calculate` braucht **zwei** Zutaten: Geländehöhen **und** das geplante
Haus. Der Server sagt es sauber:

    "91 Höhenpunkte gelesen, aber kein geplantes Haus im DXF
     (Layer 'Geplante Hauslage' o. ä.). Bitte die Hauslage im Plan platzieren."

Von allen DXF auf der Platte hat **genau eine** diesen Layer — ein Vermesser-Bestandsplan
auf dem Desktop, der byteidentisch auch als `test.DXF` herumliegt (**echte Kundendaten
trotz Testname**, nicht als Spielmaterial behandeln). Ergebnis daraus, gerundet: Haus
~68 m², Cut ≈ Fill ≈ 11 m³ (Auto-Massenausgleich), Schotter ~39 t, ±20 m³ ≈ 3 LKW.

**Die Lücke sitzt in der App.** Serverseitig ist der Ausweg fertig — Form-Feld `footprint`
(Haus-Ecken als JSON) hat Vorrang vor dem Haus im DXF. Aber:

| Schritt | Stand |
|---|---|
| DXF an `/grundstueck`, Grenzen + Gelände zeichnen | ✅ `HauslagePlatzierenView` |
| Haus-Rechteck drauflegen und verschieben | ❌ fehlt |
| Bildschirm-Ecken → DXF-Koordinaten | ❌ fehlt |
| `footprint` an `/calculate` senden | ❌ **kommt in der ganzen App nicht vor** |

Die View heißt „Hauslage platzieren", zeigt aber nur das Grundstück — bewusst als Scheibe
abgelegt (`// Das Haus-Rechteck zum Platzieren kommt im nächsten Schritt dazu`, Zeile 16),
nie zu Ende geführt. **Das ist der Hebel für „alle anderen Pläne rechenbar machen".**

Vorher aber Backend lesen: die Rechnung lief auf der Box >125 s (Mac: 0,17 s) und fiel in
Cloudflares 100-s-Deckel. Ursache war nach heutigem Stand **nicht** eine langsame Box,
sondern ein parallel laufender **32-MB-DXF-Upload**, der ohne Threadpool denselben
Event-Loop belegte (Details im mops-api-Handoff). Trotzdem gilt: Bei großen Plänen kann
der 100-s-Deckel zuschlagen — ein Platzieren-Feature nützt nichts, wenn die Antwort nie
ankommt.

### Offen

- **Push + Deploy** beider Repos (auch `mops-api` `53a4f29`, Threadpool-Fix).
- `Service/MaterialImportService.swift` splittet CSV **naiv am Komma ohne Quote-Handling**.
  Bei SketchUp-Exporten mit Dezimalkommas werden Einheiten zu `0`/`72` und Namen
  abgeschnitten (`…17cmx6` statt `…17cmx6,0cm_Ost`) — **still, ohne Meldung**. Anderer Weg
  als „Mengen aus Excel" (Material-Import im Auftrag), eigener Termin.
- `EventDetailView.swift:978` zeigt womöglich dieselbe Roh-Body-Falle — nicht geprüft.

## Delta 31.07.2026 (nachts) — DSGVO-Fund + Beispiel durchkalkuliert

> **Nachgetragen am 26.08.2026.** Dieser Abschnitt lag seit dem 31.07. auf einem lokalen
> Branch und fehlte in `main` — der Code-Fix war drin, die Erklärung dazu nicht.
> Der Originaltext sprach von zwei **offenen** PRs; [#119](../../pull/119) und
> [#120](../../pull/120) sind inzwischen **beide gemergt**. Der Rest steht unverändert.

### 🔴 Echte Kundendaten lagen im öffentlichen Repo (#119)

Gefunden nebenbei, beim Nachsehen, warum ein Test keine Positionen fand.
`MarktbreitSeeder` enthielt auf `main`:

- Name und **Privatanschrift der Bauherrin** — eine Privatperson
- die Adresse ihres Grundstücks
- Klarnamen von Architekturbüro, Tragwerksplaner und Nachunternehmer, beim NU samt
  Angebotsnummer und dessen Preisen

Ersetzt in 18 Dateien (Code, Tests, docs) nach dem Muster von `DemoSeeder`, der es
richtig macht. „Marktbreit" bleibt — der Ort steckt in Klassennamen, und eine Stadt
allein ist keine Person. `docs/Roman_*` blieb unangetastet.

Zwei Dinge, die dazugehörten:
- **`applyBeteiligte()`** wird jetzt von BEIDEN Wegen benutzt (neu anlegen UND patchen).
  Vorher setzte nur der Neuanlage-Pfad diese Felder — eine Installation mit vorhandener
  Datenbank wäre auf den Klarnamen sitzengeblieben, der Austausch hätte sie nie erreicht.
- **UserDefaults-Schlüssel** trug den Namen im Quelltext, heißt jetzt
  `marktbreit_efh_beispiel_seeded_v5`.

**Merksatz, der bisher fehlte:** echte Daten haben in einem Seeder nichts verloren,
auch nicht „nur zum Testen". Ein Seeder sieht nach Wegwerf-Code aus und wird mit
demselben Ernst veröffentlicht wie alles andere.

**🔴 OFFEN und Andreas' Entscheidung: die Historie.** Vier ältere Commits enthalten die
Daten weiterhin, dazu Klone und GitHub-Caches; öffentlich seit Anfang Juni. #119 senkt
das künftige Risiko, er repariert die Vergangenheit nicht. Wege: so lassen ·
`git-filter-repo` + Force-Push (bricht jeden Klon) · Repo auf privat. Ebenfalls offen
und nicht delegierbar: ob die Bauherrin informiert wird.

### Beispiel-Baustelle ist erstmals durchgerechnet (#120)

Sieben Positionen standen auf 0,00 € — drei Decken, drei Dach, PV-Vorrüstung. Sie
hatten Mengen aus der Statik, aber keinen Preis; die Statik gibt Maße her, keine Kosten.

`BeispielKalkulationSeeder` hängt Material, Lohn und teils Gerät an:

| Position | Menge | EP | GP | Std |
|---|---|---|---|---|
| 3.50.1 Filigrandecke | 60,62 m² | 130,02 | 7.881,74 | 45,5 |
| 3.50.2 Ringbalken | 33,00 m | 67,15 | 2.216,06 | 33,0 |
| 3.50.3 Fenstersturz | 4,57 m | 128,68 | 588,05 | 8,2 |
| 3.60.1 Binder | 14 Stk | 323,68 | 4.531,53 | 23,8 |
| 3.60.2 Dacheindeckung | 82,00 m² | 74,79 | 6.133,08 | 69,7 |
| 3.60.3 Untergurt-Ausbau | 60,62 m² | 78,27 | 4.745,00 | 42,4 |
| 4.40.1 PV-Vorrüstung | 1 psch | 873,26 | 873,26 | 6,0 |

**Netto 59.132,61 → 86.101,32 €**, Lohnstunden erstmals > 0: **228,6**. Dazu zwei
Mitarbeiter (Polier + Maurer) für die Crew-Planung.

**⚠️ Die Aufwandswerte sind recherchierte REFA-Richtwerte, NICHT gemessen.** Steht im
Dateikopf, und die Positionen tragen `mengenQuelle = .schaetzung`. 228,6 Std für Dach
und Decken sind gut zwei Wochen für eine Dreier-Kolonne — **ungeprüft**. Vor jedem
echten Angebot muss jemand drüber, der so ein Dach gebaut hat.

**Warum nicht über den Mops**, obwohl er es kann (`MopsVorschlagSheet` →
`aufwandswertVorschlag` fragt den Prof nach REFA-Werten, `MaterialQuelle.mops` stempelt
die Herkunft): Fixtures müssen reproduzierbar, offline und testbar sein. Fragt der
Seeder den Mops, sieht das Beispiel bei jedem Aufsetzen anders aus und Tests wackeln.
**Der Mops gehört ins Feature, nicht in die Fixture.**

Preise kommen aus den Stammdaten statt aus einer zweiten Liste; fehlende Einträge
werden EINZELN ergänzt, weil `StammdatenSeeder` nur anlegt, solange seine Tabelle
komplett leer ist.

### Nebenbefund: Seeder-Tests brauchen das UserDefaults-Flag

`MarktbreitSeeder.seedIfNeeded` hängt an einem UserDefaults-Schlüssel. Im Test-Host
steht der schon auf `true` → der Seeder legt nichts an → Tests ohne Positionen, mit
Meldungen, die xcodebuild nicht ausgibt. `BeispielKalkulationTests` löscht den
Schlüssel vorher und baut in einem `static let` genau einmal auf (Swift Testing läuft
parallel). Wer den nächsten Seeder-Test schreibt, spart sich damit eine Stunde.

123 Tests grün.

## Delta 31.07.2026 (nachmittags) — Kennwert-Vergleich fertig verdrahtet

**Branch `feature/kennwert-vergleich`, zwei Commits, NICHT gepusht.** Beim Sessionstart
lagen fünf Dateien unfertig im Arbeitsbaum (Rechenkern + View gebaut, aber nirgends
verdrahtet). Jetzt zusammengesteckt und belegt: **143 Tests grün**, Build sauber.

| | |
|---|---|
| `4fc5513` | Feature: Kennwert-Vergleich, Knopf, Einstellungen, Bedienungshilfe |
| `797fc44` | 12 Tests für den Rechenkern |

### Worum es geht

Der alte Knopf „Soll/Planer-Schätzung ansehen" stellte die Schätzung fürs **ganze Haus**
neben die LV-Summe: 386 T€ gegen 112 T€. Das liest sich wie „274 T€ unter Plan" und ist
trotzdem falsch — die Schätzung rechnet Sanitär, Heizung und Maler mit, das LV deckt sie
nicht ab. `KennwertVergleich` rechnet die Schätzung jetzt auf die Kostengruppen herunter,
die im LV wirklich vorkommen. Was übrig bleibt, steht als „Nicht im LV — nicht
mitgerechnet" darunter statt stillschweigend zu verschwinden.

Die drei Kennwerte (2000/2500/3200 €/m²) standen hart im Code und sind jetzt Firmenwerte
unter Einstellungen → „Kalkulation — Kennwerte je m²". Alte Zahlen = Vorgaben, es rechnet
ohne Zutun wie vorher. Leeres Feld fällt auf die Vorgabe zurück.

**Es heißt „Kennwert", nicht „BKI"** — echte BKI-Werte sind kostenpflichtig lizenziert und
stehen hier nicht drin. Steht so auch in der App, nicht nur im Commit.

### 🔴 Der eigentliche Fund: Beispieldaten sind nicht zurückholbar

Andreas wollte „alle Baustellen löschen → Zauberstab → Beispiel neu". **Das geht nicht**,
und das ist eine Falle für jeden, der es nochmal versucht:

- Der Zauberstab ruft `DemoSeeder` → „Lindenstraße 12" (`DEMO-BAU-001`), **ohne
  LV-Positionen**. Das ist nicht die Beispiel-Baustelle.
- Das kalkulierte Beispiel ist **Marktbreit** (`I-25_448-GO`), gelegt von `MarktbreitSeeder`
  beim App-Start — geschützt durch das UserDefaults-Flag `marktbreit_efh_beispiel_seeded_v5`.
- Baustelle gelöscht + Flag gesetzt = **kommt nie wieder**. Der Seeder steigt vorher aus.

Genau das war am Mac passiert („Designed for iPad", Container `581290A0-…`). Flag von Hand
gelöscht, danach lief die Kette komplett durch: 24 LV-Positionen + `houseProject` mit den
Aura-125-Daten. Backup der Preferences liegt in `_backups/`.

**Offene Aufgabe daraus:** ein „Beispieldaten neu aufsetzen" in der App. Es gibt derzeit
keinen Weg über die Oberfläche, und ein `defaults delete` im Container ist keine Antwort
für einen Anwender.

### Wo der neue Vergleich hängt

`EventDetailView` → Karte „Baustellen-Übersicht" → kleiner Link **„Gegen Kennwert prüfen"**
(erscheint nur bei vorhandenen LV-Positionen — ohne LV gibt es nichts zu vergleichen).
`app_bedienung.yaml`: neuer Eintrag `App_Kennwert_Vergleich`, und die Ist-Übersicht
beschrieb den Link noch als Weg zum Planer — korrigiert (Drift-Regel).

### Was die 12 Tests festnageln

Die Zuordnung Kostengruppe → Gewerke-Topf, vor allem die Sonderregel: **KG 334/344**
(Fenster, Türen) werden absichtlich aus dem Rohbau gezogen. Dazu der Firmenwert-Durchgriff,
der 0-Rückfall, das Addieren je Topf und die Deckel/Beleg-Falle (REB-23.003).

Ist-Werte werden bewusst gegen `LVKalkulator.effektiverEP` gehalten, nicht gegen feste
Euro: geprüft wird das Zuordnen und Addieren, nicht das Preisrechnen. Sonst fällt der Test
um, sobald jemand an den Zuschlägen dreht, und behauptet dabei, die Zuordnung sei kaputt.

### Offen

- **Nicht gepusht, kein PR.** Branch liegt lokal.
- **Die Ansicht hat niemand gesehen.** Build grün und Tests grün heißen „nichts
  kaputtgemacht" — ob die Zahlen am Beispiel plausibel aussehen, ist ungeprüft.
  Erwartung: 125 m² × 2500 = 312.500 € Schätzung, davon 32 % Rohbau = 100.000 €,
  LV ≈ 112.000 € netto über mehrere Töpfe.
- `uebergaben/…falbe-einstand…md` weiterhin untracked (bewusst nicht mitcommittet).
- **Simulator-Hinweis:** `iPhone 16` aus CLAUDE.md gibt es nicht mehr; verfügbar ist
  `iPhone 17 Pro Max`. Die Build-Befehle oben in CLAUDE.md sind insofern veraltet.

## Delta 31.07.2026 — Aufräumtag: alles gemergt, 18 Branches → 1

**`main` steht allein** (`da32408`). Neun PRs (#109–#117) sind durch, alle Arbeit der
letzten drei Tage plus die Altlasten. Damit ist Falbes Befund **P1 abgeräumt**: es gibt
wieder genau einen kanonischen Stand, nicht mehr „Vielleicht".

### Was gemergt wurde

| PR | Inhalt |
|---|---|
| #109 | DIN 276 aus einer Quelle (Baum führend), KG 532, 441-Altbug |
| #110 | KG-Namen aus einer Stelle statt fünf `switch`-Kopien |
| #111 | B-Element — ein Einheitspreis aus mehreren Arbeitsschritten |
| #112 | Zuschlag je Kostenart + Lohnstunden + Firmenwerte |
| #113 | HANDOFF Stand 31.07. |
| #114 | drei Handoffs vom 08.07., die nur auf dem Mac lagen |
| #115 | **Pflichtspur** in `CLAUDE.md` + `AGENTS.md` |
| #116 | Hauslage platzieren (Welle 7, Schritt 2b) |
| #117 | Mopsiversum-Nachzug: Saves #49–52, Regiezettel-Konzept |

Gestapelte PRs (#110 auf #109, #112 auf #111) hielten die Diffs sauber; die
Merge-Reihenfolge innerhalb einer Kette war strikt und hat gehalten.

### Drei Fehler, die erst beim Aufräumen sichtbar wurden

Keiner davon war ein Merge-Konflikt, keiner hat einen Test rot gemacht:

- **DWG lief in einen 500er** (#116). `HauslagePlatzierenView` schrieb den Dateinamen
  fest als `upload.dxf`; der Picker lässt aber `.dwg` zu. Die Box entscheidet an der
  Endung, ob sie DWG→DXF wandelt — sie hätte `ezdxf` auf DWG-Bytes losgelassen. Der
  Branch war älter als der `filename:`-Parameter, den `main` inzwischen hat.
- **Doku zeigte auf eine Datei, die es nicht gibt** (#117). `mops_server_setup.md`
  führte `bauhuette.html` als „NEU" — auf der Box liegt bis heute nur
  `kontrollzentrum.html`. Die Umbenennung ist beschlossen (Save #49), nie umgesetzt.
- **Die Pflichtspur selbst lag 20 Tage ungemergt** (#115). Die globale Notiz sagte,
  beide Repos hätten sie oben stehen; für dieses stimmte das nicht.

**Das Muster:** ein lange liegender Branch wird nicht durch das gefährlich, was git rot
anzeigt, sondern durch Annahmen, die inzwischen nicht mehr gelten. Konflikte findet das
Werkzeug — veraltete Annahmen findet nur, wer gegen den heutigen Stand nachprüft.

### Sortierung + Werkzeug (`12bc67e`, `dc1d934`)

- Ein Element sortiert seine Bausteine nach **PosNr** (= Arbeitsfolge, 534.002 vor
  534.007), nicht alphabetisch. Der Mengenträger bleibt bewusst alphabetisch — dort sagt
  die Reihenfolge nichts aus. Im Simulator gefunden, mit zwei Tests festgehalten.
- `scripts/snapshot.sh` nahm gelegentlich ein Indizierungs-Gerüst unter `Index.noindex/`
  statt des gebauten Bundles. Welches `head -1` erwischte, war Glückssache.

### Was NICHT im Repo ist

- `uebergaben/2026-07-10-falbe-einstand-pruefstatik.md` — untracked. Laut eigenem Text
  gehört die Datei ins Repo `Baustellen_Grid`, das es (noch) nicht gibt. Keine
  Kundendaten drin („Falbe" = Claude Fable 5, kein Personenname).
- Branch `docs/lieferanten-sync-uebergabe-20260624` — nur lokal, nie gepusht. Enthält
  `docs/server_kollegen_ssh_zugang.md` und zwei Branding-PNGs (4 MB). **Vor einem Push
  die SSH-Doku auf Hostnames und Schlüssel lesen** — das Repo ist öffentlich.

### 🔴 Das Wichtigste steht aus: die App ist NICHT auf dem Gerät

Alles Geprüfte war Simulator (iPhone 17 Pro Max). Beim ersten Start auf dem iPhone läuft
`ZuschlagMigration` **einmalig**. **Vorher den Container ziehen** — läuft sie schief,
gibt es keinen Weg zurück auf die alten Sätze.

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
  (App + Box), erster Happen auf der Box gegen zwei Fixtures — die Spec dazu liegt seit
  31.07. im Repo (`docs/Unterlagen-Auswerten-Routing-Spec.md`, §4b ist der wichtige Teil).
  **Davor aber: die App aufs Gerät bringen** (Migration, Container sichern — Delta 31.07.).
- **Was ist live?** Backend: Box auf **`main`** (sauberer Checkout `4ff018f`, redeployed 28.07. —
  die frühere Angabe „Box-Branch `feature/lv-seite-provenance`" war überholt). iOS-App am Gerät,
  aber auf **altem Datenmodell** (ohne `ZDECKEL`/`ZDECKELNOTIZ`, keine Importe) — die Geräte-
  Installation ist älter als Deckel/Beleg + Excel-Import, siehe Delta 29.07.
- **Was ist gebaut, aber nicht gemergt?** **Nichts.** Stand 31.07. ist `main` der einzige
  Branch (`da32408`); PRs #109–#117 sind durch, 18 Branches wurden auf 1 zurückgeschnitten
  (Delta 31.07.). Vor dem Löschen wurde jede Spitze geprüft und notiert — die Nummern
  stehen im Delta, `git push origin <sha>:refs/heads/<name>` holt sie zurück.
  Lokal liegt nur noch `docs/lieferanten-sync-uebergabe-20260624` (nie gepusht, SSH-Doku
  erst lesen). **Wenn diese Antwort wieder länger wird als zwei Zeilen, ist P1 zurück.**
- **Was ist nur Idee?** Nordstern Stufen 3–5, weitere Doctype→LV-Mappings, Kernel-Entscheidung.
- **Was darf nicht angefasst werden?** Kundendaten nicht ins Repo; `main` nicht direkt; `Kernel/` nicht mit echten Daten verdrahten.

## Zweites Repo

Backend **mops-api** immer mitdenken. Bei Backend-Arbeit dort ebenfalls zuerst die aktuelle Übergabe lesen.
