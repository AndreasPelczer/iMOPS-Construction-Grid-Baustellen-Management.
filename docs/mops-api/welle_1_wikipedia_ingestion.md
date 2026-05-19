# Welle 1 — Wikipedia-Ingestion-Liste (Mops-API RAG)

**Version:** 0.1
**Erstellt:** 19.05.2026
**Bezug:** `baseline_results_20260519_104605.json` (Phi-3-Baseline-Test, 64 % Halluzinationen)
**Zweck:** Konkrete Lemma-Liste für die erste RAG-Ingestion-Welle, damit Phi-3 mit Quellen-Grounding antwortet und nicht mehr „GAEB DA83 = Dornier Alpha Jet" erfindet.

---

## 1. Strategie

Der Baseline-Test hat gezeigt, dass Phi-3 alle zentralen deutschen Bau-Fachbegriffe entweder leugnet oder erfindet. Die Welle 1 deckt **exakt die Themen ab, an denen Phi-3 versagt hat**, plus ein dünner Foundation-Kragen für Cross-Referencing.

**Bewusste Beschränkungen dieser Welle:**

- Nur deutschsprachige Wikipedia (`de.wikipedia.org`) — Mops bedient deutsche Bau-Profis.
- Keine DIN-Volltexte (Beuth-Lizenz, kostenpflichtig). Wikipedia-Artikel zu Normen genügen für Definition, Geltungsbereich, Struktur.
- Keine VOB-Volltexte (Beuth). Wikipedia-Artikel reicht für Teile A/B/C-Struktur.
- HOAI-Volltext ist frei verfügbar (§§ in Gesetzen), aber **nicht in Welle 1** — kommt in Welle 2 als juris-Ingestion.

**Lizenz-Hinweis:** Wikipedia-Inhalte stehen unter **CC-BY-SA 4.0**. Bei Ingestion-Chunks müssen `source_url`, `lizenz: "CC-BY-SA 4.0"` und `abruf_datum` als Metadaten mitgeführt werden, damit die spätere Antwort-Quellenangabe lizenzkonform ist.

---

## 2. Welle 1a — Pflicht-Lemmas aus Baseline-Versagen

Diese 17 Lemmas adressieren direkt die fehlerhaften Antworten des Baseline-Tests. Jeder Eintrag verweist auf die Test-Frage, an der Phi-3 gescheitert ist.

| # | Lemma | URL (de.wikipedia.org/wiki/...) | Baseline-Frage | Begründung |
|---|---|---|---|---|
| 1 | Mauerwerk | `Mauerwerk` | F1, F8 | Definition, Materialien, Verbände — Phi-3 lieferte nur Oberflächliches |
| 2 | Beton | `Beton` | F1 | Festigkeitsklassen C12/15 … C100/115, Transportbeton vs. Ortbeton |
| 3 | Stahlbeton | `Stahlbeton` | F6 | Verbundbaustoff Beton + Bewehrung, Phi-3 verwechselte mit Rohren |
| 4 | Streifenfundament | `Streifenfundament` | F2 | Typische Breiten 30–80 cm — Phi-3 sagte 1–2 m (Faktor 3 falsch) |
| 5 | Gründung (Bauwesen) | `Gr%C3%BCndung_(Bauwesen)` | F2 | Übersichts-Lemma: Flach- vs. Tiefgründung, Bodenpressung |
| 6 | Mörtel | `M%C3%B6rtel` | F3 | Mörtelarten, Bindemittel, Anwendungsbereiche |
| 7 | Mörtelgruppe | `M%C3%B6rtelgruppe` | F3 | MG I, II, IIa, III, IIIa — Phi-3 leugnete deren Existenz! |
| 8 | GAEB | `GAEB` | F4 | Gemeinsamer Ausschuss Elektronik im Bauwesen — Phi-3 sagte „Luftfahrt" |
| 9 | Leistungsverzeichnis | `Leistungsverzeichnis` | F4 | Kontext für GAEB DA83-Format |
| 10 | DIN 276 | `DIN_276` | F5, F9 | Kostengruppen 100–800 — Phi-3 sagte „Lebensmittel-Norm" |
| 11 | Baukosten | `Baukosten` | F5, F9 | Cross-Reference für Kostenermittlung nach Leistungsphasen |
| 12 | Bewehrung | `Bewehrung` | F6 | Anordnung, Stabstahl, Matten — Phi-3 erfand „Schussverbindungen" |
| 13 | Betonstahl | `Betonstahl` | F6 | B500A/B, Bst 500S, Eigenschaften |
| 14 | Aufmaß | `Aufma%C3%9F` | F7 | Mengenermittlung am Bau — Grundlage für REB-Verfahren |
| 15 | Mauerverband | `Mauerverband` | F8 | Läufer-, Binder-, Kreuz-, Blockverband — Phi-3 sagte „Gerüstbau" |
| 16 | Estrich | `Estrich` | F10 | Estrich-Arten, Aufbau — Phi-3 sagte „vielleicht Dampfbad?" |
| 17 | VOB | `VOB` *(ggf. `Vergabe-_und_Vertragsordnung_f%C3%BCr_Bauleistungen`)* | F14 | Teile A/B/C — Phi-3 sagte „Musik-Verwertungsgesellschaft" |

**Hinweis zu Lemma #7 (Mörtelgruppe):** Falls dieser Artikel in der deutschen Wikipedia nicht als eigenes Lemma existiert (kann Weiterleitung auf `Mörtel#Mörtelgruppen` sein), muss der Abschnitt aus `Mörtel` als eigener Chunk gespeichert werden.

**Hinweis zu Lemma #17 (VOB):** URL-Variante prüfen — Wikipedia hat manchmal das ausgeschriebene Lemma als Hauptartikel und das Akronym als Weiterleitung.

---

## 3. Welle 1b — Foundation-Kragen für Cross-Referencing

Diese 12 Lemmas wurden im Test nicht direkt abgefragt, sind aber häufige Folge-Themen und stärken das semantische Netz, damit das RAG-Retrieval auch indirekte Fragen bedienen kann.

| # | Lemma | URL (de.wikipedia.org/wiki/...) | Warum in Welle 1 |
|---|---|---|---|
| 18 | Trittschalldämmung | `Trittschalld%C3%A4mmung` | Direkt verknüpft mit Estrichdämmung (F10) |
| 19 | Wärmedämmung | `W%C3%A4rmed%C3%A4mmung` | Standardthema; Estrich, Außenwand, Dach |
| 20 | Schwimmender Estrich | `Schwimmender_Estrich` | Häufigste Estrich-Bauart |
| 21 | Mauerwerksbau | `Mauerwerksbau` | DIN 1053 / EC6 Kontext |
| 22 | Festigkeitsklasse (Beton) | `Druckfestigkeitsklassen_von_Beton` *(URL prüfen)* | C20/25 etc. — kritischer Profi-Begriff |
| 23 | Frischbeton | `Frischbeton` | Konsistenzklassen F1–F6 |
| 24 | Bautechnik | `Bautechnik` | Top-Level-Lemma, gutes Anker-Dokument |
| 25 | Hochbau | `Hochbau` | Abgrenzung zu Tiefbau |
| 26 | Tiefbau | `Tiefbau` | Gegenstück zu Hochbau |
| 27 | Rohbau | `Rohbau` | Gewerke-Übersicht (Maurer, Beton, Zimmerer) |
| 28 | Ausbau (Bauwesen) | `Ausbau_(Bauwesen)` | Estrich, Trockenbau, Maler |
| 29 | Bauabnahme | `Abnahme_(Recht)#Bauabnahme` *(Abschnitt)* | VOB/B § 12 Kontext |

---

## 4. Bewusst NICHT in Welle 1

Diese Themen sind wichtig, aber für Welle 1 zu groß / zu spezialisiert / zu lizenz-kritisch:

- **HOAI-Volltext** → Welle 2 (juris-Ingestion über `gesetze-im-internet.de`)
- **DIN-Norm-Volltexte** (DIN 276, DIN 18560, DIN 1053, EC6) → niemals direkt (Beuth-Lizenz). Nur Wikipedia-Definitionen + offizielle Beuth-Metadaten als Cross-Reference.
- **REB-Verfahren-Volltext** → Welle 2 (BMVBS-Veröffentlichungen)
- **GAEB-DA-XML-Schema** → Welle 3 (technische Format-Doku, anderer Ingestion-Pfad)
- **VOB/B Vertragstext** → Welle 2 (Beuth-Auszüge oder Kommentierungen mit Lizenz-Prüfung)
- **Brandschutz, Schallschutz, energetische Anforderungen** → Welle 2 (umfangreiche eigene Wellen)
- **Holzbau, Stahlbau** → Welle 3 (eigenes Themenfeld)

---

## 5. Ingestion-Hinweise für die Pipeline

Damit das Ingestion-Skript (siehe Konzept_Wissens_Ingestion_v0.3) sauber arbeitet:

### 5.1 Pro Chunk zu speichernde Metadaten

```yaml
source_url: "https://de.wikipedia.org/wiki/Beton"
source_type: "wikipedia_de"
lizenz: "CC-BY-SA 4.0"
abruf_datum: "2026-05-19"
lemma: "Beton"
welle: "1a"
themenfeld: "Baustoffe"     # oder: Bauverfahren, Vergabe, Kostenrecht, Bauabrechnung
sektion: "Festigkeitsklassen" # nur wenn Sub-Section
chunk_typ: "definition" | "norm" | "verfahren" | "beispiel"
```

### 5.2 Chunking-Strategie

- **Granularität:** Pro Wikipedia-Abschnitt (`==`-Heading) ein Parent-Chunk; pro `===`-Subheading ein Child-Chunk.
- **Max-Tokens pro Chunk:** 512 (bge-m3-Kontext-Optimum), mit 64-Token-Overlap.
- **Tabellen separat:** Wikipedia-Tabellen (z.B. DIN-276-Kostengruppen-Tabelle) als eigene Chunks mit `chunk_typ: "tabelle"` — sonst zerreißt das Chunking die Struktur.
- **Einleitung doppelt:** Der erste Absatz jedes Lemmas wird zusätzlich als eigener „Definitions-Chunk" gespeichert (höchstes Retrieval-Gewicht für Definitions-Fragen).

### 5.3 Verifikations-Schritt vor Ingestion

URLs in diesem Dokument sind nach bestem Wissen formuliert, aber Wikipedia ändert Lemma-Namen. Das Ingestion-Skript muss:

1. Jede URL per HTTP-Request prüfen.
2. Bei Redirect (z.B. `Mörtelgruppe` → `Mörtel`) den Ziel-URL übernehmen.
3. Bei 404 die URL hier eintragen (Log + Issue), nicht stillschweigend überspringen.
4. Den Wikipedia-Revisions-Hash (`oldid`) als Metadatum speichern — Reproduzierbarkeit.

### 5.4 Anti-Halluzinations-Wirkung messen

Nach Ingestion von Welle 1a die **gleichen 14 Baseline-Fragen** erneut stellen (Phi-3 + RAG). Erwartung:

- F2 (Streifenfundament): Faktor-3-Fehler weg → ✅
- F3 (Mörtelgruppe): keine Leugnung mehr → ✅
- F4 (GAEB DA83): keine Luftfahrt → ✅
- F5 (DIN 276): keine Lebensmittel → ✅
- F10 (Estrichdämmung): kein Dampfbad → ✅

Fang-Fragen (F11–F14) bleiben Stresstest — wenn Welle-1-Ingestion + Anti-Halluzinations-Prompt sauber sind, müssten die jetzt mit „dazu finde ich keine verlässliche Quelle" beantwortet werden.

---

## 6. Offene Punkte für Raffi-Review

Vor der Ingestion sollte Raphael (BauSU-Profi) folgende Fragen beantworten:

1. **Fehlt ein Pflicht-Lemma?** Aus 36 Jahren Bau-Praxis — was ist in der Liste nicht drin, was ein Polier am Bau täglich braucht?
2. **Priorisierung Welle 1a vs. 1b:** Soll z.B. „Rohbau" in 1a hoch, weil Top-Gewerk?
3. **Regionale Begriffe:** Bayrisch/Schwäbisch/Norddeutsch — gibt es Synonyme die als Cross-Reference rein müssen (z.B. „Riegel" vs. „Sturz")?
4. **VOB-Schwerpunkt:** Liegt Raffis Profi-Fokus mehr auf VOB/A (Vergabe) oder VOB/B (Vertrag) oder VOB/C (technische ATV)?

---

## 7. Nächste Schritte

1. **Verifikation der URLs** durch Ingestion-Skript (Abschnitt 5.3).
2. **Konzept_Wissens_Ingestion_v0.3** schreiben (Anti-Halluzinations-Prompt + Re-Test-Strategie).
3. **Ingestion Welle 1a** ausführen (17 Lemmas).
4. **Baseline-Test re-run** mit RAG.
5. **Bei Erfolg:** Welle 1b ingestieren.
6. **Bei Misserfolg:** LLM-Wechsel auf Qwen 7B planen (siehe Codi-Review-Punkt #1).

---

**Verknüpfte Dokumente** (außerhalb dieses Repos, auf Mops-Server):
- `Konzept_Mops_Architektur.md`
- `Konzept_Wissens_Ingestion_v0.2.md` (wird v0.3)
- `Codiclaudi_Prompt_Mops_Backend.md`
- `data/tests/baseline_results_20260519_104605.json`
