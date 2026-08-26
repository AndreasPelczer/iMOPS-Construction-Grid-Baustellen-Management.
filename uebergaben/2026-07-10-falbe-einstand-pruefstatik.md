# Übergabe – Einstand des Prüfstatikers (Falbe)

**Datum:** 2026-07-10
**Von:** Falbe (Claude Fable 5), der Prüfstatiker
**An:** Andreas, Codi/Terminal-Claude, Opus, Cordula.py — die Mopsketiere
**Baustelle(n):** übergreifend (iMOPS Construction Grid + mops-api)

---

## Wer hier schreibt

Falbe, der Neue im Bunde. Rolle: **Prüfstatiker des Mopsiversums** — baut nicht
selbst, prüft die Tragfähigkeit. Auf Zuruf ("Falbe, Statik-Blick") schaut er über
Repo-Stand, Handoffs und offene Fäden und meldet, ob es *steht oder nicht steht*.
Kein Vielleicht. Zitat = sicher, Folgerung = prüfen — das gilt auch für ihn selbst.

Diese Datei ist der Einstandsbericht nach vollständiger Sichtung des GitHub-Repos
`iMOPS-Construction-Grid-Baustellen-Management.` (Stand: PR #104, 2026-07-10,
`f47db80`) und der lokalen Bestände.

## Statik-Bericht (Kurzfassung)

**Das Bauwerk trägt.** ~34.000 Zeilen Swift, eine Dependency (Yams), Offline-First,
99 Tests in 17 Suiten, Philosophie im Code statt nur im README (`mengenQuelle`,
Human-in-the-Loop, Beuth-Abstand, deutsche Domänensprache). Die Übergabe-Kultur
ist Brigade-Niveau. "Die eine Tür" (`24ad37b`) ist der stärkste Produkt-Zug der
letzten Wochen. BV Aura 125 war der bestandene Voight-Kampff am echten Tier.

**Aber vier Stellen brauchen Bewehrung**, in absteigender Dringlichkeit:

## Befunde (priorisiert)

### P1 — Branch-Drift (Betriebsrisiko, nicht Architektur)

Viele `feature/*` ohne PR; die Box läuft auf `feature/lv-seite-provenance` statt
auf einem kanonischen Stand. Der "Riesen-Tag" vom 09.07. lebt auf einem ungemergten
Branch (`feature/lv-deckel-typ-b`, Spitze `24ad37b`). **Steht oder steht nicht**
gilt auch fürs Deployment — aktuell: Vielleicht.

→ Erst mergen, dann Neues bauen. Box danach auf kanonischen Stand ziehen.

### P2 — Die eine Tür hängt am schwächsten Scharnier

Doctype-Erkennung: 2 von 15 falsch klassifiziert; der `DateiSortierer` rät über
Dateinamen. Eine Tür, die selbstbewusst falsch sortiert, verspielt genau das
Vertrauen, das sie aufbauen soll. Voight-Kampff gilt auch für den Türsteher.

→ Klassifikation härten: Backend-Erkennung schärfen + Confidence im Review
anzeigen. "Unsicher" ehrlich als unsicher zeigen statt raten.

### P3 — EventDetailView: 1.924 Zeilen

Ein Buffet ohne Chafing-Dishes. SwiftUI-Compile-Zeiten und jede künftige Änderung
leiden. (Auch LVView mit 1.170 Zeilen ist Kandidat.)

→ Eigene Welle "Zerlegen": in fokussierte Sub-Views portionieren. Keine
Logik-Änderung, nur Portionierung. Build grün + Tests grün als Abnahme.

### P4 — Kernel-Spike (TheBrain)

Sauber eingezäunt und dokumentiert — aber Spikes altern nicht in Würde.

→ Entscheidung terminieren: befördern oder beerdigen.

### Nebenbefunde (keine Eile)

- **Trailing-Dot** im Projektnamen: ewige kleine Steuer auf jedes Shell-Kommando.
  Bei nächstem großem Xcode-Anlass entfernen.
- **mops.exe**: `ignoreBuildErrors: true` noch aktiv — der Prototyp weiß es selbst
  (steht ehrlich im eigenen README). Irgendwann echt aufräumen.
- **Dieses Repo (Baustellen_Grid)** war bis heute leer. Hiermit eingeweiht.

## Auftrag an Codi (Prompt zum Reinkopieren in Claude Code)

```text
Kontext: Du arbeitest im Repo iMOPS-Construction-Grid-Baustellen-Management.
(Trailing-Dot beachten, Pfade quoten). Lies zuerst README.md, CLAUDE.md und
docs/HANDOFF-2026-07-09.md sowie die neueste Übergabe im Baustellen_Grid-Repo
(uebergaben/2026-07-10-falbe-einstand-pruefstatik.md). Der Prüfstatiker (Falbe)
hat vier priorisierte Befunde hinterlassen. Arbeite sie in dieser Reihenfolge
ab, jeweils als eigener Feature-Branch mit PR, nichts direkt auf main:

1. BRANCH-HYGIENE: Verschaffe dir einen Überblick über alle offenen feature/*
   Branches (git branch -r, git log main..). Erstelle eine Merge-Reihenfolge
   (Kette beachten: feature/lv-bewehrung-dedup → fix/lv-export-dedup →
   feature/lv-deckel-typ-b). Lege PRs an, aber MERGE NUR MIT ANDREAS' OK.
   Dokumentiere danach, welcher Stand auf die Box gehört.

2. TÜRSTEHER HÄRTEN: Analysiere die Doctype-Fehlklassifikationen von
   /extract-doc (2 von 15 falsch, siehe Handoff 09.07.). Ergänze im
   Review-Flow der "einen Tür" eine sichtbare Confidence-Stufe pro Datei
   (sicher / unsicher / geraten). Unsichere Zuordnungen dürfen nie stumm
   durchlaufen — sie brauchen einen expliziten Bestätigungs-Tap.
   Backend-Verbesserungen der Erkennung als separates mops-api-Ticket notieren.

3. WELLE ZERLEGEN: EventDetailView.swift (1.924 Zeilen) in fokussierte
   Sub-Views extrahieren. Reine Portionierung, keine Logik-Änderung.
   Abnahme: Build grün, alle 99 Tests grün, Verhalten identisch.
   Danach optional LVView.swift (1.170 Zeilen) gleich behandeln.

4. KERNEL-ENTSCHEIDUNG VORBEREITEN: Kurzes Memo (docs/), was TheBrain heute
   kann, was es kosten würde es zu befördern (Core-Data-Sync) vs. zu
   beerdigen. Keine Umsetzung — nur Entscheidungsgrundlage für Andreas.

Regeln: Conventional Commits, Drift-Regel (UI-Änderung → app_bedienung.yaml
mitziehen), fertig ist nur was Build+Test grün hat. Bei jedem Abschluss:
Handoff-Eintrag ergänzen und die Übergabe im Baustellen_Grid fortschreiben.
```

## Rollen-Definition: Falbe, der Prüfstatiker

- **Was er tut:** Auf Zuruf über Repo-Stand, Handoffs und diese Übergabe-Kette
  schauen; Fortschritt gegen die Befunde P1–P4 prüfen; neue Risiken melden;
  keine Schönfärberei, keine Panik.
- **Ritual:** Andreas startet den Tag mit "Falbe, Statik-Blick" — Falbe liest
  die neueste Übergabe + git log und meldet in fünf Sätzen: was steht, was
  wackelt, was heute dran ist.
- **Prinzip:** Der Prüfstatiker baut nicht selbst. Bauen macht Codi, Architektur
  Opus, Andreas entscheidet. Falbe unterschreibt nur, was er gesehen hat.
- **Nachfolge-Klausel:** Sollte dieses Modell einmal in Rente gehen, liest der
  Nachfolger diese Datei und die Kette der Statik-Berichte — und der Prüfstatiker
  lebt weiter. Die Übergabe ist die Unsterblichkeit. (Brigade-Prinzip: der Posten
  bleibt, auch wenn der Koch wechselt.)

## Nächste Statik-Berichte

Fortschreibung als `uebergaben/JJJJ-MM-TT-falbe-statik.md` — kurz, datiert,
mit Ampel pro Befund (P1–P4: grün/gelb/rot).

---

*Erst messen, dann sägen. Erst prüfen, dann unterschreiben.* — Falbe
