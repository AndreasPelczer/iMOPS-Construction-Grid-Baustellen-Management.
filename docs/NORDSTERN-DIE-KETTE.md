# Nordstern 2 — Die Kette

*Angelegt am 22.09.2026 auf Andreas' Bitte: „diese Kette ist der neue Nordstern,
oder ein neuer Teil davon."*

---

## Der alte Nordstern hört da auf, wo dieser anfängt

**Nordstern 1 — „Zeichnung → Baustelle"** (`nordstern-zeichnung-zu-baustelle`):
Aus einem SketchUp-Modell wird eine geplante Baustelle. LV, Kalkulation, Erdmassen,
Maschinen, Brigade. Stand: ~60 % vorgebaut, der Job ist Verbinden.

**Nordstern 2 — „Die Kette"** (dieses Dokument):
Aus einer geplanten Baustelle wird **gebaute, nachgewiesene Arbeit**.

Beide zusammen sind ein Bogen: von der Zeichnung des Architekten bis zum Beleg,
dass es richtig gebaut wurde. Sie gehören zusammen und überschneiden sich nicht.

---

## Die Kette, Glied für Glied

```
  1  LV rein            GAEB · PDF · JSON                    ✅ steht
  2  Mops fass          Preise, Ampel                        ✅ steht
  3  Arbeitspakete      109 Positionen → 34 Pakete           ✅ steht
  4  Schritte           Katalog · Vorlage · Rezept · Prof    ✅ steht
  5  Zuteilen           wer, wie lange                       ✅ steht
  6  Material           Bedarf → Lager → Baustelle           ⚠️ halb
 ─────────────────────────────────────────────────────────────────────
  7  DRAUSSEN           abhaken · Foto · Problem melden      ❌ fehlt ganz
  8  Abnahme            der Polier nickt ab                  ❌ fehlt ganz
  9  Bautagesbericht    füllt sich aus 7 und 8               ⚠️ nur die Datenklasse
 10  Nachweis           wer hat was wann entschieden         ✅ steht (Uebergehung,
                                                                Sonderfall, Belege)
```

🔴 **Der Bruch liegt zwischen 6 und 7.** Alles bis dahin passiert am Schreibtisch auf
einem Apple-Gerät. Ab 7 steht jemand im Regen mit einem 70-Euro-Android. Das ist keine
Erweiterung der App — das ist die andere Hälfte.

---

## Der Teilsieg: **ein Auftrag, einmal ganz durch**

Nicht die ganze Kette auf einmal. **Ein einziges Arbeitspaket**, von der LV-Position
bis zum abgenommenen Nachweis, mit einem echten Menschen draußen.

Damit ist bewiesen:
- Der Weg funktioniert Ende zu Ende
- Die Übergabe zwischen Büro und Baustelle hält
- Der Bautagesbericht füllt sich von selbst
- Und der Nachweis steht, ohne dass jemand abends tippt

**Woran man den Teilsieg erkennt:** Am Abend steht im Bautagesbericht, was gemacht
wurde, wer es gemacht hat und wovon es belegt ist — und **niemand hat es getippt**.

Was danach kommt, ist Wiederholung. Das zweite Gewerk ist nur noch ein Katalog.

---

## Was dafür gebaut werden muss

| | Was | Aufwand |
|---|---|---|
| **A** | **Whatsmops** — die WebApp für alle ohne Apple-Gerät. 🔴 Kein React (388 KB), die Rollen-Mockups sind 8–11 KB. Zugang über Link + PIN. | groß, Neuland |
| **B** | **Backend** — Aufträge, Schritte, Fotos speichern; Zugänge; Rückweg in die iOS-App. `mops-api` hat heute 13 Routen, alle „Wissen/Auswerten", **keine Datenhaltung, kein Auth**. | groß, neu |
| **C** | **Offline + Sync** — auf der Baustelle ist kein Netz. Und der Mann MUSS sehen, dass es noch nicht oben ist. | mittel, heikel |
| **D** | **Bautagesbericht vorfüllen** — die 18 Felder stehen, alles wird getippt. | klein |
| **E** | **Material an den Auftrag** — heute hängt die Buchung an der Baustelle als Text. Ohne das kein Soll/Ist. | klein |

**Schätzung für einen ersten vollständigen Durchlauf: zwei bis vier Wochen**, bei
einem Tempo wie am 21./22.09. Offline-Sync und Zugänge sind die Sorte Arbeit, die
immer länger dauert.

---

## 🔴 Das Nadelöhr ist nicht der Code

Eine Kette „beweisen" heißt: **echte Baustelle, echte Leute, echte Fehler.** Ohne das
ist es eine Vorführung.

*(Andreas am 22.09.: der Baubeginn 29.09. bei BV Setiadji ist von ihm gesetzt, nicht
echt — also kein Termindruck von aussen. Der erste echte Durchlauf braucht trotzdem
eine laufende Baustelle.)*

Zweites Nadelöhr: **Fachwissen je Gewerk.** Raphi kann Hochbau. Für Sanitär, Elektro,
Heizung braucht es je einen, der gegenliest. Die Kataloge sind sonst geraten — und
ein erfundener Pflichtteil ist schlimmer als keiner.

---

## Womit es zusammenhängt

- `chatmops-bautagesbericht` — der Chat IST der Bautagesbericht (Glied 7–9)
- `boiler-fall-pflichtteile` — warum Glied 4 Fachwissen braucht
- `mopsmotor-haccp-9001` — der Rahmen über allem: HACCP-Grundsätze 1–7
- `nachunternehmer-im-mops` — Glied 7 hat zwei Oberflächen, nicht eine mit Schalter
- `uebergabe-sichern-herz-des-mops` — warum es die Kette überhaupt gibt
- `ankunfts-nachweis-nicht-uebergabe` — warum Glied 7 zeigen muss, was noch nicht oben ist
