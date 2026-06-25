# Übergabe und Langzeitprotokoll — 24. Juni 2026

> Stand: Mittwochabend, 24.06.2026. App-Build grün, Server läuft, Mops ist über feste Tunnel-Struktur erreichbar. Heute war kein einzelnes Feature, sondern ein großer Ordnungstag mit mehreren Baustellen.

---

## 1. Zustand am Ende des Tages

### iMOPS-App

- Lokaler Xcode-Build ist grün.
- Unit-Tests liefen erfolgreich.
- CoreData wurde heute nicht migriert.
- Neue Logik wurde bewusst als lokale, rückbaubare Schichten ergänzt.
- Aktuelle Arbeit ist lokal vorhanden, aber noch nicht committed/gepusht.

### Mops-Server / Backend

- `mops-api` läuft auf der Mops-Box.
- Health-Check funktioniert.
- Cloudflare-Tunnel wurde auf eine dauerhafte Struktur umgestellt.
- `mops.baumops.com` zeigt die Matrix-/Kontrollzentrum-Ansicht.
- `mops.baumops.com/health` erreicht die Mops-API.

### Baumops-Domain

- `baumops.com` wurde gekauft und in Cloudflare sichtbar.
- Hauptdomain soll einfache Landingpage bleiben.
- Subdomain `mops.baumops.com` ist für Matrix/Kontrollzentrum/Mops-Zugriff gedacht.
- Landingpage wurde bewusst schlicht gehalten: Baumops ist da, lokale Baustellenintelligenz, Poster/Regeln als Signale.

---

## 2. Heute erledigte Baustellen

### A. Tunnel und Erreichbarkeit

Ziel war: nicht mehr jeden Tag eine neue Tunnel-URL verschicken.

Ergebnis:

- Cloudflare-Zertifikat/Zone für Tunnel vorbereitet.
- Tunnel als systemd-Service festgenagelt.
- Server kommt nach Neustart automatisch wieder.
- Mops kann über feste Adresse angesprochen werden.

Noch wichtig:

- Falls die Domain-/DNS-Seite spinnt, zuerst Cloudflare DNS prüfen.
- `baumops.com` und `mops.baumops.com` haben bewusst unterschiedliche Rollen.

### B. Baumops-Webseite

Ziel war: die Domain soll nicht leer wirken.

Ergebnis:

- `baumops.com` bekommt eine einfache Landingpage.
- `mops.baumops.com` bleibt die Matrix-/Kontrollzentrum-Seite.
- Idee besprochen: Mops-Maskottchen/App-Icon sparsam einsetzen, nicht als Spielerei. Der Mops darf als Sympathieanker da sein, aber die Seite soll nicht kindisch wirken.

Offen:

- Poster und Lieferkreislauf-PDF noch sinnvoll einordnen.
- Die fünf Regeln neben dem Claim platzieren:
  - Baumops ist da.
  - Lokale Baustellenintelligenz für Nachweise, Lieferketten und Arbeit, die nicht mehr jeden Morgen neu zusammengeflickt werden muss.

### C. App-Server-Adresse fest eingebaut

Ziel war: App soll nicht ständig manuell mit wechselnder Tunnel-URL gefüttert werden.

Ergebnis:

- App kann den festen Mops-Endpunkt verwenden.
- Server läuft, App läuft mit Server.
- Nutzung ist jetzt grundsätzlich überall möglich, wo Internet/WLAN vorhanden ist, solange Tunnel und Server aktiv sind.

### D. Bauwissen / Prof / Mops-Avatare

Ziel war: Der Hund im Bauwissen/Prof-Bereich soll durch die neuen Mops-/Prof-Mops-Bilder ersetzt oder ergänzt werden.

Ergebnis:

- Neue Icons/Avatare für Baustellenmops und Professor-Mops wurden gefunden/eingebunden.
- App-Änderungen wurden lokal getestet und als schön bestätigt.

Offen:

- Bild-/Poster-Ordnung für Doku und Webseite sauber festlegen.

### E. LV-Sheets auf volle Größe

Ziel war: LV-nahe Sheets sind auf dem Mac/Laptop zu klein.

Ergebnis:

- LV-nahe Funktionen wurden auf Fullscreen-Verhalten umgestellt bzw. überprüft.
- Bestellliste, Angebotsvergleich, Kostenzusammenfassung und Import-/Baustein-Flows sollen auf großen Screens besser nutzbar sein.

### F. Lieferantenmodul

Ziel der letzten Runde war: aus der Bestellliste ein echtes Baustellen-Kommunikationswerkzeug machen.

Ergebnis:

- Bestellliste wurde groß und nutzbar gemacht.
- Lieferstatus-Ampel ist sichtbar.
- Mail-/Text-Flow funktioniert.
- Erste echte Test-Mail ging raus.
- PDF-/Text-Generator-Ansatz wurde bestätigt: iMOPS bereitet vor, Mensch sendet.

Architekturregel bleibt:

- Kein automatisches Bestellen.
- Kein unsichtbarer Versand.
- Polier/Bauleiter entscheidet.

### G. Angebotsvergleich und Kostenzusammenfassung

Ziel war: klären, was diese LV-Menüpunkte können sollen.

Ergebnis:

- Angebotsvergleich soll langfristig nicht nur Liste sein, sondern Entscheidungsfläche:
  - Anbieter vergleichen
  - Positionen/Preise gegenüberstellen
  - Alternativen sichtbar machen
  - später eingehende Angebote aus Mails vorbereiten
- Kostenzusammenfassung bleibt Controlling-/Übersichtsfläche.

Vision:

- Mops liest später Angebotsmails vom Server, extrahiert Angebotspreise und trägt sie als Vorschlag ein.
- Auch hier gilt: Vorschlag, nicht automatische Wahrheit.

### H. LV-Struktur / Dokumentansicht / DIN-Baum

Ziel war: LV nicht nur flach nach KG zeigen, sondern näher am echten Dokument und an der Denkweise des Bauleiters.

Ergebnis:

- LV-Ansicht hat Umschalter `KG` / `Dokument`.
- Dokumentansicht gruppiert nach Positionsstruktur.
- LV-Baustein-Werkbank wurde ergänzt.
- Eigene Positionen können im Baustein-Flow angelegt werden.
- Danach wurde erkannt: Es gibt nicht nur LV-Titel und Positionen, sondern eine DIN-Hierarchie.

Neue saubere Logik:

```text
DIN Ebene 1: 200 Vorbereitende Maßnahmen
DIN Ebene 2: 210 Herrichten
DIN Ebene 3: 211 Sicherungsmaßnahmen
LV Ebene:    01 Baustelleneinrichtung
Position:   01.0010 An-/Abfuhr Werkzeuge/Maschinen
```

Umsetzung:

- Neuer lokaler DIN-Baum `DIN276BaumKatalog`.
- Drei-Ebenen-Auswahl im LV-Baustein-Flow.
- Baum wurde aus der DIN-276-Excel-Struktur aufgefüllt.
- Keine CoreData-Migration.

Wichtig:

- `01 Baustelleneinrichtung` ist LV-/Dokumentstruktur.
- `200 -> 210 -> 211` ist DIN-/Kostenstruktur.
- Beides darf nicht vermischt werden.

### I. Expert-Validation / Privacy-First

Ziel war: Mops soll fachlich mitdenken können, ohne Projektdaten nach außen zu geben und ohne automatisch ins LV zu schreiben.

Ergebnis:

- `ExpertValidationService` erstellt anonymisierte Requests.
- Erlaubt sind nur:
  - `bezeichnung`
  - `einheit`
- Verboten sind:
  - Bauherr
  - Adresse
  - Projektname
  - Event-Titel
  - Datei-/Planname
  - Menge
  - Preis
  - Lieferant
- Lokale Keyword-Logik schlägt DIN-KG vor.
- Ergebnis ist ein `KGProposal`, kein Schreibzugriff.
- UI zeigt Vorschlag mit Begründung und Sicherheit.
- Erst Klick auf `Vorschlag übernehmen` setzt den Wert.

Architekturregel:

```text
lokal prüfen -> Vorschlag anzeigen -> Mensch übernimmt -> erst dann CoreData
```

### J. BauplanPlanEvent / TheBrain-Brücke

Ziel war: SwiftData-Idee prüfen, ohne CoreData zu gefährden.

Ergebnis:

- Kein SwiftData-Parallelmodell eingebaut.
- Stattdessen Payload-/Adapter-Ansatz:
  - `BauplanPlanEventPayload`
  - `Codable`
  - SHA-256 Integritätsprüfung
  - schreibt nur Payload/Audit in TheBrain
- CoreData bleibt Quelle der Wahrheit.

---

## 3. Dinge, die gestern fast vergessen wurden

Für morgen bzw. nächste Dokumentationsrunde:

- Zwei neue Icons für Mops/Prof wurden erstellt und sollen sauber dokumentiert werden.
- Poster aufnehmen.
- Lieferkreislauf-PDF aufnehmen.
- Prüfen, wohin diese Assets gehören:
  - App Assets?
  - `docs/mopsiversum/`?
  - `baumops.com` Landingpage?
  - eigene `docs/assets/` Struktur?
- Tunnel war offline bzw. wechselte ständig. Heute wurde daran gearbeitet, ihn dauerhaft zu machen.
- 24-Stunden-/Tunnel-Problem sollte nicht wieder Alltag werden.
- Serverzugriff für Kollegen:
  - SSH-Key liegt vor.
  - Ziel: Zugriff für Kollegen ermöglichen, möglichst mit Leserechten bzw. begrenztem Zugriff.
  - Vorsicht: Nicht blind Admin-/Schreibrechte geben.

---

## 4. Git- und Repo-Status am Tagesende

### iMOPS-App-Repo

Lokaler Branch: `main`

Bekannter Stand:

- `main` ist lokal mehrere Commits vor `origin/main`.
- Zusätzlich liegen neue, noch nicht committed Änderungen im Arbeitsbaum.
- Noch nicht pushen ohne Andreas' ausdrückliche Bestätigung.

Heute berührte Bereiche:

- `Models/DIN276BaumKatalog.swift`
- `Service/ExpertValidationService.swift`
- `Views/LV/AddLVPositionView.swift`
- `Views/LV/LVBausteinAuswahlView.swift`
- `Views/LV/KGProposalBox.swift`
- `Tests/ExpertValidationServiceTests.swift`
- `Tests/LVBausteinKatalogTests.swift`
- `Resources/Knowledge/app_bedienung.yaml`

Zusätzlich vorhandene untracked/langzeitbezogene Dinge:

- `AGENTS.md`
- `docs/mopsiversum/`

### Backend-Repo

Heute im Gespräch relevant:

- Mops-API läuft.
- Prof wurde auf OpenAI/GPT umgestellt.
- Claude bleibt optionaler Fallback, aber nicht mehr Kernabhängigkeit.
- OpenAI-Key/Quota wurde getestet, Health war am Ende erfolgreich.
- Backend-Änderungen waren bereits über PR/Branch-Workflow behandelt.

---

## 5. Prüfungen, die heute grün waren

### iOS-App

- App-Build grün.
- Unit-Tests grün.
- Expert-Validation-Tests grün.
- DIN-Baum/Katalog-Test grün.

Bekannte Warnungen:

- AppIntents-Metadata-Warnungen sind bekannt und aktuell nicht kritisch.
- Einige bestehende Swift-6-Warnungen aus Lieferanten-Tests wurden gesehen, aber nicht heute verursacht.

---

## 6. Morgen / nächste Runde

Empfohlene Reihenfolge:

1. Arbeitsbaum anschauen.
2. Entscheiden, ob heutige iMOPS-Änderungen committed werden.
3. Falls ja:
   - sinnvolle Commit-Gruppen bilden
   - nicht alles blind in einen Sack werfen
4. App kurz in Xcode testen:
   - LV -> Drei Punkte -> LV-Bausteine auswählen
   - DIN Ebene 1/2/3 prüfen
   - Eigene Position anlegen
   - Fachvorschlag anzeigen lassen
   - Vorschlag bewusst übernehmen
5. Offene Web/Doku-Assets sortieren:
   - Poster
   - Lieferkreislauf
   - Icons
6. Server-Kollegen-Zugriff mit Leserechten planen.
7. Eventuell PR/Push erst nach Sichtprüfung.

---

## 7. Architektur-Leitsätze aus dem Tag

- CoreData bleibt die Quelle der Wahrheit.
- Neue Intelligenz zuerst lokal, deterministisch, testbar.
- KI darf Vorschläge machen, aber nicht heimlich schreiben.
- DIN-Struktur und LV-Struktur sind zwei verschiedene Ordnungen.
- Der Mensch bleibt im Loop.
- Keine automatische Bestellung.
- Keine Projektdaten in fachliche Validierung.
- Eine feste URL ist kein Luxus, sondern Betriebssicherheit.

---

## 8. Kurzfassung für den nächsten Codi

Wenn du diese Datei liest:

- Nicht sofort coden.
- Erst `git status` anschauen.
- Es gibt lokale Änderungen, die noch nicht committed sind.
- App-Build und Tests waren am Abend des 24.06.2026 grün.
- Der neue DIN-Baum ist bewusst lokal und ohne Migration.
- Die Expert-Validation ist bewusst nur Vorschlag.
- `baumops.com` ist Landingpage.
- `mops.baumops.com` ist Matrix/Mops.
- Nicht pushen, nicht PR erstellen, bevor Andreas es ausdrücklich sagt.

