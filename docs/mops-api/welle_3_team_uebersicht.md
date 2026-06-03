# Welle 3 — Plan-zu-Anfrage-Pipeline · Team-Überblick

**Stand:** 03.06.2026 · Testprojekt: BV 448-GO Schwarz, Marktbreit

## Die Vision in einem Satz
Aus dem **Statiker-PDF** automatisch **Wände → Mengen → LV → Bestellliste/Anfrage** ziehen —
direkt vor Ort, mit dem Kontext, den nur der Bauleiter hat (Brigade, Wetter, Bautagebuch).
Abgrenzung zu Phase0 (Architektur-SaaS): wir sind **auf der Baustelle**, nicht im Büro.

---

## Was wir heute gemacht haben

**1. Zwei Spikes (Machbarkeit am echten Plan geprüft)**
- Claude Vision liest die **Tabellen** der Bewehrungspläne quasi fehlerfrei (Stahlgewichte aufs Kilo).
- Bemaßte **Zeichnungs-Geometrie** kommt nur roh → eigene Nuss.
- Die große **Statik ist als Text lesbar** (kein OCR nötig). Wand-Infos stehen dort, nicht auf den B-Plänen.
- **Erkenntnis:** Der Hebel ist **Routing** — pro Frage die richtige Seite/das richtige Dokument finden.

**2. Durchstich-Prototyp gebaut (Python, server-tauglich)**
- `extract_plan.py` — Statik-PDF → **Wände** als JSON (Typen, 16 Segmente, Mengen je Dicke)
- `lv_bestellliste.py` — Wände → **LV-Positionen** (DIN 276) + **Bestellliste** (Steine/Paletten/Mörtel)
- `bewehrung.py` — alle B-Pläne → **Bewehrungsstahl** als JSON

---

## Geprüfte Ergebnisse (gegen die handgepflegte Projekt-Datei abgeglichen)

| Was | Ergebnis | Genauigkeit |
|---|---|---|
| **Wandtypen** | 4 Typen (PP 2-0.35 / PP 4-0.55 / PP 4-0.50 / Z-17.1-543) | ✅ alle korrekt |
| **Wand-Mengen UG** | 24 cm: 38,7 m² · 36,5 cm: 28,4 m² · 17,5 cm: 24,0 m² | ✅ aus Statik-Tabelle |
| **EG/OG-Außenwand** | ~82 m² (bzw. ~114 m² Seeder-Konvention) | ⚠️ SCHÄTZUNG, klar etikettiert |
| **Bewehrungsstahl** | **8 Pläne, Summe 1.709 kg B500A** | ✅ aufs Kilo (Soll 1.708,9) |

Beispiel-Ergebnis Bewehrung:
```
B 1.1 370,4 · B 1.2 259,8 · B 2 365,8 · B 3 105,1
B 4   358,2 · B 5   26,9 · B 6 201,7 · B 7  21,1   → Σ 1.709 kg
```

---

## Wo liegt was

**Prototyp-Code + Ergebnisse:** `~/Projekte/mops-extract-prototype/`
- `extract_plan.py`, `lv_bestellliste.py`, `bewehrung.py`, `README.md`
- `out/` → `448-GO_waende.json`, `448-GO_lv_bestellliste.json`, `448-GO_bewehrung.json`

**Konzept & Doku (im iOS-Repo):** `docs/mops-api/`
- `welle_3_plan_zu_anfrage_pipeline.md` (Konzept + Abgrenzung Phase0)
- `welle_3_spike_ergebnis.md` / `welle_3_spike_2_ergebnis.md` (Machbarkeits-Spikes)
- `welle_3_durchstich_prototyp.md` (Prototyp-Stand)
- `welle_3_team_uebersicht.md` (dieses Dokument)

**Projekt-Unterlagen sortiert:** `~/Downloads/UnterlagenRaphi/`
(Schwarz-448-GO Statik/Bewehrung/Architekt/Kaufmännisch · Bungalow · NTH)

---

## Ehrlich: was noch offen ist
- **Material-Stammdaten** (Steine/m², Mörtel/m², Palettengrößen) + **Schätz-Konvention** (Geschosshöhe,
  Öffnungsabzug) sind vorläufige Typwerte → **mit Raphi/Hersteller festklopfen**.
- **Oberirdische Innenwände** hat die Statik nicht tabelliert → vorerst manuell.
- **Integration** in den echten `mops-api`-Server steht noch aus (Code ist dafür schon portabel gebaut).
- **Kostenschätzung + Gewerke-/NU-Anfragen** (Stufen 4+5) noch offen.

## Erledigt (Update 03.06.)
- Bewehrungs-Tabellen aller 8 B-Pläne vollständig aufgeschlüsselt (auch B6/B7).
- Stahl als eigene LV-Positionen je Kostengruppe: KG 320 = 630,2 kg · KG 330 = 386,9 kg · KG 350 = 692,0 kg.
- Restliche Bauteile als Mengen-LV: Decke 60,62 m², Stützen 6 Stk (4× 16/30 + 2× 30/23) —
  exakt aus geometrischer Auswertung; Sohlplatte abgeleitet, Streifenfundament/Ringbalken manuell.
- **Gewerke-Zuordnung + NU-Anfragen (VOB):** alle Positionen einem Gewerk zugeordnet
  (Maurer / Stahlbeton), je Gewerk eine fertige NU-Anfrage. Zuordnung = Entwurf, Raphi-Check raus.
- **Kostenschätzung (Pre-Estimate):** Rohbau netto ~27,8 T€ / brutto ~33,1 T€ über alle KG —
  mit Platzhalter-Preisen; echte Preise kommen über die NU-Anfragen zurück.

## Wie es weitergeht (Vorschlag)
1. **Stammdaten + Gewerke-Check mit Raphi** → Bestellliste + Gewerke-Zuordnung belastbar *(beides raus, warten)*.
2. **NU-Adressbuch** mit echten Firmen füllen + NU-Anfragen versenden → echte Preise zurück.
3. **`/extract-plan` im mops-api** scharf schalten (Code heben — braucht das Backend-Repo).
4. **Vision-Pfad** für Vektor-/Scan-Pläne (oberirdische Innenwände) — Stufe „Kür".

---
*Kurz: vom PDF zur Bestellliste an einem Vormittag — und ehrlich beschriftet, was hart gemessen
und was geschätzt ist. Daten schlagen Vermutung.* 🐠
