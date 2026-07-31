# Welle 3 — Durchstich-Prototyp (Plan → LV → Bestellliste)

**Version:** 1.0
**Erstellt:** 03.06.2026
**Ort des Codes:** `~/Projekte/mops-extract-prototype/` (standalone, **außerhalb** des iOS-Repos —
Backend-Code gehört nicht hierher; wandert später in `AndreasPelczer/mops-api`).
**Vorgänger:** `welle_3_plan_zu_anfrage_pipeline.md`, `welle_3_spike_ergebnis.md`, `welle_3_spike_2_ergebnis.md`

---

## 1. Was steht

Erster **durchgängiger Durchstich** der Plan-zu-Anfrage-Pipeline, verifiziert am echten
BV 448-GO Mustermann Marktbreit:

```
PDF (163-S. Statik) → Wand-JSON → LV-Positionen (DIN 276) → Bestellliste (Steine/Paletten/Mörtel)
```

- `extract_plan.py` — Stufe 1+2: Text-Layer-Routing → Wände (Typen, 16 Segmente, Mengen je Dicke)
- `lv_bestellliste.py` — Stufe 3+4: Wand-JSON → LV-Positionen + Bestellliste

Sprache **Python/PyMuPDF** (server-portabel). Born-digital-Statik braucht **kein** Vision/OCR —
reine Text-Extraktion. Vision-Pfad ist Stub (für Plan-/Vektorseiten vorgesehen).

## 2. Ergebnis (verifiziert)

| KG | PosNr | Wand | Menge |
|---|---|---|---|
| 330 | 3.30.1 | Außen Z-17.1-543, d=36,5 | 28,42 m² |
| 330 | 3.30.2 | Außen PP 2, d=24 | 32,14 m² |
| 330 | 3.30.3 | Außen PP 4, d=24 | 6,60 m² |
| 340 | 3.40.1 | Innen PP 4-0.50, d=17,5 | 24,00 m² |

24-cm-Außenwand korrekt nach Material aufgeteilt (PP2 32,14 + PP4 6,60 = 38,74 m²).
Format deckt sich mit `MarktbreitSeeder.LVDaten` (posNr · kg · bezeichnung · einheit · menge).

## 3. Architektur-Bestätigung

- **Routing ist der Hebel:** Baustoffliste (S.10) → Wandtypen; Längen-Tabelle (S.53) → AW-Längen;
  Geometrie-Tabelle (S.55) → AW+IW Fläche/Volumen. Merge über Positionsbezeichnung.
- **Text-Layer-Qualitätscheck pro Seite** entscheidet Text vs. Vision (für `/extract-plan` übernehmen).

## 4. EG/OG-Wände — Befund + Schätzung (Schritt F, erledigt)

Die Statik **tabelliert die oberirdischen Wände nicht** (nur das UG ist FE-modelliert,
Geometrie-Tabelle S.55, h=2,77 m). „Positionsplan Erdgeschoss" (S.8) ist eine Zeichnung
ohne Mengentabelle. Lösung: **transparente geometrische Schätzung** der EG/OG-Außenwand
(Umfang × Höhe − Öffnungen + Giebeldreiecke), jede Position mit `quelle`-Tag
(`statik_tabelle` vs `schaetzung`) + Rechenweg im JSON.

**Validierung:** mit Traufhöhe 3,25 m und 0 % Öffnungsabzug → **114,5 m²** ≈ der handermittelte
Seeder-Wert **113 m²**. Bestätigt Rechenlogik *und* deckt die Seeder-Konvention auf
(Brutto-Umfang × Traufhöhe + Giebel, ohne Öffnungsabzug). Default im Prototyp steht
konservativ (EG-Höhe 2,75 + 18 % Öffnung → 81,6 m²); Konvention ist eine Bau-Entscheidung.

## 5. Offene Punkte (= nächste Schritte)

1. **E — Material-Stammdaten + Schätz-Konvention** mit Raphi/Hersteller festklopfen
   (Steine/m², Mörtel/m², Palettengrößen, Geschosshöhe/Öffnungs-% ) → beides belastbar.
2. **Oberirdische INNENwände**: weder Tabelle noch Proxy → bleiben vorerst manuell.
3. **C — Bewehrungs-Extraktor** (B-Pläne → Stahl-JSON, Spike 1 zeigte: Vision liest Tabellen top).
4. **Integration**: Code in echtes `mops-api`-Repo als `/extract-plan` heben (Repo lokal noch nicht da).

---

## 🐠 Goldfisch-Zen

> Vom PDF zur Bestellliste an einem Vormittag — aber ehrlich beschriftet, was UG-Modell ist
> und was noch Typwert. Lieber ein sauberer Ausschnitt mit Etikett als ein ganzes Haus auf Vermutung.
