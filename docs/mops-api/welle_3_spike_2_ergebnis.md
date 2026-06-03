# Welle 3 — Spike-Ergebnis W3.2 (Wand-Frage aus Statik + Werkplan)

**Version:** 1.0
**Durchgeführt:** 03.06.2026
**Frage:** Welche Innen- und Außenwände hat BV Schwarz Marktbreit? Wandtypen (PPW 2-0,35 / PP 4-0,55),
Stärken (24 / 36,5 / 17,5 cm), Geschosse?
**Quelldokumente:**
- `448-GO Statik 05.03.26 einseitig.pdf` (163 Seiten, Pos 7.1–7.4)
- `260402_1545_Schwarz_WP_kk.PDF` (11 Seiten, Werkplan)
**Ground Truth:** `Projekt-Schwarz.md` (Abschnitt 3.3/3.4) + `MarktbreitSeeder.swift` (KG 330/340)
**Methode:** wie Spike 1 (`welle_3_spike_ergebnis.md`), erweitert um **Text-Layer-Extraktion** (PDFKit/Swift)
für die born-digital Statik + **Vision auf selbst gerenderten PNGs** für Plan- und Werkplan-Seiten.

---

## 1. Kurzfassung (TL;DR)

Die Wand-Frage ist **vollständig beantwortbar** — und zwar überwiegend aus dem **sauberen Text-Layer**
der Statik (kein Vision/OCR nötig). Alle 5 Wandtypen, Stärken und Geschoss-Zuordnungen sind belegt.
Ground Truth in `Projekt-Schwarz.md` wird **auf ganzer Linie bestätigt**, mit zwei sinnvollen Präzisierungen,
die der Spike zusätzlich gefunden hat.

**Wichtigste Methoden-Erkenntnis:** Die große Statik ist ein **digital erzeugtes PDF mit Text-Layer** →
reine Text-Extraktion liefert die Wand-Tabelle exakt und **um Größenordnungen billiger als Vision**.
Vision/OCR braucht es nur für (a) Plan-/Zeichnungsseiten mit verwürfeltem Text und (b) den Werkplan
(reiner Vektorplan, **kein** Text-Layer).

---

## 2. Das Ergebnis — Wände BV Schwarz Marktbreit

### Außenwände
| Pos | Typ | Dicke | Geschoss | Mörtel / Detail | Beleg |
|---|---|---|---|---|---|
| **7.1** | PP 2-0,35 | **24,0 cm** | EG / OG (oberirdisch) | DM, Kimmschicht LM 21; gk=1,47 kN/m²; fk=4,5 | S.10, S.12, Nachweis S.132 |
| **7.2** | PP 4-0,55 | **24,0 cm** | UG (Kelleraußenwand, verstärkt) | DM, Kimmschicht MG III; mit Stb-Stütze 16/30 (Pos 7.2.1); gk=1,95 kN/m² | S.9, Nachweis S.134 |
| **7.3** | PP 4 / **Z-17.1-543** | **36,5 cm** | UG (Kelleraußenwand, verstärkt) | d=0,365 m, b=3,61 m; mit Stb-Stütze 30/23 (Pos 7.3.1) | Nachweis S.142, Wandtabelle S.53 |

### Innenwände
| Pos | Typ | Dicke | Geschoss | Detail | Beleg |
|---|---|---|---|---|---|
| **7.4** | PP 4-0,50 | **17,5 cm** | EG / OG | DM, Kimmschicht MG III; gk=1,29 kN/m²; 2-seitig gehalten | S.10, S.12, Nachweis S.151 |
| — | PP 4-0,55 | **11,5 cm** | EG / OG | örtlich (z.B. Brüstung Treppenhaus) | S.10 (Baustoffliste) |
| — | Ytong PSF AAC 4,5-600 | 17,5 / 11,5 cm | — | Sturz-/Trennwand-Elemente (l=1,25 / 1,50 m) | Positionsplan S.9 |

### Wandsegmente mit Längen (Wandlager-Tabelle S.53/55)
| Gruppe | Material | Dicke | Einzellängen [m] | Σ [m] |
|---|---|---|---|---|
| AW-TR-1 | PP 2 | 24,0 | 0,88 · 1,98 · 2,03 · 1,38 | 6,27 |
| AW-TR-2 | Z-17.1-543 (PP4) | 36,5 | 3,62 · 3,91 · 2,74 | 10,27 |
| AW-TR-3 | PP 4 / PP 2 | 24,0 | 0,74 · 3,88 | 4,62 |
| AW-TR-4 | PP 4 / PP 2 | 24,0 | 1,65 · 0,61 · 0,86 | 3,12 |

→ Hier liegt sogar die **Geometrie für ein Mengen-Aufmaß** tabelliert vor (Höhe 2,77 · Länge · Dicke).
Das war beim Spike 1 (Bewehrungsplan) noch der Schwachpunkt — die Statik liefert es als Tabelle nach.

---

## 3. Ehrliches Protokoll

### Spalte „sicher erkannt"
- Alle 5 Wandtypen + Stärken (24 / 36,5 / 17,5 / 11,5 cm) — mehrfach belegt (Baustoffliste S.10,
  Lastannahmen S.12, Einzelnachweise Pos 7.1–7.4, Wandtabelle S.53).
- Geschoss-Zuordnung: UG = verstärkte Kelleraußenwände (7.2/7.3) + Innenwände; EG/OG = PP 2-0,35 außen.
- Wandhöhe durchgängig 2,77 m (UG); Mörtel/Kimmschicht (LM 21 außen, MG III verstärkt/innen).
- Stützen-Zuordnung zur Wand: 7.2.1 (16/30) in 7.2, 7.3.1 (30/23) in 7.3.

### Spalte „unsicher / Vorsicht"
- **Plan-Text ist verwürfelt:** die reine Text-Extraktion der *Positionsplan*-Seite S.9 warf u.a.
  „7.3 Außenwand PP 4-0,50" aus — das ist ein **Layout-Artefakt** (Label-Bleeding mit Pos 7.4).
  Der Einzelnachweis (Pos 7.3 → d=0,365) und die Wandtabelle sind die verlässliche Quelle.
  → **Lehre:** bei Zeichnungsseiten nicht dem rohen Text-Layer trauen, Vision/Nachweis-Tabelle nehmen.
- Wandlängen je nach Quelle unterschiedlich aggregiert (Nachweis-Segment b=1,75 vs. Gesamtlänge) —
  fürs Aufmaß muss klar sein, welche Summe gemeint ist.

### Spalte „bewusst weggelassen / nicht behauptet"
- Keine Quadratmeter-Endsumme erfunden — die Segmentlängen sind da, aber Tür-/Fensteröffnungen-Abzug
  steht in einem anderen Schritt (nicht raten).
- Werkplan S.1 = Deckblatt/Ausführungshinweise, S.2 = Lageplan — **keine** Wandtyp-Angaben dort;
  Wandtypen kommen aus der Statik. (Werkplan-Grundrisse liegen auf Folgeseiten, hier nicht nötig.)

---

## 4. Abgleich mit Ground Truth (`Projekt-Schwarz.md`)

| Ground Truth | Statik-Befund | Verdict |
|---|---|---|
| Außen oberird. „PPW 2-0,35", d=24 | Pos 7.1 „PP 2-0.35", d=24 | ✅ (Naming: md „PPW" = Statik „PP") |
| Außen UG „PP 4-0,55", d=24 (Pos 7.2) | Pos 7.2 PP 4-0,55, d=24 | ✅ |
| Außen UG „PP 4-0,55", d=36,5 (Pos 7.3) | Pos 7.3 d=36,5; Material **Z-17.1-543** (PP4-Sonderzulassung) | ✅ Dicke/Pos; Material präziser |
| Innen 17,5 „PP 4-0,50" | Pos 7.4 PP 4-0,50, d=17,5 | ✅ |
| Innen 11,5 „PP 4-0,55" | Baustoffliste S.10: Innenwand PP 4-0,55, 11,5 | ✅ |

**Zwei Präzisierungen, die der Spike findet:**
1. Die 36,5-cm-Wand läuft statisch über eine **Sonderzulassung Z-17.1-543** (PP4-Klasse), nicht generisch „PP 4-0,55".
2. „PPW" (md) wird in der Statik durchgängig „PP 2-0,35" geschrieben — Produkt-/Schreibvariante klären.

→ Der Live-Test scheiterte also **nicht** am Wissen, sondern nur daran, dass diese Tabelle nicht
gefüttert war. Mit der Statik im Zugriff hätte der Mops die Wandliste korrekt liefern können.

---

## 5. Konsequenzen für die Pipeline (Update zu Spike 1)

| Erkenntnis | Konsequenz |
|---|---|
| Statik = born-digital, Text-Layer sauber | **Text-Extraktion zuerst**, Vision nur als Fallback → drastisch billiger |
| Plan-/Zeichnungsseiten = Text verwürfelt | dort **Vision auf gerendertem PNG** (Swift/PDFKit kann rendern, kein poppler nötig) |
| Werkplan = Vektorplan ohne Text-Layer | **nur Vision** möglich |
| Wand-Info steckt in 4 Quell-Arten (Baustoffliste, Lastannahmen, Einzelnachweis, Wandtabelle) | **Dokument-/Seiten-Routing** bestätigt: pro Frage die richtige(n) Seite(n) finden, nicht „ganzes PDF" |
| Wandtabelle S.53 liefert Längen | **Mengen-Aufmaß** für Wände ist machbar — über die Statik-Tabelle, nicht über die Zeichnung |

**Architektur-Empfehlung `/extract-plan` (mops-api):**
1. Seite einlesen → Text-Layer-Qualität prüfen (Zeichen pro Seite, Tabellen-Struktur).
2. Gut → Text-Extraktion (billig). Schlecht/leer → Seite zu PNG rendern → Vision.
3. Keyword-/Positions-Routing (z.B. „Pos 7.x", „Baustoffe", „Wandlager") führt zur richtigen Seite.

---

## 6. Methoden-/Reproduzierbarkeit

- Lokalisierung der Wandseiten: Swift+PDFKit Volltext-Scan über 163 Seiten (`/tmp/pdffind.swift`).
- Volltext der Schlüsselseiten (10, 12, 53, 132/134/142/151): PDFKit `page.string`.
- Visueller Check: Statik S.9 + Werkplan S.1/S.2 via Swift-PDFKit zu PNG gerendert (2,2× Scale), dann gelesen.
- **Kein** externes Tool nötig (kein poppler/pdftotext) — alles über das bordeigene Swift/PDFKit.
- Kein erfundener Wert; alle prüfbaren Angaben über ≥2 Statik-Stellen gegengeprüft.

---

## 🐠 Goldfisch-Zen

> Spike 1 zeigte: Vision liest Tabellen top, aber Wände stehen woanders.
> Spike 2 zeigt: „woanders" ist die Statik — und die ist sogar als reiner Text lesbar, fast gratis.
> Die eigentliche Kunst ist nicht das Lesen, sondern das **Routing**: pro Frage die richtige Seite.
> Daten schlagen Vermutung. Diesmal mit Pos-Nummer.
