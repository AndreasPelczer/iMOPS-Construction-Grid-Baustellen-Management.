# Welle 3 — Spike-Ergebnis W3.1 (Vision-Extraktion Statiker-Pläne)

**Version:** 1.0
**Durchgeführt:** 03.06.2026
**Methode:** Claude Vision (Claude Code, Opus) liest die Original-PDFs direkt — kein Mops-Server, kein OCR-Vorlauf.
**Testmaterial:** BV 448-GO Schwarz Marktbreit, 2 Pläne
- `448-GO B 2 Stb.- Stützen.pdf`
- `448-GO B 1.1 BoPla untere Lage.pdf`
**Ground Truth:** `Projekt-Schwarz.md` (handstrukturiert, Abschnitt 3.1/3.2) + `MarktbreitSeeder.swift`
**Vorgänger:** `welle_3_plan_zu_anfrage_pipeline.md`

---

## 1. Kurzfassung (TL;DR)

**Tabellen-Daten auf den Plänen werden quasi fehlerfrei gelesen** — Bewehrungslisten, Gewichte,
Betongüte, Bauteilmaße. Stahlgewicht stimmt **auf das Kilo** mit der Handarbeit überein.

**ABER:** Die **Geometrie zum Aufmaß** (Wandlängen/-flächen aus der Zeichnung) kommt nur als
loser Zahlen-Salat raus, ohne saubere räumliche Zuordnung. Und: **die Wand-Info, an der der
Live-Test gescheitert ist, steht auf diesen Plänen gar nicht** — die lebt in der großen Statik
(Pos 7.2/7.3) und im Werkplan.

→ **GO für die Pipeline — aber differenziert:** Stufe „Bewehrungs-/Stücklisten extrahieren" ist
sofort tragfähig. Stufe „Mengen-Aufmaß aus Plan-Geometrie" braucht mehr (richtige Quelldokumente
+ Geometrie-Logik), ist *nicht* mit reinem Vision auf einem Bewehrungsplan erledigt.

---

## 2. Plan B 2 — Stahlbeton-Stützen

### Spalte „sicher erkannt"
| Erkannt | Plan | Ground Truth | Treffer |
|---|---|---|---|
| 3 Stützentypen, je „2× herstellen" = 6 Stützen | TYP 1/2/3, „2x herstellen" | Typ 1/2/3 je 2× | ✅ |
| Typ 1: 16/30 cm, 7 cm Dämmung | Schnitt 1-1 | 16/30, 7 cm | ✅ |
| Typ 2: 30/23 cm, 5 + 12,5 cm Dämmung, „Eingang (EG)" | Schnitt 2-2 | 30/23, 5+12,5 | ✅ |
| Typ 3: 16/30 cm, 7 cm Dämmung | Schnitt 3-3 | 16/30, 7 cm | ✅ |
| Beton C 20/25, Expo XC1 | Schriftfeld | C 20/25 XC1 | ✅ |
| Höhe 2,77 m | Maßkette | 2,77 m lichte UG-Höhe | ✅ |
| Bewehrungsliste Pos 1–5 (Ø16/Ø12/Ø6, Längen, Anzahl) | Stahltabelle | — | ✅ |
| **Gesamtgewicht 365,81 kg B500A** | Tabelle | **365,8 kg** | ✅ **aufs Kilo** |
| Betondeckung cv=20, Vorhaltemaß 10 | Schriftfeld | — | ✅ |
| Metadaten: Plannr B 2, I-25_448-GO, 67774, 04.03.2026, M 1:25/1:75, Tragwerksplaner Neubauer | Schriftfeld | stimmt | ✅ |

### Spalte „unsicher / Vorsicht"
- Maßkette unter den Lageplänen (`3.58 · 30 · 2.71 · 5 …`) = Stützen-Abstände, aber **welche Zahl zu welcher Stütze** gehört, ist aus dem Text-Layer nicht eindeutig.

### Spalte „würde raten → bewusst weggelassen"
- **Position 7.2.1 / 7.3.1** (Statik-Positionsnummern, im Seeder hinterlegt) stehen **nicht** auf B 2.
  Das ist eine Cross-Dokument-Zuordnung (B 2 ↔ Statik) — aus dem Einzelplan **nicht** ableitbar.

---

## 3. Plan B 1.1 — Bodenplatte untere Lage

### Spalte „sicher erkannt"
| Erkannt | Plan | Ground Truth | Treffer |
|---|---|---|---|
| Bodenplatte d = 16 cm, untere Lage | Titel | Sohlplatte 16 cm | ✅ |
| Beton C 25/30, XC2/XF1 (unten), XC1 (oben) | Tabelle | C 25/30 XC2 | ✅ |
| DST-Gründung auf frostfreiem Polster | Hinweis | DST-Gründung | ✅ |
| Matten-Liste Pos 1–9 (Q188A/R188A, Längen×Breiten) | Tabelle | — | ✅ |
| Matten gesamt **331,28 kg** | Tabelle | 331,28 kg | ✅ **aufs Kilo** |
| Stab Pos 1: 6× Ø12, l=2,10 m, **11,19 kg** | Tabelle | 11,19 kg | ✅ |
| Schlange S 7: 49×, 2,00/0,70, **27,93 kg** | Tabelle | 27,93 kg | ✅ |
| **Summe untere Lage 370,4 kg** (331,28+11,19+27,93) | rechnerisch | 370,4 kg | ✅ |

### Spalte „unsicher / Vorsicht"
- Außenkontur als Maßkette vorhanden (`3.67 · 2.10 · 1.42 · 2.10 · 1.20` / `4.02 · 97 · …`), aber die
  Zahlen kommen **ohne XY-Zuordnung** — daraus „Plattenfläche = X m²" zu rechnen wäre geraten.

### Spalte „würde raten → bewusst weggelassen"
- Keine Wand-Information auf diesem Plan (ist ein Bewehrungsplan der Platte, keine Wandbau-Zeichnung).

---

## 4. Die zentrale Erkenntnis (für die Architektur wichtig)

Der Live-Test scheiterte an der Frage **„liste Innen- und Außenwände"**. Der Spike zeigt **warum**:

> Diese Info steht auf **keinem der beiden Bewehrungspläne**. Wände (PPW 2-0,35 / PP 4-0,55,
> d=24/36,5/17,5) leben in der **großen Statik** (`448-GO Statik … einseitig.pdf`, Pos 7.2/7.3)
> und im **Werkplan** (`Schwarz_WP_kk.PDF`).

**Konsequenz für Pfad C:** „PDF → Extraktion" ist nicht „ein Plan rein, alles raus". Es braucht
**Dokument-Routing**: pro Frage das *richtige* Dokument wählen (Wände → Statik/Werkplan,
Stahl → B-Pläne, Platte → B 1.x). Ein einzelner Plan ≙ ein Ausschnitt, nie das ganze Projekt.

---

## 5. Bewertung pro Pipeline-Stufe (Update zu welle_3, Abschnitt 2)

| Stufe | Spike-Befund | Reife |
|---|---|---|
| 1. PDF → Strukturierung | **Tabellen/Schriftfeld: exzellent.** Geometrie-Zeichnung: nur Roh-Zahlen. | 🟢 für Listen / 🟡 für Aufmaß |
| 2. Mengen-Ermittlung | Stahl-kg direkt ablesbar (steht tabelliert). m²/m³/Stück-Aufmaß aus Geometrie: **noch offen**. | 🟡 |
| → Wand-Mengen | Quelle ist Statik/Werkplan, nicht B-Pläne → Dokument-Routing nötig | 🔴 (anderes Dokument) |

---

## 6. Empfehlung / nächste Schritte

1. **Go für Stufe 1 (Listen-Extraktion).** Bewehrungs-/Stücklisten lassen sich heute zuverlässig
   in strukturiertes JSON ziehen → Basis für LV-Positionen + Bestelllisten.
2. **Spike-Runde 2:** dieselbe Methode gegen die **große Statik** + **Werkplan**, gezielt auf die
   Wand-Frage (PPW/PP, d, Wandlängen). Erst das beantwortet den ursprünglichen Live-Test.
3. **Dokument-Routing** als eigenes Konzept: welche Frage → welches Dokument. (Tool-Use Pfad B
   greift hier sauber ineinander: erst Routing, dann Extraktion.)
4. **Geometrie-Aufmaß** als eigene, ehrlich schwierige Teilaufgabe markieren — reines Vision auf
   gescannten Maßketten reicht nicht; ggf. Vektor-PDF/DXF nutzen (für Bungalow liegen DXF vor!).

---

## 7. Methoden-Notiz / Reproduzierbarkeit

- Auflösung war **kein** Limit — beide Pläne (~820–870 KB) wurden vollständig gelesen.
- Kein einziger erfundener Wert in der „sicher"-Spalte; alle prüfbaren Zahlen stimmen mit der
  Handarbeit überein (zwei unabhängige Gesamtgewichte aufs Kilo).
- Der Vision-Weg braucht **keinen** Server-Umbau zum Testen — produktiv läuft er über den
  bestehenden `/prof `-Claude-Pfad bzw. einen späteren `/extract-plan` im `mops-api`-Repo.

---

## 🐠 Goldfisch-Zen

> Vision liest die Tabellen besser als erhofft — und zeigt zugleich ehrlich die Grenze:
> die Wände stehen woanders. Genau dafür macht man einen Spike: nicht um Recht zu haben,
> sondern um zu wissen, wo der nächste Plan hinmuss. Daten schlagen Vermutung.
