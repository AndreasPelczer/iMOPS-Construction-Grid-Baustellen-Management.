# Welle 5.2 — AufmassView UI · Pre-Spec für „wir 3"

> **Status**: Diskussions-Grundlage für Andreas + Codi + Mops.
> **Verfasst**: 9.6.2026, Nachmittag, während Branch-Cleanup + Step-0-Nachzügler.
> **Nächster Schritt**: gemeinsam besprechen → finale Spec → Codi implementiert.

---

## Wo wir stehen

✅ **Welle 5.1 (PR #56)** — Aufmass-Entity + Soll/Ist-Computed-Properties auf LVPosition. Datenfundament steht.

🔧 **Step-0-Nachzügler** (heute Nachmittag) — `mengenQuelleRaw` in `ParsedLVPosition` durchgereicht.

🌊 **Welle 5.2** — der UI-Schritt: **wie gibt der Polier ein Aufmaß ein, und wie sieht er Soll/Ist?**

🛑 **NICHT in 5.2** — diese Stellen sind explizit ausgeklammert (Buch Kap 11):
- BuildIQ-Foto-Erkennung (= 5.3)
- LVPosition-Picker im BuildIQ-Flow (= 5.4)
- `mengenQuelle`-Update beim ersten Aufmaß (= 5.5 Welle-9-Brücke)
- Stockwerk-/Gebäude-Hierarchie als eigene Entity (= später, wenn empirisch nötig)
- Lieferanten-Anfrage/Bestellung-Workflow (= separate Welle)
- Schicht-A (Onboarding) + Schicht-C (Settings-Bereich) aus Save #45 (eigenständige Bauten)

---

## 🎯 Definition of Done — grob

5.2 ist fertig, wenn:
1. Polier kann in der App ein Aufmaß zu einer LV-Position eingeben (manuell, ohne BuildIQ)
2. Polier sieht Soll-Menge, Ist-Summe, Abweichung pro LV-Position
3. Mindestens **eine Schicht-B-Stelle** ist implementiert (Save #45, kontextuelle Mini-Aufklärung)
4. Tests grün (Stack-Load + Aufmaß erstellen + Soll/Ist-Berechnung)
5. UI funktioniert auf iPhone (iPad-Anpassung via SwiftUI-Standard)
6. PR-Beschreibung mit Buch-Kap + Roman-VTP-Anker + DoD + 5.3-5.5-Abgrenzung

---

## ❓ Sechs Fragen für die Sitzung

### Frage 1: Wo gibt der Polier ein Aufmaß ein?

| Option | Beschreibung | Pro | Contra |
|---|---|---|---|
| **A) LV-Position-Detail-View** *(Empfehlung)* | Polier tappt LV-Position an → Detail mit Aufmaß-Liste + „Neues Aufmaß"-Button | kontextuell richtig (Position im Blick), Buch Kap 11 (eine Stelle) | mehr Taps bei Multi-Erfassung |
| B) Quick-Add via Toolbar | globaler „+ Aufmaß"-Button öffnet Sheet mit LV-Position-Picker | schnell von überall | LV-Position-Picker = vorgezogenes 5.4 |
| C) Hybrid (A + B) | beides parallel | best of both | doppelter Code-Pfad, Verstoß gegen Kap 11 |

**Empfehlung**: **A**. Quick-Add kann später als 5.2.5 nachgeschoben werden, wenn Polier-Feedback es einfordert. *„Halbgas, nicht Avengers"*.

**Frage**: einverstanden, oder soll Quick-Add direkt mit rein?

---

### Frage 2: Welche Felder im Aufmaß-Formular?

| Feld | Required? | Default | Hinweis |
|---|---|---|---|
| `istMenge` | ✅ ja | — | Double, numerische Tastatur |
| `istEinheit` | nein | `lvPosition.einheit` | übernimmt LV-Einheit, kann überschrieben werden |
| `notiz` | nein | leer | Freitext (z.B. „EG, Treppenhaus West") — **kandidiert für VoiceInputButton** |
| `fotoData` | nein | leer | Slot bleibt leer in 5.2 — wird in 5.3 von BuildIQ befüllt |
| `quelle` | implizit | `.manuell` | in 5.2 alle Aufmaße manuell; .buildiq kommt in 5.3 |
| `erstelltAm` | automatisch | `Date()` | Timestamp = Nachweis-Anker (Buch Kap 4) |

**Offene Frage 2a**: Soll `notiz` direkt den `VoiceInputButton` haben (existiert im Code-Graph), oder erstmal nur Tastatur?
**Offene Frage 2b**: Wenn `istEinheit` von `lvPosition.einheit` abweicht — warnen oder akzeptieren?

---

### Frage 3: Wie wird Soll/Ist angezeigt?

| Option | Beschreibung | Pro | Contra |
|---|---|---|---|
| **A) Karte im Detail-View** *(Empfehlung)* | Soll-Menge groß oben, Ist-Summe darunter, Abweichung % + Farbe, dann Aufmaß-Liste | klare Hierarchie, Buch Kap 6 (Zustand sichtbar) | nur im Detail sichtbar |
| B) Liste mit Abweichungs-Spalte | LV-Liste zeigt pro Zeile Soll · Ist · Abw% · Status | Überblick auf einen Blick | viel Info pro Zeile, mobile-eng |
| **C) Hybrid (A + Mini-Indikator)** *(starke Alternative)* | Liste hat Mini-Ampel (Punkt), Detail hat Vollkarte | Überblick + Detail | etwas mehr Aufwand |

**Empfehlung**: **A für 5.2**, **C als 5.2.6** nachgeschoben — Mini-Ampel ist trivial, wenn `istMengeSumme` + `abweichungProzent` schon computed sind (sind sie, dank 5.1).

**Farbschema** für Abweichung — Park-Zettel-konform:
- **|Abweichung| ≤ 5 %** → grün
- **|Abweichung| ≤ 15 %** → orange
- **|Abweichung| > 15 %** → rot
- **`!hatAufmass`** → grau („noch nicht gemessen")

→ Das ist die **Welle-9-Ampel auf Position-Ebene**, schon hier nutzbar.

---

### Frage 4: Schicht-B-Tooltips (aus Save #45) — wo genau?

**Mindestens 1 Tooltip in 5.2 als erster Test der App-Philosophie-Schicht.**

| Stelle | Tooltip-Text (Vorschlag) | Buch-Bezug |
|---|---|---|
| **A) Schätzkarte (`lvPosition.istGeschaetzt == true`)** | *„Geschätzt, noch nicht gemessen. Damit du den Unterschied siehst, ohne nachfragen zu müssen."* | Kap 6 |
| B) Aufmaß-Eintrag-Formular | *„Dieser Zustand ist jetzt fest. Mit Datum und Quelle. Der nächste Polier weiß Bescheid."* | Kap 5 |
| C) Soll/Ist-Karte (wenn Abweichung > 0) | *„Mops vergleicht, kontrolliert nicht. Du weißt selbst, was zu tun ist."* | Kap 7 |

**Empfehlung**: **A + B**. Minimal aufwendig, maximaler Effekt — Polier sieht Schicht-B in Aktion, ohne dass es nervt. C ist gut, aber kann 5.2.7 sein.

**Komponente**: `PhilosophieTooltip` als wiederverwendbare SwiftUI-View (Skelett in Save #45 — `Image(systemName: "book.fill")` + `.popover`).

---

### Frage 5: Navigation

```
LVView (existiert)
   │
   │ tap auf LV-Position
   ▼
LVPositionDetailView (existiert? oder neu?)
   ├── Soll/Ist-Karte oben
   ├── PhilosophieTooltip 📖 wenn istGeschaetzt
   ├── Aufmaß-Liste (chronologisch DESC)
   │      └── AufmassRowView pro Eintrag
   └── „+ Neues Aufmaß" Button
              │
              │ tap
              ▼
       NeuesAufmassSheet (modal/sheet)
              ├── istMenge (Required)
              ├── istEinheit (Optional, Default-Übernahme)
              ├── notiz (Optional, Voice?)
              └── PhilosophieTooltip 📖 (B-Stelle)
```

**Frage 5a**: Gibt es schon `LVPositionDetailView` oder muss die neu? *(Mops-Code-Scan zeigt: `LVView` ja, `EventDetailView` ja, aber `LVPositionDetailView` unklar — bitte beim Implementieren checken)*

---

### Frage 6: iPad-First oder iPhone-First?

**Empfehlung**: **iPhone-First + SwiftUI-Standard-Layouts**.

Begründung:
- Raphi nutzt iPhone (Setup von gestern morgen)
- Polier auf der Baustelle hat eher iPhone in der Tasche
- iPad bekommt durch `NavigationSplitView` automatisch eine gute Adaptation
- Mehrkosten gering, Wirkung groß

**Offene Frage 6a**: `NavigationStack` oder `NavigationSplitView` als Root? *(Vermutlich SplitView, weil das schon im Code für iPad-Nutzung steht)*

---

## 📖 Buch- und Roman-Bezüge (für PR-Beschreibung)

| Element | Buch / Roman |
|---|---|
| `AufmassListView` zeigt Liste chronologisch | **Kap 5** Übergabe als Zustandswechsel mit Datum |
| `NeuesAufmassSheet` mit `istMenge` als Required | **Kap 2** Eindeutigkeit (Menge ist Pflicht, alles andere optional) |
| Soll/Ist-Karte mit Ampel-Farbe | **Kap 6** Zustand statt Bewertung + Park-Zettel |
| `PhilosophieTooltip` an Schätzkarte | **Kap 10** Gute Systeme sind still — aber haben Antworten parat |
| `quelle = .manuell` automatisch gesetzt | **Kap 11** Einfachheit — kein Auswahl-Dialog für etwas, das in 5.2 immer manuell ist |
| Foto-Slot leer in 5.2, befüllt in 5.3 | **Roman Anhang C VTP** — *„Foto vom Buffet"* als künftiger Anker |
| Polier-Eingabe der Menge selbst | **Roman Anhang C** — *„Der Polier beweist sein Aufmaß selbst"* (= VTP-Übersetzung) |

---

## 🧪 Test-Strategie

Da UI-Tests in SwiftUI schwer sind: **Logik in testbare Helper auslagern**, View-Tests minimal halten.

| Was | Wie |
|---|---|
| Aufmaß-Erstellung + Persistenz | Unit-Test wie in 5.1 (existiert schon, ggf. ergänzen) |
| Soll/Ist-Berechnung | Unit-Test auf LVPosition computed properties (sollte aus 5.1 bestehen) |
| Tooltip-Anzeige-Logik | Unit-Test auf ViewModel/Helper, der `istGeschaetzt` prüft |
| SwiftUI-Views | Smoke-Test (Build grün + Preview lädt), keine Snapshot-Tests |

---

## 📁 Datei-Liste (geschätzt)

**NEU**:
- `Views/AufmassListView.swift` (Liste pro LV-Position)
- `Views/NeuesAufmassSheet.swift` (Eingabe-Formular)
- `Views/AufmassRowView.swift` (Zeile in der Liste)
- `Views/PhilosophieTooltip.swift` (Schicht-B-Komponente, wiederverwendbar)
- ggf. `Views/LVPositionDetailView.swift` (falls noch nicht existiert)

**ANGEFASST**:
- `Views/LVView.swift` (Navigation zu Detail erweitern, falls nötig)
- ggf. `LVTiefenkalkulationView` oder `LVImportView` (kleine Anpassungen)

**Erwartung**: ~5-7 Dateien, ~300-500 Zeilen — größer als 5.1 (Daten-Etappe war kleiner), aber überschaubar.

---

## 🚧 Wenn keine Spec-Sitzung erfolgt — Default-Entscheidungen

Falls Andreas sagt *„mach was du für richtig hältst, ich vertraue euch"*, dann gelten:

1. **Frage 1**: Option A (Detail-View)
2. **Frage 2**: alle Standard-Defaults, `VoiceInputButton` mit drin (existiert eh)
3. **Frage 3**: Option A (Detail-Karte) — Mini-Ampel als 5.2.6 nachgeschoben
4. **Frage 4**: Tooltips A + B implementiert
5. **Frage 5**: Detail-View neu anlegen, falls nicht da
6. **Frage 6**: `NavigationStack` als Root, iPhone-First

→ **Codi kann auf Basis dieser Defaults legitim starten**, wenn Andreas signalisiert „ich vertraue".

---

## 🐶 Mops-Anmerkung

Diese Pre-Spec ist **Diskussions-Grundlage, kein Befehl**. Sie sortiert die Optionen, hebt Empfehlungen hervor, lässt offene Fragen sichtbar.

In der Sitzung „wir 3" entscheiden wir gemeinsam — und Codi bekommt am Ende die finale Spec als Briefing, exakt wie zu 5.1 (mit Buch-Bezügen, klarer Etappen-Abgrenzung, DoD).

**Halbgas-konform**: nicht in einem Rutsch implementieren, sondern erst entscheiden, dann sauber bauen. Buch Kap 5 — *„Effizienz ohne Zustandsklarheit ist geliehene Zeit."*

---

_Pre-Spec verfasst von Mops auf Branch `claude/clever-clarke-aRgdt`._
_Wartet auf Spec-Sitzung mit Andreas + Codi._
