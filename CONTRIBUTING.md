# Contributing zu iMOPS Construction Grid

Kurze Sammlung von Regeln die uns hier nicht überraschen sollen.

## Code-Stil

- **Swift, SwiftUI, iOS 17+** (kein UIKit-Mix mehr außer wo zwingend nötig)
- **Deutsch im Code** für Variablen/Kommentare die Domain-Begriffe enthalten (z.B. `bauherr`, `kostenGruppe`), Englisch sonst
- **MVVM** wo sinnvoll, sonst pragmatisch
- Keine externen Dependencies ohne klaren Mehrwert (Yams für YAML-Pflege ist OK, eigener YAML-Parser wäre Overengineering)

## Branch-Konvention

- `feature/...` für neue Features
- `fix/...` für Bug-Fixes
- `chore/...` für Hygiene (Tests, Docs, Refactoring ohne Verhalten-Änderung)
- Direkt auf `main` pushen nur für Mikro-Fixes (Typos, Kommentare). Alles andere durch PR.

## Drift-Regeln — bevor du PR aufmachst

Wenn dein PR **UI-Views ändert** (neuer Button, umbenannter Tab, geänderter Workflow):
- [ ] **`Resources/Knowledge/app_bedienung.yaml` mit aktualisiert** — Bedienungshilfe-Einträge die zur Änderung passen
- [ ] Beispiel: Wenn du den GAEB-Import-Button umbenennst, ändere auch den passenden Eintrag in `app_bedienung.yaml`
- [ ] Bei komplett neuen Features: neuer Eintrag mit `app_version_min` auf die nächste Release-Version

Warum: der ExactMatchKnowledge-Pre-Filter zeigt diese Texte als "Bedienungshilfe" an. Wenn die Hilfe lügt, ist das schlimmer als gar keine Hilfe.

Wenn dein PR **DIN-Tabellen oder Bau-Fachwissen ändert** (z.B. neue DIN-Norm):
- [ ] Eintrag in der passenden YAML unter `Resources/Knowledge/` ergänzen
- [ ] `quelle_kurz` und `license_note` Pflichtfelder ausfüllen
- [ ] **KEIN Norm-Wortlaut** kopieren — nur Sachverhalte/Werte. Volltexte sind Beuth-lizenziert

Wenn dein PR den **Mops-Server** anspricht (mops-api Repo):
- [ ] Geht in das eigene Repo `AndreasPelczer/mops-api`, nicht hierher
- [ ] iMOPS-Construction enthält NUR den iOS-Client + Doku-Verweis im README

## Pull Request Template (manuell ausfüllen)

```markdown
## Was
<1-3 Sätze>

## Warum
<Hintergrund / Issue-Verweis>

## Tests
- [ ] Lokal gebaut, Build grün
- [ ] App auf Simulator getestet (für UI-PRs)

## Drift-Check
- [ ] Wenn UI geändert: app_bedienung.yaml aktualisiert
- [ ] Wenn DIN/Fachwissen geändert: passende YAML ergänzt
```

## Commit-Messages

- Conventional Commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`
- Erste Zeile max 70 Zeichen, Imperativ, Englisch oder Deutsch (konsistent im Repo)
- Body: warum, nicht was — der Code zeigt das was

## Bei Unsicherheit

Lieber fragen als raten. Codi-Sessions sind in den Commit-Footern als `https://claude.ai/code/session_...` verlinkt — wenn du an einem Commit zweifelst, lies die Session.
