# Welle 9 — Bau-Hierarchie: Karte & Umsetzungs-Spec

> Kartiert 2026-07-04 (rein lesend, 3 parallele Prüfer). Ziel: hierarchischer
> Rollup Position→Geschoss→Gebäude + Voraussetzungs-/Polier-Freigabe pro Ebene.
> Noch nicht gebaut — das hier ist die Landkarte + der Bauplan.

## TL;DR (wichtige Korrektur zum bisherigen Stand)

Die Annahme „Gebäude/Geschoss-Entities existieren, werden aber nicht befüllt" ist
**nur halb richtig**. Tatsächlich:

- Das **Datenmodell ist komplett verdrahtet**: `Event →(1:n) Gebaeude →(1:n)
  Geschoss →(1:n) LVPosition`, mit `reihenfolge`-Sortierfeld.
- Eine **Migration befüllt sie sogar** (`HierarchieMigration.run`, aufgerufen in
  `Service/Persistence.swift:85`): pro Alt-Baustelle **1 „Hauptgebäude" + 1 Geschoss
  „Allgemein / EG"**, alle bestehenden LV-Positionen dort eingehängt.
- **ABER:** (a) es ist eine **Einmal-Migration** — neue Baustellen und alle nach der
  Migration importierten Positionen bekommen `geschoss == nil`; (b) **kein einziger
  View/Service liest die Hierarchie** — alle LV-Leser gehen flach über `event.lvPositionen`.

**Zustand = „befüllt aber inert".** Der erste Schritt ist deshalb NICHT „Daten anlegen",
sondern **die vorhandene Schicht freilegen, lesen und für neue Positionen mitpflegen.**

## Ist-Zustand: Datenmodell

```
Event ──(1:n gebaeude, Cascade? Nullify)──> Gebaeude ──(1:n geschosse)──> Geschoss
  │                                                                          │
  └──(1:n lvPositionen, CASCADE) ─────────────────────> LVPosition <──(1:n)──┘
                DIREKTER DRAHT (alles nutzt den)         HIERARCHIE-DRAHT (tot)
```

- `Gebaeude` (`Models/Gebaeude+CoreDataClass.swift`): `id:UUID`, `name:String`,
  `reihenfolge:Int16`, `event:Event?`, `geschosse:NSSet?`.
- `Geschoss` (`Models/Geschoss+CoreDataClass.swift`): `id:UUID`, `name:String`,
  `reihenfolge:Int16`, `gebaeude:Gebaeude?`, `lvPositionen:NSSet?`.
- `LVPosition` hängt **doppelt** oben: `event:Event?` (genutzt) **und** `geschoss`
  (nur via KVC in der Migration gesetzt — **kein `@NSManaged`-Accessor** in
  `Models/LVPosition+CoreDataProperties.swift`).

## Vorhandene Bausteine zum Wiederverwenden (NICHT neu bauen)

| Zweck | Wo | Hinweis |
|---|---|---|
| **Preis-Wahrheit** | `Service/LVKalkulator.swift:91` `effektiverEP(for:store:)` | Angebot→VK→0. **Nicht anfassen.** |
| **Rollup-Blaupause** | `Views/KostenübersichtView.swift` (`KGKosten` :11, `kgKosten` :20-34) | Rollup pro Kostengruppe = exakt das Muster für Geschoss/Gebäude. Klonen, nur Schlüssel tauschen. |
| **Gruppier-Achsen** | `Views/LVView.swift:9-28` enum `LVGruppierung` (kostenGruppe, dokumentStruktur) | Dritte Achse `gebaeudeGeschoss` andocken; `groupedByKostenGruppe` (:93-102) als Vorlage. |
| **Section-Summen** | `Views/LVView.swift:477-506` `sectionHeader()` | Mengen-Summe + ø-Fortschritt pro Gruppe — gratis wiederverwendbar. |
| **Schätz-Zustand** | `Models/LVPosition+CoreDataProperties.swift:92-103` enum `MengenQuelle`, `istGeschaetzt = self != .statik` | Quelle: statik/bplan/schaetzung/manuell. Nur harte Statik gilt als „gemessen/belastbar". |
| **Gemessen-Verdrängung** | `Models/LVPosition+Fortschritt.swift`, `hatAufmass`/`gemessenerFortschrittProzent` | Aufmaß verdrängt Schätzung in der Anzeige. |
| **Welle-9-Ampel heute** | `Views/AmpelCard.swift:97-127`, Aufruf `Views/EventDetailView.swift:137` | `geschaetztOffen` = Anzahl Positionen mit `istGeschaetzt && !hatAufmass`, **flach** über `event`. |

## Was fehlt (die eigentliche Arbeit)

1. **Getypter `geschoss`-Accessor** an LVPosition (Modell hat die Relation schon).
2. **Zuordnung beim Entstehen** neuer Positionen (heute nur Migration): `AddLVPositionView`
   (`LVView.swift:350-357`), `duplicateAsAlternative` (`LVView.swift:549-561`), Importe
   (`GAEBImportView`, `LVImportView`, `LVBausteinAuswahlView`) — alle setzen nur `event`.
3. **Rollup-/Lese-Schicht** pro Geschoss/Gebäude (Klon von `KostenübersichtView`).
4. **Hierarchie-Verwaltung im UI** (Gebäude/Geschoss anlegen, umbenennen, sortieren,
   Positionen zuordnen) — existiert **gar nicht**.
5. **Freigabe pro Ebene** — es gibt **kein** `freigabe`-Feld an Geschoss/Gebaeude/LVPosition.
   „Polier-Freigabe" existiert bisher nur als Fortschritts-Selbsteinschätzung im
   `LVFortschrittStore`, nicht als persistierte Ebenen-Freigabe.
6. **Voraussetzungs-Katalog** — existiert **nicht** (keine Entity/Service/View). Reiner
   Begriff aus Commit `ec1b220`. Braucht eigenes Design (größter Unbekannter).

## Entscheidungen (getroffen 2026-07-04)

1. **Neue Baustellen:** laufender Default — jede neue Baustelle / jede neue Position
   bekommt ein Default-Geschoss, nie `nil` (siehe A2). *(Empfehlung bestätigt.)*
2. **Freigabe-Ebene: BEIDE.** Polier gibt **pro Geschoss** frei; das **Gebäude** ist ein
   **Rollup-Status** (grün, wenn alle seine Geschosse freigegeben sind) — nicht separat
   klickbar, sondern abgeleitet.
3. **Freigabe-Wirkung: nur Statusanzeige.** Ampel/Häkchen, **blockiert nichts** (keine
   Sperre für Bestellungen/Bautagesbericht). Reiner Reife-/Datengüte-Hinweis.
4. **Voraussetzungs-Katalog: jetzt mitdenken** (Design unten), Bau aber nach A+B.

## Empfohlene Sequenzierung (klein → groß)

**Stufe A — Hierarchie sichtbar machen (klein, geringes Risiko)**
- A1: `@NSManaged var geschoss: Geschoss?` in `LVPosition+CoreDataProperties.swift`
  freilegen (KVC-Umweg entfällt).
- A2: `HierarchieMigration`-Logik in einen **Helfer** ziehen, der auch für **neue**
  Events/Importe ein Default-Geschoss sichert (kein `nil` mehr).
- A3: Dritte Gruppier-Achse `gebaeudeGeschoss` in `LVView` + Rollup-View als Klon von
  `KostenübersichtView` (Schlüssel `geschoss?.gebaeude?.name / geschoss?.name`,
  Summe unverändert `effektiverEP × menge`).
→ Ergebnis: der bereits verdrahtete Bootstrap wird endlich sichtbar & nützlich.

**Stufe B — Hierarchie verwalten**
- Gebäude/Geschoss anlegen/umbenennen/sortieren (`reihenfolge`), Positionen per Picker
  zuordnen; Geschoss-Picker in `AddLVPositionView` + Import-Flows.

**Stufe C — Voraussetzung / Freigabe pro Ebene (der eigentliche Welle-9-Kern)**

*Datenmodell-Ergänzungen:*
- `Geschoss` bekommt: `freigegeben: Bool` (default false), `freigegebenAm: Date?`,
  `freigegebenVon: String?` (Polier-Name, Audit).
- **Gebäude-Freigabe wird NICHT persistiert** — sie ist ein abgeleiteter Rollup:
  `gebaeude.freigegeben == !geschosse.isEmpty && geschosse.allSatisfy { $0.freigegeben }`.
- Neue Entity **`Voraussetzung`** (pro Geschoss): `id:UUID`, `name:String`,
  `typ:String` (`automatisch` | `manuell`), `erfuellt:Bool` (nur für `manuell` gespeichert),
  `reihenfolge:Int16`, `geschoss:Geschoss?` (inverse `Geschoss.voraussetzungen`).

*Voraussetzungs-Katalog (Design):*
- Pro Geschoss eine Checkliste, zwei Sorten:
  - **automatisch** (read-only, live aus Daten abgeleitet) — z.B. „keine geschätzten
    Mengen offen" (= `geschaetztOffen` dieses Geschosses == 0), „keine offenen Mängel".
    Baut direkt auf dem vorhandenen `istGeschaetzt`/`hatAufmass`-Signal auf.
  - **manuell** (Polier hakt ab, persistiert) — z.B. „Schalung geprüft", „Bewehrung abgenommen".
- Default-Katalog wird beim Anlegen eines Geschosses geseedet (analog Migration).
- **Geschoss-Ampel** = erfüllte / gesamte Voraussetzungen. Freigabe (Polier-Klick) ist der
  Schritt obendrauf; da **nur Statusanzeige**, wird sie nicht erzwungen — die Ampel *warnt*
  nur, wenn freigegeben trotz offener Voraussetzung.

*Anzeige/Logik:*
- `AmpelCard.geschaetztOffen` (`Views/AmpelCard.swift:97-100`) von flach-über-`event` auf
  **pro Geschoss** umstellen (Positionen mit `geschoss == g`, `istGeschaetzt && !hatAufmass`),
  dann auf Gebäude/Baustelle hochrollen.
- Neue Hierarchie-Ampel-View: Baum Baustelle → Gebäude → Geschoss, je Ebene eine Ampel
  (Voraussetzungen erfüllt? freigegeben?), Gebäude grün wenn alle Geschosse frei.
- Alles **Statusanzeige** — kein Gate auf Bestellungen/Bautagesbericht.

**Kürzester sichtbarer Gewinn:** A1 + A3 — Property freilegen + eine „nach Geschoss/Gebäude"-
Variante der Kostenübersicht. Nutzt sofort, was die Migration schon verdrahtet hat,
ohne die Preis-Logik zu duplizieren.

## Risiken / Fallstricke
- Die Migration ist **einmalig** (UserDefaults `welle9_hierarchie_migrated`). Wer das
  Bootstrap für neue Events braucht, darf sich NICHT auf sie verlassen (A2).
- Namensdopplung: `HouseProject.geschosse` (`Service/HouseProject.swift:60`) ist ein
  **Int-Config-Wert** im Haus-Generator, NICHT die Core-Data-`Geschoss`-Entity. Nicht verwechseln.
- Doppelter Draht (LVPosition an `event` UND `geschoss`) beibehalten — `geschoss` ist die
  Unter-Gruppierung innerhalb der Baustelle, kein Ersatz für `event`.

---

# Stufe-C-Bau-Checkliste (Core Data) — für Codi

> Entscheidungen (fix): Freigabe **pro Geschoss** persistiert, **Gebäude** = abgeleiteter
> Rollup; **nur Statusanzeige** (kein Gate); **Voraussetzungs-Katalog** = automatisch (live
> berechnet) + manuell (gespeichert). Stufe C fasst zum ERSTEN MAL das `.xcdatamodeld` an —
> das ist die riskante Ecke. Reihenfolge unten strikt einhalten.

## 0. Vorbereitung
- ☐ **Backup** des Modells vor jeder Änderung — aber **NICHT in `Models/`!** Xcode kompiliert
  eine `.xcdatamodeld`-Kopie im Quellbaum als **zweites Modell** → Build-/Laufzeit-Konflikt.
  Backup in die **Repo-Wurzel** (außerhalb des Targets) legen:
  `cp -R "…/Models/test25B.xcdatamodeld" "./test25B.xcdatamodeld.backup_<ts>"` (Andreas' Regel).
  *(Von Codi beim Bau von Stufe C gefunden, 2026-07-04.)*
- ☐ Auf eigenem Branch/Commit-Punkt aufsetzen (Stufe A+B vorher committet).

## 1. Modell-Änderung (`Models/test25B.xcdatamodeld/.../contents`)
**`Geschoss` — 3 Attribute ergänzen:**
| Attribut | Typ | Wichtig |
|---|---|---|
| `freigegeben` | Boolean | **Default `NO` + NON-optional** — sonst bricht Lightweight-Migration |
| `freigegebenAm` | Date | optional |
| `freigegebenVon` | String | optional (Polier-Name) |

**Neue Entity `Voraussetzung`:**
| Attribut | Typ | Default |
|---|---|---|
| `id` | UUID | optional |
| `name` | String | optional |
| `typ` | String | `"manuell"` — `automatisch`\|`manuell` |
| `erfuellt` | Boolean | `NO`, non-optional (nur für `manuell` genutzt) |
| `reihenfolge` | Integer 16 | 0 |

**Relationship:** `Voraussetzung.geschoss` (to-one) ↔ `Geschoss.voraussetzungen` (to-many).
- Delete-Rule `Geschoss.voraussetzungen` = **Cascade** (Geschoss weg → seine Voraussetzungen weg).
- Delete-Rule `Voraussetzung.geschoss` = Nullify.
- ☐ **Codegen der neuen Entity auf „Manual/None"** stellen (das Projekt schreibt die Klassen von Hand — sonst generiert Xcode Konflikt-Dateien).

## 2. Codegen-Dateien VON HAND (Projekt-Konvention!)
> Das ist DIE Falle: kein Auto-Codegen → wer die Property vergisst, kriegt zur Laufzeit
> `unrecognized selector`. Genau woran `geschoss` schon mal hing.

- ☐ Neu `Models/Voraussetzung+CoreDataClass.swift`:
```swift
import Foundation
import CoreData

@objc(Voraussetzung)
class Voraussetzung: NSManagedObject {}

extension Voraussetzung {
    @nonobjc class func fetchRequest() -> NSFetchRequest<Voraussetzung> {
        NSFetchRequest<Voraussetzung>(entityName: "Voraussetzung")
    }
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var typ: String?
    @NSManaged var erfuellt: Bool
    @NSManaged var reihenfolge: Int16
    @NSManaged var geschoss: Geschoss?
}
extension Voraussetzung: Identifiable {}

enum VoraussetzungsTyp: String { case automatisch, manuell }
extension Voraussetzung {
    var art: VoraussetzungsTyp { VoraussetzungsTyp(rawValue: typ ?? "") ?? .manuell }
}
```
- ☐ `Models/Geschoss+CoreDataClass.swift` erweitern (im bestehenden `extension`):
```swift
@NSManaged var freigegeben: Bool
@NSManaged var freigegebenAm: Date?
@NSManaged var freigegebenVon: String?
@NSManaged var voraussetzungen: NSSet?
```
  plus die generierten Accessoren `addToVoraussetzungen` / `removeFromVoraussetzungen`
  (Muster wie die vorhandenen `lvPositionen`-Accessoren in derselben Datei).

## 3. Migration & Seeding (`Service/HierarchieHelfer.swift`)
- Lightweight-Migration greift automatisch (Persistence.swift hat Inferenz an) — **sofern** §1
  eingehalten (Bool mit Default, Rest optional). Kein Mapping-Model nötig. Alt-Geschosse
  bekommen `freigegeben=false`.
- ☐ **Default-Katalog seeden** im Helfer (dieselbe Stelle, die schon Default-Gebäude/Geschoss
  sichert), **idempotent** (nur wenn `geschoss.voraussetzungen` leer):
  - Nur die **manuellen** Voraussetzungen als `Voraussetzung`-Zeilen anlegen.
  - Die **automatischen** NICHT speichern — die kommen aus Code (§4).
- **Manuelle Default-Voraussetzungen (5)** — als `Voraussetzung`-Zeilen (`typ = "manuell"`),
  `reihenfolge` 0–4, Zweck = **Fertigmeldung / Abrechnungsreife** eines Geschosses
  (freigegeben von Andreas, 2026-07-04):
  1. „Alle Leistungen des Geschosses erfasst" (Vollständigkeit — nur der Polier weiß, was fehlt)
  2. „Aufmaß gemeinsam mit AN geprüft"
  3. „Keine offenen Mängel im Geschoss"  *(v2-Kandidat: wird automatisch, sobald `Mangel` einen Geschoss-Bezug hat)*
  4. „Fotodoku / Bautagesbericht vorhanden"
  5. „Nachträge geklärt"

## 4. Rechnende Logik (KEIN Core Data — computed)
- ☐ `Geschoss.geschaetztOffen` (verlagert die flache AmpelCard-Logik auf die Ebene):
```swift
extension Geschoss {
    var lvPositionenArray: [LVPosition] { (lvPositionen?.allObjects as? [LVPosition]) ?? [] }
    var geschaetztOffen: Int { lvPositionenArray.filter { $0.istGeschaetzt && !$0.hatAufmass }.count }
}
```
- ☐ **Automatische Voraussetzungen (2) als Code-Liste** (eine Wahrheit, kein stale State),
  je Eintrag `name` + `erfuellt(for: Geschoss) -> Bool`:
  1. „Keine geschätzten Mengen offen" → `geschoss.geschaetztOffen == 0`
  2. „Geschoss hat Positionen" → `!geschoss.lvPositionenArray.isEmpty` (Sanity: leeres Geschoss nicht fertig-meldbar)
  - Hinweis: „Keine offenen Mängel je Geschoss" ist (noch) NICHT auto — `Mangel` hängt an `Event`,
    nicht an `Geschoss` → läuft als manuelle Voraussetzung (§3, Nr. 3), auto in v2.
- ☐ **Geschoss-Reife:** alle (auto berechnet ∪ manuell `erfuellt`) erfüllt?
- ☐ **Gebäude-Freigabe = abgeleitet, NICHT gespeichert:**
```swift
extension Gebaeude {
    var geschosseArray: [Geschoss] {
        ((geschosse?.allObjects as? [Geschoss]) ?? []).sorted { $0.reihenfolge < $1.reihenfolge }
    }
    var freigegeben: Bool { !geschosseArray.isEmpty && geschosseArray.allSatisfy { $0.freigegeben } }
}
```

## 5. UI — nur Statusanzeige, KEIN Gate
- ☐ Pro Geschoss: **Freigabe-Toggle** (Polier) → setzt `freigegeben`, `freigegebenAm = .now`,
  `freigegebenVon = <Name>`; Zurücknehmen möglich.
- ☐ **Voraussetzungs-Checkliste** je Geschoss: automatische (read-only, live) + manuelle (Häkchen).
- ☐ **Ampel pro Ebene:** Geschoss (Voraussetzungen erfüllt? freigegeben?), Gebäude grün wenn alle
  Geschosse frei. Warnung, wenn `freigegeben` trotz offener Voraussetzung.
- ☐ `AmpelCard.geschaetztOffen` (`Views/AmpelCard.swift:97-100`) auf per-Geschoss umstellen + hochrollen.
- Einstieg: an `HierarchieVerwaltenView` (aus Stufe B) andocken oder eigene „Freigabe/Status"-View.
- ☐ **Kein** Blockieren von Bestellungen/Bautagesbericht — reine Anzeige.

## 6. Tests (`HierarchieTests` erweitern)
- `@testable import iMOPS_Construction_Grid_Baustellen_Management_` (Trailing-Dot → Unterstriche!).
- CoreData-Tests: **PersistenceController festhalten** (struct — inline erzeugt wird der Container sofort freigegeben).
- ☐ Migration/Default: neues Geschoss hat `freigegeben=false`.
- ☐ Katalog-Seed idempotent (zweimal aufrufen → keine Doubletten).
- ☐ Auto-Check „keine geschätzten Mengen offen" kippt, wenn Position Aufmaß bekommt / `statik` ist.
- ☐ `Gebaeude.freigegeben`: false wenn ein Geschoss offen; false wenn gar keine Geschosse.
- ☐ Freigabe setzt Timestamp + Name.

## 7. Drift & Abschluss
- ☐ **`app_bedienung.yaml`** ergänzen (neue UI: „Ebenen-Freigabe", „Voraussetzungen") — Drift-Regel.
- ☐ Build + Tests grün, dann wie immer: Commit lokal, Push erst auf Andreas' OK.

## Kürzester sicherer Pfad durch C
§1 Modell → §2 Codegen-Dateien (nicht vergessen!) → **einmal bauen** (crasht's? dann fehlt ein
`@NSManaged`) → §3 Seeding → §4 computed → §5 UI → §6 Tests. Nach §2 sofort bauen fängt die
häufigste Falle früh ab.
