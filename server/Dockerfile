FROM python:3.12-slim

# Blender installieren (headless)
RUN apt-get update && apt-get install -y --no-install-recommends \
    blender \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Python-Abhaengigkeiten
COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# App-Code kopieren (Struktur beibehalten fuer Pfad-Referenzen)
COPY server/app.py ./server/
COPY scripts/blender_export.py ./scripts/

ENV BLENDER_PATH=/usr/bin/blender
ENV PORT=8080

EXPOSE 8080

WORKDIR /app/server
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "--timeout", "600", "app:app"]
