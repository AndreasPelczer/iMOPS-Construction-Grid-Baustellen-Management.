# Welle-Kandidat — Visuelle Refusal-Sprache (Icon-Layer)

*Gefunden 11.06.2026, ~02:30, im nächtlichen Wach-Block. Aus der Bauwagen-Karte herausgewachsen.*
*Notiert von Opus 4.8. Für den Mops (Codi) zum Verstehen, für Andreas zum mit-den-Kollegen-Drüber-Reden.*

**Ablage:** liegt in `~/Documents`, gehört nach `…/iMOPS-Construction-Grid-Baustellen-Management./docs/`.
```
mv ~/Documents/Welle-Refusal-Sprache.md "$HOME/XcodeProjects/iMOPS-Construction-Grid-Baustellen-Management./docs/"
```

---

## Der Kern in einem Satz

Die fünf Icons der Bauwagen-Karte sind nicht Deko. Sie sind die **visuelle Sprache der Verweigerung** — das Bildschirm-Äquivalent zum SYSTEM_REFUSAL. Ein Polier mit Handschuhen, Sonne aufm Display, liest keinen Text. Er liest ein Icon. Picard, nicht Sokrates: nicht erklären, zeigen.

## Warum das eine echte Welle ist (kein Reskin)

Der entscheidende Satz, fast nebenbei gefallen: **„Läuft trotzdem" darf nur erscheinen, wenn der Punkt wirklich abgehakt ist.**

Das Helm-Icon ist damit nicht dekorativ — es ist **abgeleitet**. Es darf gar nicht angezeigt werden, solange die Vorleistung nicht steht. Das ist `deriveState`. Exakt der `DerivedStatus` aus *Der MOPS kam in die Küche*, Kapitel 4:
`.reworkDone(awaitingSignoff: true)` → zeigt **nicht** den Helm.
Erst `.fulfilled(...)` → Helm.

Das Icon lügt nicht, weil es nicht **gesetzt**, sondern **abgeleitet** wird. Die Bauwagen-Karte und der Code sind dasselbe Ding. **Das Plakat ist die Legende zum System.**

→ Das unterscheidet diese Welle vom reinen Icon-Tausch (siehe unten). Die Navi-Icons benennen einen Ort. Diese fünf leiten einen Zustand ab.

## Die fünf, als Zustands-Signale

| Karten-Satz | Bedeutung im UI | abgeleitet aus |
|---|---|---|
| **Steht oder steht nicht** (Mauer) | Vorleistung erfüllt / nicht erfüllt | `DerivedStatus.fulfilled` vs. `.pending/.deficient` |
| **Der Zettel zählt** (Klemmbrett) | Nachweis vorhanden / fehlt | Event in der Kette vorhanden? |
| **Abgehakt UND angenommen** (Haken) | Übergabe vollständig | Abgabe + Annahme, nicht nur Abgabe |
| **Wenn du jeden Morgen nachgucken musst, fehlt was** (Lupe) | da fehlt was → Warnsignal | offener Blocker / ausstehende Freigabe |
| **Läuft trotzdem** (Helm) | grün, auch ohne den Besten | NUR wenn alle Vorleistungen `.fulfilled` |

## Buch-Kapitel-Bezug (Hausregel erfüllt)

- **Kapitel 3** — Das erste Nein (Warnung ≠ Verweigerung)
- **Kapitel 4** — Verweigerung ist ein Ereignis (`DerivedStatus`, SYSTEM_REFUSAL)

Damit qualifiziert es sich als Welle. Welle-Nummer vergibt Andreas/Codi (Kandidat: 5.x, da nah an BuildIQ-Aufmaß-Logik).

## Form im UI (Vorschlag, offen)

- Kleines Zustands-Symbol am Eintrag/Auftrag, **dem Event entsprechend** — nicht statisch, abgeleitet.
- Bei aktiver Verweigerung: Popup/Sheet im Stil der Buch-Mockups („⛔ AUFTRAG GESPERRT" → jetzt als Icon + Grund + Regel).
- **Wichtig:** Die fünf Zustands-Icons müssen optisch von den Navi-Icons getrennt sein (gefüllt vs. outline, oder der gelb-schwarze Karten-Look). Sonst Doppeldeutigkeit — z. B. liest sich die Lupe in der MA-Suche neutral, auf der Karte als Warnung. Das Auge muss „Zustand" von „Ort" unterscheiden können.

## Abgrenzung — was NICHT diese Welle ist

Der andere Icon-Punkt von heute Nacht (Hochhaus = Planarchiv Großküche, Lupe = MA-Suche, Hirn = BuildIQ, Buch = Bauwissen, Zahnrad = Settings, Zauberstab/Files = Sheets, grüner Haken = keine Mängel) ist **reiner SF-Symbols-Tausch / Branchen-Reskin**. Fleißarbeit, kein Architektur-Eingriff, kein Welle-Status. Getrennt halten, damit die Kraft der fünf Zustands-Icons nicht verwässert (TAO Kap. 10: Begrenzung statt Vollständigkeit).

## Polier-Reflex / Wachhund (klein, aber notiert)

Falls später Mitarbeiter-/Zunft-Symbole dazukommen (Rolandsbrüder-Logo o. ä.): Symbol für **Zugehörigkeit** ja, Symbol fürs **Tracking** nie. „Wer war wo" ist BourdainGuard-Grenze. Wahrscheinlich eh als Stolz gemeint — nur die Linie im Kopf behalten.

---

*Status: aufgenommen, nicht ausgeführt. Andreas will es zuerst sehen und mit Codi + Terminal-Claude besprechen. Cowork nicht — der macht nur Post. 🐶*

*— Opus 4.8, 11.06.2026, zweiter Wach-Block. Danach: Glas.* 🐠
