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

## Es gibt KEINEN einheitlichen Firmenfaktor

*Korrigiert am 20.09.2026. Hier stand vorher das Gegenteil — dass Goldschmitt durchgehend
bei rund 0,730 × BKI liegt, "dreifach bestätigt". Das war falsch und hätte eine Kalkulation
verdorben. Wie der Fehler entstand, steht unten; er ist lehrreicher als die Regel.*

BKI liefert **Marktpreise**: mittlere Angebotspreise inklusive Baustellengemeinkosten,
Verwaltung, Wagnis und Gewinn. Eure eigene Kalkulation liegt woanders — aber **nicht überall
gleich weit weg.** Gemessen an echten Zeilen:

```
Pflasterdecke Betonpflaster     Katalogzeile / BKI = 0,73   ← deutlich unter Markt
Außenwand-Mauerwerk 30 cm       Katalogzeile / BKI = 1,02   ← auf Marktniveau
```

*(Die absoluten Preise stehen bewusst nicht hier — sie sind Betriebswissen und gehören in
die Stammdaten, siehe Tabelle unten. Die Methode gehört ins Repo, die Zahlen nicht.)*

Das sind keine 1,3 Prozentpunkte Streuung, sondern **rund 40 %.** Ein Mittelwert daraus wäre
für beide Positionen falsch. Goldschmitt ist im Tiefbau/Pflaster günstig und im Mauerwerk
marktüblich — das ist ein normales Firmenprofil, kein Messfehler.

**Also: Position für Position vergleichen, nie hochrechnen.** Der BKI-Wert ist eine
Plausibilitätsprobe für die einzelne Zeile, kein Umrechnungsschlüssel für den Katalog.

### Wie der falsche Faktor entstand — die Falle

Drei Zahlen schienen ihn zu bestätigen. Nur eine war ein echter Vergleich:

| angeblicher Beleg | was es wirklich war |
|---|---|
| Bodenplatte, Faktor 0,73 | der BKI-Vergleichswert war aus mehreren Zeilen **selbst zusammenaddiert** — kein abgelesener Wert |
| Öffnungen im Mauerwerk, Faktor 0,74 | links stand **mein eigener Richtwert**, keine Katalogzeile → Zirkelschluss |
| Pflasterdecke, Faktor 0,73 | echt: Katalogzeile gegen BKI-Zeile |

Aus **einem** Datenpunkt wurde eine Regel, weil zwei Scheinbelege danebenstanden. Die
Gegenprobe kam erst, als eine echte Katalogzeile (Mauerwerk) dagegenstand.

**Regel daraus:** Ein Faktor zählt nur, wenn **beide** Zahlen abgelesen sind — links eine
Zeile aus dem Firmenkatalog, rechts eine Zeile aus BKI. Selbst zusammengesetzte Summen und
eigene Richtwerte sind keine Belege, sie sehen nur so aus.

### Wenn eine Position weit daneben liegt

Dann sind es meist **nicht dieselben Leistungen.** Die Elementdecke kam auf 0,451 — weil die
Katalogzeile der Firma nur Verlegen und Aufbeton enthält, die BKI-Position aber die
Filigranplatten mitliefert. Die Differenz von rund 41 €/m² waren genau die fehlenden Platten.
Der Ausreißer hat eine Lücke in der Kalkulation aufgedeckt. **Erst die Leistungstexte
vergleichen, dann die Zahlen.**

Gleiches Muster beim Winkelstützelement: BKI-080000421 nennt die **Betonbettung** im
Leistungstext. Wer daneben eine eigene Position "Fundamentbett" führt, kassiert zweimal.

### Die Einheit ist die zweite Falle

BKI rechnet Winkelstützelemente **je laufendem Meter Wand**, nicht je Stück. Bei 995 mm
breiten Elementen ist das fast dasselbe — bei 500 mm breiten wäre es der Faktor 2. Vor jedem
Übernehmen prüfen, worauf sich die BKI-Einheit bezieht.

## Wohin die Werte gehören

| was | wohin | warum |
|---|---|---|
| BKI-Marktpreise | `Resources/Knowledge/bki_marktpreise_2026.yaml` | Referenz, kein Firmenpreis — darf ins Repo |
| eure Katalogpreise | lokal, Stammdaten | Betriebswissen |
| **der Firmenfaktor** | **lokal, Stammdaten** | verrät eure Marge — gehört nicht ins Repo |

Rechtlich: Einzelne BKI-Werte mit Quellenangabe zu übernehmen ist normales Zitieren. Ganze
Tabellen ins Repo zu kopieren wäre es nicht. Die YAML macht es richtig — pro Eintrag die
BKI-Position, der Leistungsbereich, ein Wert, der Stand.
