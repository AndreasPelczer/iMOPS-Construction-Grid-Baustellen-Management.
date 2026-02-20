"""
iMOPS SKP-Konvertierungsserver.

Nimmt SKP-Dateien (und andere 3D-Formate) per Upload entgegen,
konvertiert sie serverseitig zu USDZ und gibt die Datei zurueck.

Ablauf:
  1. iOS-App POST /api/convert  (multipart SKP-Datei)
  2. Server: SKP -> OBJ/DAE (via Blender headless) -> USDZ
  3. Server: USDZ zurueck an App

Starten:
  pip install -r requirements.txt
  python app.py

Produktion:
  gunicorn -w 2 -b 0.0.0.0:8080 app:app
"""

import os
import uuid
import shutil
import subprocess
import tempfile
from pathlib import Path

from flask import Flask, request, jsonify, send_file

app = Flask(__name__)

# Konfiguration
MAX_UPLOAD_SIZE = 200 * 1024 * 1024  # 200 MB
ALLOWED_INPUT = {".skp", ".obj", ".dae", ".fbx", ".stl", ".gltf", ".glb"}
BLENDER_PATH = os.environ.get("BLENDER_PATH", shutil.which("blender") or "blender")
BLENDER_SCRIPT = Path(__file__).parent.parent / "scripts" / "blender_export.py"

app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_SIZE


# ------------------------------------------------------------------
# Konvertierungs-Logik
# ------------------------------------------------------------------

def convert_to_usdz(input_path: Path, work_dir: Path) -> Path:
    """
    Konvertiere eine 3D-Datei zu USDZ via Blender.

    Fuer SKP-Dateien: SKP -> (Blender) -> USDZ
    Fuer andere: Direkt via Blender -> USDZ

    Returns: Pfad zur USDZ-Datei oder raise bei Fehler.
    """
    output_path = work_dir / (input_path.stem + ".usdz")

    # Blender im Headless-Modus mit unserem Export-Skript
    cmd = [
        BLENDER_PATH,
        "--background",
        "--python", str(BLENDER_SCRIPT),
        "--",
        "--input", str(input_path),
        "--output", str(output_path),
        "--format", "usdz",
    ]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=600,  # 10 Minuten max
    )

    if result.returncode != 0:
        # Blender gibt Fehler sowohl ueber stdout als auch stderr aus
        combined = result.stdout + "\n" + result.stderr
        error_lines = [
            line for line in combined.splitlines()
            if "Error" in line or "FEHLER" in line or "Traceback" in line
        ]
        if not error_lines:
            # Letzten relevanten Output als Fehler nehmen
            error_msg = combined.strip()[-500:]
        else:
            error_msg = "\n".join(error_lines)
        raise RuntimeError(f"Blender-Konvertierung fehlgeschlagen: {error_msg}")

    if not output_path.exists():
        raise RuntimeError("USDZ-Datei wurde nicht erzeugt")

    return output_path


def convert_with_trimesh_fallback(input_path: Path, work_dir: Path) -> Path:
    """
    Fallback-Konvertierung mit trimesh fuer einfache Formate.
    Erzeugt OBJ als Zwischenformat wenn USDZ nicht direkt moeglich.
    """
    try:
        import trimesh
    except ImportError:
        raise RuntimeError("Weder Blender noch trimesh verfuegbar")

    ext = input_path.suffix.lower()
    if ext == ".skp":
        raise RuntimeError("SKP-Konvertierung benoetigt Blender")

    mesh = trimesh.load(str(input_path))
    # Trimesh kann kein USDZ direkt -> OBJ als Zwischenformat
    obj_path = work_dir / (input_path.stem + ".obj")
    mesh.export(str(obj_path), file_type="obj")
    return obj_path


# ------------------------------------------------------------------
# API-Endpunkte
# ------------------------------------------------------------------

@app.route("/api/health", methods=["GET"])
def health():
    """Health-Check Endpoint."""
    blender_ok = shutil.which(BLENDER_PATH) is not None or os.path.isfile(BLENDER_PATH)
    return jsonify({
        "status": "ok",
        "blender_available": blender_ok,
        "blender_path": BLENDER_PATH,
        "max_upload_mb": MAX_UPLOAD_SIZE // (1024 * 1024),
    })


@app.route("/api/convert", methods=["POST"])
def convert():
    """
    Konvertiere eine 3D-Datei zu USDZ.

    Request: multipart/form-data mit Feld 'file'
    Optional: ?format=usdz (Standard) oder ?format=obj|dae

    Response: Die konvertierte Datei als Download.
    """
    if "file" not in request.files:
        return jsonify({"error": "Kein 'file'-Feld im Upload"}), 400

    uploaded = request.files["file"]
    if not uploaded.filename:
        return jsonify({"error": "Leerer Dateiname"}), 400

    ext = Path(uploaded.filename).suffix.lower()
    if ext not in ALLOWED_INPUT:
        return jsonify({
            "error": f"Format '{ext}' nicht unterstuetzt",
            "allowed": sorted(ALLOWED_INPUT),
        }), 400

    target_format = request.args.get("format", "usdz").lower()

    # Temporaeres Arbeitsverzeichnis
    work_dir = Path(tempfile.mkdtemp(prefix="imops_convert_"))

    try:
        # Datei speichern
        input_path = work_dir / uploaded.filename
        uploaded.save(str(input_path))

        # Konvertieren
        try:
            output_path = convert_to_usdz(input_path, work_dir)
        except (RuntimeError, FileNotFoundError, subprocess.TimeoutExpired) as e:
            # Blender nicht verfuegbar -> Fallback
            if ext != ".skp":
                try:
                    output_path = convert_with_trimesh_fallback(input_path, work_dir)
                except Exception as fallback_err:
                    return jsonify({
                        "error": f"Konvertierung fehlgeschlagen: {e}",
                        "fallback_error": str(fallback_err),
                    }), 500
            else:
                return jsonify({
                    "error": str(e),
                    "hint": "SKP-Konvertierung benoetigt Blender auf dem Server",
                }), 500

        # Ergebnis zuruecksenden
        return send_file(
            str(output_path),
            mimetype="model/vnd.usdz+zip",
            as_attachment=True,
            download_name=output_path.name,
        )

    finally:
        # Aufraeumen (im Hintergrund, damit send_file fertig wird)
        # Hinweis: In Produktion besser mit einem Cleanup-Job loesen
        import threading

        def cleanup():
            import time
            time.sleep(30)  # Warten bis Download abgeschlossen
            shutil.rmtree(work_dir, ignore_errors=True)

        threading.Thread(target=cleanup, daemon=True).start()


@app.route("/api/formats", methods=["GET"])
def formats():
    """Listet unterstuetzte Ein-/Ausgabeformate."""
    return jsonify({
        "input_formats": sorted(ALLOWED_INPUT),
        "output_formats": ["usdz", "obj", "dae"],
        "max_upload_mb": MAX_UPLOAD_SIZE // (1024 * 1024),
    })


# ------------------------------------------------------------------
# Startup
# ------------------------------------------------------------------

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"

    print(f"\n{'='*50}")
    print(f"  iMOPS Konvertierungsserver")
    print(f"  Port: {port}")
    print(f"  Blender: {BLENDER_PATH}")
    print(f"  Max Upload: {MAX_UPLOAD_SIZE // (1024*1024)} MB")
    print(f"{'='*50}\n")

    app.run(host="0.0.0.0", port=port, debug=debug)
