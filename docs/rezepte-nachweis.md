# Rezepte: woher jede Zahl kommt

Stand 20.09.2026. Regel dieser Runde: **keine erfundene Zahl.** Jeder Baustein hängt an
einem Aufwandswert, der schon belegt im Repo steht. Wo kein Beleg da war, wurde die Lücke
offen gelassen statt geschätzt.

Preise stehen bewusst **nicht** in dieser Datei — sie sind Betriebswissen und liegen lokal.

## 1. Was ohne eine einzige neue Zahl gelöst wurde

Fünf Positionen fanden ihr Rezept nicht, obwohl es existierte — der Katalogtext und der
Text auf der Baustelle sind verschiedene Sprachen. Gelöst durch **Tags**, nicht durch Werte:

| Baustein | neue Tags | fängt jetzt |
|---|---|---|
| ABD-002 Abdichtung Kelleraußenwände | Bauwerksabdichtung, Spritzwasserbereich, Sockelabdichtung, Sockel | „Bauwerksabdichtung W1.1-E, +15 cm ü. Gelände" |
| BET-009 Fundamentbeton | Fundamentbett, Bettung, Unterbeton, Stützwinkel | „Beton Fundamentbett unter Stützwinkel C25/30" |
| KAN-006 PVC-Rohr DN100 | Grundleitung, Grundleitungen, frostfrei | „Grundleitungen KG DN 100 frostfrei" |
| PFL-002 Betonverbundpflaster | Stellplatz, Stellplätze, Fahrwege, Zufahrt, Pflaster | „Stellplätze befestigen (2 Stück lt. B-Plan)" |
| BET-007 Treppenläufe | Treppenloch, Treppenauge, Innentreppe | „Treppenloch aussparen" |

Dazu MAU-008 um die ASCII-Schreibweisen ergänzt (Deckendurchbrueche/Bodendurchbrueche) —
importierte LV-Texte tragen oft keine Umlaute, und der Matcher macht aus „ü" ein „u",
nicht „ue".

## 2. Neue Bausteine — jeder an einem vorhandenen, belegten Aufwandswert

| Baustein | Einheit | Aufwandswert | dessen Quelle (aufwandswerte.yaml) |
|---|---|---|---|
| MAU-007 Mauerwerk Porenbeton (Ytong/Hebel) | m² | mauerarbeiten.mauerwerk_porenbeton 0,5 h | BUB, PRAXIS |
| MAU-008 Aussparungen und Durchbrüche | St | mauerarbeiten.sturz_einbauen 0,35 h | PRAXIS |
| BET-013 Ortbetonergänzung auf Elementdecke | m³ | betonarbeiten.betonieren_allgemein 0,5 h | HOF, PAK |
| ERD-014 Gelände modellieren (Cut/Fill) | m³ | erdarbeiten.baugrube_ausheben_bagger 0,05 h | PAK, PRAXIS |
| ERD-015 Böschung herstellen | m² | erdarbeiten.boden_verdichten 0,03 h | PRAXIS |
| KAN-015 Zisterne setzen | St | kanalbau.schacht_setzen 6,0 h | PRAXIS |
| ABD-010 XPS-Dämmeinlage unterseitig | m | abdichtung.perimeterdaemmung 0,18 h | RAFFI |

Material-Mengen für MAU-007: `Service/YtongBedarf.swift` — Bedarfswerte je m³ Mauerwerk
aus dem öffentlichen Ytong/Xella-Vordruck („Bedarfswerte je m³ Mauerwerk", Höhe 249,
Länge 599). Der **Preis** je Stein steht bewusst auf 0 und kommt aus den Stammdaten.

## 3. Die einzige neue Zahl — und ihre Herleitung

`betonarbeiten.elementdecke_verlegen` = **0,75 h/m²**

```
betonarbeiten.stahlbeton_decke      1,20 h/m²   (Ortbetondecke, Quelle HOF/BNW)
schalarbeiten.schalung_decke      − 0,45 h/m²   (Deckenschalung, Quelle HOF/ARH)
                                  ───────────
elementdecke_verlegen               0,75 h/m²
```

Begründung: Eine Filigran-/Elementdecke braucht **keine** Deckenschalung, nur
Montageunterstützung. Min und Max im selben Verhältnis (0,55 / 1,0).
`RezepteRohbauTests.derAbgeleiteteWertStimmtMitSeinerHerleitung` rechnet das bei jedem
Testlauf nach — ändert jemand einen der beiden Ausgangswerte, ohne den abgeleiteten
mitzuziehen, schlägt der Test an.

## 4. Was bewusst OHNE Rezept bleibt

| Position | warum kein Wert |
|---|---|
| Kimmschicht LM 21 (MG III) | kein Aufwandswert im Repo, keine belastbare Fremdquelle. Von Raphi eintragen lassen. |
| Fundamenterder umlaufend | dito. Material ist belegt (Erdungsband 30×3,5 mm im Firmenkatalog), die Arbeitszeit nicht. |
| Plattendruckversuch Ev2 | Fremdleistung eines Prüfinstituts — kein Eigenleistungsrezept sinnvoll, Angebot einholen. |
| Drempelstützen | Rezept existiert (betonarbeiten.stuetze 5,0 h/m³), aber die Position rechnet in Stück. Entweder Position auf m³ umstellen (4 × 0,24 × 0,17 × 2,02 = 0,33 m³) oder einen Stück-Wert eintragen. |

Diese vier hält `RezepteRohbauTests.bewussteLueckenBleibenLeer` fest. Schlägt der Test an,
hat jemand eine Zahl ohne Herkunft nachgeschoben — oder eine Lücke sauber geschlossen.
Beides soll auffallen.

## 5. Zwei offene Punkte am Nachweis-System selbst

1. **Die Quellen-Kürzel haben keine Legende.** BUB, ARH, HOF, PAK, FSG, BNW, ART-P, CIV,
   RAFFI, PRAXIS — nirgends im Repo steht, wofür sie stehen. Damit ist keiner dieser
   Werte im strengen Sinn nachlesbar. Eine Legende im `meta`-Block von
   `aufwandswerte.yaml` würde das lösen; die Auflösung kann nur jemand liefern, der die
   Werte eingetragen hat.
2. **„ARH" widerspricht dem eigenen Hinweis.** Im `meta` steht „Richtwerte aus
   öffentlichen Quellen. Keine geschützten ARH-Tabellen." Trotzdem ist ARH bei
   `mauerarbeiten.mauerwerk_ks_planstein` und drei Schalungswerten als Quelle angegeben.
   Entweder stimmt die Quellenangabe nicht oder der Hinweis. Vor einer Veröffentlichung
   klären — ARH-Tabellen sind lizenzpflichtig.

## Wirkung

Rohbau-Positionen einer laufenden Baustelle mit Rezept: **65 von 80 → 76 von 80.**
Gemessen mit dem echten Katalog gegen die echten Positionsbezeichnungen, nicht gegen
Katalogtexte.
