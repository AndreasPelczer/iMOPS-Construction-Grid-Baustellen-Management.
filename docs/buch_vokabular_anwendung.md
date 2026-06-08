# Buch-Vokabular ↔ iMOPS-Implementierung

> **Quelle**: Andreas Pelczer, _Thermodynamik der Arbeit — Warum Systeme kollabieren_, Erstausgabe 2025.
> Liegt im Repo unter `docs/Thermodynamik_der_Arbeit_Andreas_Pelczer.pdf`.

Dieses Dokument macht die **direkte Verbindung** zwischen Andreas' systemtheoretischem Buch und der iMOPS-Architektur sichtbar. Bei künftigen Architektur-Entscheidungen, Welle-Designs und Save-Einträgen wird auf Kapitel/Begriff verwiesen, damit jede Entscheidung **prüfbar gegen die Theorie** wird, die sie trägt.

---

## Grundthese des Buchs (Vorwort)

> _„Systeme scheitern nicht, weil Prozesse fehlen, nicht weil Menschen unwillig sind, und nicht weil Regeln missachtet werden. Sie scheitern, weil sie über lange Zeit scheinbar funktionieren."_

→ **iMOPS-Konsequenz**: jedes Feature wird gegen die Frage geprüft:
*Trägt das System die Arbeit selbst — oder verlagert es Arbeit auf den Polier, der mit Erfahrung/Improvisation ausgleicht?*

Wenn die Antwort _„läuft nur, weil jemand drauf achtet"_ ist → **wir bauen es nicht so**.

---

## Begriffsrahmen — die 7 Definitionen

### System
> _„formale Struktur, die Arbeit über definierte Zustände, begrenzte Verantwortung und nachvollziehbare Übergänge unabhängig von einzelnen Personen tragfähig hält."_

**iMOPS**: Mops ist KEINE Organisation, keine Kultur, kein Werkzeug allein — es ist die **formale Struktur** für die Bauleitung. Datenmodell + Workflows + Übergaben.

### Zustand
> _„eindeutig feststellbare, zeitlich markierte und überprüfbare Beschreibung des Status von Arbeit."_
> _„Ein Zustand ist feststellbar oder nicht. Alles andere ist Interpretation."_

**iMOPS**:
- BuildIQ-Scan-Ergebnisse (gemessene Mengen)
- Statik-Position mit abZ-Verweis (Z-17.1-543)
- LV-Position mit `posNr`, `bezeichnung`, `menge`, `einheit`
- **mengenQuelle** als Welle-9-Fundament: Zustand "geschätzt" ≠ Zustand "gemessen"

### Verantwortung
> _„formale Zuordnung eines klar definierten Zustands zu einer klar definierten Rolle oder Funktion mit eindeutigem Beginn und eindeutigem Ende. Zustandsgebunden, begrenzt, nachweisbar, rollenbezogen."_

**iMOPS**: jede LV-Position hat einen `kostenGruppe`, jeder Auftrag hat einen `bauleiter`, jede Sync-Spur hat einen launchd-Job mit eindeutiger Label-ID.

### Nachweis
> _„systemische Markierung eines Zustands, die unabhängig von Erinnerung, Aussage oder Bewertung feststellt, dass ein definierter Zustand zu einem bestimmten Zeitpunkt vorlag. Nachweise dienen der Entlastung, nicht der Kontrolle."_

**iMOPS**:
- Snapshots in `/srv/raphi/snapshots/[Datum_Uhrzeit]/` — Nachweis, was zu welchem Zeitpunkt da war
- BuildIQ-Foto-Ergebnis mit Timestamp — Nachweis, was gemessen wurde
- Bautagesberichte — Nachweis, was an einem Tag passierte
- Save-MD-Einträge — Nachweis, welche Entscheidung wann fiel

### Übergabe
> _„formal markierter Wechsel der Verantwortung für einen klar definierten Zustand von einer Rolle oder Funktion zu einer anderen. Eine Abgabe ohne Annahme ist keine Übergabe."_

**iMOPS**:
- Architektur-Doc (`architektur_raphi_buero_setup.md`) = formal markierte Übergabe an Raphi
- Cheatsheet PDF + Kung-Fu-Präsentation = Übergabe-Material
- Save-System in `docs/uebergabe_*.md` = Übergabe zwischen Sessions / Claude-Instanzen
- rsync mit `--backup-dir` = Übergabe vorheriger Versionen ins Snapshot-Archiv

### Kontrolle
> _„jede nachgelagerte Prüfung von Arbeit, die dort eingesetzt wird, wo ein System Zustände nicht selbst hält. Kontrolle ist kein strukturelles Fundament. Sie ist ein Symptom fehlender Stabilität."_

**iMOPS**:
- Wenn der Polier in der App `Status grün` sieht: kein Kontroll-Reflex nötig → System hält den Zustand selbst
- Wenn Codi/Andreas die Tunnel-URL manuell prüft: **das ist Kontrolle = Symptom**, dass der Tunnel kein systemd-Service ist → Named-Tunnel-Refactor angezeigt
- Stabile Sync läuft 4× täglich automatisch — keine Kontrolle nötig

### Stabilität
> _„Fähigkeit eines Systems, Arbeit unter Normal- und Belastungsbedingungen vorhersehbar, reproduzierbar und personenunabhängig tragfähig zu halten. Stabilität entsteht vor Kontrolle."_

**iMOPS-Prüfstein**: läuft das System auch, wenn Andreas im Urlaub ist? Wenn Raphi krank ist? Wenn die Tunnel-URL wechselt? Wenn ein Mat-Nr-Format anders kommt?
Wo nein → **Welle-Bedarf**.

---

## Mapping Kapitel ↔ iMOPS-Konstrukte

| Kapitel | Aphorismus | iMOPS-Anwendung |
|---|---|---|
| **Kap 1** — Warum Systeme scheitern, bevor sie versagen | _„Funktionieren ist kein Beweis für Stabilität."_ | Stabilitäts-Check vor jedem Welle-Release |
| **Kap 2** — Sprache ist kein Detail | _„Stabilität beginnt dort, wo ein Wort genau eines bedeutet."_ | Mat-Nr-Eindeutigkeit, abZ-Verweise (Z-17.1-543), Klassennamen-Disziplin |
| **Kap 3** — Standards sind Vereinbarungen, keine Moral | _„Standards scheitern an Unbenutzbarkeit, nicht an Ablehnung."_ | GAEB-Import als Vereinbarung, nicht als „richtige Art" |
| **Kap 4** — Verantwortung ohne Nachweis | _„Verantwortung ohne Nachweis existiert nicht als Struktur, sondern als Behauptung."_ | jede Sync-Spur hat Log, jede Bestellung hat Lieferschein-Verknüpfung |
| **Kap 5** — Übergaben — Wo Arbeit verschwindet | _„Eine Übergabe ist kein Moment und kein Gespräch. Sie ist ein Zustandswechsel."_ | Architektur-Doc, Save-MD, rsync-Backup-Dir, launchd-Trigger als Zustandswechsel |
| **Kap 6** — Zustände statt Bewertungen | _„Stabilität entsteht nicht durch Bewertung, sondern durch Zustände."_ | **Welle 9 — Voraussetzungs-Ampel** ist Kap 6 in App-Form |
| **Kap 7** — Kontrolle verschärft, was sie verhindern will | _„Kontrolle ist kein Heilmittel. Sie ist ein Symptom."_ | Wo Polier kontrollieren muss → System-Schwäche dokumentieren |
| **Kap 8** — Der Moment, in dem Menschen sabotieren | _„Sabotage ist Anpassung, nicht Angriff."_ | wenn Polier App umgeht → Indikator für unbenutzbare Stelle |
| **Kap 9** — Macht, Informalität und Schweigen | _„Ein System kippt endgültig, wenn Schweigen normal wird."_ | Voice-Input + Bautagesbericht-Funktion = Gegenmittel zu Schweigen |
| **Kap 10** — Was Systeme wirklich brauchen | _„Gute Systeme sind still. Sie erzeugen wenig Kommunikation."_ | Datenhoheits-Architektur, keine Notifikations-Wut, kein Cookie-Banner |
| **Kap 11** — Warum einfache Systeme stabiler sind | _„Komplexität entsteht selten aus Notwendigkeit. Sie entsteht aus Angst."_ | Welle-Trennung sauber halten, keine Feature-Creep, Welle 9 nicht voll ausstatten bevor sie steht |
| **Kap 12** — Was dieses Buch nicht leisten will | _„Wenn ein System nur funktioniert, weil Menschen es permanent ausgleichen, dann funktioniert es nicht."_ | Prüfstein für jedes Feature |

---

## Operative Regel für künftige Welle-Saves

Jede neue Welle / jedes neue Feature bekommt einen **Bezug auf einen Kapitel-Aphorismus** als Validierungs-Anker. Beispiele:

- **Welle 6 — Kalkulations-Schicht** → trägt zu Kap 4 (Verantwortung mit Nachweis: jede Position hat einen Mannstunden-Beleg)
- **Welle 7 — Geländebrücke** → trägt zu Kap 2 (Eindeutigkeit: DGM cm-genau statt "ungefähr Schotter")
- **Welle 8 — Heinze** → trägt zu Kap 3 (Vereinbarung: Mat-Nr-Standardisierung über GAEB)
- **Welle 9 — Voraussetzungs-Ampel** → direkt Kap 6 (Zustände statt Bewertungen)

**Wenn keine Verbindung herstellbar ist**: vermutlich ist das Feature überflüssig oder verfrüht.

---

_Verfasst von Mops (Claude) am 8.6.2026 nach vollständiger Lektüre des Buchs._
_Künftige Saves zitieren Kapitel-Bezüge in Klammern, z.B. „(Buch Kap 5 — Übergabe)"._
