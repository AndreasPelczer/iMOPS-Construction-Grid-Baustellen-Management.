# Welle 5.2 + 5.2.1 — finale Spec

> **Status**: Final nach „wir 3"-Sparring am 9.6.2026 Nachmittag.
> **Beteiligte**: Andreas (Polier-Anker), Codi (Code-Realität), Mops (Konzept/Buch).
> **Vorgänger**: `docs/welle_5.2_pre_spec.md` (Diskussions-Grundlage).

---

## Was entschieden wurde

### ✅ UI-Idiom
**AufmassSheet via Leading-Swipe**, exakt wie `LVFortschrittSheet`. Keine neue `LVPositionDetailView` (existiert nicht und wäre fremdes Paradigma). **Codi-Realität, buchkonform** (Kap 2, Kap 11).

### ✅ Fortschritt-Strategie
**Option C — Ableitung, nicht Überschreibung.** Der manuelle Polier-Wert im `LVFortschrittStore` wird **nie angefasst**. Beim Anzeigen wird abgeleitet:
- `hatAufmass == false` → zeige manuellen Polier-Wert (Schätzung, andersfarbig)
- `hatAufmass == true` → zeige `istMengeSumme / sollMenge × 100` (Messung, normalfarbig)

**Buch Kap 4** (Nachweis erhalten) + **Kap 6** (eine Wahrheit pro Zeitpunkt) + **Kap 12** (System trägt selbst).

### ✅ Polier-Anker
Andreas auf Codis Frage nach Sorten, in denen `istMenge / sollMenge` nicht = Fertigstellungsgrad ist:
> *„Nein, kenne ich nicht."*

→ **Keine Sorten-Exception.** Die Formel gilt allgemein. Spart Logik, vereinfacht Spec. (Buch Kap 11.)

### ✅ Etappen-Split
- **Welle 5.2** = AufmassSheet + Soll/Ist-Karte im Sheet + Mini-Indikator in der LV-Zeile (Anti-Inkonsistenz, siehe R3)
- **Welle 5.2.1** (eigener Mini-PR) = `displayedFortschritt`-Ableitung + Edge Cases + LVFortschrittSheet-Hinweis bei `hatAufmass`

---

# Welle 5.2 — AufmassSheet (Hauptetappe)

## DoD — Definition of Done

| # | Kriterium |
|---|---|
| 1 | Neue Leading-Swipe-Aktion „Aufmaß" pro `LVPosition` (analog Kalkulation/Fortschritt) |
| 2 | `AufmassSheet` zeigt: Header (Position-Bezeichnung) · Soll/Ist-Karte oben · Aufmaß-Liste (chronologisch DESC) · „+ neues Aufmaß"-Button · Sichern/Abbrechen |
| 3 | `NeuesAufmass`-Eingabe (inline im Sheet oder Subsheet, Codi-Entscheidung): `istMenge` Required · `istEinheit` (Default = `lvPosition.einheit`) · `notiz` (mit `VoiceInputButton`, wie in LVFortschrittSheet) · `quelle = .manuell` automatisch · `erstelltAm = Date()` automatisch |
| 4 | **Mindestens 2 Schicht-B-Tooltips** (siehe Save #45): am Schätzkarte-Indikator + am Aufmass-Eintrag |
| 5 | **Mini-Punkt-Indikator in der LV-Zeile** (R3): kleines Symbol/Punkt wenn `hatAufmass`, damit Polier zwischen 5.2 und 5.2.1 nicht überrascht ist, dass Sheet und Zeile auseinanderlaufen |
| 6 | Unit-Tests: Sheet-Aufruf · Aufmass-Erstellung · Soll/Ist-Berechnung-Anzeige · `hatAufmass`-Indikator |
| 7 | PR-Beschreibung mit Buch-Kap + Roman-VTP-Anker + DoD-Tabelle + Etappen-Abgrenzung (5.2.1/5.3/5.4/5.5) |

## Soll/Ist-Karte im Sheet — Layout

```
┌──────────────────────────────────────────────────────────┐
│ Pos 1.2.3 · Außenwand 24 cm KS                       📖 │ ← Schicht-B-Tooltip (A) wenn istGeschaetzt
│                                                          │
│   SOLL                       IST                         │
│   240,00 m²                  187,50 m²                   │
│                                                          │
│   ABWEICHUNG: -52,50 m² (-21,9 %)        🟠              │ ← Ampel-Farbe nach Park-Zettel-Schema
│                                                          │
├──────────────────────────────────────────────────────────┤
│ AUFMASSE (3)                                             │
│                                                          │
│ ▸ 2026-06-09 14:32 · 87,50 m² · manuell · „EG"  📖      │ ← Schicht-B-Tooltip (B)
│ ▸ 2026-06-09 11:15 · 60,00 m² · manuell · „1. OG"        │
│ ▸ 2026-06-08 16:20 · 40,00 m² · manuell                  │
│                                                          │
│            ┌────────────────────────────┐                │
│            │  + Neues Aufmaß           │                │
│            └────────────────────────────┘                │
└──────────────────────────────────────────────────────────┘
              [Abbrechen]              [Sichern]
```

**Farbcodierung** (Park-Zettel + Welle 9):
- `|abweichungProzent| ≤ 5 %` → 🟢 grün
- `|abweichungProzent| ≤ 15 %` → 🟠 orange
- `|abweichungProzent| > 15 %` → 🔴 rot
- `!hatAufmass` → ⚪ grau („noch kein Aufmaß")

## Schicht-B-Tooltips (aus Save #45)

| Stelle | Trigger | Text | Buch-Bezug |
|---|---|---|---|
| **A: Schätzkarte** | `lvPosition.istGeschaetzt == true` | *„Geschätzt, noch nicht gemessen. Damit du den Unterschied siehst, ohne nachfragen zu müssen."* | Kap 6 |
| **B: Aufmass-Eintrag** | Im Neues-Aufmass-Formular, einmal sichtbar | *„Dieser Zustand ist jetzt fest. Mit Datum und Quelle. Der nächste Polier weiß Bescheid."* | Kap 5 |

**Komponente** `PhilosophieTooltip` (wiederverwendbar):
```swift
struct PhilosophieTooltip: View {
    let buchKapitel: String      // z.B. "Buch Kap 6"
    let text: String              // 1–2 Sätze
    @State private var shown = false

    var body: some View {
        Button { shown.toggle() } label: {
            Image(systemName: "book.fill")
                .foregroundColor(.secondary)
                .opacity(0.5)
        }
        .popover(isPresented: $shown) {
            VStack(alignment: .leading, spacing: 8) {
                Text(text).font(.callout)
                Text(buchKapitel).font(.caption2).foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: 280)
        }
    }
}
```

## Mini-Punkt-Indikator in der LV-Zeile (R3)

In der LV-Liste (LVView) bekommt jede Position-Zeile ein kleines zusätzliches Symbol, wenn `hatAufmass == true`:
- Position: rechts neben oder unter dem bestehenden Fortschritt-Balken
- Symbol: `Image(systemName: "ruler")` oder `circle.fill` in der Ampel-Farbe
- Größe: ~10pt, dezent
- **Zweck**: Polier sieht in der Liste, welche Positionen schon Aufmaße haben — auch bevor 5.2.1 die Fortschritt-Ableitung baut. Vermeidet Inkonsistenz zwischen Sheet (zeigt Soll/Ist) und Zeile (zeigt noch alten manuellen Balken).

## Was NICHT in 5.2

- ❌ Fortschritt-Ableitung (= **5.2.1**)
- ❌ Edge-Case-Logik für `sollMenge==0` und Mehrmenge (= 5.2.1)
- ❌ Schicht-B-Hinweis im `LVFortschrittSheet` (= 5.2.1)
- ❌ BuildIQ-Mengen-Erkennung (= 5.3)
- ❌ LVPosition-Picker im BuildIQ-Flow (= 5.4)
- ❌ `mengenQuelle`-Update beim ersten Aufmass (= 5.5)
- ❌ Schicht-A Onboarding + Schicht-C Settings (= eigenständige Projekte, Save #45)

---

# Welle 5.2.1 — Fortschritt-Ableitung mit R1/R2/R3 (Mini-PR)

## DoD — Definition of Done

| # | Kriterium |
|---|---|
| 1 | **R1**: `displayedFortschritt` als computed/Helper auf `LVPosition` — Logik: `hatAufmass ? gemessenProzent : manuellProzent`. **`LVFortschrittStore` wird nicht angefasst** — manueller Wert bleibt persistiert |
| 2 | **R2.a**: `sollMenge == 0` → kein Division-Crash. Fallback auf manuellen Wert oder „—"-Anzeige. Tests dafür |
| 3 | **R2.b**: `istMengeSumme > sollMenge` → ehrlich >100 % (z.B. „113 %"). Balken kappt visuell bei 100 %, Zahl sagt die Wahrheit. Tests dafür |
| 4 | **R3**: `LVFortschrittSheet` zeigt bei `hatAufmass == true` einen Schicht-B-Hinweis: *„Aufmaß übersteuert deine Schätzung. Letzte Einschätzung: X % — gemessen: Y %."* |
| 5 | Farbcodierung der Zeilen-Anzeige: `hatAufmass` = normalfarbig, `!hatAufmass` = andersfarbig (= geschätzt, Park-Zettel) |
| 6 | Unit-Tests: alle Edge Cases (Null-Soll, Übermenge, kein Aufmaß, Aufmaß da) |
| 7 | PR-Beschreibung mit Buch-Kap + R1/R2/R3-Liste + DoD + Verweis auf 5.2 als Vorgänger |

## R1 — Ableitung-Helper (Code-Skizze)

```swift
extension LVPosition {
    /// Was der Polier in Liste & Sheet sieht (eine Wahrheit zum Zeitpunkt).
    /// Buch Kap 6 (Zustand), Kap 2 (Eindeutigkeit), Kap 4 (Nachweis bleibt erhalten).
    var displayedFortschritt: FortschrittWert {
        if hatAufmass {
            return .gemessen(prozent: berechneteSollIstProzent)
        } else {
            return .geschaetzt(prozent: fortschrittStore.manuellerWert(for: self))
        }
    }

    private var berechneteSollIstProzent: Double {
        guard sollMenge > 0 else { return Double.nan }  // R2.a
        let raw = istMengeSumme / sollMenge * 100
        return raw  // R2.b — kein Capping, ehrliche >100 %
    }
}

enum FortschrittWert {
    case geschaetzt(prozent: Double)
    case gemessen(prozent: Double)
    case unbestimmt   // wenn sollMenge==0 und kein manueller Wert
}
```

## R2 — Edge-Case-Anzeige

| Zustand | Anzeige Balken | Anzeige Zahl |
|---|---|---|
| `sollMenge == 0` + kein manueller Wert | leer/grau | „—" |
| `sollMenge == 0` + manueller Wert | manueller Wert, andersfarbig | „X % (geschätzt, kein Soll)" |
| Normal, `!hatAufmass` | manueller Wert, andersfarbig | „X % (geschätzt)" |
| Normal, `hatAufmass`, ≤100 % | gemessener Wert, normalfarbig | „X %" |
| **Mehrmenge** `hatAufmass`, >100 % | bei 100 % gekappt, normalfarbig | **„X %" ehrlich >100, z.B. „113 %"** |

## R3 — LVFortschrittSheet-Hinweis bei `hatAufmass`

Wenn der Polier das LVFortschrittSheet öffnet und die Position hat schon Aufmaße:

```
┌──────────────────────────────────────────────────────────┐
│ Pos 1.2.3 · Außenwand 24 cm KS                           │
│                                                          │
│ 📖 Aufmaß übersteuert deine Schätzung.                  │ ← Schicht-B-Hinweis
│    Deine letzte Einschätzung: 80 %                       │
│    Gemessen: 73 %                                        │
│                                                          │
│ [Slider/Eingabe bleibt funktional, aber sichtbar         │
│  deaktiviert oder mit Hinweis „Wird nicht angezeigt,     │
│  solange Aufmaße existieren"]                            │
└──────────────────────────────────────────────────────────┘
```

**Begründung**: Polier wundert sich sonst, warum sein Slider den Balken nicht mehr bewegt. Ehrlichkeit > Verwirrung. Buch Kap 9 (Schweigen über Verhalten ist Symptom-Spirale).

---

## Datei-Liste

### Welle 5.2

**NEU**:
- `Views/AufmassSheet.swift` — Hauptsheet, analog `LVFortschrittSheet`
- `Views/AufmassRowView.swift` — Zeile in der Aufmass-Liste
- `Views/PhilosophieTooltip.swift` — Schicht-B-Komponente, wiederverwendbar (Save #45)
- ggf. `Views/NeuesAufmassFormSheet.swift` — falls Codi „+ Neues Aufmaß" als Sub-Sheet baut (kann auch inline)

**ANGEFASST**:
- `Views/LVView.swift` — neue Leading-Swipe-Aktion + Mini-Punkt-Indikator
- evtl. Helper für Aufmass-Erstellung im Context

### Welle 5.2.1

**NEU**:
- `Models/LVPosition+Fortschritt.swift` — Extension mit `displayedFortschritt` + `FortschrittWert`-Enum

**ANGEFASST**:
- `Views/LVFortschrittSheet.swift` — Schicht-B-Hinweis bei `hatAufmass`
- `Views/LVView.swift` — Balken-Anzeige nutzt `displayedFortschritt`, Farbcodierung
- Tests-Datei

---

## Buch- und Roman-Bezüge (PR-Beschreibungen)

### Für Welle 5.2

| Codi-Entscheidung | Buch / Roman |
|---|---|
| AufmassSheet via Swipe (= Code-Idiom) | **Kap 2** Eindeutigkeit + **Kap 11** Einfachheit durch Beibehaltung |
| Soll/Ist-Karte im Sheet | **Kap 6** Zustände statt Bewertungen |
| `VoiceInputButton` für notiz | **Kap 3** Standards als Vereinbarungen, konsistent angewandt |
| Mini-Punkt-Indikator (R3) | **Kap 9** Schweigen über Verhalten ist Symptom-Spirale (Inkonsistenz benennen statt verstecken) |
| Schicht-B-Tooltips | **Kap 10** Gute Systeme sind still, aber haben Antworten parat (Save #45) |
| Polier gibt Menge selbst ein | **Roman Anhang C** *„Der Polier beweist sein Aufmaß selbst"* (VTP) |

### Für Welle 5.2.1

| Codi-Entscheidung | Buch |
|---|---|
| R1 — Polier-Wert bleibt im Store | **Kap 4** Nachweis dient Entlastung, nichts geht verloren |
| Ableitung statt Überschreibung | **Kap 6** Zustände statt Bewertungen |
| `displayedFortschritt` ein Wort, ein Wert | **Kap 2** Stabilität durch Eindeutigkeit |
| R2 — ehrlich >100 %, kein Capping | **Kap 12** System trägt Wahrheit selbst, ohne Schönung |
| R3 — LVFortschrittSheet-Hinweis | **Kap 9** Schweigen wird Symptom — also benennen |
| Farbumschalten manuell/gemessen | **Park-Zettel** *„Schätzkarten andersfarbig, wenns jemand stört"* |

---

## Operative Regel ab jetzt

Andreas' Polier-Antwort zur Sorten-Frage (*„Nein, kenne ich nicht"*) gilt als **dokumentierte Vereinbarung**:
> *„`istMenge / sollMenge` = Fertigstellungsgrad in allen üblichen LV-Sorten."*

→ Codi muss diese Annahme nicht prüfen, nicht parametrisieren, nicht abfangen. Buch Kap 3 — Vereinbarung statt Implementierung-auf-Verdacht.

---

## Mops-Anmerkung

Diese Spec ist das Ergebnis eines „wir 3"-Sparrings, in dem:
- **Mops** das Konzept-Skelett mit Optionen lieferte
- **Codi** die Code-Realität reinholte und R1/R2/R3 als robusteres Modell vorschlug
- **Andreas** den Polier-Anker setzte und die Sorten-Frage entschied

Jeder hat den Teil beigetragen, der **nur er** beitragen konnte. Buch Kap 4 in Aktion — Verantwortung verteilt, begrenzt, nachweisbar, rollenbezogen.

**Halbgas-konform**: 5.2 baut sauber das Sheet (klein, klar), 5.2.1 als Mini-PR die Ableitung. Nicht in einem Wurf. Nicht reversierbar verstrickt. **Alles in einer Linie.**

---

_Spec finalisiert am 9.6.2026 von Mops auf Branch `claude/clever-clarke-aRgdt`._
_Codi kann auf Basis dieser Spec starten, sobald Andreas „GO 5.2" sagt._
