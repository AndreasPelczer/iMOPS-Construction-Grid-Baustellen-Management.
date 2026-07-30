# HANDOFF — Aufwands-Eingaben: Positions-Gesamt in der Vorschau (Lohn/Material/Geräte)

> Selbsttragend. Du (Codi/Codex) siehst die auslösende Unterhaltung NICHT — alles steht hier.
> Bei Widerspruch Doku↔Code gilt der Code; dann kurz notieren, was abwich.
> Kleiner UX-Fix, 3 Views + 1 gemeinsamer Baustein. **Kein Rechen-Bug** — die Kalkulation
> stimmt; es geht um Klarheit bei der Eingabe.
> **Erweiterung (§2.4):** Eingabe wahlweise *je Einheit* ODER *gesamt* — die App rechnet um,
> gespeichert wird immer der Wert je Einheit (Engine bleibt unangetastet).

## 0. Warum (echter Feldtest-Befund)

Beim „Lohnanteil hinzufügen" hat der Nutzer die **Gesamt-Stunden** des Mitarbeiters
eingetragen (z. B. 4 h), obwohl das Feld den **Aufwandswert = Stunden je Mengeneinheit**
meint (z. B. 0,033 h/m³). Die Engine rechnet `stunden × Menge` → 4 h × 120 m³ = **480
Mannstunden**. Der Fehler ist erst in der späteren Auswertung aufgefallen.

**Ursache ist die UI, nicht der Nutzer:** Das Feld heißt zwar schon „Stunden/m³", aber die
**Vorschau zeigt nur die Kosten *je Einheit*** — nie den **Positions-Gesamtbetrag**. Damit
bleibt die `× Menge`-Multiplikation genau dort unsichtbar, wo man sie zur Plausi-Prüfung
braucht. Fix: den **Gesamtbetrag (und die Gesamt-Menge) schon bei der Eingabe** anzeigen —
dann fällt „480 h?!" sofort auf. Das ist iMOPS-Philosophie: die App muss die Bau-Realität
aussprechen, weil sie nicht jeder gelebt hat.

## 1. Fundstellen (verifiziert 8.7.2026)

Alle drei Views haben dieselbe Struktur: ein `detailSection` mit Eingabefeld „…/Einheit",
einer `berechneVorschau()` (liefert Kosten **je Positions-Einheit**) und einer Vorschau-HStack
„Kosten/Einheit". `position.menge` (Double) und `position.einheit` (String?) sind da.

| View | Feld-Label | Vorschau-HStack | `berechneVorschau()` = je Einheit |
|---|---|---|---|
| `Views/LohnHinzufuegenView.swift` | Z.117 `"Stunden/\(einheit)"` | Z.126–137 `"Kosten/\(einheit)"` | Z.163–167 `stunden × stundenBruttoEK` |
| `Views/MaterialHinzufuegenView.swift` | Z.115 `"Menge/\(einheit)"` | Z.146–157 `"Kosten/\(einheit)"` | Z.194–199 `menge × preis × (1+verschnitt)` |
| `Views/GeraetHinzufuegenView.swift` | Z.117 `"Stunden/\(einheit)"` | Z.126–137 `"Kosten/\(einheit)"` | Z.163–167 `stunden × kostenProStunde` |

Engine-Kontext (unverändert lassen): `LVKalkulator.kalkuliere` bildet EK aus den
`kostenProEinheit`-Summen und rechnet `gesamt = VK × position.menge`. Die `× Menge` ist also
korrekt — sie muss nur bei der Eingabe **sichtbar** werden.

## 2. Änderung

### 2.1 Gemeinsamer Vorschau-Baustein (DRY)
Neu in `Views/LV/LVSupportViews.swift` (bestehende Heimat für LV-Support-UI):
```swift
/// Vorschau für die Aufwands-Eingaben (Lohn/Material/Geräte): zeigt die Kosten JE Einheit
/// UND — entscheidend — den Positions-Gesamtbetrag, damit die × Menge-Multiplikation schon
/// bei der Eingabe sichtbar wird (Plausi-Prüfung: "480 h?! — falsch").
struct AufwandVorschau: View {
    let proEinheit: Double     // Kosten je Positions-Einheit (aus berechneVorschau())
    let menge: Double          // position.menge
    let einheit: String        // position.einheit ?? "Einheit"
    let mengenGesamt: String?  // optional: "480 h" / "84,0 kg" — der Mengen-Gesamtwert
    let farbe: Color           // .green (Lohn) / .orange (Material) / .purple (Geräte)

    private func z(_ label: String, _ wert: String, bold: Bool) -> some View {
        HStack {
            Text(label).font(bold ? .subheadline.bold() : .caption).foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(wert).font((bold ? Font.subheadline.bold() : .caption).monospacedDigit())
                .foregroundStyle(bold ? farbe : .secondary)
        }
    }
    var body: some View {
        VStack(spacing: 4) {
            z("Kosten je \(einheit)", proEinheit.formatted(.currency(code: "EUR")), bold: false)
            if let mg = mengenGesamt { z("Menge gesamt", mg, bold: false) }
            Divider()
            z("Gesamt für \(menge.formatted(.number.precision(.fractionLength(0...2)))) \(einheit)",
              (proEinheit * menge).formatted(.currency(code: "EUR")), bold: true)
        }
    }
}
```

### 2.2 Die drei Views umstellen
In jeder View die bestehende „Kosten/Einheit"-HStack durch `AufwandVorschau(...)` ersetzen
(nur wenn `vorschau > 0`), Menge/Einheit von `position` ziehen:

- **Lohn** — `mengenGesamt`: Gesamt-Stunden = `stundenWert × position.menge` →
  `"\(gesamtStunden.formatted(...)) h"`, `farbe: .green`.
- **Geräte** — analog Stunden, `farbe: .purple`.
- **Material** — `mengenGesamt`: Gesamt-Materialmenge in der **Material**-Einheit
  `mengeProEinheit × position.menge` (die Netto-Menge; der €-Gesamtbetrag enthält den
  Verschnitt bereits über `proEinheit`), `farbe: .orange`.

### 2.3 Label schärfen (kleiner, aber wirksam)
- Feld-Label von `"Stunden/\(einheit)"` → **`"Stunden je \(einheit)"`** (Material: „Menge je …").
- In der Section einen `footer`/Hinweis ergänzen:
  **„Wert für **eine** \(einheit) — nicht für die ganze Position. Die Gesamt-Vorschau
  multipliziert mit der Menge (\(position.menge) \(einheit))."**

### 2.4 Eingabe in beide Richtungen (je Einheit ODER gesamt)

**Motivation (Andreas, 8.7.):** Der Aufwandswert je Einheit (z. B. 0,05 h/m³) ist die
Rechenbasis — aber im Kopf kennt man den **Gesamtwert** („Helfer braucht 6 h für die
Position"), nicht die 0,0x. Der Nutzer soll dafür **keinen Taschenrechner** zücken müssen.

Umschaltbare Eingabe in allen drei Views:
- Segmented Picker über/neben dem Eingabefeld: `["je \(einheit)", "gesamt"]`,
  `@State private var eingabeGesamt = false` (Default: **je Einheit** — das ist auch, was die
  Stammdaten liefern).
- **„je Einheit"** = heutiges Verhalten (Feld = Wert je Einheit).
- **„gesamt"** = Feld = Gesamtwert für die Position; die View rechnet beim Speichern
  `jeEinheit = gesamtWert / position.menge`.
- **Gespeichert wird IMMER der Wert je Einheit** (`PositionLohn.stunden` /
  `PositionMaterial.mengeProEinheit` / `PositionGeraet.stunden`) — der Engine-Vertrag
  (`× position.menge`) bleibt unverändert. **Voller Double, nicht runden** (sonst kommt der
  Gesamtwert nicht exakt zurück).
- **Guard `position.menge <= 0`:** im „gesamt"-Modus nicht teilbar → Feld deaktivieren +
  Hinweis „Erst die Menge der Position setzen". (Im „je Einheit"-Modus egal.)
- Beim **Moduswechsel** den angezeigten Feldwert passend umrechnen (je-Einheit ↔ gesamt), den
  Rohtext nicht stehen lassen.
- `AufwandVorschau` (§2.1) zeigt ohnehin **beide** Zahlen (je Einheit + gesamt) → in jedem
  Modus sieht man die jeweils andere Richtung zur Kontrolle.
- Gilt für Lohn/Geräte (Stunden) **und** Material (Menge).

## 3. Definition of Done
- `AufwandVorschau` existiert, alle drei Views nutzen ihn; **Positions-Gesamtbetrag** ist bei
  der Eingabe sichtbar, plus die Gesamt-Menge (Stunden bzw. Materialmenge).
- Label „…je \(einheit)" + Hinweistext in allen drei Views.
- Beispiel-Gegencheck: Position 120 m³, Lohn 0,5 h/m³ @ 50 €/h → Vorschau „Kosten je m³ 25 € ·
  Menge gesamt 60 h · **Gesamt für 120 m³: 3.000 €**". Bei 4 h/m³ zeigt sie „Menge gesamt
  480 h · Gesamt 24.000 €" → der Fehler ist sofort sichtbar.
- **Richtungs-Toggle „je Einheit / gesamt"** in allen drei Views; im gesamt-Modus wird
  korrekt auf je-Einheit normalisiert **und** gespeichert; `position.menge <= 0` abgefangen.
  Gegencheck: 6 h gesamt bei 120 m³ → speichert 0,05 h/m³; zurück im gesamt-Modus steht
  wieder 6 h (keine Rundungsverluste).
- Build grün (§5).
- **Drift-Regel:** sichtbare UI-Änderung an der Kalkulations-Eingabe → `Resources/Knowledge/
  app_bedienung.yaml` ergänzen/prüfen (Kernaussage: „Aufwand je Einheit eingeben; die
  Vorschau zeigt den Positions-Gesamtwert").

## 4. Regeln
- Vor Patch `.backup_*` (gitignoriert). **Kein Push / kein PR ohne Andreas' OK.**
- Conventional Commit, z. B. `feat(ui): Positions-Gesamt in Aufwands-Vorschau (Lohn/Material/Geräte)`.
- Engine (`LVKalkulator`, `kostenProEinheit`) NICHT anfassen — die rechnet korrekt.

## 5. Build (Trailing-Dot — Pfade quoten)
```bash
xcodebuild -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
```

## 6. NICHT in Scope
- Keine Änderung an der Rechen-Engine oder am Datenmodell.
- Keine Migration bestehender Positionen (falsche Alt-Eingaben bleiben, bis der Nutzer sie
  korrigiert — die neue Vorschau hilft beim Erkennen).
- Keine Aufwandswert-Vorschläge vom Mops (eigene, spätere Idee).
