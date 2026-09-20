# BKI ernten — das Verfahren

Erarbeitet am 20.09.2026 an einer laufenden Baustelle. Wiederverwendbar für jede weitere.
BKI Baupreise Online, Abo erforderlich.

## Bevor du anfängst: zwei Einstellungen

Oben rechts im Portal, über das Zahnrad:

1. **Regionalfaktor** von `DE` auf euren Kreis stellen. Main-Tauber = **1,027**.
   Ohne das rechnest du mit Bundesdurchschnitt — bei 40.000 € macht das über 1.000 €.
   Alle Preise in der Liste ändern sich sofort um diesen Faktor.
2. **Baupreisindex** notieren (stand oben rechts, z. B. `BPI Q2/2026 = 140,3`). Er gehört
   zu jedem geernteten Wert dazu, sonst weiß später niemand, auf welchem Stand er ist.

## So suchst du

**Ein einziges Wort.** Keine Maßangaben, kein Komma, kein Schrägstrich. Die Suche ist
UND-verknüpft: „Mauerwerk 24 cm, Innen-/Außenwand" liefert null Treffer, `Mauerwerk` liefert
zehn.

**Das Namensschema ist die halbe Miete.** BKI benennt Positionen anders, als man auf dem Bau
spricht:

| du suchst | BKI nennt es |
|---|---|
| Mauerwerk einer Wand | **Innenwand, …** / **Außenwand, …** |
| Filigrandecke | **Elementdecke, xx cm, inkl. Aufbeton** |
| Bewehrungsmatten | **Betonstahlmatten, BSt B500A/B500B** |
| Pflaster | **Pflasterdecke, Betonpflaster** |
| Sperrschicht unter der ersten Steinreihe | **Querschnittsabdichtung, Mauerwerk bis xx cm** |

„Mauerwerk" findet nur Nebenleistungen (abgleichen, Dämmstein, Öffnungen) — die Wände selbst
heißen Innenwand/Außenwand.

**Wenn nichts kommt:** Leistungsbereich als Filter setzen, Suchfeld **komplett leeren**, Lupe
drücken. Dann siehst du alles, was der Bereich hergibt (LB 012 hat z. B. 107 Positionen), und
lernst die Benennung.

Wichtige Leistungsbereiche: **LB 002** Erdarbeiten · **LB 012** Mauerarbeiten ·
**LB 013** Betonarbeiten · **LB 018** Abdichtung · **LB 080** Freianlagen.

## Was du je Position notierst

```
Positionstext:  Innenwand, HLz-Planstein 24cm, 12DF
BKI ID:         BKI-012000xxx
ME:             m²
MITTEL Ø:       115 €
VON / BIS:      xx € / xx €
```

Die **Spanne** ist wichtig, nicht nur der Mittelwert — sie zeigt, wie sicher der Wert ist.
Liegt VON/BIS weit auseinander, ist die Position unscharf definiert.

## Der Firmenfaktor — der eigentliche Trick

BKI liefert **Marktpreise**: mittlere Angebotspreise inklusive Baustellengemeinkosten,
Verwaltung, Wagnis und Gewinn. Eure eigene Kalkulation liegt woanders. Diese Werte
danebenzustellen, ohne das zu berücksichtigen, macht die Endsumme unbrauchbar.

**So ermittelst du den Faktor:** Such dir drei bis vier Positionen, die **beide** Kataloge
führen — eure und BKI. Rechne je Position `euer Preis / BKI-Preis`. Kommen ähnliche Werte
heraus, hast du den Faktor.

Beispiel aus der Praxis (20.09.2026), drei verschiedene Gewerke:

```
Bodenplatte Ortbeton C25/30   174,00 / 239,29 = 0,727
Pflasterdecke Betonpflaster    33,50 /  46,21 = 0,725
Öffnungen im Mauerwerk         45,00 /  61,00 = 0,738
                                       Mittel  0,730
```

Spanne 1,3 Prozentpunkte über Beton, Pflaster und Mauerwerk. Damit ist der Faktor belastbar.

Ab dann gilt: `Firmenpreis = BKI-Mittelwert × Faktor`. Mit Rechenweg dokumentieren —
BKI-Position, Mittelwert, Regionalfaktor, Faktor.

**Ein Ausreißer ist ein Befund, kein Fehler.** Fällt eine Position aus der Reihe, sind die
beiden Positionen nicht dasselbe. Beispiel: die Elementdecke kam auf 0,451 statt 0,730 — weil
die Katalogzeile der Firma nur Verlegen und Aufbeton enthält, die BKI-Position aber die
Filigranplatten mitliefert. Die Differenz von rund 41 €/m² waren genau die fehlenden Platten.
Der Ausreißer hat einen Kalkulationsfehler aufgedeckt.

## Wohin die Werte gehören

| was | wohin | warum |
|---|---|---|
| BKI-Marktpreise | `Resources/Knowledge/bki_marktpreise_2026.yaml` | Referenz, kein Firmenpreis — darf ins Repo |
| eure Katalogpreise | lokal, Stammdaten | Betriebswissen |
| **der Firmenfaktor** | **lokal, Stammdaten** | verrät eure Marge — gehört nicht ins Repo |

Rechtlich: Einzelne BKI-Werte mit Quellenangabe zu übernehmen ist normales Zitieren. Ganze
Tabellen ins Repo zu kopieren wäre es nicht. Die YAML macht es richtig — pro Eintrag die
BKI-Position, der Leistungsbereich, ein Wert, der Stand.
