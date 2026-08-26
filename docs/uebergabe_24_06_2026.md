# Übergabe und Statusprotokoll - 24. Juni 2026

> ⚠️ **Historisches Dokument, nachgetragen am 26.08.2026.** Beschreibt den Stand vom
> 24.06.2026 und lag bis dahin nur lokal. Der aktuelle Stand steht in
> `docs/HANDOFF-AKTUELL.md` — dieses Dokument nicht als Gegenwart lesen.


> Stand: morgens. Server läuft, Xcode-Build ist grün, PR #77 ist in `main` gemergt.

---

## 1. Was fertig ist

### Lieferanten-Synchronisation: technischer Kern

Das Modul "Lokale Lieferanten-Synchronisation" ist im iOS-Client angekommen.

- `UniversalAnfrage` bildet den Bedarf als lokales, codierbares Objekt ab.
- `BedarfsQuelle` hält den Nachweis: LV, Plan, Foto oder manuelle Polier-Eingabe.
- `LieferDetails` enthält Beauftragung, Lieferfenster, Bestätigung und Warnschwelle.
- `WarnStufe` bleibt reine Anzeige-Logik: keine Aktion, keine automatische Bestellung.
- Unit-Tests decken die Warnlogik inklusive Grenzfall ab.

Leitsatz: Der Mops bereitet vor. Der Mensch entscheidet.

### Bestellliste und Ampel

Die Bestellliste im LV ist jetzt bildschirmfüllend und zeigt Lieferstatus-Badges.

- Grün: kein Handlungsdruck.
- Orange: Bestätigung fehlt innerhalb der Warnschwelle.
- Rot: Termin ist kritisch.

Die Ampel ist bewusst klein und direkt an der Position. Sie soll dem Polier nicht erklären,
dass ein System komplex ist, sondern zeigen, wo er handeln muss.

### Anfrage-Export

Für Lieferanten-Anfragen existieren zwei Ausgabewege:

- Textformat für WhatsApp, E-Mail oder Copy/Paste.
- PDF-Export über `LieferantenAnfragePDFExporter`.

Das ist noch keine Mail-Server-Automation. Es ist absichtlich ein sendefertiges Werkzeug:
iMOPS erzeugt die Nachricht, der Nutzer verschickt sie.

### Angebotsvergleich

Der Angebotsvergleich wurde von "Liste anschauen" in Richtung Rückmelde-Werkzeug erweitert.

- Pro Position kann eine Rückmeldung / ein Angebot erfasst werden.
- Lieferstatus und optionales Lieferdatum können gespeichert werden.
- Bestehende `angebote.json`-Daten bleiben kompatibel.

Der nächste sinnvolle Ausbau ist nicht mehr "Button reparieren", sondern:
Antworten aus echten Lieferanten-Mails strukturiert eintragen oder später vom Mops vorbereiten lassen.

---

## 2. Repo-Stand

### GitHub

- PR #77 `feat: Lieferanten-Sync und LV-Ampel UI` ist gemergt.
- `origin/main` enthält die Lieferanten-Sync-Arbeit.

### Lokal

- Lokales `main` wurde per Fast-Forward auf `origin/main` gebracht.
- Neuer Arbeitsbranch für diese Doku: `docs/lieferanten-sync-uebergabe-20260624`.
- Offene ungetrackte Dateien bleiben bewusst separat:
  - `AGENTS.md`
  - `docs/mopsiversum/`

Diese Dateien wurden nicht automatisch in den PR gezogen, weil sie eher Arbeitsweise /
Mopsiversum-Dokumente sind und nicht blind mit Produktcode vermischt werden sollten.

---

## 3. Morgen-/Tagesliste

### A. Dokumentation sauber einsortieren

- Diese Übergabe prüfen.
- Entscheiden, ob `docs/mopsiversum/` ins Repo soll oder als lokales Archiv bleibt.
- Poster und Lieferanten-Kreislauf wurden als Bildassets unter
  `docs/assets/mops-branding/` gesichert.
- Zwei Mops/Prof-Icon-Kandidaten wurden ebenfalls unter
  `docs/assets/mops-branding/` gesichert.
- Falls es zusätzlich eine echte `Lieferkreislauf.pdf` gibt, muss sie noch gefunden werden.
- Danach entscheiden:
  - App-Asset?
  - Doku-Asset?
  - beides?

### B. Dauerzugriff klären

Offen ist die "24-Stunden-Sache":

- Was war bisher temporär?
- Geht es um Tunnel, URL, BuildIQ, Mops, Prof oder alles zusammen?
- Ziel: dauerhafter, nachvollziehbarer Zugriff ohne morgendliches Basteln.

Server-Befund vom 24.06.2026:

- Mops-API läuft im LAN.
- `PROF_PROVIDER=openai`, `OPENAI_MODEL=gpt-4.1`.
- Kein aktiver `cloudflared`-Prozess.
- Kein sichtbarer `cloudflared`-systemd-Service.
- Alte Tunnel-Logs zeigen QUIC-/DNS-Timeouts und danach Shutdown.

Empfehlung:

- Dauerhaft richtig: Cloudflare Named Tunnel mit fester Subdomain.
- Nur Zwischenlösung: Quick Tunnel per systemd automatisch neu starten lassen; URL bleibt aber wechselbar.

Erst nach Entscheidung Domain/Named-Tunnel vs. Quick-Tunnel-Zwischenlösung an der Server-Konfiguration ändern.

### C. Kollege per SSH

Ziel: Ein Kollege soll auf den Server schauen können, aber nicht aus Versehen das System
verändern.

Plan abgelegt unter `docs/server_kollegen_ssh_zugang.md`.

Vorschlag:

- eigener Linux-User für den Kollegen
- SSH-Key statt Passwort
- keine sudo-Rechte
- nur Leserechte auf freigegebene Ordner / Logs / Dokumentation

Keine Weitergabe des bestehenden `mops`-Users.

### D. Angebotsvergleich weiterführen

Wenn Doku und Zugriff sauber sind:

- Rückmelde-Flow visuell verbessern.
- Angebotsvergleich stärker mit Bestellliste verbinden.
- Später: Mops liest Lieferanten-Mails und schlägt strukturierte Einträge vor.

---

## 4. Architektur-Reminder

Das Lieferanten-Modul ist kein autonomer Bestellroboter.

Es ist ein präzises Werkzeug für reale Baustellenkommunikation:

1. Bedarf erkennen.
2. Nachweis sichern.
3. Anfrage vorbereiten.
4. Mensch versendet.
5. Rückmeldung erfassen.
6. Ampel zeigt Handlungsdruck.
7. Feuerwehr-Modus wird später als Handlungsangebot ergänzt, nicht als automatische Aktion.

Das passt zur Thermodynamik-der-Arbeit-Regel:

> Wenn ein System nur funktioniert, weil Menschen es permanent ausgleichen, dann funktioniert es nicht.

iMOPS soll die Ausgleichsarbeit sichtbar machen, reduzieren und sauber übergeben.
