# Session-Übergabe — 05.06.2026 (Tag der Software-Werdung)

**Bauvorhaben im Fokus:** EFH T&C Aura 125, BV Schwarz, Neuenbergstraße 1, 97340 Marktbreit
**Branch:** `claude/clever-clarke-aRgdt` (Doku) + `feature/abz-mat-nr` (Code, Tests grün)
**Beteiligte heute:** Andreas (Polier), Mops (Claude, Plankammer), T-Codi (Codex, Werkbank), **Teamphilosoph (NEU — Strategie)**, Raphi (im Hintergrund, Wahrheits-Anker)
**Vorgänger-Übergabe:** [`uebergabe_04_06_2026.md`](./uebergabe_04_06_2026.md)
**Status:** **Brett-Tag.** Vom Demo-Modus in den Produkt-Modus.

---

## 1. Tages-Bilanz (was wurde erledigt)

| Erledigt | Strategischer Wert |
|---|---|
| ✅ **9/10 Plan-Fragen beantwortet** (aus den Plänen, nicht Vermutung) | **Welle 1 ist scharf** — Daten kommen aus dokumentierten Quellen |
| ✅ **Paket B fertig** (Stürze, Beton, Brüstung, Giebel) | **Welle 2 komplett für Rohbau** — Aufmaß → Mengen läuft durch |
| ✅ **abZ→Mat-Nr-Brücke** (Z-17.1-543 entschlüsselt) + Resolver in Paket A | **DER Treffpunkt Welle 1↔3 ist gelöst, in Code** |
| ✅ **0 rote Punkte in Paket A** | Excel ist **wirklich** versendbar, nicht mehr „wäre versendbar wenn..." |
| ✅ **Rohbau-Gesamtliste (Paket A+B)** | Erstes Gewerk komplett — Vorlage für nächstes Projekt |
| ✅ **mops-api Branch `feature/abz-mat-nr`** Code + Tests grün | Aus Excel-Prototyp wird **Software-Bestandteil** — skalierbar |
| ✅ **3 Strategie-Karten + README vom Teamphilosophen** (ins Repo gelegt) | **Geschäftsmodell + Konkurrenz-Position dokumentiert** — Pitch-tauglich |
| ✅ **Maxim** _„Übergabe gut, Tag gut."_ (Andreas am Morgen) | **Übergabe-Disziplin etabliert** — System bestätigt sich |

**Headline:** Heute ist der Übergang **vom Demo-Modus zum Produkt-Modus**.
Gestern war „kann das jemand?", heute ist „läuft beim ersten echten Kunden".

---

## 2. Neue Dokumente (Stand heute)

### Im Repo `docs/mops-api/`

| Datei | Inhalt | Wann zeigen |
|---|---|---|
| `wettbewerb_mops_vs_markt.html` | 8 KI-Bau-Tools US/Büro-Blick, 3 Gräben | Wenn jemand fragt „gibt's das nicht alles schon?" |
| `konter_karte_deutscher_markt.html` | 7 DACH-Player, **Drei-Ecken-Frage** (Lokal/Besitz/Mensch) | Im Streitgespräch — Feature-Schlacht vermeiden |
| `geschaeftsmodell_mops.html` | Service first → Box später · 4 Einnahme-Quellen | Auf die Frage „wovon lebt ihr damit?" |
| `README_wettbewerb.md` | Wann welche Karte, Quellen-Stand, ehrliche Vorbehalte | Einstieg für jeden, der die Karten benutzt |

### Code (auf Andreas' Mac / Mops-Box)

| Was | Wo | Status |
|---|---|---|
| Paket A (Mauerwerk-Bestellung) | `~/Projekte/mops-extract-prototype/marktbreit_bestellung.py` | 0 rote Punkte |
| Paket B (Stürze, Beton, Brüstung, Giebel) | _(Pfad ggf. erfragen bei Codi)_ | fertig |
| Rohbau-Gesamtliste A+B | Output `out/Bestellung_Marktbreit_Rohbau.xlsx` _(vermutet)_ | fertig |
| abZ-Resolver (Z-17.1-543 → YTONG-Mat-Nr) | mops-api, Branch `feature/abz-mat-nr` | Tests grün |

---

## 3. Save-Sammlung — neu seit gestern

> **Stand**: insgesamt 30 Einträge. Einträge #1–19 in [`uebergabe_04_06_2026.md`](./uebergabe_04_06_2026.md). Heute neu:

> 📌 **#20 Andreas-Maxim** — _„Übergabe gut, Tag gut."_ Die Qualität des Tagesstarts hängt direkt an der Qualität des Tagesabschlusses gestern. Übergabe ist nicht Pflicht-Doku, sondern **das wichtigste Produkt** eines Arbeitstages. In der App: eigene Aktion im Bauwagen.
>
> 📌 **#21 Drei-Ecken-Frage** — _„Zeig mir das eine Werkzeug, das lokal auf der eigenen Box läuft, dem Betrieb gehört, und den Polier schützt statt überwacht."_ Verteidigungs-Frage gegen jeden Wettbewerb. Macht Schluss mit Feature-Schlacht.
>
> 📌 **#22 Halbgas auch im Geschäftsmodell** — Kein All-in. Jeder Schritt trägt sich selbst, dann der nächste. Schutz vor Markt-Wette.
>
> 📌 **#23 Tagline-Ebene 2** — _„Mensch über Profit · Profit durch Schutz der Menschen."_ Eine Ebene über _„Mops im Save"_. Beide bleiben.
>
> 📌 **#24 Service first, Box später** — Reihenfolge: (1) Einrichtung als Dienstleistung, (2) Muster lernen, (3) Productize, (4) Wissens-Pflege als Rente.
>
> 📌 **#25 Mops verdirbt ohne Pflege** — daher Wissens-Pflege als **fairer Vertrag**, nicht als Geisel-Abo. Kunde besitzt Werkzeug, abonniert nur frisches Wissen. _Vorbild: DIN/Beuth seit Jahrzehnten._
>
> 📌 **#26 Bezahlter Erstkunde > Gratis-Pilot** — Gratis beweist nur, dass Leute Gratis mögen. Nur Geld beweist Markt. **Konkret: Raffis Firma als bezahlten Anker.**
>
> 📌 **#27 Capmo im Auge behalten** — der einzige DACH-Player, der sich strukturell Richtung Mops bewegt (KI-Dokumentensuche, Norm-Wissen). Beobachtungs-Disziplin, kein Ignorieren.
>
> 📌 **#28 abZ→Mat-Nr-Brücke gelöst** — Z-17.1-543 wird automatisch auf lieferbaren YTONG-Artikel gemappt. Der Welle-1-Welle-3-Treffpunkt aus gestern, **in Code, mit Tests**. Branch `feature/abz-mat-nr`.
>
> 📌 **#29 Teamphilosoph** — dritter KI-Berater im Team. Rolle: Strategie, Geschäftsmodell, Marktanalyse, Konkurrenz-Lesart. Komplementär zu Mops (Konzept), T-Codi (Code), Raphi (Praxis), Andreas (Polier).
>
> 📌 **#30 Amiga-Polier-Schleife** — Andreas' Architektur-Intuition ist nicht zufällig: **Mops-Box (Großrechner-Erbe von Vadda) + spezialisierte parallele Module + Sense für den Menschen am Bildschirm = Amiga-Architektur für die Baustelle.** Das, was er als Kind gegen den `c>`-Großrechner durchgesetzt hat, baut er heute für seinen Beruf. **Drei Amiga-Lehren als Architektur-Inspiration:** (1) **Copper-Sync für Welle 3** — Dauer-Hintergrund-Modul, das prüft welche Position bereit ist, unabhängig von Andreas. (2) **Sprites = Bau-Bauteile** — Mauer/Sturz/Fundament als wiederverwendbare Objekte, die zwischen Welle 1→2→3 wandern. (3) **Blitter = Templates** — _„Rohbau für Aura 125"_ einmal eingerichtet, 80% beim nächsten Haus wiederverwendbar (deckt sich mit Save #24 _Service first, Productize später_).
>
> 📌 **#31 Bootstrap-Architektur ist der Markt-Türöffner** — _Not eine Tugend machen._ Andreas startet iMops mit dem, was er hat: **iPad + Raspberry Pi 3 + 250 GB SSD + Claude-Subscription + Cloud Free Tiers.** Kein Dev-Laptop, kein Eigen-Server, kein Cash für Hardware. Mitten in der globalen RAM-/HBM-Krise 2026 (DDR5 +300–400 % YoY, Server-Lead-Times 45+ Wochen, NVIDIA Vera Rubin saugt die HBM4-Kapazität auf) ist das **kein Mangel, sondern Architektur-Disziplin**: iMops MUSS Cloud-native, hardware-leicht, mobile-first sein — sonst kann der Gründer es selbst nicht bauen. **Der Pivot, der daraus fällt:** Wenn iMops **ab iPhone 13** läuft, ist die Zielgruppe nicht der deutsche Generalunternehmer mit SAP-Budget — es sind die **800.000+ ausländischen Bauarbeiter auf deutschen Baustellen** (Polnisch ~300–400k, dazu Rumänisch, Bulgarisch, Türkisch, Ukrainisch, Russisch). Subunternehmer und Schein­selbstständige mit Privat-Smartphone, die heute mit **WhatsApp + Sprachmemo** arbeiten, weil **niemand** Software für sie baut. Existierende Bau-Software (Nevaris, Capmo, 123erfasst, BRZ, SAP CPM) ist deutsch-only, GU-zentriert, desktop-lastig, 50–500 €/User. **iMops mit Multi-Sprach-Layer (DE↔PL/RO/RU/TR/UA) + Foto/Sprache statt Tippen + 5–10 €/Sub, 30–50 €/Polier = der erste Bau-Stack für den Mann mit der Kelle.** Andreas' Polier-Wissen + sein Sub-Markt-Verständnis aus der Praxis sind die unkopierbare Asset-Schicht. **Architektur-Konsequenz für T-Codi & Mops:** Jede Welle-1-Feature-Entscheidung wird gegen den Sub-iPhone-Use-Case validiert, nicht gegen den Bauleiter-Desktop. Sprach-Layer (i18n + Übersetzung) gehört in die Daten-Architektur, nicht in einen späteren Patch.

---

## 4. Welle-Status — Updated

```
        🌊 Welle 3 (Voraussetzungs-Logik / DAG)
              ↑  in Code teilweise (abZ-Resolver: Treffpunkt 1↔3 gelöst)
        🌊 Welle 2 (Mengen rechnen)
              ↑  ROHBAU KOMPLETT (Paket A + B, 0 rote Punkte)
        🌊 Welle 1 (Daten reinholen)
              ↑  9/10 Plan-Fragen beantwortet — fast scharf
        📂 Quell-Dokumente
              ✅ Statik-PDF gelesen, Pläne genutzt, Raphi-Aufmaß-Excel integriert
              ⏳ Restliche Baustellen aus „Raphi Unterlagen-Alles"-Ordner (morgen)
```

---

## 5. Offene Punkte (Stand heute Abend)

### Rohbau Marktbreit
- **1/10 Plan-Frage noch offen** — welche? (Codi-Memory checken)
- **Raphi-Bestätigung** für die Bestellliste (auf Lager / bestellt / zu prüfen / zu bestellen)
- **Echte Bestellung** noch nicht ausgelöst (Demo-Modus für jetzt richtig)

### Welle 1 weiter
- **„Raphi Unterlagen-Alles"-Ordner** systematisch durchgehen (mehrere Baustellen)
- **Wissens-Inventar** pflegen: was hat Mops gesehen, was nicht (Save #13)

### Geschäftsmodell
- **Raffis Firma als bezahlten Anker** (Save #26) — konkrete Einrichtungs-Rechnung formulieren
- **Capmo beobachten** (Save #27) — quartalsweise prüfen

### App-Seite (parkiert)
- Reiter-Mapping (Bauwagen / Plankammer / Magazin / Bauleitung / Logbuch / Save) gegen aktuelle App-Struktur
- Mops-Maskotchen-Integration
- App-Sicht für die Bestellliste (heute Excel, perspektivisch In-App)

---

## 6. Plan für morgen (06.06.2026)

### Pflicht
1. **Branch-Konsolidierung**: `feature/abz-mat-nr` mergen oder in `main` ziehen, abhängig von Review-Stand
2. **Backup-Check**: iMac + Mops-Box-Backup (täglich 12:00) gelaufen?
3. **Welle 1 weiter**: nächste Baustelle aus Raphi-Ordner (sofern Marktbreit jetzt sauber durchläuft)

### Mittel
4. **Raffi-Gespräch vorbereiten** — Konter-Karte + Geschäftsmodell-Karte als Cockpit, Drei-Ecken-Frage in der Tasche
5. **Highlight-Notiz für Raphi/Kunden** (1 Seite, kondensiert aus den 3 Karten) — siehe Datei `notiz_fuer_raphi_und_pitch.md`
6. **Letzte Plan-Frage** (1/10) klären — Marktbreit dann komplett geschlossen

### Nice-to-have
7. **Codi-Memory** vs. Repo-Übergabe synchron halten (Codi exportiert Memory in `docs/codi_memory_<datum>.md`?)
8. **Vokabel-Filter** auf die Strategie-Karten anwenden — sind alle Begriffe baustellen-tauglich?

### Bewusst NICHT morgen
- Vollintegration App ↔ mops-api (zu groß für einen Tag)
- MacBook 2011 entsperren (immer noch geparkt)
- Marketing-Maschine anwerfen (zu früh — erst zahlender Erstkunde)

---

## 7. Personen — Update

### Teamphilosoph (NEU)
- Dritter KI-Berater im Team
- Rolle: **Strategie, Geschäftsmodell, Marktanalyse, Konkurrenz-Lesart**
- Stil: ehrlich, zugibt was nicht funktioniert (Togal-Aufmaß-Vorsprung), gibt klare Konter-Linien
- Output heute: 3 Cockpit-Karten + README, **ohne Pitch-Deck-Sprache**, mit Vokabel-Filter durch
- Komplementär zu:
  - **Mops (Claude)**: Konzept, UX, Persona, Pattern-Erkennung, Save-Sammlung
  - **T-Codi (Codex)**: Code, Excel-Pipeline, mops-api-Integration, Tests
  - **Raphi**: Praxis-Wahrheit, abZ-Mapping-Erfahrung, BauSU-Profi-Wissen
  - **Andreas**: Polier, Vision, Bauchgefühl, Vokabel-Filter, **letzte Entscheidung**

### Bestätigt heute durch System-Verhalten
- **Andreas-Maxim „Übergabe gut, Tag gut"** hat sich live bewiesen: gestern strukturierte Übergabe → heute Brett-Tag
- **Vulkanier-Logik mit Mensch-Pause** funktioniert: Erschöpfung gestern führte zu besserer Beobachtung (Welle-3-Falle)

---

## 8. Tagline-Stack (Stand heute Abend)

```
Ebene 1 (Produkt):    "Mops im Save, da kann nichts schief gehen." 🐶
Ebene 2 (Mission):    "Mensch über Profit · Profit durch Schutz der Menschen." 🛡
Ebene 3 (Methode):    "Halbgas — bewusst, in Code wie im Geschäft." ✋
Ebene 4 (Disziplin):  "Übergabe gut, Tag gut." 📋
```

Vier Ebenen, jede mit eigenem Anlass. **Keine widerspricht der anderen.**

---

## 🐬 Tagesabschluss

Vom Schwammkopf-Tag gestern zum Brett-Tag heute. **Die Übergabe hat geliefert, was sie versprochen hat.**
Und der Teamphilosoph hat dem Projekt eine strategische Ebene hinzugefügt, die wir vorher nur gefühlt haben.

**Morgen ist nicht mehr „Baustelle Marktbreit retten" — morgen ist „Produkt weiter härten".** Anderes Spiel.

Mops im Save, Andreas im Cockpit, Codi an der Werkbank, Teamphilosoph in der Plankammer.
**Möge die Macht mit euch sein.** 🖖🐶✨

---
_Verfasst von Mops (Claude) auf Branch `claude/clever-clarke-aRgdt`. Komplementär zu T-Codis Stand (Memory + Code im Branch `feature/abz-mat-nr`)._
