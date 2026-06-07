# Architektur — Raphis Setup (MacBook + Box + Büromac)

_Stand: 7. Juni 2026 (Sonntag). Verfasst von Mops (Claude) auf Branch `claude/clever-clarke-aRgdt` während der Live-Einrichtung._

---

## 🎯 Mission

Raphi (Polier-Kollege) bekommt eine **3-stufige Datenheimat**, die im eigenen Netz läuft, keine Cloud braucht, und für ihn unsichtbar funktioniert.
**Andreas-Wort:** _"Deinen Mac kannste mitnehmen, der Mops hat's schon geregelt."_

---

## 🧭 Rollen der drei Geräte

| Gerät | Rolle | Pfad / Adresse |
|---|---|---|
| **Raphis MacBook Air** | Arbeitsplatz (mobil) — wo Raphi tatsächlich zeichnet/tippt | `raphaeldelacruz@MacBookAir` |
| **Mops-Server (die Box)** | **Single Source of Truth** + Versionierung (Snapshots) | `mops@192.168.2.42` |
| **Büromac mit 1-TB-HDD** | "Bauwagen" = Kontrollzentrum für Office-Arbeit + Zweitbackup | wird Montag angeschlossen |

**iMOPS-App** (iPads/iPhones der Polierer) liest **direkt vom Mops-Server** — nicht vom Büromac. Büromac ist Office-Werkbank und Notfall-Fallback, nicht Datendrehscheibe.

---

## 📐 Datenfluss-Diagramm

```
┌─────────────────────────┐
│ Raphis MacBook (mobil)  │  ← Arbeit findet hier statt
│ ~/Mops-SketchUp/        │     (Baustelle, Café, Couch)
│ ~/imops-dokumente/      │
└──────────┬──────────────┘
           │ Live-Sync 4× täglich (8/12/16/20 Uhr)
           │ via rsync + SSH-Key (passwortlos)
           ▼
┌─────────────────────────┐
│ Mops-Server (die Box)   │  ◄── DAS ist die echte Backupplatte
│ /srv/raphi/sketchup/    │      Single Source of Truth
│ /srv/raphi/imops-dok./  │      iMOPS-App liest von hier
│ /srv/raphi/snapshots/   │      (Versionshistorie)
└──────────┬──────────────┘
           │ Nächtlicher Backup-Sync (z.B. 02:00 Uhr)
           │ via rsync (große Pakete, hat Zeit)
           ▼
┌─────────────────────────┐         ┌─────────────────┐
│ Büromac mit 1-TB-HDD    │         │ iMOPS App       │
│ /Volumes/IMOPS-Backup/  │         │ (iPads/iPhones) │
│                         │         └────────┬────────┘
│ Kontrollzentrum =       │                  │
│ "Bauwagen" (Office,     │                  │
│ Mails, große Pläne)     │                  │
│ + Zweitbackup           │                  │
└─────────────────────────┘                  │
            ▲                                │
            │                                │
            └── kein Live-Sync ── Mops ◄─────┘
                              (App holt direkt von der Box)
```

---

## 🛡️ Warum so? — 3-2-1-Regel der Datensicherung

- **3 Kopien** der Daten (Mac + Mops + Büromac)
- **2 verschiedene Medien** (SSDs in Mac/Mops, HDD im Büromac)
- **1 Kopie** "off-machine" (Büromac steht woanders als die Box)

Das ist nicht Übervorsicht — das ist **Bauleiter-Standard**. Bei Statik, LVs und Verträgen Pflicht.

---

## 🚦 Phasen-Status

### ✅ Phase 1 — Backup auf Intenso *(7.6.2026, früh)*
- Time-Machine-Surrogat per `rsync` auf FAT32-Platte
- Pfad: `/Volumes/INTENSO/Raphi-Backup-2026-06-07/`
- 26 GB transferiert, Mai-Backup unangetastet als Doppelboden

### ✅ Phase 2 — Klar Schiff auf MacBook *(7.6.2026, früh)*
- 83 % → 77 % Belegung (+14 GB frei)
- Installer-Schlacht, SketchUp 23/24 + Wallpaper-Cache, Caches/Logs, CoreSimulator
- Wartet auf Raphi-Klärung: Claude (12 GB), SketchUp 2025 (1,6 GB), Microsoft (1,4 GB), Chrome-Cache (~5 GB), DrFone (361 MB)

### ✅ Phase 3 — Mops-Server-Sync für SketchUp *(7.6.2026, früh)*
- SSH-Key `~/.ssh/mops_sync_key` (ed25519) auf Raphis Mac
- Public Key auf Box installiert → passwortlos
- launchd-Job `com.mops.sketchup-sync` läuft 4× täglich
- Snapshots in `/srv/raphi/snapshots/[Datum_Uhrzeit]/`

### ⏳ Phase 4 — Büromac-Setup *(Montag 8.6.2026 vorgesehen)*

**4a) Nächtliches Backup Box → Büromac:**
- SSH-Vertrauen Box → Büromac einrichten
- Cron-Job auf der Box: 02:00 Uhr `rsync /srv/raphi/ → büromac:/Volumes/IMOPS-Backup/raphi/`

**4b) iMOPS-Dokumente-Spur (zweite Sync-Lane):**
- Ordner-Skelett auf Box: `/srv/raphi/imops-dokumente/`
- Raphi-Mac-Sync zweite Spur: `~/imops-dokumente/` → Box
- Eigener launchd-Job mit gleichem Mechanismus wie SketchUp-Sync

---

## 📁 iMOPS-Dokumente — Ordner-Struktur (Vorschlag)

```
/srv/raphi/imops-dokumente/
├── Baustellen/
│   ├── 2026-448-GO_Schwarz_Marktbreit/
│   │   ├── Statik/          (PDF von Statiker, Z-Nummern, abZ)
│   │   ├── LV/              (Leistungsverzeichnis, GAEB, Excel)
│   │   ├── Angebote/        (von Lieferanten, Subunternehmen)
│   │   ├── Lieferanten/     (Datenblätter, Lieferantenmails)
│   │   ├── Baupläne/        (Architektur, Konstruktion, DWG/PDF)
│   │   ├── Fotos/           (Baustellen-Doku)
│   │   ├── Korrespondenz/   (Mails, Briefe an/von Bauherr)
│   │   ├── Bautagesberichte/
│   │   ├── Aufmasse/        (von BuildIQ + manuell)
│   │   ├── Rechnungen/
│   │   └── Verträge/
│   ├── 2026-XXX_Schmidt_Hettingen/
│   │   └── ... (gleiche Struktur)
│   └── ...
└── Vorlagen/                (LV-Templates, Bauzeitenpläne, etc.)
```

**Konventionen:**
- Baustellen-Ordner: `JAHR-AUFTRAGSNR_KUNDE_ORT`
- Pro Baustelle gleiche Schubladen (Konsistenz für iMOPS-App und Polier-Reflex)
- Welche Schubladen wirklich gebraucht werden → **Raphi entscheidet**

---

## 🔧 Tech-Stack Phase 3 (Referenz)

### SSH-Key
- Typ: ed25519
- Pfad auf Mac: `~/.ssh/mops_sync_key` (+ `.pub`)
- Auf Box installiert via `ssh-copy-id` → in `/home/mops/.ssh/authorized_keys`

### Sync-Skript auf Raphis Mac
- Pfad: `~/Mops-SketchUp/.sync.sh`
- Funktion: `rsync -avz --delete-after --backup --backup-dir="../snapshots/[Datum]"`
- Log: `~/Mops-SketchUp/.sync.log`

### launchd-Job
- Pfad: `~/Library/LaunchAgents/com.mops.sketchup-sync.plist`
- Trigger: 8:00, 12:00, 16:00, 20:00 Uhr
- Check: `launchctl list | grep mops`

### Server-Seite
- Owner: `mops:mops`
- Permissions: 750 auf `/srv/raphi/{sketchup,snapshots}`
- Snapshot-Versionierung läuft automatisch bei jedem Sync

---

## 🪛 Was Raphi tun muss (= praktisch nichts)

1. **SketchUp-Dateien** in `~/Mops-SketchUp/` speichern
2. **Baustellen-Dokumente** in `~/imops-dokumente/Baustellen/[Baustelle]/[Schublade]/` ablegen
3. Wenn er was kaputt klickt: alte Version in `/srv/raphi/snapshots/[Datum_Uhrzeit]/` auf der Box (er ruft Andreas, der zieht's zurück)

Das war's. Kein Login, kein Cloud-Konto, kein "wo war die Datei nochmal".

---

## 🛡️ Datenhoheit (= Tagline-Ebene 2)

> **"Mensch über Profit · Profit durch Schutz der Menschen."** 🛡

Nichts geht in fremde Hände:
- Kein Google Drive, kein iCloud, kein Dropbox
- Alles im **eigenen Netz** (192.168.2.x)
- SSH-Keys statt Passwörter (sicher gegen Brute Force)
- Snapshots als **Polier-Doppelboden** (versehentliches Überschreiben → alte Version ist da)

Diese Architektur ist **TSS-Hausbesetzer-Geist auf Postgres-Niveau** (siehe Save #32 im Übergabe-Doc).

---

_Setup live durchgeführt am Sonntag 7.6.2026 zwischen 06:00 und 09:00 Uhr von Andreas + Mops. Phase 4 folgt Montag mit dem Büromac vor Ort._
