# Welle 3 — Plan-zu-Anfrage-Pipeline (Konzept v0.1)

**Version:** 0.1 (Pre-Spike-Konzept)
**Erstellt:** 03.06.2026
**Bezug:** Kollegen-Treffen 02.06.2026 + Live-Test des Mops am selben Abend
**Status:** Konzept — Spike (W3.1) noch nicht gelaufen, Entscheidung über B/C hängt am Spike-Ergebnis
**Vorgänger:** `welle_1_wikipedia_ingestion.md`, `baseline_test_02_vergleich.md`

---

## 1. Vision in einem Satz

Aus dem **Statiker-PDF** automatisch **Mengen → LV → Kostenschätzung → Gewerke-Anfrage** ziehen —
direkt vor Ort, mit dem Kontext, den nur der Bauleiter hat (Brigade, Wetter, Bautagebuch).

---

## 2. Die Pipeline

```
PDF-Pläne  →  Mengen  →  LV  →  Kostenschätzung  →  Gewerke-Anfragen
   ⬇️           ⬇️       ⬇️         ⬇️                  ⬇️
 Vision      Geometrie  DIN-276    AngebotsStore     NU-Mailings
  + OCR     + Material
```

| Stufe | Status heute | Was fehlt |
|---|---|---|
| 1. PDF → Strukturierung | **offen** (Kern-Risiko) | Vision-Extraktion, in `mops-api` einbauen |
| 2. Mengen-Ermittlung | halb da | Plan-Geometrie → Längen/Flächen + Material-DB |
| 3. LV erstellen | **da** (`LVKalkulator`, Seeder-Pattern) | generisch statt Mustermann-spezifisch |
| 4. Kostenschätzung | halb da (`AngebotsStore`) | BKI-Rahmen (vorerst Pauschalpreise/KG) |
| 5. Gewerke-Anfragen | halb da (`BestelllisteService`) | Gewerke-Zuordnung + NU-Adressbuch + VOB-Template |

**Kernaussage:** Stufen 3–5 existieren schon halb. **Die ganze Vision steht und fällt mit Stufe 1+2.**
Darum wird zuerst genau die riskanteste Annahme getestet — nicht der billigste Baustein zuerst gebaut.

---

## 3. Abgrenzung gegen Phase0

| | Phase0 | iMOPS / Mops |
|---|---|---|
| Zielgruppe | Architektur-Büros | **Bauleiter vor Ort** |
| Modell | SaaS, LV für Kunden | eigenständige App auf dem iPad |
| Killer-Feature | „VOB-konforme LVs auf Knopfdruck" | **Plan lesen + sofort kalkulieren, mit Brigade-/Wetter-/Bautagebuch-Kontext** |

Den Vor-Ort-Kontext kann Phase0 strukturell nicht liefern. Das ist die Abgrenzung, nicht die Pipeline an sich.

---

## 4. Erkenntnis aus dem Live-Test (02.06.2026)

Der Mops wurde gefragt, Innen- und Außenwände einer Baustelle aufzulisten — **ohne** die Pläne mitzugeben.
Ergebnis: er hat **nicht halluziniert**, sondern gesagt *„ohne diese Pläne wäre das pure Spekulation"*.
Beim Tippfehler „Speed Marktbreit" blieb er beim Wort statt heimlich auf „Mustermann" zu raten.

→ Der verschärfte RAG-Prompt wirkt. Lieber „weiß ich nicht" als ein erfundenes Wand-Verzeichnis,
nach dem ein Bauleiter handeln würde. **Das ist der wichtigere Test als jede Vorzeige-Antwort.**

→ Welle 1+2 gaben dem Mops das *allgemeine* Bau-Wissen. Was fehlt, sind **die eigenen Projekt-Daten**.

---

## 5. Drei Pfade zur Daten-Anbindung — und die Bewertung

| Pfad | Was | Ehrliche Einordnung |
|---|---|---|
| **A** | `Projekt-Mustermann.md` (handstrukturiert) ins RAG indexieren | Quickwin, aber **Sackgasse**: indexiert Handarbeit, nur 1 Baustelle, **Drift-Risiko** — ein Schnappschuss wird selbstbewusst zitiert, auch wenn das LV sich ändert. Bringt die Vision **nicht** voran. Nur als Demo. |
| **B** | Tool-Use: Mops fragt iMOPS live ab (`getBaustellenLV`) | **Richtige Lösung.** Live, alle Baustellen, kein Drift. Eigene Architektur-Runde. |
| **C** | PDF-Plan → Extraktion | **Das *ist* Welle 3.** Stufe 1+2 der Vision. Spike = Kern von C. |

Entscheidung: **A überspringen** (außer es muss kurzfristig was vorgezeigt werden) →
**Spike zu C zuerst** → **B erst planen, wenn der Spike zeigt, dass Extraktion taugt.**

---

## 6. Spike-Plan — W3.1

**Frage, die der Spike beantwortet:** Kann Claude Vision aus den echten Statiker-PDFs
zuverlässig Stützen + Wände ziehen — oder halluziniert er?

**Vorgehen (kostet keine Server-Arbeit):**
- Claude Vision liest PDFs **direkt** — Test läuft im Claude-Code-Chat, nicht am Mops-Server.
- Testmaterial (in `~/Downloads/`, 9 Pläne zu BV 448-GO):
  - `448-GO B 2 Stb.- Stützen.pdf` → Stützen-Extraktion
  - `448-GO B 1.1 BoPla untere Lage.pdf` → Geometrie / Wände / Bewehrungslage
- Pro Plan ehrlich protokollieren: **was sicher erkannt, was unsicher, wo würde er raten.**
- Abgleich gegen Bekanntes: `Projekt-Mustermann.md` (PPW 2-0,35 innen, PP 4-0,55 außen, d=24/36,5/17,5)
  und `MarktbreitSeeder` (Stb-Stützen Pos 7.2.1 + 7.3.1).

**Erfolgskriterium:** Wenn Vision z.B. „7 von 8 Stützen samt Position erkannt" liefert,
lohnt sich B/C. Wenn er rät oder Maße erfindet → Pipeline neu denken (mehr OCR/Geometrie nötig).

**Ergebnis** landet als eigener Abschnitt hier (v0.2) bzw. als `welle_3_spike_ergebnis.md`.

---

## 7. Architektur-Hinweise (gegen Verwechslung)

- Der **Vision-Endpoint** (`/extract-plan`) gehört in **`AndreasPelczer/mops-api`** — NICHT in dieses iOS-Repo.
- Der `server/`-Ordner *hier* ist der Blender/USDZ-Konverter, **nicht** der Mops-Server.
- Die App routet schwere Fragen heute schon via `/prof ` an Claude → der Vision-Weg passt da rein.
- BKI ist Politur, kein Blocker. Erst Pauschalpreise pro KG, BKI später.

---

## 8. Nächste Schritte

1. **W3.1 Spike** — Claude Vision gegen die 2 Pläne, ehrliches Protokoll. *(nach Absprache mit Andreas)*
2. Spike-Ergebnis hier als v0.2 eintragen → erst dann Go/No-Go für B/C.
3. Bei Go: Material-DB skizzieren (Wandtyp → Verbrauch/m²) + Gewerke-Mapping als Folge-Welle.

---

## 9. Offene Fragen

- Reicht Vision allein, oder braucht es echtes OCR/Vektor-Parsing für bemaßte Pläne?
- Tool-Use (Pfad B): welche iMOPS-Schnittstelle gibt das LV maschinenlesbar her?
- NU-Adressbuch: wo lebt das (Core Data vs. eigener Stammdaten-Store)?

---

## 🐠 Goldfisch-Zen

> Der Mops war ehrlich über seine Wissenslücke. Bei der Architektur bleiben wir's auch:
> erst den schwächsten Punkt (Plan → Mengen) testen, dann bauen. Daten schlagen Vermutung.
