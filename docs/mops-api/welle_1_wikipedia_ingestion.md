# Welle 1 — Wikipedia-Ingestion-Liste (Mops-API RAG)

**Version:** 0.2 (erweitert auf 72 Lemmas nach Codi-Konsultation)
**Erstellt:** 19.05.2026 (v0.1) — Aktualisiert: 20.05.2026 (v0.2)
**Bezug:** `baseline_results_20260519_104605.json` (Phi-3-Baseline-Test, 64 % Halluzinationen)
**Operative Datei:** `data/wiki_topics.txt` auf dem Mops-Server (Flat-List für Scraper)
**Zweck:** Konkrete Lemma-Liste für die erste RAG-Ingestion-Welle, damit Phi-3 mit Quellen-Grounding antwortet und nicht mehr „GAEB DA83 = Dornier Alpha Jet" erfindet.

---

## 1. Strategie

Der Baseline-Test hat gezeigt, dass Phi-3 alle zentralen deutschen Bau-Fachbegriffe entweder leugnet oder erfindet. Welle 1 deckt **die Themen ab, an denen Phi-3 versagt hat**, plus das umliegende Profi-Grundwissen für Maurer-Lernfelder 1–6.

**Bewusste Beschränkungen dieser Welle:**

- Nur deutschsprachige Wikipedia (`de.wikipedia.org`) — Mops bedient deutsche Bau-Profis.
- Keine DIN-Volltexte (Beuth-Lizenz, kostenpflichtig). Wikipedia-Artikel zu Normen genügen für Definition, Geltungsbereich, Struktur.
- Keine VOB-Volltexte (Beuth). Wikipedia-Artikel reicht für Teile A/B/C-Struktur.
- HOAI-Volltext kommt in Welle 2 als juris-Ingestion über `gesetze-im-internet.de`.

**Lizenz-Hinweis:** Wikipedia-Inhalte stehen unter **CC-BY-SA 4.0**. Bei jeder Ingestion-Chunk müssen `source_url`, `lizenz: "CC-BY-SA 4.0"` und `abruf_datum` als Metadaten mitgeführt werden, damit die spätere Antwort-Quellenangabe lizenzkonform ist.

---

## 2. Mapping Baseline-Versagen → Welle-1-Lemmas

| Baseline-Versagen | Adressiert durch |
|---|---|
| „Streifenfundament 1–2 m" (F2) | Streifenfundament, Fundament_(Bauwesen), Gründung_(Bauwesen) |
| „Mörtelgruppe existiert nicht" (F3) | Mörtel, Mauermörtel, Mörtelgruppe, Kalkmörtel, Zementmörtel |
| „GAEB = Dornier Alpha Jet" (F4) | GAEB, Leistungsverzeichnis, Bauabrechnung |
| „DIN 276 = Lebensmittel-Norm" (F5, F9) | DIN_276, DIN_277, Baukosten |
| „Bewehrung = Schussverbindungen" (F6) | Bewehrung, Bewehrungsstahl, Betonstahl, Stahlbeton |
| „REB = Nachhaltigkeits-Beschaffung" (F7) | Bauabrechnung, Mengenermittlung, Aufmaß |
| „Mauerverband = Vierendecker" (F8) | Mauerverband, Verband_(Mauerwerk), Läufer-/Kreuz-/Blockverband |
| „Estrichdämmung = Dampfbad" (F10) | Estrich, DIN_18560, Fußbodenaufbau, Wärmedämmung, Schallschutz |
| „VOB Teil Z = Musikgesellschaft" (F14) | VOB, Vergabe_und_Vertragsordnung_für_Bauleistungen |

---

## 3. Lemma-Liste (72 Artikel, 10 Themenfelder)

Diese Liste entspricht **eins zu eins** der Datei `data/wiki_topics.txt` auf dem Mops-Server.

### 3.1 Grundbegriffe Bauwesen (7)
Bauwesen · Hochbau · Tiefbau · Bauausführung · Bauproduktion · Bauwerk · Baustelle

### 3.2 Mauerwerk + Mauerbau (10)
Mauerwerk · Mauerziegel · Kalksandstein · Porenbeton · Hochlochziegel · Verband_(Mauerwerk) · Mauerverband · Läuferverband · Kreuzverband · Blockverband

> **Dedup-Hinweis für Scraper:** `Mauerverband` ist möglicherweise Redirect auf `Verband_(Mauerwerk)`. Der Scraper muss Redirects auflösen und Duplikate vermeiden (gleicher `oldid` = gleicher Artikel).

### 3.3 Beton + Stahlbeton (11)
Beton · Stahlbeton · Bewehrung · Bewehrungsstahl · Betonstahl · Zement · Portlandzement · Frischbeton · Festbeton · Betondeckung · Betonfestigkeitsklasse

> **Dedup-Hinweis:** `Bewehrungsstahl` und `Betonstahl` überlappen stark. Beide laden, dann beim Chunking auf inhaltliche Duplikate prüfen.

### 3.4 Mörtel (6)
Mörtel · Mauermörtel · Putzmörtel · Mörtelgruppe · Kalkmörtel · Zementmörtel

### 3.5 Fundamente + Gründung (6)
Fundament_(Bauwesen) · Streifenfundament · Plattenfundament · Punktfundament · Frostschürze · Gründung_(Bauwesen)

### 3.6 Bauteile (9)
Wand · Decke_(Bauteil) · Dach · Geschossdecke · Stahlbetondecke · Estrich · Fußbodenaufbau · Putz_(Baustoff) · Trockenbau

### 3.7 Normen + Abrechnung (13)
DIN_276 · DIN_277 · DIN_18560 · DIN_1053 · DIN_1045 · DIN_EN_1996 · GAEB · VOB · Leistungsverzeichnis · Bauabrechnung · Mengenermittlung · Aufmaß · Baukosten

> **Erwartungs-Management:** DIN-Artikel in Wikipedia sind Definitions-Stubs (Geltungsbereich, Struktur, Historie), keine Volltexte. Das genügt für „Was regelt DIN 18560?" — nicht für „Welcher Anhang DIN 18560 betrifft Heizestrich?". Letzteres ist Welle 2 (Beuth-Auszüge mit Lizenz-Prüfung).

### 3.8 Vergabe + Vertrag (3)
Vergabe_und_Vertragsordnung_für_Bauleistungen · Honorarordnung_für_Architekten_und_Ingenieure · Bauvertrag

### 3.9 Bauphysik (4)
Wärmedämmung · Schallschutz · Brandschutz · Feuchtigkeitsschutz

### 3.10 Baustoffe-Übersicht (3)
Baustoff · Naturstein · Holz_im_Bauwesen

**Gesamt: 72 Lemmas.** Geschätztes Roh-Markdown-Volumen: 20–50 MB.

---

## 4. Bewusst NICHT in Welle 1

- **HOAI-Volltext** → Welle 2 (juris-Ingestion über `gesetze-im-internet.de`)
- **DIN-Norm-Volltexte** → niemals direkt (Beuth-Lizenz). Nur Wikipedia-Definitionen.
- **REB-Verfahren-Volltext** → Welle 2 (BMVBS-Veröffentlichungen)
- **GAEB-DA-XML-Schema** (DA81, DA83, DA84 …) → Welle 3 (technische Format-Doku)
- **VOB/B Vertragstext** → Welle 2 (Beuth-Auszüge mit Lizenz-Prüfung)
- **Holzbau, Stahlbau, BIM, Bauphysik-Vertiefung** → Welle 3 (eigene Themenfelder)

---

## 5. Ingestion-Hinweise für die Pipeline

### 5.1 Pro Chunk zu speichernde Metadaten

```yaml
source_url: "https://de.wikipedia.org/wiki/Beton"
source_type: "wikipedia_de"
lizenz: "CC-BY-SA 4.0"
abruf_datum: "2026-05-20"
oldid: 234567890           # Wikipedia-Revisions-ID für Reproduzierbarkeit
lemma: "Beton"
welle: "1"
themenfeld: "Beton + Stahlbeton"
sektion: "Festigkeitsklassen"  # nur wenn Sub-Section
chunk_typ: "definition" | "norm" | "verfahren" | "tabelle" | "beispiel"
```

### 5.2 Chunking-Strategie

- **Granularität:** Pro Wikipedia-Abschnitt (`==`-Heading) ein Parent-Chunk; pro `===`-Subheading ein Child-Chunk.
- **Max-Tokens pro Chunk:** 512 (bge-m3-Kontext-Optimum), mit 64-Token-Overlap.
- **Tabellen separat:** Wikipedia-Tabellen (z.B. DIN-276-Kostengruppen-Tabelle, Mörtelgruppen-Tabelle) als eigene Chunks mit `chunk_typ: "tabelle"` — sonst zerreißt das Chunking die Struktur.
- **Einleitung doppelt:** Der erste Absatz jedes Lemmas wird zusätzlich als eigener „Definitions-Chunk" gespeichert (höchstes Retrieval-Gewicht für Definitions-Fragen).
- **Redirects auflösen:** Bei Wikipedia-Redirect (z.B. `Mauerverband` → `Verband_(Mauerwerk)`) den Ziel-URL übernehmen, aber das ursprüngliche Lemma als zusätzliche Suchvariante speichern.

### 5.3 Verifikations-Schritt vor Ingestion

URLs werden vom Scraper automatisch geprüft. Erwartete Ausfälle (siehe Welle1_Wikipedia_Topics.md):

- **DIN_18580** (Mauermörtel) — wahrscheinlich Stub
- **REB-Verfahren** — eventuell Redirect oder Abschnitt
- **Konkrete GAEB-DA-Versionen** — wahrscheinlich nicht vorhanden

Diese Lücken werden in Welle 2 geschlossen.

### 5.4 Anti-Halluzinations-Wirkung messen

Nach Ingestion die **gleichen 14 Baseline-Fragen** erneut stellen (Phi-3 + RAG). Erwartung pro Frage:

| Frage | Erwartung Test #3 |
|---|---|
| F1 Mauerwerk vs Beton | ✅ correct (klare Wikipedia-Quellen) |
| F2 Streifenfundament-Größe | ⚠️ partial (Größenordnung ja, exakte Werte ggf. nicht) |
| F3 Mörtelgruppe | ✅ correct (MG I, II, IIa, III in Wikipedia) |
| F4 GAEB DA83 | ⚠️ partial (GAEB-Hauptartikel ja, DA83-Detail ggf. nicht) |
| F5 DIN 276 Kostengruppen | ✅ correct (KG 100–800 in Wikipedia) |
| F6 Bewehrung Stahlbeton | ✅ correct |
| F7 REB Mengenermittlung | ⚠️ partial |
| F8 Mauerverband | ✅ correct |
| F9 KG 300 | ✅ correct (über DIN 276) |
| F10 Estrichdämmung | ✅ correct (über Estrich + DIN 18560) |
| F11–F14 Traps | ✅ refused (keine Quelle → keine Antwort) |

**Erfolgs-KPIs (siehe `baseline_test_02_vergleich.md`):**
- Halluzinations-Rate: 64 % → < 20 %
- Trap-Refusal: 2/4 → 4/4
- Quellenangaben: 0 % → ≥ 95 %

---

## 6. Offene Punkte für Raffi-Review

Vor / parallel zur Ingestion sollte Raphael (BauSU-Profi) folgende Fragen beantworten:

1. **Fehlt ein Pflicht-Lemma?** Aus 36 Jahren Bau-Praxis — was ist nicht drin, was ein Polier täglich braucht?
2. **Regionale Begriffe:** Bayrisch/Schwäbisch/Norddeutsch — Synonyme die als Cross-Reference rein müssen (z.B. „Riegel" vs. „Sturz")?
3. **VOB-Schwerpunkt:** Liegt Raffis Profi-Fokus mehr auf VOB/A (Vergabe) oder VOB/B (Vertrag) oder VOB/C (technische ATV)?
4. **Lehrplan-Mapping:** Decken die Themenfelder 3.1–3.10 die Maurer-Lernfelder 1–6 sinnvoll ab, oder fehlen Lernfeld-spezifische Themen?

---

## 7. Operative Schritte auf dem Mops-Server

```
[1] docker compose up -d                  # Qdrant + Ollama starten
[2] python scripts/01_scrape_wikipedia.py # 72 Artikel laden
[3] manuelle Sichtung                     # welche Artikel sind dünn?
[4] python scripts/02_chunk.py            # 512-Token-Chunks erzeugen
[5] python scripts/03_ingest.py           # in Qdrant einspeisen
[6] python scripts/04_sanity_check.py     # Test-Retrieval prüfen
[7] python scripts/05_baseline_rerun.py   # die 14 Fragen mit RAG
[8] Vergleich Test #2 vs. Test #3         # Erfolg messen
```

---

## 8. Erweiterungs-Ideen für später

### Welle 1.5 (Lücken-Schließung)
Falls nach Test #3 einzelne Artikel zu dünn waren: Wiktionary-Bau-Einträge, Wikipedia-Kategorien-Übersichten, ergänzende Wikipedia-Stub-Erweiterungen.

### Welle 2 (eigenes Konzept v0.3)
KMK-Rahmenlehrplan Maurer (PDF), GAEB-Spec-Dokumente (öffentlich), DIN-Übersichts-Vertiefung, HOAI-Volltext, BIM-Grundlagen.

### Welle 3 (laufend)
Raffis BauSU-Lerntagebuch, Andreas' Lerntagebuch, FAQ aus Mops-Anfragen (was Praktiker tatsächlich fragen).

---

**Verknüpfte Dokumente:**
- `docs/mops-api/baseline_test_02_vergleich.md` (in diesem Repo)
- `data/wiki_topics.txt` (auf Mops-Server, operativer Flat-List für Scraper)
- `data/tests/baseline_results_20260519_104605.json` (Test #1)
- `Welle1_Wikipedia_Topics.md` (Codi-Vorlage, identisch mit dieser Lemma-Liste)
- `Konzept_Mops_Architektur.md`, `Konzept_Wissens_Ingestion_v0.2.md` (auf Mops-Server)

---

## 🐠 Goldfisch-Zen

> Welle 1 ist nicht die finale Antwort, sondern die erste Hypothese.
> Nach Test #3 wissen wir konkret: welche Artikel decken gut ab, wo sind Lücken, welche Antworten sind besser/gleich/schlechter geworden — diesmal **mit Quellen**.
>
> Daten schlagen Vermutung. Wieder.
