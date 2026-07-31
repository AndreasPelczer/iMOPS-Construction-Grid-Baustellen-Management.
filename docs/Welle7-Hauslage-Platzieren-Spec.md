# Welle 7 — Hauslage geführt platzieren (Spec)

**Stand:** 2026-07-07 · **Status:** geplant, noch nicht gebaut · verwandt: `Welle7-Adresse-Automatik.md`

## 1. Problem

Der tolerante DXF-Leser (`api/routes/gelaendebruecke.py`, live seit 07.07.2026) liest die
Geländehöhen aus jedem Vermesser-Bestandsplan — egal wie die Layer benannt sind. **Aber:**
Bestandspläne zeigen das Gelände **ohne das geplante Haus**. Fehlt die Hauslage, gibt der
Server ehrlich `422: „X Höhenpunkte gelesen, aber kein geplantes Haus … bitte platzieren"`
zurück (statt Absturz). Für Cut/Fill brauchen wir aber einen Footprint.

Beispiel Musterfrau (V4181): 72 Höhen + Höhenlinien sauber gelesen, `DFK_Grenze` vorhanden,
**aber kein Haus-Layer** → keine Aushubrechnung möglich.

## 2. Kern-Erkenntnis (aus dem Ordner `BV-Musterfrau_LV`)

Wir brauchen **kein Haus im DXF**. Für den Footprint in UTM32 reichen drei Zutaten, die alle
in den üblichen Bauantragsunterlagen liegen:

1. **Haus-Größe/Form** — Grundriss EG / Abstandsflächenplan (Musterfrau: Typenhaus „Flair 124").
2. **Wo es steht** — die **Abstandsmaße** Haus↔Grundstücksgrenze im „Lageplan mit Hausstellung"
   (Musterfrau abgelesen: **8,00 / 3,50 / 3,00 m**).
3. **Grundstücksrand in UTM32** — steckt **schon im Bestands-DXF** (`DFK_Grenze`), also im selben
   Koordinatensystem wie die Höhen.

→ Das Haus lässt sich vom bekannten Grundstücksrand um die angegebenen Abstände **einrücken** —
präzise, ohne Vermesser-DXF-mit-Haus.

Belege im Ordner (Musterfrau):
- `04_Lageplan/Lageplan mit Hausstellung …pdf` — amtl. Flurkarte 1:1000, Haus auf Flst. 000/00,
  UTM32-Rahmenkoordinaten, Abstandsmaße. **Rasterscan** (kein Vektor).
- `01_…/Bauantragsunterlagen/Abstandsflächenplan …pdf` — 1:200, **Vektorplan**, Haus (rot) +
  Grundstücksgrenze (magenta) = dieselbe Grenze wie im DXF.
- `03_Vermessung-Bebauungsplan/alkisdaten_utm32.dxf` — Flurstück in UTM32 (nur Grenzen, keine Höhen).
- `…/Bodengutachten/…pdf` — Untergrund-Wahrheit (Bodenklasse/Aushubtiefe).

## 3. Gewählter Weg: (A) Geführtes Platzieren

Nutzer legt in der App ein **maßhaltiges Rechteck** (Haus-Footprint) an den — aus dem DXF
bekannten — Grundstücksrand, geführt durch die Abstandsmaße des Lageplans.

**Warum nicht (B) vollautomatisch:** Grundstückspolygon aus dem Vektor-Abstandsflächenplan mit
dem DXF-Grundstück überlagern und das Haus rechnerisch nach UTM32 transformieren ist möglich
(beide teilen die Grenze), aber pro Plan fummelig und nur so genau wie die Überlagerung. → später,
optional. (A) ist robust und ehrlich.

## 4. Datenfluss

1. DXF hochladen → Server liest Höhen **und** liefert (neu) das **Grundstückspolygon**
   (`DFK_Grenze`, UTM32) + Gelände-Bounding-Box zurück, auch wenn kein Haus da ist
   (Status `kein_haus`, aber mit Geometrie statt nacktem 422).
2. App zeigt Grundstücksumriss + (optional) Höhen als Hintergrund.
3. Nutzer definiert das Haus über **eine** der Eingaben:
   - **Maße + Abstände:** Haus-Länge/-Breite (aus Grundriss/Typ) + Abstände zu 2 Grenzseiten
     (aus Lageplan, z. B. 8,00 / 3,50) + Drehung → App rechnet die 4 Ecken in UTM32.
   - **Direkt ziehen:** Rechteck auf dem Grundstück verschieben/drehen/skalieren (Feinschliff).
4. App schickt das Footprint-Polygon (4 UTM32-Ecken) an einen erweiterten Endpoint
   `/gelaendebruecke/calculate_with_footprint` (DXF + footprint-JSON) → normale Cut/Fill-Rechnung.
5. Ergebnis wie gehabt; übernommene LV-Positionen bekommen `mengenQuelle = .schaetzung`
   (Welle-9-Ampel).

## 5. Backend-Aufgaben

- `process_dxf_and_calculate`: Footprint-Quelle austauschbar machen — entweder aus dem DXF
  (`_extract_footprint`, wie jetzt) **oder** aus einem übergebenen Polygon.
- `kein_haus`-Antwort erweitern: `grundstueck_utm` (Polygon), `bbox`, `n_hoehen` mitgeben,
  damit die App etwas zum Zeichnen hat.
- Neuer/erweiterter Endpoint, der ein Footprint-Polygon annimmt.
- Rest (IDW, Massenausgleich, Schotter/Vlies/LKW) unverändert.

## 6. App-Aufgaben (iOS)

- Kleine Platzier-Ansicht in `EventDetailView` (Geländebrücke-Karte): Grundstück zeichnen,
  Rechteck mit Maßen/Abständen/Drehung, Live-Vorschau.
- Eingabe der Abstandsmaße + Haus-Maße (Zahlenfelder) als primärer, verlässlicher Weg;
  Ziehen als Komfort.
- Footprint in `event.extras` persistieren (rückwärtssicher, optional), damit die Platzierung
  eine Baustelle „behält".

## 7. Ehrlichkeit (Raphi-Prinzip)

Bleibt **Planungs-Schätzung** für Vorplanung/Verkauf. Ersetzt **nicht** Vermesser-Abrechnung und
**nicht** das Bodengutachten (Bodenklasse, Tragfähigkeit, Grundwasser, Aushubtiefe). 1-m-DGM/
Lageplan kennen nur Geometrie, nicht den Untergrund. Footprint aus Abstandsmaßen = so genau wie
die Maße im Lageplan.

## 8. Offen / Entscheidungen für den Bau-Tag

- Genügt „Maße + 2 Abstände + Drehung", oder braucht es freies Ziehen von Anfang an?
- Rechteck-Footprint reicht (Typenhaus) — L-Formen/Garage erst später?
- Weg (B) vollautomatisch: nur notieren oder als Spike ansetzen?
