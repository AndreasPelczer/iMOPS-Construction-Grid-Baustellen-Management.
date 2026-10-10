# Nordstern 2 — Die Kette

*Angelegt am 22.09.2026 auf Andreas' Bitte: „diese Kette ist der neue Nordstern,
oder ein neuer Teil davon."*

---

## Was der Mops eigentlich ist

Andreas am 22.09.2026, als ich anfing, vom Bau her zu denken:

> „du solltest doch auch langsam von der DNA des Mops durchdrungen sein. Eine
> Dokumentations-Wissensmonster-Rezeptmaschine, die zufällig auch Rohbau und
> Ausbildung von Maurern kann."

🔴 **Der Mops ist kein Bau-Programm, das nebenbei dokumentiert.** Er ist eine
Nachweis-Maschine, und Rohbau ist gerade nur das, was drinliegt. Darum ging die
Gastro-Wurzel so glatt mit — es ist dieselbe Mechanik unter verschiedenen Namen:

| Küche | Bau | Ausbildung |
|---|---|---|
| Rezept | Arbeitsauftrag | Lernziel aus dem Rahmenplan |
| Arbeitsschritte | Arbeitsschritte | zu vermittelnde Fertigkeit |
| Pass: abgegeben, angenommen | Übergabe: gemeldet, übernommen | gefragt, gezeigt |
| HACCP-Nachweis | Bautagesbericht | Berichtsheft |

Vier Spalten, **eine** Maschine. Wer das vergisst, baut für den Bau, was schon
für die Küche dasteht — und wundert sich, dass das Berichtsheft „plötzlich" fast
fertig ist. Es ist derselbe Vorgang, von der anderen Seite angeschaut.

Praktische Folge für jede Instanz: **bevor du etwas Neues für den Bau entwirfst,
frag, wie es in der Küche hiess.** Meistens gibt es das schon
(`frischer-kopf-unterschaetzt-den-code`).

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
| **B** | ~~**Backend** — groß, neu~~ → **kleiner als gedacht.** *Korrigiert am 22.09.:* Der Server liefert schon Web-Seiten aus (`/admin-ui/…`, echte Route mit Schloss davor), hat ein funktionierendes Türschloss (PBKDF2, fail-closed) und hängt über Cloudflare im Netz. **Die Ablage ist am 22.09. gebaut** (`api/services/ablage.py`, SQLite, 39 Tests) — Aufträge, Schritte und Fotos haben jetzt einen Ort. Offen bleiben: **Zugänge pro Person** (PIN statt einem Admin-Passwort) und der **Rückweg in die iOS-App**. | mittel |
| **C** | **Offline + Sync** — auf der Baustelle ist kein Netz. Und der Mann MUSS sehen, dass es noch nicht oben ist. | mittel, heikel |
| **D** | **Bautagesbericht vorfüllen** — die 18 Felder stehen, alles wird getippt. | klein |
| **E** | **Material an den Auftrag** — heute hängt die Buchung an der Baustelle als Text. Ohne das kein Soll/Ist. | klein |

**Schätzung für einen ersten vollständigen Durchlauf: zwei bis vier Wochen**, bei
einem Tempo wie am 21./22.09. Offline-Sync und Zugänge sind die Sorte Arbeit, die
immer länger dauert.

*22.09., nachmittags:* Der Bruch zwischen 6 und 7 ist angebohrt. Es gibt jetzt eine
**Ablage**, in der bleibt, was jemand bezeugt hat — und die erste Tür daran ist nicht
die Baustelle, sondern **Raphi in SketchUp**: der Mops liest sein Bauteil, sagt was er
verstanden hat, und stellt eine einzige wegklickbare Frage. Dieselbe Ablage trägt
später das Abhaken von draussen; `schritt_erledigt`, `schritt_abgenommen` und
`problem_gemeldet` sind dort schon vorgesehen. Zwei Türen, ein Ort.

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

---

## Am Horizont (10.10.2026): die eigene Cloud mit Offline-Ablage – Nextcloud auf der Box

Andreas: „das mit dem iCloud gefällt mir nicht“ → seit 10.10. ist der iMOPS-Ordner eine **Samba-Freigabe
auf der Box** (`smb://mops-box/imops`, nur Tailscale). Baustelle = Ordner: die Box legt beim Melden
`Baustellen/<Titel>/` mit den Fächern an. **Grenze:** ohne Netz ist die Freigabe nicht da – auf einer
Baustelle ohne Empfang fehlen die Dateien (die Daten der App sind offline da).

- **Nächster Schritt (klein):** „Offline mitnehmen“ je Baustelle in der App – vor der Fahrt die Unterlagen
  dieser einen Baustelle aufs Gerät holen, später abgleichen.
- **Nordstern (groß):** **Nextcloud auf der Box** – eigene Cloud mit Offline-Ablage, Teilen und Abgleich
  für alles, Datenhoheit wie bei Samba. Dann kann auch `MopsAblage` (heute noch iCloud) auf die eigene
  Cloud zeigen, und iPad, Mac, Raphi und der Mops sehen wirklich denselben Ordner – auch offline.
