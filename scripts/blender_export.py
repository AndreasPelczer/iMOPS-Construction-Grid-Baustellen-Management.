"""
blender_export.py - Blender-internes Skript fuer 3D-Datei-Konvertierung.

Dieses Skript wird von convert_skp.py via Blender im Headless-Modus aufgerufen.
Es importiert 3D-Dateien (SKP, OBJ, DAE, FBX, STL, glTF) und exportiert sie
in das gewuenschte Zielformat (USDZ, OBJ, DAE, FBX, STL, glTF).

Verwendung (intern, wird von convert_skp.py aufgerufen):
    blender --background --python blender_export.py -- \
        --input /pfad/zur/datei.skp \
        --output /pfad/zur/ausgabe.usdz \
        --format usdz

Unterstuetzte Import-Formate:
    - .skp  (SketchUp - benoetigt SketchUp-Importer-Addon in Blender)
    - .obj  (Wavefront OBJ)
    - .dae  (Collada)
    - .fbx  (FBX)
    - .stl  (STL)
    - .gltf/.glb (glTF)

Unterstuetzte Export-Formate:
    - .usdz (Universal Scene Description - Apple-nativ)
    - .usdc (USD Crate)
    - .obj  (Wavefront OBJ)
    - .dae  (Collada)
    - .fbx  (FBX)
    - .stl  (STL)
    - .gltf/.glb (glTF)
"""

import sys
import os
import argparse


def parse_args():
    """Parse Kommandozeilen-Argumente (nach dem '--' Separator von Blender)."""
    # Blender uebergibt eigene Argumente vor '--', unsere kommen danach
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    parser = argparse.ArgumentParser(
        description="Blender-basierte 3D-Datei-Konvertierung"
    )
    parser.add_argument(
        "--input", "-i",
        required=True,
        help="Pfad zur Eingabedatei"
    )
    parser.add_argument(
        "--output", "-o",
        required=True,
        help="Pfad zur Ausgabedatei"
    )
    parser.add_argument(
        "--format", "-f",
        required=True,
        choices=["usdz", "usdc", "obj", "dae", "fbx", "stl", "gltf", "glb"],
        help="Zielformat"
    )
    return parser.parse_args(argv)


def clear_scene():
    """Loesche alle Objekte aus der Blender-Szene."""
    import bpy

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    # Auch verwaiste Daten loeschen
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in bpy.data.textures:
        if block.users == 0:
            bpy.data.textures.remove(block)
    for block in bpy.data.images:
        if block.users == 0:
            bpy.data.images.remove(block)


def import_file(filepath):
    """
    Importiere eine 3D-Datei in Blender.
    Gibt True zurueck bei Erfolg, False bei Fehler.
    """
    import bpy

    ext = os.path.splitext(filepath)[1].lower()
    print(f"[blender_export] Importiere: {filepath} (Format: {ext})")

    try:
        if ext == ".skp":
            # SketchUp-Import benoetigt ein Addon/Extension
            # Versuche bekannte Addon-Namen zu aktivieren
            skp_addon_names = [
                "io_import_sketchup",
                "sketchup_importer",
                "import_sketchup",
            ]
            for addon_name in skp_addon_names:
                try:
                    bpy.ops.preferences.addon_enable(module=addon_name)
                    print(f"[blender_export] SKP-Addon '{addon_name}' aktiviert")
                    break
                except Exception:
                    continue

            # Jetzt den Import versuchen
            try:
                bpy.ops.import_scene.skp(filepath=filepath)
                print("[blender_export] SKP-Import via Addon erfolgreich")
            except AttributeError:
                msg = (
                    "[blender_export] FEHLER: SketchUp-Importer nicht gefunden!\n"
                    "  Bitte oeffne Blender -> Edit -> Preferences -> Get Extensions\n"
                    "  und installiere einen SketchUp-Importer.\n"
                    "  Dann den Server neu starten."
                )
                print(msg, file=sys.stderr)
                return False

        elif ext == ".obj":
            # Blender 4.x: neuer OBJ-Importer
            if hasattr(bpy.ops.wm, "obj_import"):
                bpy.ops.wm.obj_import(filepath=filepath)
            else:
                # Blender 3.x Fallback
                bpy.ops.import_scene.obj(filepath=filepath)

        elif ext == ".dae":
            bpy.ops.wm.collada_import(filepath=filepath)

        elif ext == ".fbx":
            bpy.ops.import_scene.fbx(filepath=filepath)

        elif ext == ".stl":
            if hasattr(bpy.ops.wm, "stl_import"):
                bpy.ops.wm.stl_import(filepath=filepath)
            else:
                bpy.ops.import_mesh.stl(filepath=filepath)

        elif ext in (".gltf", ".glb"):
            bpy.ops.import_scene.gltf(filepath=filepath)

        else:
            print(f"[blender_export] FEHLER: Unbekanntes Format: {ext}", file=sys.stderr)
            return False

        print(f"[blender_export] Import erfolgreich: "
              f"{len(bpy.data.objects)} Objekte geladen")
        return True

    except Exception as e:
        print(f"[blender_export] FEHLER beim Import: {e}", file=sys.stderr)
        return False


def export_file(filepath, fmt):
    """
    Exportiere die aktuelle Blender-Szene in das Zielformat.
    Gibt True zurueck bei Erfolg, False bei Fehler.
    """
    import bpy

    # Sicherstellen, dass das Ausgabeverzeichnis existiert
    out_dir = os.path.dirname(filepath)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)

    print(f"[blender_export] Exportiere nach: {filepath} (Format: {fmt})")

    try:
        if fmt in ("usdz", "usdc"):
            # USD-Export (Blender 3.0+)
            if not hasattr(bpy.ops.wm, "usd_export"):
                print(
                    "[blender_export] FEHLER: USD-Export nicht verfuegbar. "
                    "Blender 3.0+ erforderlich.",
                    file=sys.stderr
                )
                return False
            bpy.ops.wm.usd_export(
                filepath=filepath,
                export_textures=True,
                generate_preview_surface=True,
                export_materials=True,
            )

        elif fmt == "obj":
            if hasattr(bpy.ops.wm, "obj_export"):
                bpy.ops.wm.obj_export(filepath=filepath)
            else:
                bpy.ops.export_scene.obj(filepath=filepath)

        elif fmt == "dae":
            bpy.ops.wm.collada_export(filepath=filepath)

        elif fmt == "fbx":
            bpy.ops.export_scene.fbx(filepath=filepath)

        elif fmt == "stl":
            if hasattr(bpy.ops.wm, "stl_export"):
                bpy.ops.wm.stl_export(filepath=filepath)
            else:
                bpy.ops.export_mesh.stl(filepath=filepath)

        elif fmt in ("gltf", "glb"):
            export_format = "GLB" if fmt == "glb" else "GLTF_SEPARATE"
            bpy.ops.export_scene.gltf(
                filepath=filepath,
                export_format=export_format
            )

        else:
            print(f"[blender_export] FEHLER: Unbekanntes Export-Format: {fmt}", file=sys.stderr)
            return False

        print(f"[blender_export] Export erfolgreich: {filepath}")
        return True

    except Exception as e:
        print(f"[blender_export] FEHLER beim Export: {e}", file=sys.stderr)
        return False


def main():
    args = parse_args()

    input_path = os.path.abspath(args.input)
    output_path = os.path.abspath(args.output)

    if not os.path.exists(input_path):
        print(f"[blender_export] FEHLER: Eingabedatei nicht gefunden: "
              f"{input_path}", file=sys.stderr)
        sys.exit(1)

    # Szene leeren
    clear_scene()

    # Importieren
    if not import_file(input_path):
        sys.exit(1)

    # Exportieren
    if not export_file(output_path, args.format):
        sys.exit(1)

    print("[blender_export] Konvertierung abgeschlossen!")
    sys.exit(0)


if __name__ == "__main__":
    main()
