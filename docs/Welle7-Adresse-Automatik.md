# Welle 7 — Adresse → automatische Geländebrücke (Server + App)

> Design-Spec, Stand 2026-07-03. Noch nicht gebaut.
> Vorstufe: Der DXF-basierte Weg läuft schon komplett (siehe unten).
> Diese Spec beschreibt NUR den fehlenden „Adresse statt DXF"-Automatik-Pfad.

## 1. Was heute schon läuft (nicht neu bauen!)

Der **App-Teil ist zu ~80 % fertig** und funktioniert:
- `EventDetailView.uploadDXF` lädt eine **DXF** hoch → `POST /gelaendebruecke/calculate`
  (Query `?fix_okbp=`), dekodiert `GelaendeResult`.
- `geländeCard` zeigt **Cut/Fill, Schotter (t), Vlies (m²), LKW-Fahrten, Heatmap**.
- „Ins LV übernehmen" (`insertGelaendeIntoLV`) legt Aushub/Schotter/Vlies als
  LV-Positionen an — seit 3.7. korrekt mit `mengenQuelle = .schaetzung` (Welle-9-Ampel).
- **PDF-Aushub-Bericht** vorhanden.

Der Server-Endpoint `/gelaendebruecke/calculate` ist **live** auf der Box.

## 2. Die Lücke

Der Live-Endpoint nimmt **nur einen DXF-Upload** entgegen. Es gibt keinen Weg,
aus einer **Adresse** automatisch die DGM-Massen zu ziehen. Damit fehlt:
- ein **Adress-Feld** im `HouseConfigurator`,
- der **Automatik-Pfad**: Adresse → DGM1-Kachel → Cut/Fill → Pauschal-Aushub
  (`HouseProjectGenerator`: `gf × 3,0 m³`) durch echte Massen ersetzen (als Schätzwert).

**Kernpunkt:** Das ist **kein reiner App-Teil** — es braucht zuerst einen neuen
**Box-Endpoint**. Die Pipeline dafür existiert im Prototyp, aber nicht als API.

## 3. Der harte Teil zuerst benennen: der Footprint

Cut/Fill braucht eine **Hauslage** (Grundriss-Polygon), um Abtrag/Auftrag im
Baufeld zu rechnen. Beim DXF-Weg liefert die Zeichnung diese Lage. Bei „nur Adresse"
gibt es sie nicht (vgl. Handoff-Punkt 3: Musterfrau-Bestand-DXF hatte keinen Footprint → 422).

**Vorschlag (Schätzung, ehrlich gelabelt):** Aus dem `HouseConfigurator` einen
**Rechteck-Footprint** ableiten (Grundfläche aus Wohnfläche ÷ Geschosse, Seitenverhältnis
~1:1,3), platziert auf dem **Adress-Zentroid**. Das ist grob, reicht aber für eine
Massen-**Schätzung** und ist als solche gekennzeichnet. Die **präzise** Hauslage
(echtes Polygon, Rotation, Lage im Grundstück) bleibt eine spätere Verfeinerung —
sie hängt am selben Faden wie Stufe 3 (Geometrie aus dem Architekten-DXF).

## 4. Architektur

```
HouseConfigurator (App)
   │  Adresse + abgeleiteter Rechteck-Footprint + optional fix_okbp
   ▼
mops-api  NEUER Endpoint  POST /gelaende-analyse
   │  1. Adresse → UTM32 → DGM1-Kachel  (geodaten_fetch.py-Pipeline)
   │  2. DGM laden/cachen  (SHA-Verify, wie im Prototyp)
   │  3. Footprint auf Kachel legen → Cut/Fill (IDW)  (welle6_mustermann_cutfill.py)
   │  4. GelaendeResult zurück (dasselbe Schema wie /gelaendebruecke/calculate!)
   ▼
App: bestehende geländeCard + insertGelaendeIntoLV WIEDERVERWENDEN
     (identisches GelaendeResult → keine neue Anzeige nötig)
```

- **Wiederverwenden:** Antwort-Schema `GelaendeResult` **gleich lassen** wie beim
  DXF-Endpoint → die ganze Anzeige + LV-Übernahme funktioniert ohne Änderung.
- **Prototyp-Bausteine (liegen in `~/Projekte/mops-extract-prototype/`):**
  `geodaten_fetch.py` (Adresse→Kachel, mit Cache+SHA), `welle6_mustermann_cutfill.py`
  (IDW, Cut/Fill, Heatmap-PNG). → In eine `api/routes/gelaende_analyse.py` überführen.
  ⚠️ DSGVO vor dem Push: kein Kunden-/Adressmaterial ins Repo (grep nach echten Bauherren-Namen und Adressen — Beispieldaten immer pseudonym).

## 5. Endpoint-Contract (Entwurf)

**Request** `POST /gelaende-analyse` (JSON)
```json
{
  "adresse": "97225 Zellingen, Musterstraße 2",
  "footprint_m": {"laenge": 12.0, "breite": 9.0, "rotation_grad": 0},
  "fix_okbp": null
}
```
**Response** `200` — **identisch zu `/gelaendebruecke/calculate`** (`GelaendeResult`):
`ok_bp`, `gelaende_min/max`, `cut`, `fill`, `schotter_t`, `vlies_m2`, `lkw_fahrten`, `plot_png`.
- `422` wenn Adresse nicht geocodierbar / keine DGM-Kachel / Footprint fehlt.
- Meldung immer: „DGM-Schätzung, ersetzt keinen Vermesser."

## 6. App-Änderungen

1. **`HouseProject`-Modell:** Feld `adresse: String?` (+ ggf. `footprintLaenge/Breite`).
2. **`HouseConfiguratorView`:** neue Sektion „Standort" mit Adress-TextField.
3. **Auto-Aufruf:** beim Generieren/„Massen berechnen" — wenn Adresse gesetzt →
   `/gelaende-analyse` rufen, sonst Pauschal-Aushub (`gf × 3,0`) wie bisher.
4. **Pauschal ersetzen:** die DGM-Massen ersetzen die Pauschal-Position im
   `HouseProjectGenerator`, gekennzeichnet als `mengenQuelle = .schaetzung`.
5. **Fallback ehrlich:** kein Netz / 422 → Pauschal + Hinweis „grobe Schätzung".

## 7. Sequenzierung (klein anfangen)

1. **Box-Endpoint zuerst** (wie die Geländebrücke selbst startete): Prototyp
   `geodaten_fetch.py` + `cutfill` als `POST /gelaende-analyse` verdrahten, gegen
   eine Test-Adresse (BV Mustermann) lokal beweisen. **Kein App-Deploy.**
2. Endpoint live auf der Box (tmux-Runbook), OpenAPI bestätigen.
3. App: Adressfeld + Auto-Aufruf + Pauschal-Ersatz. Anzeige/LV-Übernahme = bestehend.
4. Footprint verfeinern (echte Hauslage) — später, Stufe-3-nah.

## 8. Risiken / Nicht-Ziele
- **Genauigkeit:** Rechteck-Footprint + DGM1 (1 m Raster) = **Schätzung**, kein
  Vermesser/Gutachten. Im UI klar so kennzeichnen (Ampel-Farbe via `mengenQuelle`).
- **Geocoding:** Adresse → Koordinate braucht einen Geocoder (welchen? Nominatim/
  Bayern-Atlas?) — Datenhoheit beachten, möglichst über die Box.
- **Nicht-Ziel:** präzise Hauslage/Rotation aus Architektur-DXF (Stufe 3).

## Verbindung zu offenen Fäden
- `mengenQuelle = .schaetzung` (3.7. im DXF-Pfad gesetzt) gilt hier genauso →
  speist die Welle-9-Voraussetzungs-Ampel.
- Footprint-Thema = verwandt mit Stufe 3 (Geometrie) und dem `fix_okbp`-Test aus dem Handoff.
