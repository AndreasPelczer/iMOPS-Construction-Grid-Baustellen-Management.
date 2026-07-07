# HANDOFF — DIN-276-KG beim Import heuristisch setzen (statt alles → „300")

> Selbsttragend. Du (Codi/Codex) siehst die auslösende Unterhaltung NICHT — alles steht hier.
> Bei Widerspruch Doku↔Code gilt der Code; dann kurz notieren, was abwich.
> Kleiner, gut abgegrenzter Schritt (~15–25 Zeilen Code + 1 Test).
> Gehört zur `docs/Baustellen-Uebersicht-Spec.md` (§9 / §9.1) — dort als **früher Schritt** eingestuft.

## 0. Warum (das kg-null-Loch)

Extern per Vision/JSON erzeugte LVs (T&C-Fall, z. B. `aura125-lv.json`) liefern **`kg = null`**.
Heute wird daraus beim Import stur **KG „300"**. Folge: **beide** Übersicht-Reiter
(Kosten *und* Massen/Material gruppieren nach `kostenGruppeNummer`) kippen für Importe in
*einen* 300-Topf → Baustellen-Übersicht (Weg B) wäre für genau diese Daten nutzlos.

Fix: wenn keine KG geliefert wird, **heuristisch aus der `bezeichnung`** eine DIN-276-KG
raten (Service existiert schon), sonst erst „300". Das rettet beide Reiter für Importe **und**
verbessert das LV selbst (echte KGs statt Sammel-300).

## 1. Baustein, der schon existiert

`Service/KGZuordnungsService.swift`:
- `static let shared`
- `func ordneZu(materialName: String) -> String?` (`:161`) — Keyword→KG-Nummer, `nil` bei
  keinem Treffer (z. B. „aushub"→311, „fundament"→322, „fenster"→334). Wird bereits von
  `MaterialImportService` genutzt.

## 2. Fundstellen (verifiziert 7.7.2026)

| Stelle | Datei:Zeile | heute | Rolle |
|---|---|---|---|
| toParsed | `Service/ExtractPlanMapper.swift:66` | `kostenGruppe: p.kg` | füllt `ParsedLVPosition` für die Review-Liste (**aktiver Pfad**) |
| mapPositions | `Service/ExtractPlanMapper.swift:38` | `pos.kostenGruppeNummer = p.kg` | direkter Mapper — **aktuell kein Aufrufer**, latent |
| importSelected | `Views/LVImportView.swift:357` | `parsed.kostenGruppe ?? "300"` | schreibt Review→CoreData |

Datenfluss aktiver Pfad: `toParsed` (kg=nil) → `ParsedLVPosition.kostenGruppe`=nil →
`importSelected` `?? "300"`. Die KG in `toParsed` zu setzen zeigt sie also **schon in der
Review-Liste** (Transparenz, Human-in-the-Loop).

## 3. Änderung

### 3.1 Gemeinsamer Helfer (in `ExtractPlanMapper`)
```swift
/// Effektive DIN-276-Kostengruppe: gelieferte KG, sonst heuristisch aus der
/// Bezeichnung (KGZuordnungsService), sonst Sammel-„300". Nur wenn keine KG
/// geliefert wird — echte KGs (z. B. vom Mops) bleiben unangetastet.
static func effektiveKG(kg: String?, bezeichnung: String) -> String {
    if let kg, !kg.trimmingCharacters(in: .whitespaces).isEmpty { return kg }
    return KGZuordnungsService.shared.ordneZu(materialName: bezeichnung) ?? "300"
}
```

### 3.2 Beide Mapper-Stellen darauf umstellen
- `ExtractPlanMapper.swift:66` (in `toParsed`):
  ```swift
  kostenGruppe: effektiveKG(kg: p.kg, bezeichnung: p.bezeichnung),
  ```
- `ExtractPlanMapper.swift:38` (in `mapPositions`, für die latente Nutzung konsistent):
  ```swift
  pos.kostenGruppeNummer = effektiveKG(kg: p.kg, bezeichnung: p.bezeichnung)
  ```

### 3.3 `importSelected` NICHT anfassen nötig
`LVImportView.swift:357` bleibt `parsed.kostenGruppe ?? "300"` — bekommt jetzt eine
nicht-leere KG aus `toParsed`, das `?? "300"` ist nur noch harmloses Sicherheitsnetz.
(Optional zur Klarheit ein Kommentar „KG kommt bereits aufgelöst aus ExtractPlanMapper".)

## 4. Semantik / ehrliche Erwartung

- **Nur wenn `kg == nil/leer`** greift die Heuristik. Echte KGs (Mops-`/extract-plan`,
  Statik-Import) bleiben unverändert.
- `ordneZu` ist **keyword-heuristisch** → abstrakte Posten („Toilette", „Sturmsicherung",
  „TMP Kostenpaket") finden kein Keyword und landen weiter in „300". Das ist ok und ehrlich —
  Ziel ist „nicht mehr ALLES in 300", nicht „100 % perfekt".

## 5. Tests

**5.1 Unit (deterministisch, ohne Import-Flow) — bevorzugt:**
```swift
// effektiveKG: gelieferte KG gewinnt
#expect(ExtractPlanMapper.effektiveKG(kg: "334", bezeichnung: "egal") == "334")
// nil-KG → Heuristik greift (Bezeichnung mit klarem Keyword)
#expect(ExtractPlanMapper.effektiveKG(kg: nil, bezeichnung: "Erdaushub für Gründungspolster") != "300")
// nil-KG ohne Keyword → Sammel-300
#expect(ExtractPlanMapper.effektiveKG(kg: nil, bezeichnung: "Blafasel ohne Treffer") == "300")
```
(Die exakten KG-Nummern aus `KGZuordnungsService` ablesen und einsetzen statt `!= "300"`,
wenn du sie festnageln willst — robuster gegen künftige Keyword-Änderungen ist `!= "300"`.)

**5.2 Integration gegen die Fixture (optional, Muster wie `LVJSONImportTests`):**
- `~/Desktop/mopsss/LV/aura125-lv.json` (241 Positionen, alle kg=null) durch
  `ExtractPlanMapper.toParsed` schicken → **NICHT alle** `kostenGruppe == "300"`;
  Stichprobe: „Erdaushub …" und „Fundamente …" bekommen ihre KG, nicht 300.

## 6. Definition of Done
- Helfer `effektiveKG` da; `toParsed` + `mapPositions` nutzen ihn; Build grün (§8).
- Unit-Test 5.1 grün.
- Import von `aura125-lv.json` verteilt die Positionen über mehrere KGs (nicht alles 300).
- **Keine `app_bedienung.yaml`-Drift nötig** — das ist eine interne Daten-Verbesserung,
  keine sichtbare UI-Änderung (kein neuer Button/Tab/Workflow).

## 7. Regeln
- Vor Patch `.backup_*` (gitignoriert). **Kein Push / kein PR ohne Andreas' OK.**
- Conventional Commit, z. B. `feat: DIN-276-KG beim Import heuristisch setzen (statt Sammel-300)`.
- Deutsch für Domänen-Begriffe, iOS 17+.

## 8. Build & Test (Trailing-Dot — Pfade quoten)
```bash
xcodebuild test -project "iMOPS-Construction-Grid-Baustellen-Management..xcodeproj" \
  -scheme "iMOPS-Construction-Grid-Baustellen-Management." \
  -only-testing:"iMOPS-Construction-Grid-Baustellen-Management.Tests" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## 9. NICHT in Scope
- Keine Übersicht-View (das ist Weg B, eigener Schritt).
- Kein Titel-Klartext-Mitspeichern (spätere Kür, §9).
- Kein Umbau von `KGZuordnungsService` selbst — nur aufrufen.
- `importSelected`-Logik nicht umbauen.
