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

- **Woran arbeiten wir gerade?** Wandleser/DXF-Geschoss läuft; als nächster geplanter Brocken **#3 Unterlagen-Routing `/extract-auto`** (App + Box), erster Happen auf der Box gegen zwei Fixtures.
- **Was ist live?** iOS-App am Gerät; Backend laut letzter Übergabe auf Box-Branch `feature/lv-seite-provenance`.
- **Was ist gebaut, aber nicht gemergt?** #2 Auswertung-speichern (gebaut, Merge-Status prüfen); außerdem siehe `docs/HANDOFF-2026-07-09.md` und Falbe-Bericht. (#1 ist schon in `main`.)
- **Was ist nur Idee?** Nordstern Stufen 3–5, weitere Doctype→LV-Mappings, Kernel-Entscheidung.
- **Was darf nicht angefasst werden?** Kundendaten nicht ins Repo; `main` nicht direkt; `Kernel/` nicht mit echten Daten verdrahten.

## Zweites Repo

Backend **mops-api** immer mitdenken. Bei Backend-Arbeit dort ebenfalls zuerst die aktuelle Übergabe lesen.
