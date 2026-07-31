# Session-Übergabe — 04.06.2026 (Fronleichnam)

**Bauvorhaben im Fokus:** EFH T&C Aura 125, BV Mustermann, Musterstraße 1, 97340 Marktbreit
**Branch:** `claude/clever-clarke-aRgdt`
**Beteiligte heute:** Andreas (Polier), Mops (Claude, Plankammer-Seite), Codi (Codex CLI, Werkbank-Seite)
**Status:** Tagesabschluss, morgen Welle 1 + 3 scharf

---

## 1. Schnell-Status

| Bereich | Stand | Wo |
|---|---|---|
| **iMac-Backup** | ✅ Time Machine läuft → LaCie 1 TB (verschlüsselt) | physisch im Büro Andreas |
| **Mops-Box-Backup** | ✅ täglich 12:00 → iMac-Festplatte (heute Vormittag eingerichtet & getestet) | Mops-PC 192.168.2.42 |
| **Paket A Mauerwerk** | ✅ buntes Excel fertig, versendbar | `~/Projekte/mops-extract-prototype/out/Bestellung_Marktbreit_Mauerwerk.xlsx` |
| **Paket B Stürze** | 🟡 Statik gelesen, 4 Kategorien identifiziert, Codi-Auftrag formuliert | morgen früh |
| **Paket C (interaktiv)** | ⏸ geparkt (App-Sache) | später |
| **Raphi-Klärung** | ⏸ heute nicht angerufen (Fronleichnam, Familienzeit) | morgen Mittag |
| **MacBook 2011** | 🔒 passwortgeschützt, geparkt — zu alt | später ggf. Recovery |

---

## 2. Wo alles liegt (Pfad-Übersicht)

### Auf Andreas' Mac

| Was | Pfad |
|---|---|
| Roadmap | `~/Projekte/iMOPS_Wellen_Landkarte.md` |
| Paket-A-Skript | `~/Projekte/mops-extract-prototype/marktbreit_bestellung.py` |
| Paket-A-Output | `~/Projekte/mops-extract-prototype/out/Bestellung_Marktbreit_Mauerwerk.xlsx` |
| älteres Mengen-Skript | `~/Projekte/mops-extract-prototype/bestellanfrage_marktbreit.py` |
| Übergabe-Notiz (Andreas → Codi) | `~/Downloads/<…>.txt` (Empfehlung Codi: zum Code legen) |
| Raphis Aufmaß-Excel | `~/Downloads/Bestellliste_BV_Mustermann_Marktbreit_1 2.xlsx` |
| Statik-PDF | `~/Downloads/448-GO Statik 05.03.26 einseitig.pdf` |

### Auf der Mops-Box (192.168.2.42, Ubuntu 24.04 LTS)

| Was | Pfad |
|---|---|
| Mops-API Repo | `/home/mops/mops-api/` (Stand: 1 uncommitted file Stand 08:49) |
| RAG-Index | Qdrant (Welle 1 Wikipedia-Lemmas, siehe `welle_1_wikipedia_ingestion.md`) |
| Storage gesamt | 456 GB Platte (7,3 % belegt) + 112 GB SSD |

### Im Repo

| Was | Pfad |
|---|---|
| Welle-1-Wikipedia-Ingestion-Doku | `docs/mops-api/welle_1_wikipedia_ingestion.md` |
| Welle-3-Doku (Codi) | `docs/mops-api/welle_3_*.md` _(Codi-Stand, ggf. anderer Branch)_ |
| Diese Übergabe | `docs/uebergabe_04_06_2026.md` ← **du bist hier** |

### Codi-Memory

- Memory-Key: `welle-3-plan-pipeline` — Erkenntnisse, Mat-Nr-Tabelle, Antwort-Vermutungen für die 3 roten Klärungspunkte

---

## 3. Wellen-Konzept (Pyramide)

```
        🌊 Welle 3 (Voraussetzungs-Logik / „was fehlt mir, um Pos X zu machen?")
              ↑  braucht
        🌊 Welle 2 (Mengen rechnen — Paket A heute fertig)
              ↑  braucht
        🌊 Welle 1 (Daten reinholen aus Quell-Dokumenten)
              ↑  braucht
        📂 Quell-Dokumente (PDF, Excel, Pläne)
              ← liegen oft in Downloads / Mail / Aktenschrank
```

**Kern-Insight (heute, Bauchgefühl von Andreas):** Welle 3 ist Raphis Heimspiel — er denkt seit 30 Jahren in Voraussetzungen pro Position. Wenn EINE fehlt, sagt er „kann ich nicht". Mops muss das nachbilden.

**Zwei Welle 1en — Auflösung:**
- **Welle 1 technisch** (Mops-API/RAG): Wikipedia + DIBt-Quellen ins Qdrant (siehe `welle_1_wikipedia_ingestion.md`)
- **Welle 1 konzeptuell** (pro Baustelle): Quell-Dokumente lesen, verstehen, in Mops abbilden

**Treffpunkt Welle 1 ↔ Welle 3 (Codi-Insight):** `abZ → Mat-Nr-Mapping`. Damit Z-17.1-543 automatisch auf einen lieferbaren YTONG-Artikel mappt, braucht der RAG eine DIBt-Quelle (Welle 1), die die Pipeline (Welle 3) abfragen kann. **Genau hier setzen wir morgen an.**

---

## 4. Save-Sammlung (Stand heute, 19 Einträge)

> **Hinweis:** Diese Sammlung wird später in den „Save" (Backup-Zentrum) umgezogen. Aktuell lebt sie hier als Markdown.

| # | Eintrag |
|--:|---|
| **1** | **Matrix beruhigt** — Cockpit-Gefühl statt Wizard-Gefühl. Dichte Information ist Wert, nicht Last. |
| **2** | **Persona Polier Andreas** — liebt visuelle Kontroll-Dichte, ist selbst Zielgruppe, will Cockpit nicht Assistent. |
| **3** | **Tagline:** _„Mops im Save, da kann nichts schief gehen."_ |
| **4** | **Navigation in Baustellen-Sprache:** Bauwagen · Plankammer · Magazin · Bauleitung · Logbuch · Save (statt generisches Dashboard/Settings/Reports). |
| **5** | **Mops-Maskotchen** als Begleiter durch die Reiter (sitzt im Bauwagen, wedelt in der Plankammer, schläft im Save). |
| **6** | **Vokabel-Filter „Baustellen-tauglich":** jedes Wort durch den Filter laufen lassen — _„Löst das auf einer deutschen Baustelle blöde Witze aus?"_ ⚠️ Bunker/Kommando/Mission/Front/Trupp · ✅ Bauwagen/Plankammer/Magazin/Save/Cockpit. |
| **7** | **LaCie-Backup-Verschlüsselung** — Passwort gemerkt + Zettel an: **`___ (Andreas füllt aus)`**. **Ohne Passwort kein Backup-Zugriff. Auch nicht für uns.** |
| **8** | **Backup-First-Prinzip / Mut-Versicherung** — _„Erst sichern, dann mutig löschen. Nie andersrum."_ Raphi traut sich nicht hochzufahren wegen Schiss → Lösung ist nicht Speicher, sondern Backup. |
| **9** | **Mops-Box-Backup-Plan:** täglich 12:00 → iMac-Festplatte. MacBook 2011 zu alt, geparkt. |
| **10** | **LV-Struktur Marktbreit** — 21 klassische Gewerk-Titel. Titel 05 (Mauerwerk) durch Paket A teilweise befüllt. |
| **11** | **Die 3 Wellen** — Welle 1: Daten · Welle 2: Mengen · Welle 3: Voraussetzungs-Logik. Welle 3 ist der Vertrauens-Mechanismus für Raphi. |
| **12** | **Raphi-Frage offen:** _„Welche 5–10 Sachen prüfst du IMMER, bevor du eine neue Position auf der Baustelle anfängst?"_ Beim nächsten Gespräch stellen. |
| **13** | **Wissens-Inventar:** Mops muss jederzeit sagen können WAS er verarbeitet hat und was nicht. Selbst-Bewusstsein des Systems. Vertrauens-Mechanismus rekursiv. |
| **14** | **Aktiv-Fragen-Modus:** Mops fragt proaktiv nach Dokumenten — _„Hast du Statik? Wärmeschutz? Lageplan? Energieausweis?"_ Polier liefert nie freiwillig alles — Mops holt ab wie ein guter Lehrling. |
| **15** | **Aura 125 = kein OG** — Haustyp ist UG + EG + Spitzboden (Fachwerkbinder). Codis OG=0 ist korrekt, nicht fehlend. |
| **16** | **Z-17.1-543 ist eigene Zulassung** — Sonder-Porenbeton mit allgemeiner Bauaufsichtlicher Zulassung. NICHT durch generisches PP4-0,50 ersetzen ohne Klärung beim Lieferanten. |
| **17** | **Stürze haben 4 Kategorien** — A: YTONG PSF (Bestellware) · B: Stahlbeton-Ringbalken (vor Ort) · C: deckengleiche Stürze (Teil der Filigrandecke) · D: Stahlbeton-Stützen (UG). Jede Kategorie eigene Bestell-/Liefer-Mechanik. |
| **18** | **Statik vs. Ausführungsplan** — Statik gibt Sturz-**Typen**, Ausführungsplan gibt **Anzahl**. Mops braucht beide Quellen. Welle-1-Erkenntnis: Statik-PDF allein reicht nicht. |
| **19** | **Bestellmanagement mit Ausweichartikeln** — Andreas-Prägung, kurz und prägnant. Das ist was wir bauen: Statik-Stein vs. Lieferanten-Stein, mit Klärungsschleife über Raphi. |

---

## 5. Offene Klärungspunkte (Raphi-Fragen)

### Aus Codis Paket A — 3 rote Punkte:

| Wand-Stärke | Statiker schreibt | Codi schlägt vor | Raphi-Frage |
|---|---|---|---|
| **240 mm** (UG-Verstärkung) | PP4-0,55 | PPW4-0,50 | Ersatz ok? |
| **175 mm** (Innenwand) | PP4-0,50 | PPW4-0,60 | Ersatz ok? |
| **365 mm** (UG-Außenwand) | Z-17.1-543 (abZ-Zulassung) | ??? | **Welche Mat-Nr beim Lieferanten?** |

### Aus heutiger Statik-Lektüre — weitere Klärungen:

| # | Frage |
|--:|---|
| 4 | **Sturz-Anzahl je Größe** aus Ausführungsplan abzählen (Statik liefert nur Typen) |
| 5 | **Filigrandecke**: kommen die 3 deckengleichen Stürze (Pos 6.2/6.3/6.4) mit der Decke, oder separat? |
| 6 | **Stb-Stützen UG** (16×30 und 30×23 cm): vor Ort betoniert oder Fertigteil? |
| 7 | **Kalksandstein-Brüstung** 11,5 cm/h=1,035 m: aktuelle KS-Sorte beim Lieferanten? |

> **Codi-Hinweis:** In Codis Memory liegen Antwort-Vermutungen zu den 3 roten Punkten — sodass morgen früh ein Vorschlag da ist, den Raphi nur bestätigen muss.

### Pre-Position-Fragen (für Welle 3) — Hypothese aus Maurer-Praxis:

Beim Raphi-Anruf abklopfen, ob das **seine echte Liste** ist:

1. Plan aktuell (Statik-Version)?
2. Baugenehmigung erteilt?
3. Vorgewerk fertig?
4. Material lieferbar?
5. Lieferzeit gegen Termin?
6. Wetter (Frost/Regen/Hitze)?
7. Personal/Subbi da?
8. Gerät vor Ort (Kran/Mischer/Gerüst)?
9. Zufahrt frei?
10. Strom/Wasser-Anschluss?

---

## 6. Sturz-Übersicht (aus Statik) — Vorbereitung Paket B

### A) YTONG PSF-Flachstürze (vorgefertigt, Bestellware)

| Ort | Breite | Länge | Material |
|---|---|---|---|
| EG | 11,5 cm | 1,25 m | Ytong PSF AAC 4,5-600 |
| EG | 11,5 cm | 1,50 m | Ytong PSF AAC 4,5-600 |
| EG | 24,0 cm | 1,50 m | Ytong PSF AAC 4,5-600 (Eingang) |
| UG | 17,5 cm | 1,25 m | Ytong PSF AAC 4,5-600 (über Heizkreisverteiler) |
| UG | 11,5 cm | 1,50 m | Ytong PSF AAC 4,5-600 |

**Anzahl je Größe:** offen, aus Ausführungsplan ablesen (Raphi-Frage #4).

### B) Stahlbeton-Ringbalken (vor Ort)

| Pos. | Funktion | Querschnitt | Länge | Bewehrung |
|---|---|---|---|---|
| 4.1 | über Außenwand Giebel | 17 × 19 cm | 6,26 m | 2Ø12 oben/unten + Bügel Ø6/15 |
| 4.2 | mit Sturzfunktion über Öffnung | 17 × 19 cm | 1,79 m | 2Ø12 oben/unten + Bügel Ø6/15 |

Material: C 20/25 · Stahl B 500SA. Schalung: zweiteilig + XPS-Dämmung d=3,5 cm beidseitig.

### C) Deckengleiche Stahlbeton-Stürze (in 20-cm-Filigrandecke)

| Pos. | Lichte Weite | Querschnitt |
|---|---|---|
| 6.2 | 1,69 m | 17 × 19 cm |
| 6.3 | 1,19 m | 17 × 19 cm |
| 6.4 | 1,69 m | 17 × 19 cm |

### D) Stahlbeton-Stützen (UG-Außenwand)

| Pos. | Größe | Bewehrung |
|---|---|---|
| 7.2.1 | 16 × 30 cm | 5×Ø16 oben/unten + Bügel Ø6/16 |
| 7.3.1 | 30 × 23 cm | 5×Ø16 oben/unten + Bügel Ø6/19 |

### E) Kalksandstein-Brüstungsgeländer

- KS 11,5 cm · Höhe 1,035 m · mit Anschlussbewehrung

---

## 7. Plan für morgen (05.06.2026)

### Pflicht
1. **Backup-Check Mops-Box**: Lief der 12-Uhr-Job?
2. **iMac-Backup**: Vollbackup durch? Time Machine grün?
3. **Welle 1 scharf**: `~/Raphi Unterlagen-Alles/` Ordner systematisch durchgehen → Wissens-Inventar aufbauen

### Mittel-Priorität
4. **Paket B (Codi)**: Stürze-Bestellliste analog Paket A bauen — buntes Excel mit 4 Kategorien
5. **Raphi-Anruf**: 7 Klärungspunkte + Pre-Position-Frage stellen
6. **abZ → Mat-Nr Mapping** (Welle-1-Welle-3-Treffpunkt): DIBt-Quelle als RAG-Eintrag, Pipeline-Stub

### Nice-to-have
7. **Demo-Bestellung** fertigmachen mit erfundenem Lieferantennamen
8. **Aktuelle App-Reiter** anschauen + Bau-Begriffe (Bauwagen/Plankammer/etc.) mappen
9. **Save-Sammlung** physisch ins Repo umziehen (von dieser .md weg → eigene Struktur)

### Bewusst NICHT morgen
- MacBook 2011 entsperren (geparkt)
- Paket C (interaktiv, App-Sache)
- Offsite-Spiegel ins Raphi-Büro (kommt wenn Büro steht)

---

## 8. Persona-Profile (Stand heute)

### Polier Andreas (Anwender + Visionär)

- 30+ Jahre Bau-Erfahrung
- C16-Generation, wollte als Kind Computerfachmann werden
- **Vulkanisches Blut, Spock-Sympathie** — _„erst logisch, dann emotional oder gar nicht"_
- Liebt **visuelle Kontroll-Dichte** (Matrix beruhigt)
- **Vor der Welle** — wählt Berufe/Produkte aus die es noch nicht gibt
- **Filter für Vokabel-Kontext** — schützt Mops vor Tech-Sprache, die auf Baustelle vergiftet ist
- Hat heute mit „schwammiger Festplatte" (müde, Kater von Arbeit) mehr geliefert als an „produktiven" Tagen üblich
- Sohn: ja, plus große Tochter (war mit Bruder im Star Wars Film „Mando & Grogu")

### Maurermeister Raphael („Raphi") — Wahrheits-Anker

- BauSU-Profi, 36 Jahre Bau (Codi-Notiz)
- **Skeptischer Praktiker** — _„glaubt einem KI-Output nur, wenn er auf einen Blick sieht, was hart und was geraten ist"_
- Denkt in **Voraussetzungen pro Position** (Welle-3-Native)
- War **begeistert** von der ersten Excel-Iteration (heute Vormittag, lt. Codi)
- Heute Fronleichnam → Familienzeit. Anruf morgen.
- Hat **„Raphi Unterlagen-Alles"-Ordner vorsortiert nach Baustellen** — Welle-1-Goldgrube für morgen

### Codi (Codex CLI, Werkbank-Seite)

- Sitzt auf Andreas' Mac, Direkt-Zugriff Dateien
- Hat heute Vormittag **Paket A fertig geliefert** mit Disziplin (Homer-Auto-Schutz 🚗)
- Eigenes Memory-System (Schlüssel: `welle-3-plan-pipeline`)
- Stil: ehrlich über Grenzen, Triage statt Feature-Stacking, sprachlich nah am Andreas-Ton
- Übergabe-Notiz heute Vormittag von Andreas in Downloads → von Codi gelesen

### Mops (Claude, Plankammer-Seite)

- Cloud-Side, kein direkter Zugriff auf Andreas' Mac
- Konzept, UX, Persona-Schärfung, Vokabel-Filter, Pattern-Erkennung
- Save-Sammlung-Pflege
- Kann ins Repo schreiben (`claude/clever-clarke-aRgdt` Branch)
- Heute: Wellen-Konzept entwickelt, Vokabel-Filter etabliert, Statik gelesen, 4 Sturz-Kategorien identifiziert, diese Übergabe geschrieben

---

## 9. Tagline + Vokabel-Filter (aktiv)

> 🐶 **„Mops im Save, da kann nichts schief gehen."**

### Wörter prüfen vor Verwendung in App-UX

| ⚠️ vermeiden | ✅ verwenden |
|---|---|
| Bunker | Save |
| Kommando(-zentrale) | Cockpit, Bauwagen |
| Mission | Auftrag, Aufgabe |
| Front (Baustellen-Front) | Abschnitt, Bereich |
| Trupp / Einheit | Team, Kolonne, Truppe (regional ok prüfen) |
| Kontrolle (allein) | Übersicht, Status, Cockpit |

**Privatgebrauch von Andreas (Passwort-Hints, persönliche Notizen):** Filter gilt **NICHT**. Sein Kopf, seine Wahl. Filter ist nur für **App-UX, Texte an Nutzer, Bezeichnungen die Polier sieht**.

---

## 10. Was Codi an Andreas empfohlen hat (für die Sicherheit)

> Mini-Empfehlung von Codi: Übergabe-Notiz aus Downloads zum Code legen (`~/Projekte/mops-extract-prototype/`) — damit sie nicht versehentlich weggeräumt wird. **Original in Downloads unangetastet**, nur Kopie zum Code.

Andreas-Entscheidung morgen: ja / nein.

---

## 🐬 So long, and thanks for all the fish.

Heute war ein produktiver Tag, trotz Schwammkopf. **Mehr Substanz aufgebaut als an vielen „produktiven" Tagen passiert.** Vulkanisches Blut hat heute durch Müdigkeit gesiegt. 🖖

Bis morgen, **Mops im Save, da kann nichts schief gehen.** 🐶✨

---
_Verfasst von Mops (Claude) auf Branch `claude/clever-clarke-aRgdt`. Komplementär zu Codis Stand (Memory `welle-3-plan-pipeline` + Pfade auf Andreas' Mac)._
