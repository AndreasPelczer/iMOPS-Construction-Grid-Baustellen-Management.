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

## Delta 29.07.2026 — DIN 276: zwei Kataloge aus zwei Fassungen zusammengeführt

**Branch `fix/din276-kg-532`, zwei Commits, NICHT gepusht, kein PR.**

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

### Offen aus dieser Session

- **Altbug, bewusst liegen gelassen:** „zählerkasten / hak / netzanschluss" → **441**
  „Hoch- und Mittelspannungsanlagen" (Hausanschluss ist Niederspannung → 443). 441 ist in beiden
  Fassungen gleich, also keine Editionsdrift — nicht angefasst, um den Umbau nicht ausufern zu lassen.
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

- **Woran arbeiten wir gerade?** Zuletzt (29.07.) DIN-276-Katalog konsolidiert — siehe Delta oben;
  zwei Entscheidungen von Andreas stehen dort offen. Als nächster geplanter Brocken weiterhin
  **#3 Unterlagen-Routing `/extract-auto`** (App + Box), erster Happen auf der Box gegen zwei Fixtures.
- **Was ist live?** Backend: Box auf **`main`** (sauberer Checkout `4ff018f`, redeployed 28.07. —
  die frühere Angabe „Box-Branch `feature/lv-seite-provenance`" war überholt). iOS-App am Gerät,
  aber auf **altem Datenmodell** (ohne `ZDECKEL`/`ZDECKELNOTIZ`, keine Importe) — die Geräte-
  Installation ist älter als Deckel/Beleg + Excel-Import, siehe Delta 29.07.
- **Was ist gebaut, aber nicht gemergt?** `fix/din276-kg-532` (2 Commits, **ungepusht**, kein PR);
  #2 Auswertung-speichern (gebaut, Merge-Status prüfen); außerdem siehe `docs/HANDOFF-2026-07-09.md`
  und Falbe-Bericht. (#1 ist schon in `main`.)
- **Was ist nur Idee?** Nordstern Stufen 3–5, weitere Doctype→LV-Mappings, Kernel-Entscheidung.
- **Was darf nicht angefasst werden?** Kundendaten nicht ins Repo; `main` nicht direkt; `Kernel/` nicht mit echten Daten verdrahten.

## Zweites Repo

Backend **mops-api** immer mitdenken. Bei Backend-Arbeit dort ebenfalls zuerst die aktuelle Übergabe lesen.
