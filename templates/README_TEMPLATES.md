# Excel/CSV-Vorlagen für Baustellenplanung

## 📋 Übersicht

Diese Vorlagen dienen als Input für das SketchUp-Plugin. Sie definieren alle Parameter einer Baustelle, die dann automatisch in 3D visualisiert werden.

---

## 📁 Verfügbare Vorlagen

### `baustelle_vorlage.csv`
**Hauptvorlage für Baustellenzonen**

#### Spalten-Beschreibung:

| Spalte | Typ | Pflicht | Beschreibung | Beispiel |
|--------|-----|---------|--------------|----------|
| **Zonen-Name** | Text | ✅ | Eindeutiger Name der Zone | "Kranbereich Nord" |
| **X-Position** | Zahl | ✅ | X-Koordinate (in Metern) | 10 |
| **Y-Position** | Zahl | ✅ | Y-Koordinate (in Metern) | 10 |
| **Breite** | Zahl | ✅ | Breite der Zone (in Metern) | 20 |
| **Höhe** | Zahl | ✅ | Höhe/Länge der Zone (in Metern) | 20 |
| **Risiko-Level** | Text | ✅ | `niedrig` / `mittel` / `hoch` / `sehr-hoch` / `sicher` | "hoch" |
| **Erforderliche-PSA** | Text | ❌ | Persönliche Schutzausrüstung (getrennt mit `\|`) | "Helm\|Sicherheitsschuhe" |
| **Zugangs-Beschränkung** | Text | ❌ | Erforderliche Qualifikation | "Kranführerschein" |

#### Risiko-Level → Farben (SketchUp-Darstellung):
- `sicher` → 🟦 Blau
- `niedrig` → 🟢 Grün
- `mittel` → 🟡 Gelb
- `hoch` → 🟠 Orange
- `sehr-hoch` → 🔴 Rot

---

## 🎯 Anwendungsbeispiel

### 1. Vorlage ausfüllen
```csv
Zonen-Name,X-Position,Y-Position,Breite,Höhe,Risiko-Level,Erforderliche-PSA,Zugangs-Beschränkung
Kranbereich,10,10,20,20,hoch,"Helm|Warnweste",Kranführerschein
Lagerplatz,50,30,15,10,niedrig,"Helm",Keine
```

### 2. In SketchUp importieren
- SketchUp öffnen
- Menü: `Plugins` → `Construction Grid: Importieren`
- CSV-Datei auswählen
- **→ 3D-Modell wird automatisch generiert**

### 3. JSON exportieren
- Menü: `Plugins` → `Construction Grid: JSON Export`
- Datei speichern
- **→ An iMOPS-App übergeben**

---

## 📐 Koordinaten-System

```
     Y (Höhe)
     ↑
     |
     |    [Zone]
     |     ┌─────┐
     |     │     │  Breite →
     |     └─────┘
     |
     └──────────────→ X (Breite)
   (0,0)

Ursprung (0,0) = Südwest-Ecke der Baustelle
```

---

## ✅ Validierungs-Regeln

Das SketchUp-Plugin prüft:
- ✅ Alle Pflichtfelder ausgefüllt
- ✅ X/Y/Breite/Höhe sind positive Zahlen
- ✅ Risiko-Level ist gültiger Wert
- ✅ Zonen-Name ist eindeutig
- ⚠️ Zonen überlappen sich nicht (Warnung, kein Fehler)

---

## 🚀 Erweiterte Vorlagen (Future)

### `baustelle_equipment.csv` (geplant)
Für Krane, Gerüste, Container, etc.
```csv
Equipment-Name,Typ,X-Position,Y-Position,Höhe,Radius,Inspektions-Intervall
Turmdrehkran-1,Kran,20,20,35,25,wöchentlich
Baucontainer-Büro,Container,85,70,3,0,monatlich
```

### `baustelle_zufahrten.csv` (geplant)
Für Tore, Eingänge, Notausgänge
```csv
Zufahrt-Name,Typ,X-Position,Y-Position,Breite,Check-In-Pflicht
Haupttor,Fahrzeug-Tor,0,40,6,Ja
Fußgänger-Eingang,Fußgänger-Tor,0,55,2,Ja
Notausgang-Nord,Notausgang,50,0,2,Nein
```

---

## 💡 Best Practices

1. **Eindeutige Namen:** Jede Zone braucht einen einzigartigen Namen
2. **Realistische Maße:** 1 Einheit = 1 Meter (SketchUp-Standard)
3. **Sicherheitszonen:** Hochrisiko-Bereiche großzügig dimensionieren
4. **PSA klar definieren:** Verwende standardisierte Begriffe
5. **Regelmäßig speichern:** CSV-Datei versionieren (Git)

---

## 🔧 Troubleshooting

**Problem:** Import schlägt fehl
**Lösung:** Prüfe, ob alle Pflichtfelder ausgefüllt sind

**Problem:** Zonen werden nicht angezeigt
**Lösung:** X/Y/Breite/Höhe müssen > 0 sein

**Problem:** Falsche Farben
**Lösung:** Risiko-Level exakt schreiben (Kleinschreibung!)

---

## 📞 Support

Bei Fragen zum Ausfüllen der Vorlagen:
- GitHub Issues: [iMOPS-Construction-Grid Issues](https://github.com/AndreasPelczer/iMOPS-Construction-Grid-Baustellen-Management/issues)
- Oder direkt an Raphael wenden
