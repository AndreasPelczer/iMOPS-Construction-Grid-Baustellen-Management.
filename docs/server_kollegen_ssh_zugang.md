# Serverzugang fuer Kollegen - Read-only Konzept

> ⚠️ **Planungsdokument vom 24.06.2026, nachgetragen am 26.08.2026.** Beschreibt ein
> Konzept für einen Nur-Lese-SSH-Zugang — **nicht umgesetzt**, Stand unklar.
> Vor Verwendung gegen die Box prüfen.


Stand: 24. Juni 2026.

Ziel: Ein Kollege kann auf der Mops-Box lesen und prüfen, aber nicht aus Versehen
Systemdienste, Repos oder Daten veraendern.

## Befund

- Aktiver Arbeitsuser: `mops`
- `mops` ist in privilegierten Gruppen, u.a. `sudo`, `docker`, `lxd`.
- Deshalb: **Den `mops`-User nicht teilen.**
- Repository `/home/mops/mops-api` ist fuer andere Benutzer grundsaetzlich lesbar
  (`drwxr-xr-x`), Logs/static sind ebenfalls lesbar.

## Empfohlene Umsetzung

### 1. Eigenen User anlegen

Beispielname:

```bash
sudo adduser --disabled-password --gecos "" mops-leser
```

Keine Gruppen wie `sudo`, `docker`, `lxd` vergeben.

### 2. SSH-Key des Kollegen eintragen

Der Kollege liefert seinen Public Key, z.B.:

```text
ssh-ed25519 AAAA... name@geraet
```

Dann:

```bash
sudo mkdir -p /home/mops-leser/.ssh
echo 'ssh-ed25519 AAAA... name@geraet' | sudo tee /home/mops-leser/.ssh/authorized_keys
sudo chown -R mops-leser:mops-leser /home/mops-leser/.ssh
sudo chmod 700 /home/mops-leser/.ssh
sudo chmod 600 /home/mops-leser/.ssh/authorized_keys
```

### 3. Bequeme Lesepfade setzen

Optional Symlinks im Home des Kollegen:

```bash
sudo -u mops-leser ln -s /home/mops/mops-api /home/mops-leser/mops-api
```

Damit kann der Kollege:

```bash
ssh mops-leser@192.168.2.42
cd ~/mops-api
git status
less logs/...
```

## Nicht tun

- Kein Passwort-Login.
- Kein Zugriff ueber den bestehenden `mops`-User.
- Keine Aufnahme in `sudo`, `docker`, `lxd`.
- Keine privaten Keys teilen.

## Noch benoetigt

- Gewuenschter Username fuer den Kollegen.
- Public Key des Kollegen.
- Entscheidung, ob nur LAN-Zugriff reicht oder ob der Zugang auch von extern ueber
  Tunnel/VPN laufen soll.
