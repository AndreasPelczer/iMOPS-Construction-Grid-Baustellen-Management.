# Mops-Server · Setup-Spickzettel

> _Damit wir beim nächsten Mal nicht 20 Minuten suchen. Gepflegt 9.6.2026._

---

## 📦 Box

| | |
|---|---|
| **SSH** | `ssh mops` |
| **IP** | 192.168.2.42 (LAN-only) |
| **Port** | 8080 |
| **OS** | Ubuntu Server 24.04.4 LTS |
| **Status-Banner zeigt** | Load, RAM, Swap, Temperatur, Updates, Drift-Check |

---

## 📂 Pfade auf der Box

```
~/mops-api/              # Haupt-Repo (branch: main)
  ├── api/               # Python-Source (FastAPI)
  │   └── main.py        # Zeile 158: app.mount("/admin-ui", ...)
  ├── static/            # Web-Dateien (über /admin-ui/ erreichbar)
  │   ├── index.html
  │   ├── chat.html              # öffentlicher Mops-Chat
  │   ├── kontrollzentrum.html   # ALT — wird ersetzt durch bauhuette.html
  │   ├── bauhuette.html         # NEU — Raphis Verifikations-Posten (siehe bauhuette_entwurf.html im iMOPS-Repo)
  │   └── render-test.html
  ├── data/              # Daten
  ├── qdrant_storage/    # Vektor-DB (Bibliothek "bau_wissen_v1")
  ├── logs/
  ├── scripts/
  ├── tests/
  ├── venv/              # nicht anfassen
  ├── docker-compose.yml
  ├── requirements.txt
  └── restart.sh         # Service-Neustart

~/imops-repo/            # iMOPS-iOS-Repo (klon)
~/mops-backups/          # Backups
~/tunnel.log             # Cloudflared-Logs
~/mops-drift-check.sh    # läuft beim Login als Banner
```

---

## 🛣 FastAPI-Mount

```python
# api/main.py:158
app.mount("/admin-ui", StaticFiles(directory="static", html=True), name="admin-ui")
```

→ Alles in `static/` ist über `http://192.168.2.42:8080/admin-ui/<datei>` erreichbar.

---

## 🔌 Bekannte Endpoints

| Methode | Pfad | Auth | Zweck |
|---|---|---|---|
| GET | `/health/detailed` | – | Server-Vitals (status, model, cpu, ram, disk) |
| POST | `/chat` | – | Mops/Prof-Chat (`{question, max_tokens, top_k}`) |
| GET | `/admin/stats` | Basic | Tagesstats nach Pfad |
| GET | `/admin/pending` | Basic | Review-Queue (Q&A-Verifikation) |
| POST | `/admin/approve/{id}` | Basic | Antwort als korrekt markieren |
| POST | `/admin/reject/{id}` | Basic | Antwort verwerfen (`{reason}`) |
| POST | `/admin/correct/{id}` | Basic | Antwort korrigieren + Goldstandard |

### Geplant (Backend muss noch geschrieben werden)
- `GET /imops/puls` → `{welle, last_commit, open_prs, saves_count, branch}` — von der neuen Bauhütte erwartet
- `/health/detailed` erweitern um `uptime`, `temperature_c`, `claude_fallback` (boolean)

---

## 🔐 Auth-Modell

- HTTP Basic auf allen `/admin/*`-Pfaden
- **Login-Trick in der UI:** versteckter `<iframe>` lädt `/admin/pending` → Browser zeigt nativen Basic-Auth-Dialog → Credentials werden gecacht → spätere `fetch()`-Calls senden sie automatisch mit (same-origin).

---

## 🧠 LLM-Stack

- **Mops** (lokal): `ollama` mit `llama3.2:3b`
- **Prof** (Fallback): Claude API
- **RAG**: `qdrant` mit Bibliothek `bau_wissen_v1` (~2653 chunks Stand Boot-Anzeige)
- **Persona**: „Maurermeister-Bibliothekar"

---

## 🚇 Tunnel (Cloudflare Quick Tunnel)

```bash
# Starten
cloudflared tunnel --url http://localhost:8080 &> ~/tunnel.log &

# Aktuelle URL aus Log
grep -o 'https://.*\.trycloudflare\.com' ~/tunnel.log | tail -1

# Bei Drop: Neustart
pkill cloudflared
cloudflared tunnel --url http://localhost:8080 &> ~/tunnel.log &
```

**Stand 9.6.2026:** `https://juice-online-entitled-cgi.trycloudflare.com` (seit 8.6. stabil, Quick Tunnel — kann jederzeit droppen).

**Welle „später":** Named Tunnel mit fester Sub-Domain einrichten (z.B. `box.mops.<deine-domain>`), wenn Domain registriert ist.

---

## 🔧 Häufige Operationen

```bash
# HTML vom Mac auf die Box kopieren
scp ~/path/datei.html mops:~/mops-api/static/datei.html

# Service neu starten
ssh mops './mops-api/restart.sh'

# Drift-Check manuell
ssh mops 'cd ~/mops-api && git status'

# Letzte Mops-Logs
ssh mops 'tail -50 ~/mops-api.log'

# Tunnel-Status
ssh mops 'ps aux | grep cloudflared'
```

---

## 🔄 Repo-Workflow (mops-api)

- Branch `main` (kein Feature-Branching aktuell)
- Drift-Check warnt beim Login wenn uncommitted Files da sind
- Nach Änderung in `static/` reicht meist **kein** Service-Restart (FastAPI StaticFiles lädt frisch). Bei Änderung in `api/*.py` → `./restart.sh`.

---

## 🐶 Wichtige UI-Easteregg-Wörter (chat.html / Bauhütte)

- `bin da` · `bin da?` · `feierabend` → triggert das **Mops-Poem** (Buchkern in Lyrik)
- Klick auf `^Bin da ;=)` im Boot-Header (Bauhütte) → triggert ebenfalls Poem
- `?as=raphi` in URL → „Willkommen, Lehrmeister"-Bar (alt) / kann in neuer Version übernommen werden

---

## 📋 Bekannte Wartungs-Themen

- `Mops-API` (Großbuchstabe, untracked) — versehentliche Datei, irgendwann aufräumen
- 39 Updates ausstehend, 15 Sicherheits-Updates (Stand 9.6.) — irgendwann `apt upgrade`
- ESM Apps nicht aktiviert (4 zusätzliche Security-Updates verfügbar)
- Backups: `~/mops-api-backup-*.tar.gz` (manuell, letzte 26.5.)

---

_Wenn diese Datei veraltet ist: Korrigieren statt Schimpfen. Buch Kap 4 — Nachweis dient der Entlastung._
