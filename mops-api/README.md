# Mops-API

Lokales LLM-Backend für **iMOPS Construction Grid**. Läuft auf dem Mops-Server
(Ubuntu 24.04, i5-3470, 16 GB RAM, CPU-only) und bedient die iOS-App
mit Phi-3-Antworten.

> Diese Version ist die **Baseline (Aufgabe 1+2)**: FastAPI-Skelett mit
> `/health` und `/chat`, **ohne RAG**. Sie dient dazu, ein Gefühl dafür zu
> kriegen, wie Phi-3 ohne Wissensbasis bei Bau-Fragen abschneidet. RAG,
> Wikipedia-Scraper, Chunking und Qdrant-Ingest kommen in einer folgenden
> Iteration dazu.

## Voraussetzungen

- Python 3.11+ (Ubuntu 24.04 liefert 3.12 mit)
- Laufende Ollama-Instanz mit dem `phi3:mini` Modell
  ```bash
  ollama pull phi3:mini
  ```

## Installation

```bash
cd ~/mops-api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Werte in .env nach Bedarf anpassen
```

## Start

```bash
source venv/bin/activate
uvicorn api.main:app --host 0.0.0.0 --port 8080
```

Vom Mac aus probieren:

```bash
curl http://192.168.2.42:8080/health
curl -X POST http://192.168.2.42:8080/chat \
  -H "content-type: application/json" \
  -d '{"question": "Was ist Mauerwerk?", "max_tokens": 200}'
```

## Endpoints

| Methode | Pfad | Zweck |
|---|---|---|
| GET | `/health` | Liveness + Ollama-Reachability |
| GET | `/health/detailed` | + RAM, CPU, Disk, verfügbare Modelle |
| POST | `/chat` | Frage an Phi-3 (ohne RAG) |

OpenAPI-Doku: http://192.168.2.42:8080/docs

## Baseline-Test ausführen

Im laufenden Server-Verzeichnis (separater Terminal):

```bash
source venv/bin/activate
pytest tests/test_baseline.py -v
```

Der Test schickt 10 echte Bau-Fragen + 4 Fang-Fragen an `/chat` und
schreibt die Antworten nach `data/tests/baseline_results_<timestamp>.json`.

**Wichtig:** Phi-3 auf CPU braucht pro Frage 30 s – 3 min. Plant 15–40 min für
einen vollen Lauf ein.

Konfiguration über Umgebungsvariablen:

```bash
MOPS_BASE_URL=http://192.168.2.42:8080 pytest tests/test_baseline.py -v
MOPS_MAX_TOKENS=300 pytest tests/test_baseline.py -v
```

### Fang-Fragen?

Vier der Fragen beziehen sich auf erfundene Normen (DIN 99999, GAEB DA42, …).
Erwartung: Phi-3 sollte sagen „kenne ich nicht". Macht er das nicht, ist das
ein **Halluzinations-Signal** — gut, das vor RAG zu wissen.

## Manuelle Bewertung

Nach dem Lauf jede Antwort in der Ergebnisdatei mit einem `rating` versehen:

| Wert | Bedeutung |
|---|---|
| `correct` | Sachlich richtig, mit relevantem Kontext |
| `partial` | Im Kern richtig, aber unvollständig oder zu generisch |
| `wrong` | Faktisch falsch |
| `hallucination` | Erfindet Normen/Begriffe, die es nicht gibt |
| `refused` | Sagt ehrlich „weiß ich nicht" |

Ziel-Baseline für RAG-Vergleich: notiert für jede der 10 echten Fragen das
Rating und die Dauer.

## Verzeichnisstruktur

```
mops-api/
├── api/
│   ├── main.py                # FastAPI app + lifespan
│   ├── config.py              # Pydantic Settings
│   ├── models.py              # Request/Response-Schemas
│   ├── routes/
│   │   ├── health.py
│   │   └── chat.py
│   └── services/
│       └── ollama_client.py   # Async Wrapper um ollama-python
├── tests/
│   └── test_baseline.py
├── data/
│   └── tests/
│       └── baseline_questions.json
├── requirements.txt
├── .env.example
└── README.md
```

## Was hier (noch) NICHT drin ist

- RAG / Vektor-Suche / Qdrant
- Wikipedia-Scraper
- PDF-Parser
- Embedding-Pipeline
- Auth / HTTPS / Tailscale
- systemd-Auto-Start

Das kommt nach dem Baseline-Test, sobald wir wissen wo Phi-3 wirklich schwächelt.

## Hinweis: zwei Server im selben Repo

Es gibt im Repo zusätzlich `server/app.py` — das ist ein **anderer**
Flask-Service für die SKP→USDZ-Konvertierung der iOS-App. Beide Services
nutzen Default-Port 8080; auf demselben Host muss einer umkonfiguriert
werden. Der Mops-API-Port ist über `API_PORT` in der `.env` änderbar.
