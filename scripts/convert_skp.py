#!/usr/bin/env python3
"""
convert_skp.py - SKP/3D-Datei-Konvertierungstool fuer iMOPS Baustellen-Management.

Konvertiert SketchUp-Dateien (.skp) und andere 3D-Formate in iOS-kompatible
Formate (USDZ, OBJ, DAE) fuer die Verwendung im CAD-Viewer der App.

Unterstuetzt drei Konvertierungs-Backends:
  1. Blender (empfohlen) - Voller SKP-Support mit Addon
  2. Apple Reality Converter CLI (xcrun usdz_converter) - nur macOS
  3. Trimesh (Python) - fuer einfache OBJ/STL/GLB Konvertierungen

Installation:
  pip install trimesh numpy

  Fuer Blender-Backend:
    - Blender 3.0+ installieren (https://www.blender.org/download/)
    - Fuer SKP-Import: SketchUp-Importer-Addon in Blender installieren

  Fuer Apple-Backend (nur macOS):
    - Xcode Command Line Tools: xcode-select --install
    - Reality Converter: https://developer.apple.com/augmented-reality/tools/

Verwendung:
  # Einzelne Datei konvertieren
  python convert_skp.py model.skp --format usdz
  python convert_skp.py model.skp --format obj --output ausgabe.obj

  # Mehrere Formate gleichzeitig
  python convert_skp.py model.skp --format usdz obj dae

  # Ganzen Ordner konvertieren (batch)
  python convert_skp.py /pfad/zu/skp-dateien/ --format usdz --batch

  # Backend explizit waehlen
  python convert_skp.py model.dae --format usdz --backend apple
  python convert_skp.py model.skp --format obj --backend blender

  # Blender-Pfad angeben (falls nicht im PATH)
  python convert_skp.py model.skp --format usdz --blender-path /opt/blender/blender
"""

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Optionale Imports - nicht alle werden benoetigt
try:
    import trimesh
    HAS_TRIMESH = True
except ImportError:
    HAS_TRIMESH = False

# ------------------------------------------------------------------
# Konstanten
# ------------------------------------------------------------------

SCRIPT_DIR = Path(__file__).parent.resolve()
BLENDER_SCRIPT = SCRIPT_DIR / "blender_export.py"

SUPPORTED_INPUT = {".skp", ".obj", ".dae", ".fbx", ".stl", ".gltf", ".glb"}
SUPPORTED_OUTPUT = {"usdz", "usdc", "obj", "dae", "fbx", "stl", "gltf", "glb"}

# Formate, die Trimesh direkt lesen kann (ohne Blender)
TRIMESH_INPUT = {".obj", ".stl", ".ply", ".glb", ".gltf", ".off"}

# Formate, die Trimesh direkt schreiben kann
TRIMESH_OUTPUT = {"obj", "stl", "ply", "glb", "gltf", "off"}

FORMAT_EXTENSIONS = {
    "usdz": ".usdz",
    "usdc": ".usdc",
    "obj": ".obj",
    "dae": ".dae",
    "fbx": ".fbx",
    "stl": ".stl",
    "gltf": ".gltf",
    "glb": ".glb",
}


# ------------------------------------------------------------------
# Backend: Blender
# ------------------------------------------------------------------

def find_blender(custom_path=None):
    """Finde den Blender-Executable-Pfad."""
    if custom_path:
        if os.path.isfile(custom_path) and os.access(custom_path, os.X_OK):
            return custom_path
        print(f"[WARNUNG] Angegebener Blender-Pfad nicht gefunden: "
              f"{custom_path}")

    # Standard-Suchpfade
    blender = shutil.which("blender")
    if blender:
        return blender

    # Plattform-spezifische Standardpfade
    candidates = [
        # macOS
        "/Applications/Blender.app/Contents/MacOS/Blender",
        # Linux (Snap)
        "/snap/bin/blender",
        # Linux (Flatpak)
        "/var/lib/flatpak/exports/bin/org.blender.Blender",
    ]

    for candidate in candidates:
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK):
            return candidate

    return None


def convert_with_blender(input_path, output_path, fmt, blender_path):
    """Konvertiere eine Datei mit Blender im Headless-Modus."""
    if not blender_path:
        print("[FEHLER] Blender nicht gefunden!")
        print("  Installiere Blender: https://www.blender.org/download/")
        print("  Oder gib den Pfad an: --blender-path /pfad/zu/blender")
        return False

    if not BLENDER_SCRIPT.exists():
        print(f"[FEHLER] Blender-Skript nicht gefunden: {BLENDER_SCRIPT}")
        return False

    cmd = [
        blender_path,
        "--background",          # Kein GUI
        "--factory-startup",     # Keine User-Einstellungen laden
        "--python", str(BLENDER_SCRIPT),
        "--",
        "--input", str(input_path),
        "--output", str(output_path),
        "--format", fmt,
    ]

    print(f"[Blender] Starte Konvertierung: {input_path} -> {output_path}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300,  # 5 Minuten Timeout
        )

        # Blender-Output filtern (nur relevante Zeilen)
        for line in result.stdout.splitlines():
            if "[blender_export]" in line:
                print(f"  {line.strip()}")

        if result.returncode != 0:
            print(f"[FEHLER] Blender-Konvertierung fehlgeschlagen "
                  f"(Exit-Code: {result.returncode})")
            # Fehlerdetails ausgeben
            for line in result.stderr.splitlines():
                if "Error" in line or "FEHLER" in line:
                    print(f"  {line.strip()}")
            return False

        return True

    except subprocess.TimeoutExpired:
        print("[FEHLER] Blender-Timeout (>5 Minuten). "
              "Die Datei ist moeglicherweise zu gross.")
        return False
    except FileNotFoundError:
        print(f"[FEHLER] Blender nicht ausfuehrbar: {blender_path}")
        return False


# ------------------------------------------------------------------
# Backend: Apple Reality Converter (macOS)
# ------------------------------------------------------------------

def has_apple_converter():
    """Pruefe ob Apple's usdz_converter verfuegbar ist (nur macOS)."""
    if sys.platform != "darwin":
        return False
    return shutil.which("xcrun") is not None


def convert_with_apple(input_path, output_path):
    """
    Konvertiere eine Datei mit Apple's usdz_converter (nur macOS).
    Unterstuetzt: OBJ, DAE, ABC, USD -> USDZ
    """
    if not has_apple_converter():
        print("[FEHLER] Apple usdz_converter nicht verfuegbar.")
        print("  Nur auf macOS mit Xcode Command Line Tools verfuegbar.")
        return False

    cmd = ["xcrun", "usdz_converter", str(input_path), str(output_path)]

    print(f"[Apple] Starte USDZ-Konvertierung: {input_path} -> {output_path}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300,
        )

        if result.returncode != 0:
            print(f"[FEHLER] Apple-Konvertierung fehlgeschlagen")
            if result.stderr:
                print(f"  {result.stderr.strip()}")
            return False

        print(f"[Apple] Export erfolgreich: {output_path}")
        return True

    except subprocess.TimeoutExpired:
        print("[FEHLER] Timeout bei Apple-Konvertierung.")
        return False
    except FileNotFoundError:
        print("[FEHLER] xcrun nicht gefunden. "
              "Xcode Command Line Tools installieren.")
        return False


# ------------------------------------------------------------------
# Backend: Trimesh (Python-nativ)
# ------------------------------------------------------------------

def convert_with_trimesh(input_path, output_path, fmt):
    """
    Konvertiere mit trimesh (Python-nativ).
    Begrenzte Format-Unterstuetzung, aber keine externen Tools noetig.
    """
    if not HAS_TRIMESH:
        print("[FEHLER] trimesh nicht installiert.")
        print("  Installiere mit: pip install trimesh numpy")
        return False

    ext = Path(input_path).suffix.lower()
    if ext not in TRIMESH_INPUT:
        print(f"[FEHLER] trimesh kann '{ext}' nicht lesen.")
        print(f"  Unterstuetzte Eingabeformate: {', '.join(TRIMESH_INPUT)}")
        return False

    if fmt not in TRIMESH_OUTPUT:
        print(f"[FEHLER] trimesh kann nicht nach '{fmt}' exportieren.")
        print(f"  Unterstuetzte Ausgabeformate: {', '.join(TRIMESH_OUTPUT)}")
        return False

    print(f"[Trimesh] Starte Konvertierung: {input_path} -> {output_path}")

    try:
        mesh = trimesh.load(str(input_path))
        mesh.export(str(output_path), file_type=fmt)
        print(f"[Trimesh] Export erfolgreich: {output_path}")
        return True

    except Exception as e:
        print(f"[FEHLER] Trimesh-Konvertierung fehlgeschlagen: {e}")
        return False


# ------------------------------------------------------------------
# Konvertierungs-Logik
# ------------------------------------------------------------------

def choose_backend(input_path, fmt, preferred_backend=None):
    """
    Waehle automatisch das beste verfuegbare Backend.
    Gibt den Backend-Namen zurueck: 'blender', 'apple', 'trimesh'.
    """
    ext = Path(input_path).suffix.lower()

    # Wenn ein Backend explizit gewuenscht ist
    if preferred_backend:
        return preferred_backend

    # SKP -> immer Blender (einzige Option)
    if ext == ".skp":
        return "blender"

    # USDZ-Export auf macOS -> Apple-Tools bevorzugen (schneller)
    if fmt == "usdz" and has_apple_converter() and ext in {".obj", ".dae"}:
        return "apple"

    # Einfache Formate -> trimesh (schnellster Start)
    if HAS_TRIMESH and ext in TRIMESH_INPUT and fmt in TRIMESH_OUTPUT:
        return "trimesh"

    # Fallback -> Blender (kann alles)
    return "blender"


def convert_file(input_path, output_path, fmt, backend=None,
                 blender_path=None):
    """
    Konvertiere eine einzelne Datei.
    Gibt True zurueck bei Erfolg.
    """
    input_path = Path(input_path).resolve()
    output_path = Path(output_path).resolve()

    if not input_path.exists():
        print(f"[FEHLER] Eingabedatei nicht gefunden: {input_path}")
        return False

    ext = input_path.suffix.lower()
    if ext not in SUPPORTED_INPUT:
        print(f"[FEHLER] Nicht unterstuetztes Eingabeformat: {ext}")
        print(f"  Unterstuetzt: {', '.join(sorted(SUPPORTED_INPUT))}")
        return False

    if fmt not in SUPPORTED_OUTPUT:
        print(f"[FEHLER] Nicht unterstuetztes Ausgabeformat: {fmt}")
        print(f"  Unterstuetzt: {', '.join(sorted(SUPPORTED_OUTPUT))}")
        return False

    # Ausgabeverzeichnis erstellen
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Backend waehlen
    backend = choose_backend(str(input_path), fmt, backend)
    print(f"\n{'='*60}")
    print(f"  Eingabe:  {input_path.name}")
    print(f"  Ausgabe:  {output_path.name}")
    print(f"  Format:   {fmt}")
    print(f"  Backend:  {backend}")
    print(f"{'='*60}")

    if backend == "blender":
        blender = find_blender(blender_path)
        return convert_with_blender(input_path, output_path, fmt, blender)
    elif backend == "apple":
        return convert_with_apple(input_path, output_path)
    elif backend == "trimesh":
        return convert_with_trimesh(input_path, output_path, fmt)
    else:
        print(f"[FEHLER] Unbekanntes Backend: {backend}")
        return False


def generate_output_path(input_path, fmt, output_dir=None):
    """Generiere den Ausgabepfad basierend auf Eingabe und Format."""
    input_path = Path(input_path)
    ext = FORMAT_EXTENSIONS.get(fmt, f".{fmt}")
    output_name = input_path.stem + ext

    if output_dir:
        return Path(output_dir) / output_name
    else:
        return input_path.parent / output_name


# ------------------------------------------------------------------
# CLI
# ------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="SKP/3D-Datei-Konvertierungstool fuer iMOPS",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Beispiele:
  %(prog)s model.skp --format usdz
  %(prog)s model.skp --format usdz obj dae
  %(prog)s /pfad/zu/dateien/ --format usdz --batch
  %(prog)s model.dae --format usdz --backend apple
  %(prog)s model.skp --format obj --blender-path /opt/blender/blender

Empfohlener Workflow fuer iOS:
  1. SKP-Datei aus SketchUp als DAE exportieren
  2. python %(prog)s modell.dae --format usdz
  3. USDZ-Datei in die iOS-App importieren
        """
    )

    parser.add_argument(
        "input",
        help="Eingabedatei oder Verzeichnis (bei --batch)"
    )
    parser.add_argument(
        "--format", "-f",
        nargs="+",
        required=True,
        choices=sorted(SUPPORTED_OUTPUT),
        help="Zielformat(e)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Ausgabedatei oder -verzeichnis (optional)"
    )
    parser.add_argument(
        "--batch", "-b",
        action="store_true",
        help="Alle 3D-Dateien im Verzeichnis konvertieren"
    )
    parser.add_argument(
        "--backend",
        choices=["blender", "apple", "trimesh"],
        help="Konvertierungs-Backend (automatisch wenn nicht angegeben)"
    )
    parser.add_argument(
        "--blender-path",
        help="Pfad zum Blender-Executable"
    )

    args = parser.parse_args()
    input_path = Path(args.input)

    # Batch-Modus: Verzeichnis verarbeiten
    if args.batch:
        if not input_path.is_dir():
            print(f"[FEHLER] Kein Verzeichnis: {input_path}")
            sys.exit(1)

        output_dir = Path(args.output) if args.output else input_path / "converted"
        files = [
            f for f in input_path.iterdir()
            if f.suffix.lower() in SUPPORTED_INPUT
        ]

        if not files:
            print(f"[INFO] Keine 3D-Dateien gefunden in: {input_path}")
            sys.exit(0)

        print(f"\n[BATCH] {len(files)} Dateien gefunden")
        print(f"[BATCH] Ausgabeverzeichnis: {output_dir}\n")

        success = 0
        failed = 0

        for f in sorted(files):
            for fmt in args.format:
                out = generate_output_path(f, fmt, output_dir)
                if convert_file(f, out, fmt, args.backend, args.blender_path):
                    success += 1
                else:
                    failed += 1

        print(f"\n[BATCH] Fertig: {success} erfolgreich, {failed} fehlgeschlagen")
        sys.exit(0 if failed == 0 else 1)

    # Einzeldatei-Modus
    else:
        if not input_path.is_file():
            print(f"[FEHLER] Datei nicht gefunden: {input_path}")
            sys.exit(1)

        all_success = True
        for fmt in args.format:
            if args.output and len(args.format) == 1:
                out = Path(args.output)
            else:
                out = generate_output_path(input_path, fmt, args.output)

            if not convert_file(input_path, out, fmt, args.backend,
                                args.blender_path):
                all_success = False

        sys.exit(0 if all_success else 1)


if __name__ == "__main__":
    main()
