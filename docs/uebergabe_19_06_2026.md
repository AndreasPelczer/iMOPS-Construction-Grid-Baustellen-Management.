# Übergabe und Statusprotokoll — 19. Juni 2026

> "Code lügt nicht, Fantasie schon. Wir bleiben am Boden der Tatsachen, der Commits und der echten Baustelle."

---

## 1. Was heute passiert ist (Meilensteine)

Heute haben wir die Brücke von der lokalen Python-Idee zu einer voll integrierten, kommerziellen iOS-App geschlagen.

### Welle 7: Geländebrücke (Vollständig implementiert)

**Backend (mops-api):** Neuer Endpoint POST /gelaendebruecke/calculate erstellt.
- Nimmt Vermessungs-DXF-Dateien entgegen.
- Nutzt ezdxf und numpy für IDW-Interpolation.
- Berechnet Cut/Fill (Aushub/Auftrag), OK-Bodenplatte, Schotter, Vlies und LKW-Fuhren.
- Generiert eine Base64-PNG-Heatmap für den PDF-Report.

**iOS-App:** EventDetailView erweitert.
- Datei-Picker für .dxf implementiert.
- Upload an die Mops-Box (192.168.2.42:8080).
- JSON-Antwort wird geparst und in der UI angezeigt.
- Brücke ins LV: Button "Ins LV übernehmen" schreibt Aushub, Schotter und Vlies automatisch als LVPosition in Core Data.
- PDF-Report: Button "PDF-Report erstellen" generiert ein A4-PDF mit Massen und Heatmap zum Versenden.

**Git:** PR #21 (Backend) und PR #67 (Frontend) erfolgreich gemergt.

### Welle 6: Kalkulation (MVP implementiert)

- **Core Data:** Entity LVPosition um Kalkulations-Relationships erweitert. NSManagedObject Subclasses neu generiert.
- **iOS-App:** Neue View LVKalkulationView.swift gebaut.
  - Zeigt alle LV-Positionen einer Baustelle.
  - Inline-Eingabefelder für Einkaufspreise.
  - Berechnet live Zeilensummen und die Gesamt-Angebotssumme (netto).
- **UI-Anbindung:** kalkulationCard in der EventDetailView verlinkt.
- **Git:** PR #68 auf main gemergt (via Feature-Branch feature/welle6-kalkulation).

---

## 2. Architektur-Reminder (Wo liegt was?)

### Frontend (Mac): Xcode-Projekt iMOPS-Construction-Grid-Baustellen-Management

| Merkmal | Wert |
|---------|------|
| Sprache | Swift / SwiftUI |
| Datenhaltung | Core Data (Offline-First) |
| Welle 7 UI | Views/EventDetailView.swift |
| Welle 6 UI | Views/LVKalkulationView.swift |
| Welle 7 Modell | Models/GelaendeResult.swift |

### Backend (Mops-Box): Repo mops-api (Ubuntu, 192.168.2.42)

| Merkmal | Wert |
|---------|------|
| Framework | FastAPI / Python |
| Server-Start | (venv) uvicorn api.main:app --reload --host 0.0.0.0 --port 8080 |
| Welle 7 Logik | api/routes/gelaendebruecke.py |
| Dependencies | ezdxf, numpy, matplotlib |

---

## 3. Der nächste Sprint (Welle 9 — Voraussetzungs-Ampel)

**Ziel:** Der Polier sieht auf einen Blick, ob er anfangen darf.

- [ROT] Rot: Baugenehmigung fehlt, Bodenplatte nicht da.
- [GRÜN] Grün: Alles da, Baufrei.
- **Wichtig:** Schätzwerte (aus Welle 7) müssen optisch anders markiert werden als gemessene Ist-Werte (aus Welle 5).

### Voraussetzungen für Welle 9

- [ERLEDIGT] Core-Data-Feld quelle bereits vorhanden als LVPosition.mengenQuelleRaw (gemergt via PR #54, "Welle-9-Basis"). Wird vom Import bereits persistiert (ExtractPlanMapper). Protokoll-Korrektur: ursprünglich als "temporär entfernt, nachzurüsten" notiert — ist bereits produktiv.
- [OFFEN] Hierarchie noch offen: Entscheidung echte Entities (Gebaeude/Geschoss) vs. strukturierte Felder.
- [OFFEN] Rollup-Logik bauen: Wenn Vorleistung A fehlt, ist Bauteil B rot (ReadinessManager).
- [OFFEN] Neue Header-Card AmpelCard in EventDetailView.
- [OFFEN] TheBrain an Core Data ankoppeln (läuft aktuell In-Memory/entkoppelt).

---

## 4. Arbeitsweise (The Mops Protocol)

- **Halbgas:** Erst messen, wo man ist, dann bauen, wohin man will. Kein Feature-Creep.
- **Chor und Agent:** Andreas baut das Vorderteil (Xcode/SwiftUI), der Mops baut den Motorraum (Python/Server/Snippets).
- **Git-Disziplin:** Direkte Pushes auf main sind via Hook blockiert. Immer feature/... Branch -> Push -> PR -> Merge.
- **Ehrlichkeit:** Ein "Ich denke, das funktioniert" reicht nicht. Nur ein grüner Build und ein erfolgreicher Test sind ein Zustand, den das System selbst trägt.

---

## 5. Referenzen

- Frontend-Repo: AndreasPelczer/iMOPS-Construction-Grid-Baustellen-Management.
- Backend-Repo: AndreasPelczer/mops-api
- Roadmap: docs/roadmap_wellen_5_bis_9.md
- Vorherige Übergaben: docs/uebergabe_04_06_2026.md, docs/uebergabe_05_06_2026.md, docs/uebergabe_09_06_2026.md
