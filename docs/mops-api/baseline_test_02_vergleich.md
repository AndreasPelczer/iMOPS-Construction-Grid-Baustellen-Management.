# 🧪 Baseline-Test #2 — Vergleichs-Auswertung

**Datum:** 19.05.2026 (Nachmittag)
**Bezug:** Erster Test → `data/tests/baseline_results_20260519_104605.json`
**Änderung gegenüber Test #1:** Anti-Halluzinations-System-Prompt live im Backend (`api/services/ollama_client.py`, Branch `claude/review-concept-document-SMnYf`)
**Test-Suite:** Unverändert (10 Bau-Fragen + 4 Fang-Fragen)
**Modell:** Phi-3 Mini (3.8B) Q4 via Ollama — unverändert
**Hardware:** Mops-Server (i5-3470, 16 GB RAM, CPU-only) — unverändert

---

## 🎯 Zweck dieses zweiten Tests

Test #1 hat 64 % Halluzinationen offengelegt und 0 % ehrliches Refusal. Daraufhin wurde ein **Anti-Halluzinations-System-Prompt** eingeführt mit der Kernregel:

> Wenn die Wissensbasis keine Antwort hergibt: antworte
> „Dazu finde ich keine verlässliche Quelle in meiner Wissensbasis."
> Erfinde NIEMALS Normen, DIN-Nummern, GAEB-Codes oder KG-Bezeichnungen.

**Forschungsfrage:** Wirkt Prompt-Engineering allein — oder ist RAG zwingend?

**Kurzantwort:** Prompt-Engineering wirkt **teilweise**. RAG bleibt **zwingend**, weil das Fehlerprofil sich nur verschoben, nicht aufgelöst hat.

---

## 📊 Brutale Bilanz — Vorher vs. Nachher

### Trap-Fragen (existieren nicht, sollten ehrlich abgelehnt werden)

| Frage | Test #1 | Test #2 | Δ |
|---|---|---|---|
| F11: DIN 99999 | „DIN 4057, DIN 9865…" erfunden | **„keine verlässliche Information"** + Verweis | ✅ Gewonnen |
| F12: GAEB DA42 | „Gehirn-Atem-Entspannung, Qigong" 🤡 | **„existiert nicht, könnte fiktional sein"** + GAEB richtig erklärt | ✅ Gewonnen |
| F13: KG 999 | „CFRP-Bewehrung…" erfunden | „Hypothetisch, ohne Definition keine Info" — aber zu lang | ⚠️ Besser, aber labert |
| F14: VOB Teil Z | „VOMBI = Musikgesellschaft" | „muss intern recherchiert werden" — schwammig, erfindet „Teil 1 bis 7" | ⚠️ Teil-Erfindung |

**Refusal-Rate Traps:** **0/4 → 2/4** (erste messbare KPI-Bewegung im Projekt)

### Echte Bau-Fragen — Stichprobe der dramatischsten Stellen

| Frage | Test #1 | Test #2 | Δ |
|---|---|---|---|
| F3: Mörtelgruppe | „Es gibt keine 'Mörtelgruppe' im Bauwesen" 🚨 | „Dazu habe ich keine verlässliche Information. Mörtelgruppen sind im Rahmen der Baubranche üblich…" | ✅ Existenz nicht mehr geleugnet |
| F4: GAEB DA83 | „General Aviation Examination Book, Dornier Alpha Jet" 🚨 | „keine verlässliche Information, an Fachpersonal wenden" | ✅ Kein Dornier mehr |
| F5: DIN 276 | „Lebensmittel-Norm für Nährwertangaben" 🚨🚨🚨 | „fünf Hauptkostengruppen: Grundstein, Estrich, Oberflächenbehandlung, Decken- und Wändeinlagesysteme, Türen Fenster Treppen" | ⚠️ Domain stimmt jetzt, Inhalt weiter erfunden |
| F8: Mauerverband | „Vierendecker + Diagonalen" (Gerüstbau) | „Gruppe von Arbeitern im Baugewerbe, die Mauern montieren" | ❌ Immer noch falsch, neuer Quatsch |
| F10: Estrichdämmung | „vielleicht Dampfbadtherapie, Massage?" 🤡 | Eiert über Außenwände, dann „Mitte September als optimaler Zeitraum" | ❌ Kein Wellness mehr, aber weiter verwirrt |

---

## 🚨 Wichtigste Erkenntnis: Failure-Mode hat sich verschoben

Der Anti-Hallu-Prompt hat **nicht** die Halluzinationen eliminiert — er hat ihren **Charakter** verändert:

| | Test #1 — Offensichtlicher Bullshit | Test #2 — Plausibler Bullshit |
|---|---|---|
| **DIN 276** | „Lebensmittel-Norm, Getreide, Fette" | „Grundstein, Estrich, Oberflächenbehandlung…" |
| **Mauerverband** | „Vierendecker im Gerüstbau" | „Gruppe von Arbeitern" |
| **GAEB** | „Dornier Alpha Jet" | (jetzt richtig) |
| **Erkennbarkeit** | Polier lacht und ignoriert | Polier könnte glauben |

**Das ist NICHT unbedingt eine Verbesserung.** Test #1-Bullshit war offensichtlich abwegig — selbstschützend. Test #2-Bullshit klingt domain-richtig und ist deshalb **gefährlicher**.

→ **Ein Polier am Bau, der „DIN 276 = Grundstein, Estrich, Oberflächenbehandlung" liest, würde es nicht hinterfragen.** Das ist genau die Bau-Sphäre, in der der Begriff hingehört — nur die fünf Hauptkostengruppen sind frei erfunden (real: KG 100–800).

---

## 📈 Neue KPI: Token-Verhalten als Confidence-Signal

| Metrik | Test #1 | Test #2 | Δ |
|---|---|---|---|
| Gesamtdauer | 11:52 | 14:23 | +21 % |
| Trap-Fragen Ø Tokens | 329 | 228 | **−31 %** |
| Echte Fragen Ø Tokens | 255 | 280 | +10 % |
| Längste Antwort | 500 (Cap) | 500 (Cap) | gleich |

**Auslegung:**

- Bei **Traps**: Phi-3 wird **kürzer** — Anti-Hallu-Prompt schafft Vorsicht.
- Bei **echten Fragen**: Phi-3 wird **länger** — Unsicherheit führt zu Schwadronieren statt Klarheit.

**Implikation für RAG-Phase:** Token-Verhalten ist ein nutzbares Confidence-Signal. Antworten ≥ 400 Tokens auf einfache Definitionsfragen sind ein Halluzinations-Verdachts-Marker und sollten ins Re-Ranking / Quellen-Check einfließen.

---

## 🎯 Konsequenzen für die Roadmap

### Bestätigt
- ✅ **RAG ist zwingend.** Anti-Hallu-Prompt allein reicht nicht — Phi-3 erfindet weiter, nur in plausiblerer Form.
- ✅ **Welle-1-Wikipedia-Ingestion bleibt priorisiert** (siehe `welle_1_wikipedia_ingestion.md`).
- ✅ **Anti-Hallu-Prompt bleibt im Backend** — er bringt messbar 2/4 Trap-Refusals und reduziert die offensichtlichste Domain-Verwechslung.

### Neu erkannt
- ⚠️ **„Plausibler Bullshit" ist gefährlicher als offensichtlicher** — Anti-Hallu-Prompt darf nicht als Heilung gelten, nur als Erste Hilfe.
- ⚠️ **Quellen-Pflicht in jeder Antwort** wird kritischer — ohne Quellenangabe ist plausibler Bullshit nicht von echtem Wissen unterscheidbar.
- ⚠️ **Token-Länge als Confidence-Signal** ins Monitoring aufnehmen.
- ⚠️ **Re-Test nach Welle 1a Ingestion** muss F5 (DIN 276) und F8 (Mauerverband) als Kern-Indikator behandeln — wenn die nach RAG noch erfunden sind, ist das Modell zu schwach (→ Qwen-7B-Plan ziehen).

### Verschärfter Test-Standard
Ab jetzt gehört zur Baseline-Suite verpflichtend:

1. **Refusal-Rate auf Trap-Fragen** (Ziel: ≥ 90 %)
2. **Domain-Richtigkeit** (separat von Inhalt-Richtigkeit zu bewerten)
3. **Token-Länge pro Fragetyp** (Definitions-Fragen sollten Tokens reduzieren, nicht erhöhen)
4. **Quellenangaben-Quote** (nach RAG-Phase: ≥ 95 % der Antworten müssen Quellen zitieren)

---

## 🐠 Goldfisch-Zen dieses Tests

> Prompt-Engineering ist Erste Hilfe, nicht Heilung.
>
> Der höfliche Anti-Halluzinations-Prompt hat Phi-3 nicht zum Bau-Experten gemacht — er hat ihn zu einem **vorsichtigeren Halluzinanten** gemacht. Das ist Fortschritt, aber kein Ziel.
>
> Test #1 war absurd falsch und deshalb selbst-entlarvend.
> Test #2 ist plausibel falsch und deshalb gefährlicher.
> Test #3 (mit RAG) muss zeigen: ist Phi-3 mit Quellen sauber, oder schwadroniert er trotz Quellen weiter? Wenn letzteres → Modell-Wechsel.

---

## 📋 Status & nächste Schritte

**Heute erledigt:**
- ✅ Baseline-Test #1 ausgeführt + ausgewertet
- ✅ Anti-Hallu-System-Prompt ins Backend integriert
- ✅ Baseline-Test #2 ausgeführt + ausgewertet (dieses Dokument)
- ✅ Welle-1-Wikipedia-Liste committet (PR #24)

**Noch offen:**
- ⏳ Codi-Konsultation: Reihenfolge Pipeline-Skripte vs. Raffi-Review
- ⏳ Konzept_Wissens_Ingestion_v0.3 schreiben
- ⏳ Raffi-Review der Welle-1-Liste (4 offene Fragen aus `welle_1_wikipedia_ingestion.md`)
- ⏳ Ingestion-Pipeline (Scraper, Chunker, Qdrant) bauen
- ⏳ Welle 1a tatsächlich ingestieren
- ⏳ **Baseline-Test #3 mit RAG** — die eigentliche Wahrheits-Probe

---

**Erstellt:** 19.05.2026, Nachmittag
**Verknüpfte Dokumente:**
- `docs/mops-api/welle_1_wikipedia_ingestion.md` (in diesem Repo)
- `data/tests/baseline_results_20260519_104605.json` (Test #1, auf Mops-Server)
- Test-#2-Ergebnis-JSON (Pfad nachtragen, sobald exportiert)
- `Konzept_Mops_Architektur.md` (auf Mops-Server)
