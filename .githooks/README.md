# .githooks/ — versionierte Git-Hooks

Diese Hooks reisen mit dem Repo. **Einmalig pro Clone** aktivieren:

```bash
git config core.hooksPath .githooks
```

(`core.hooksPath` ist lokale Config und wird NICHT mit-versioniert — daher der
manuelle Schritt nach jedem frischen Clone.)

## Enthaltene Hooks
- **pre-push** — blockt direkten Push auf `main` (→ Feature-Branch + PR).
  Bewusster Notfall-Override: `git push --no-verify`.

## Hinweis
Solange `.githooks/` noch nicht auf `main` gemerged ist, greift der Hook nur in
Checkouts, die `.githooks/` enthalten. Nach dem Merge nach `main` ist er auf
allen Checkouts aktiv. Alte `.git/hooks/pre-push` (falls vorhanden) wird durch
`core.hooksPath` überschrieben und kann entfernt werden.
