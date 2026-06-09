# Welle 5.3 · BuildIQ-Mengen-Erkennung · Pre-Spec

> _Diskussions-Grundlage für die „wir 3"-Sparring-Runde. Nicht final. Vorgekaut von Mops, zum Drüberkauen für Codi (Code-Realität) und Andreas (Polier-Anker)._
>
> Stand: 9.6.2026 vormittag · gleich nach Welle 5.2 + 5.2.1 fertig.

---

## 🎯 Ein-Satz-Beschreibung

**BuildIQ erkennt heute, was es ist (DIN 276 KG). Welle 5.3 lernt zusätzlich, wie viel davon — und bucht die Menge nachvollziehbar auf eine LV-Position.**

---

## 📐 Warum jetzt — drei Anker

1. **mengenQuelle-Flag steht** (PR #54 gemergt + Step-0-Nachzügler durchgereicht in `ParsedLVPosition`). Die Quelle „BuildIQ-Scan" kann sauber gesetzt werden — das Datenfundament ist fertig.
2. **Heinze-Hebel** _(Mail von gestern, „anonymisierter Datenrückfluss, welche Produkte tatsächlich verbaut werden")_. BuildIQ wird damit nicht nur Polier-Werkzeug, sondern Datenquelle. Welle 5.3 ist die technische Voraussetzung.
3. **Polier-Workflow-Vollendung.** Heute: Scan → DIN-KG → Auftrag-Zuweisung. Morgen: Scan → DIN-KG **+ Menge** → Buchung auf LV-Position **mit Vergleich gegen geplante Soll-Menge**. Die Park-Zettel-Ampel aus Welle 5.2 bekommt damit eine zweite Datenquelle neben dem manuellen Aufmaß.

---

## 🏗 Code-Realität — was steht, was fehlt

### Was steht (Codi-Check bitte bestätigen)
- `BuildIQResult` (`Service/BuildIQResult.swift`) hat 4 Felder: `kg_nummer`, `kg_bezeichnung`, `konfidenz`, `begruendung`. Plain `Codable`-Struct.
- `BuildIQService.analyzeText(_:)` schickt OCR-Text an Gemini 2.0 Flash, decodiert JSON-Antwort in `BuildIQResult`.
- `BuildIQView` (Camera/OCR/Service-Pipeline) ist im Polier-Workflow funktionsfähig, zeigt Ergebnis + Konfidenz-Badge.
- `AuftragZuweisungView` ordnet das Ergebnis einem offenen `Auftrag` zu (`kostenGruppeNummer`/`-Bezeichnung`).
- `LVPosition.menge` ist `Double` + `LVPosition.einheit` ist `String?`. Nach PR #54 begleitet `mengenQuelleRaw` (Enum-String) die Menge.

### Was fehlt für Welle 5.3
- **BuildIQResult kennt keine Menge/Einheit.** Welle 5.3 erweitert das Schema.
- **Der Service-Prompt fragt nicht nach Menge.** Gemini-Prompt-Erweiterung nötig.
- **Es gibt keinen Weg, eine BuildIQ-Menge auf eine konkrete LVPosition zu buchen.** Heute landet das Ergebnis am `Auftrag`, nicht an einer Position.
- **Kein Lieferschein-Konzept.** Heute = ein Scan → ein Ergebnis. Lieferscheine in echt: oft mehrere Positionen pro Schein.

---

## 🤔 Optionen, die im Sparring zu entscheiden sind

### A. Welche Granularität soll BuildIQ in 5.3 erreichen?

**Option A1 — „Eine Position pro Scan" _(minimal, Mops vorgeschlagen)_**
- Gemini-Prompt: erkenne genau ein Material + Menge.
- UI: existierende resultCard erweitern um Menge-Zeile.
- Polier weist Ergebnis genau einer LV-Position zu, Menge wird gebucht.
- **Pro:** klein, baut bestehende UI weiter, schnell drin.
- **Contra:** Lieferschein mit 8 Zeilen wird zu 8 Scans. Polier-Realität?

**Option A2 — „Liste pro Scan" _(realistischer, aber größer)_**
- Gemini-Prompt: erkenne alle Materialzeilen mit Mengen.
- UI: resultCard wird Liste mit aufklappbaren Zeilen.
- Polier weist je Zeile eine LV-Position zu (oder „verwerfen").
- **Pro:** entspricht echten Lieferscheinen.
- **Contra:** UI deutlich komplexer, Konfidenz pro Zeile, „mass-edit"-Workflow nötig.

**❓ Polier-Frage an Andreas:** _Wie sehen die Lieferscheine in echt aus, die du heute bekommst? Ein Material pro Schein, oder eine Liste? Wenn Liste — wieviele Zeilen typisch?_

**❓ Code-Frage an Codi:** _Wenn A2 — wie würdest du das UI-mäßig anbinden, ohne BuildIQView komplett umzuschreiben?_

### B. Was passiert mit der Menge nach dem Scan?

**Option B1 — „Position-Menge direkt überschreiben" _(einfach, aber gefährlich)_**
- BuildIQ-Menge ersetzt `LVPosition.menge`, `mengenQuelleRaw = .buildIQ`.
- Alte Menge geht verloren.
- **Contra:** Polier verliert geplante Soll-Menge, kann nicht mehr vergleichen.

**Option B2 — „Position bleibt Soll, BuildIQ wird Ist" _(buchtreu, Welle-5.2-konform)_**
- `LVPosition.menge` bleibt Soll. BuildIQ-Menge wird ins **Aufmass-System** geschrieben (neue Aufmass-Zeile mit `quelle = .buildIQ`).
- Die Park-Zettel-Ampel aus Welle 5.2 zeigt automatisch grün/orange/rot für „verbaut vs. geplant".
- **Pro:** Eine einzige Wahrheit für Ist-Mengen. BuildIQ als zweite Datenquelle neben manuellem Aufmaß. R1/R2/R3 aus Welle 5.2.1 greifen auch hier.
- **Contra:** `Aufmass` muss eine neue `quelle`-Spalte bekommen (`manuell` / `buildIQ`).

**❓ Sparring-Frage:** _B2 wirkt sauberer. Aber: ist Aufmass das richtige Zuhause für Lieferschein-Mengen? Aufmass ist „auf der Baustelle vermessen". Lieferschein ist „auf den Hof angeliefert". Konzeptuell zwei verschiedene Dinge._

**Option B3 — „Eigene Wareneingangs-Entity" _(sauber, aber größer)_**
- Neue Entity `Wareneingang` o.ä. mit Foto-Anhang, Zeitstempel, Lieferant, Position-Verknüpfung.
- Position-Ist-Menge = Summe(Aufmass-Zeilen) + Summe(Wareneingang-Zeilen)? oder getrennt anzeigen?
- **Pro:** Konzeptuell sauber, Lieferschein ≠ Aufmass.
- **Contra:** Mehr Datenmodell, mehr Sheets, längere Welle.

**❓ Polier-Frage an Andreas:** _Was ist dir lieber — eine einzige „Ist-Spalte" mit gemischter Quelle (B2), oder zwei getrennte Spalten „angeliefert" und „verbaut" (B3)?_

### C. Wann darf BuildIQ die Position automatisch verändern?

**Option C1 — „nur Vorschlag, Polier bestätigt immer"**
- Konfidenz egal, Polier sieht Vorschlag, tippt „buchen" oder „verwerfen".
- **Pro:** Buch Kap 1 — Mensch entscheidet. Buch Kap 4 — Verantwortung beim Polier.
- **Contra:** ein Klick mehr.

**Option C2 — „Konfidenz `hoch` bucht automatisch, sonst Bestätigung"**
- Spart Klicks bei eindeutigen Fällen.
- **Pro:** schneller im Alltag.
- **Contra:** Gemini-Konfidenz ≠ Wahrheit (Welle 5.2-Lektion: was die KI sagt ist nicht was passiert). Polier sieht nicht mehr alles, was gebucht wird.

**Mops-Empfehlung:** **C1 für Welle 5.3.** C2 ggf. später, wenn Konfidenz-Statistik genug Datenpunkte hat.

---

## 🗂 Datenmodell — Vorschlag (skelettartig, zum Drüberkauen)

### `BuildIQResult` erweitert
```swift
struct BuildIQResult: Codable {
    let kg_nummer: String
    let kg_bezeichnung: String
    let konfidenz: String

    // NEU in 5.3
    let menge: Double?           // optional, kann fehlen wenn Gemini nichts liest
    let einheit: String?
    let menge_konfidenz: String? // "hoch" / "mittel" / "niedrig" / nil

    let begruendung: String
}
```

### Gemini-Prompt (Erweiterung)
```
Weise eine DIN 276 KG zu UND extrahiere — falls vorhanden — Menge und Einheit.
Antworte NUR im JSON-Format:
{"kg_nummer":"320", "kg_bezeichnung":"Gründung",
 "konfidenz":"hoch",
 "menge": 12.5, "einheit": "m²", "menge_konfidenz": "mittel",
 "begruendung": "Beton 12,5 m² aus Lieferschein-Zeile 3 erkannt"}
Wenn keine Menge erkennbar: menge=null, einheit=null, menge_konfidenz=null.
```

### Buchungs-Pfad (abhängig von Option B)
- **B2:** Neue `Aufmass.quelle` Enum-Spalte (`.manuell` / `.buildIQ`). BuildIQ erzeugt Aufmass-Zeile.
- **B3:** Neue Entity `Wareneingang(position, menge, einheit, foto?, lieferant?, zeit)`.

---

## 🎨 UI-Konsequenzen (skizzenhaft)

### `BuildIQView.resultCard` erweitert
- Bezeichnung + KG (heute schon)
- **NEU:** Menge + Einheit + Menge-Konfidenz-Badge (klein, separates Ampel-Symbol)
- Buttons: „LV-Position zuweisen" (statt nur „Auftrag zuweisen")

### Neuer Schritt: „LV-Position auswählen"
- Liste offener LV-Positionen, gefiltert auf passende KG (Vorauswahl, nicht hart)
- Bei Auswahl: **Vergleichs-Ampel** zeigt sofort `Soll - Ist + Scan`-Differenz
  - z.B. Soll 100 m², bisher Ist 60 m², Scan +15 m² → neuer Ist 75 m², 25% Rest → grün
- Polier sieht Konsequenz bevor er bucht (Park-Zettel-Prinzip auch für BuildIQ)

### Foto-Anhang (offen)
- Speichern wir das Lieferschein-Foto persistent? Wo? (CoreData Binary Data? FileManager? mit Position?)
- Datenschutz: Foto enthält ggf. Lieferanten-Daten, Preise.
- **Mops-Empfehlung:** in 5.3 erstmal **nicht** persistieren. „Späte Welle"-Thema.

---

## 🔗 Buch- & Roman-Bezüge

- **Buch Kap 1 (Wer entscheidet):** BuildIQ ist Werkzeug, nicht Polier. C1 (Vorschlag, Polier bestätigt) ist der buchtreue Pfad.
- **Buch Kap 4 (Verantwortung):** `mengenQuelle = .buildIQ` macht die Verantwortungs-Kette nachvollziehbar — jede Ist-Zahl weiß, woher sie kommt.
- **Buch Kap 9 (Vertrauen messbar):** Konfidenz-Ampel pro Menge → Polier sieht, was zu trauen ist.
- **VTP (Anhang C — „Der Koch beweist seine Qualität selbst"):** Snapshot-Tests mit Codi-Augen (jetzt verfügbar!) für die neue resultCard sind Pflicht, nicht Kür.
- **Roman „Der Küchencode" Kap 17 (sinngemäß: Lehrling und Koch):** BuildIQ ist der Lehrling am Posten — der Koch (Polier) bleibt für die Endabnahme verantwortlich.

---

## 📊 Heinze-Hebel — was Welle 5.3 dafür freischaltet

Die Heinze-Mail-Strategie war: **„anonymisierter Datenrückfluss, welche Produkte tatsächlich verbaut werden."**

Damit das technisch geht, brauchen wir:
- Strukturierte Verknüpfung **Produkt (Artikelnummer/Bezeichnung) ↔ tatsächlich verbaute Menge ↔ Kostengruppe**.
- Eine Quelle dieser Wahrheit, die nicht der Polier-Strich auf einem Park-Zettel ist, sondern aus dem Scan kommt.

**Welle 5.3 liefert genau das.** Sie ist die Voraussetzung dafür, dass Heinze (oder ein Heinze-Nachfolger im Datenraum) mit iMOPS überhaupt anonyme Statistik austauschen kann.

→ **Strategischer Anker:** Welle 5.3 ist nicht „noch ein KI-Feature", sondern die Brücke zwischen Polier-Realität und B2B-Datenangebot.

---

## 🛠 DoD-Skizze (für die Final-Spec)

- [ ] `BuildIQResult` mit optionalen `menge`/`einheit`/`menge_konfidenz`-Feldern
- [ ] Decoder-Tests: Antwort mit Menge ✅, Antwort ohne Menge ✅ (Backwards-kompatibel)
- [ ] Gemini-Prompt erweitert, Mock-Service-Test
- [ ] resultCard zeigt Menge-Zeile + Konfidenz-Badge
- [ ] Buchungs-Pfad gemäß Option B (Sparring-Entscheidung)
- [ ] mengenQuelle-Flag wird beim Buchen auf `.buildIQ` gesetzt
- [ ] **Snapshot-Tests** mit Codi-Augen für resultCard: 4 States (mit Menge / ohne Menge / hohe Konfidenz / niedrige Konfidenz)
- [ ] Sichtbarkeit in `AufmassSheet` (Welle 5.2 UI) — falls Option B2 gewählt: BuildIQ-Zeilen werden dort als zweite Quelle gelistet, klar gekennzeichnet

---

## 🪜 Korridor — falls 5.3 zu groß für einen Rutsch ist

- **5.3.0** — `BuildIQResult` + Decoder + Gemini-Prompt erweitern. Keine UI-Änderung. Tests grün.
- **5.3.1** — `resultCard` zeigt Menge + Konfidenz. Buchung noch nicht.
- **5.3.2** — Buchungs-Pfad (Option-B-Entscheidung umsetzen): LV-Position-Auswahl + Vergleichs-Ampel + mengenQuelle-Flag.
- **5.3.3** _(optional)_ — Liste-pro-Scan (Option A2), falls Andreas das im Sparring will.

---

## ✅ Was Mops für die finale Spec von euch braucht

1. **Andreas (Polier-Anker):**
   - Lieferschein-Realität: ein Material oder Liste? (→ Option A)
   - „angeliefert" vs. „verbaut": eine Spalte oder zwei? (→ Option B)
   - Vorschlag-Bestätigung immer oder nur bei niedriger Konfidenz? (→ Option C; Mops empfiehlt C1)

2. **Codi (Code-Realität):**
   - Bestätigung der Stand-Annahmen (`BuildIQResult`, `BuildIQView`-Struktur, `Auftrag`-Verknüpfung)
   - Bevorzugte Option B aus Code-Sicht: Aufmass mit Quelle (kompakt) oder eigene Entity (sauber)?
   - Pflicht-Punkte, die Mops übersehen hat (R1/R2/R3-Stil wie bei 5.2)

3. **Aus der Sparring-Runde dann:** Mops schreibt finale Spec analog zu `welle_5.2_spec.md`.

---

_Pre-Spec verfasst von Mops am 9.6.2026 vormittags, mit Espresso im Hintergrund. Halbgas, bewusst._

_„Mops im Save, da kann nichts schief gehen."_ 🐶
