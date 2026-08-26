# Bestandsaufnahme — SketchUp-Daten ins LV (26.08.2026)

> Erhoben, **bevor** die neue Datei von Raphi da war. Zweck: nicht raten müssen, wenn sie kommt.
> Alles hier ist am Code nachgesehen, nicht aus Erinnerung. Zeilenangaben Stand `main` 26.08.

---

## 1. Es gibt drei Wege — nur einer ist der aktuelle

| Weg | Format | Landet in | Stand |
|---|---|---|---|
| **Materialliste** ← *der aktive* | `.xlsx` / `.csv` → Box | **LV** (Deckel + Belege) | 06.08. |
| WandLeser | DXF/DWG → Box | LV (Wandflächen, Öffnungen) | 06.08. |
| MaterialImportService | CSV/JSON, lokal | **Auftrag**, nicht LV | Mai, fehlerhaft |

Der dritte ist der alte lokale Weg. Sein bekannter Komma-Bug ist bestätigt:
`Service/MaterialImportService.swift`, `parseCSV` splittet mit
`components(separatedBy: trenner)` **ohne Quote-Handling**, und die Anführungszeichen
werden erst **nach** dem Split entfernt — Quoting hilft also nicht. Bei
`"Wand_AW_17cmx6,0cm_Ost",3,1.5,…` zerlegt es mitten im Namen. Still, ohne Meldung.

**Für „SketchUp → LV" zählt Weg 1.** Die anderen beiden hier nur, damit niemand am
falschen Ende sucht.

---

## 2. Die Kette von SketchUp bis ins LV

```
SketchUp-Mengenauszug (.xlsx oder .csv)
  └→ POST /materialliste                          [Box, api/routes/materialliste.py]
       └→ kategorisiere()   Bauteilname → Kategorie   [api/services/materialliste.py:53]
            └→ kgFuer()     Kategorie   → KG-Nummer   [Views/MateriallisteView.swift:294]
                 └→ LVPosition: 1 Deckel + n Belege   [MateriallisteView.swift:333]
                      └→ LVView: gruppierbar, bearbeitbar
```

SketchUp rechnet Volumen und Maße selbst; wir lesen nur ab. Alles wird als
`mengenQuelle = .schaetzung` eingetragen — Rohzahlen sind Fakt, die Einordnung ist
Folgerung (Ehrlichkeits-Prinzip).

---

## 3. Woran der Import hängt — drei Bruchstellen

### 3.1 Die Kopfzeile
Der Parser sucht eine Zeile, die `definition` **und** `quantity` enthält (klein geschrieben),
dann die Spalten per Stichwort:

| Feld | akzeptierte Stichworte |
|---|---|
| Name | `definition`, `name` |
| Menge | `quantity`, `anzahl` |
| Volumen | `volume`, `volumen` |
| Maße | `lenx` / `len x`, `leny`, `lenz` |

**Bricht sichtbar:** „Kein Materiallisten-Kopf gefunden … Ist das ein SketchUp-Mengenauszug?"

### 3.2 Das Namensschema — die stille Bruchstelle
Die Kategorie wird **allein aus dem Bauteilnamen** geraten, in dieser Reihenfolge
(`api/services/materialliste.py:53`):

```
putz          → putz_aussen / putz_innen / putz     (Fläche)
bodenplatte   → bodenplatte                          (Volumen)
boden+fläche  → bodenflaeche                         (Fläche)
ringbalken    → ringbalken                           (Volumen)
sturz|flachsturz|ytong → sturz                       (Stück)
beton         → beton                                (Volumen)
AW-Muster     → aussenwand                           (Volumen)
IW-Muster     → innenwand                            (Volumen)
sonst         → unbekannt
```

Das AW/IW-Muster verlangt das Kürzel **abgegrenzt**: `(?:^|[_\-\s])aw(?:[_\-\s]|\d)`.
Also greift `Wand_AW_24_Ost`, aber **nicht** `Aussenwand24` und **nicht** `ExtWall`.

**Bricht still:** Bei anderem Namensschema landet alles in `unbekannt` — keine
Fehlermeldung, nur ein leeres Ergebnis. Das ist die wahrscheinlichste Ursache, wenn
„es plötzlich nicht mehr geht".

### 3.3 Die KG-Zuordnung ist grob
Siehe Abschnitt 4.

---

## 4. 🔴 Zwei KG-Systeme, die nichts voneinander wissen

| | Regeln | wird genutzt von |
|---|---|---|
| `Service/KGZuordnungsService.swift` | **41 Regeln, 280 Keywords**, 41 verschiedene KGs | Material-Import (Auftrag) |
| `kgFuer()` in `MateriallisteView.swift:294` | **9 feste Fälle** + Default `300` | **dem SketchUp-Weg** |

Der SketchUp-Weg benutzt die grobe Neun-Fall-Tabelle, während nebenan ein
ausdifferenzierter Service liegt und nicht angefasst wird. Wenn feinere KG-Einteilung
gewünscht ist, ist das vermutlich die Antwort: **verbinden, nicht neu bauen.**

⚠️ In `kgFuer()` stehen Kommentare wie *„lag fälschlich auf 331"* und *„war 324 =
Gründungsbeläge"*. Da wurde zweimal nachkorrigiert — vor dem „Richtigstellen" also
erst nachsehen, warum eine Zuordnung so ist.

### 4.1 Der Zuordnungsservice: Stand und Grenzen

Abdeckung gegen den Katalog (`Models/DIN276BaumKatalog.swift`, 335 Nummern):

| Hauptgruppe | abgedeckt |
|---|---|
| 300 Bauwerk — Baukonstruktion | **22 von 78** |
| 400 Technische Anlagen | 11 von 71 |
| 500 Außenanlagen | 8 von 72 |
| 100/200/600/700/800 | 0 — richtig so, keine Bauteile |

Die 22 in KG 300 sind **systematisch die Gebäudesubstanz**: Gründung (322–325),
Außenwände (331–336), Innenwände (341–345), Decken (351–354), Dächer (361–364).

**Mechanik** (`ordneZu`, Zeile 183): einfaches `contains` über alle Keywords,
**längster Treffer gewinnt**. Erweitern = eine Zeile in die Tabelle.

**🔴 Aber: `contains` kennt keine Wortgrenzen.** Mit den echten Regeln nachgespielt:

```
Baumaterial Lager       → KG 573 Pflanzungen    (Treffer auf "baum")
Aufhängung Decke        → KG 351 Decken         (Treffer auf "decke")
Wand_AW_24_Ost          → keine Zuordnung
Innenstütze Stahlbeton  → keine Zuordnung
Rolladenkasten          → keine Zuordnung
```

Zwei Dinge stehen da:
1. **„Baumaterial" landet bei den Pflanzungen.** Es gibt Keywords mit drei Zeichen
   (`tor`, `led`, `gkb`). Jedes neue kurze Keyword erhöht die Kollisionsgefahr für alle
   anderen — die Methode skaliert **nicht** linear.
2. **Der Service versteht das SketchUp-Namensschema nicht.** `Wand_AW_24_Ost` findet
   nichts. Die AW/IW-Kürzel kennt nur der Backend-Parser.

**Reihenfolge beim Erweitern — wichtig:**
1. Wortgrenzen einbauen (`contains` → Regex mit `\b`). Macht alles Weitere erst sicher.
2. AW/IW-Kürzel beibringen (dieselben Muster wie im Backend).
3. *Dann* neue Regeln.

Ohne Schritt 1 erzeugt Schritt 3 Fehltreffer, die niemand bemerkt.

**Lohnende Lücken in KG 300:**

| | | |
|---|---|---|
| 343 | Innenstützen | systematische Lücke — 333 Außenstützen existiert |
| 352 | Deckenöffnungen | systematische Lücke — 334 und 344 existieren |
| 326 | Dränagen | relevant, sobald ein Keller im Modell ist |
| 337/346/355/365 | Elementierte Konstruktionen | Fertigteile |
| 338/348/366 | Sonnenschutz | `Rolladenkasten` findet heute nichts |
| 391–394 | Baustelle, Gerüst, Abbruch | eigene Welt, aber real |

Nicht lohnend: 371–379 (Straßen-/Schienen-/Wasserbau), 381–389 (Einbauten),
alle „Sonstiges"-Nummern (319, 329, 339 …) — das sind Sammelposten.

---

## 5. Der Deckel — Ist-Stand und der offene Umbau

### Wie es heute ist

```swift
var istDeckel: Bool { (unterPositionen?.count ?? 0) > 0 }
```

**Ein Deckel ist schlicht „eine Position, die Kinder hat."** Es gibt kein Konzept
„Gruppe" — deshalb belegt er zwangsläufig eine Positionsnummer und trägt eine Menge.
Im Import (`MateriallisteView.swift:343`):

```swift
deckel.posNr      = String(format: "06.%02d", nextPos)      // belegt eine LV-Nummer
deckel.bezeichnung = "\(sek.label) (aus Materialliste)"      // Name generiert, nicht wählbar
```

Datenmodell (`test25B.xcdatamodel`, Entity `LVPosition`): Selbstbeziehung
`deckel → LVPosition` und `unterPositionen → LVPosition (viele)`, dazu die Felder
`deckelArt`, `deckelNotiz`, `mengeJeDeckelEinheit`.

Zwei Deckel-Arten sind bereits gebaut (`LVPosition+CoreDataProperties.swift:229`):

| `DeckelArt` | Bedeutung |
|---|---|
| `.mengentraeger` | Deckel trägt die Menge, Unterpunkte sind Belege |
| `.element` | Deckel ist die Summe seiner Bausteine (B-Element) |

Drumherum fertig: `deckelTyp` (getypter Zugriff), `setzeDeckelArt()` in der LVView,
`zusammenfuehren(deckel:kinder:)` zum manuellen Gruppieren.

### Was Andreas will (26.08.)

> „Der Deckel soll als solcher einzeln stehen und ich muss die Gruppe selbst benennen können."

Also: ein Kopf, der **überschreibt und benennt**, aber selbst keine Menge trägt und
nicht in Summen zählt.

### Der kleinste Weg dahin

Kein Umbau — **ein dritter Fall** `.gruppe` in `DeckelArt`. Das Muster steht bereits.
Drei Stellen:

1. **`DeckelArt`** um `.gruppe` erweitern (Enum-Fall + Anzeigetext)
2. **`Service/LVKalkulator.swift`** — bei `.gruppe` zählt nur, was drunterhängt
3. **Import** — `bezeichnung` wählbar machen statt automatisch zu setzen

Anzeige, Bearbeiten und Zusammenführen laufen dann mit, weil sie auf `istDeckel` und
`deckelTyp` aufbauen.

**Günstig:** `deckelArt` wird im Import **gar nicht gesetzt** und liegt im Modell schon
vor. Bestehende Deckel fallen per Default auf `.mengentraeger` — keine Migration,
nichts kann kippen.

### 🟡 Zwei Design-Fragen, vorher zu klären

**Was passiert mit der Nummer?** Heute bekommt der Deckel `06.01`, die Kinder keine.
Entweder die Gruppe bekommt gar keine Nummer und die Positionen darunter zählen normal
weiter — oder es wird echt hierarchisch (`06` als Gruppe, `06.01`/`06.02` darunter).
Das Zweite ist näher am echten LV, greift aber in die Nummernvergabe ein.

**Was macht der Export?** `GAEBExporter` und `LVPDFExporter` bauen auf denselben
Positionen auf. Eine Gruppe, die nicht zählt, muss dort als Überschrift erscheinen und
darf nicht in Summen einfließen — sonst weichen Export und Ansicht voneinander ab.
**Noch nicht geprüft.**

---

## 6. Was in der LVView schon geht

Damit nichts doppelt gebaut wird:

- **Gruppierung umschaltbar**, drei Modi: `KG` · `Dokument` · `Ebene`
  (`enum LVGruppierung`, `Views/LVView.swift:9`)
- **Bearbeiten**: Swipe-Actions beidseitig, „Position bearbeiten", Aufmaß- und
  Fortschritts-Sheets — für Deckel **und** Belege (`LVView.swift:331`)
- **Manuelles Zusammenführen** ausgewählter Positionen zu einem Deckel
  (`zusammenfuehren`, `LVView.swift:454`)
- **Deckelart umstellen** über die Oberfläche (`setzeDeckelArt`, `LVView.swift:423`)

---

## 7. 🔴 Lücken im Sicherheitsnetz

- **Es gibt keinen `test_materialliste.py`.** Für WandLeser, Klassifizierung und
  Bestellliste ja — für genau diesen Weg nicht.
- **Keine einzige `.xlsx` als Fixture** im Repo.

Wenn sich das Exportformat ändert, meldet das also nichts. Der Bruch fällt erst
draußen auf. Passend dazu steht im Backend-Handoff: *„Namensschemata anderer
SketchUp-Exporte können abweichen → mehr `unbekannt`; Regeln ggf. erweitern."*

**Vorschlag:** eine kleine `.xlsx` im heutigen Format plus einen Test dagegen. Dann
zeigt ein Vergleich mit Raphis neuer Datei schwarz auf weiß, was anders ist — statt
es aus Fehlermeldungen zu erraten.

---

## 8. Wenn die neue Datei kommt — Reihenfolge

1. **Kopfzeile ansehen.** Enthält sie `definition` und `quantity`? → sonst Bruchstelle 3.1
2. **Drei, vier Bauteilnamen ansehen.** Greift das AW/IW-Muster? → sonst Bruchstelle 3.2
3. **Erst dann** über KG-Einteilung, Gruppierung und Deckel reden.

Punkt 1 und 2 dauern zusammen eine Minute und entscheiden, ob es ein Parser-Thema
oder ein LV-Thema ist.
