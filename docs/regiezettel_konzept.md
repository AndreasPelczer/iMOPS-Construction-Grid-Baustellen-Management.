# Regiezettel & Abschlagsrechnung — Konzept-Notiz

*Aufgenommen am 9.6.2026 abends, Sofa-Modus, vor dem Wunsch-Day. Damit Andreas es vergessen kann.*

---

## Worum geht es

**Regiezettel** (= Stundenlohnzettel, Tagelohnzettel, Regierapport) sind das **Belegpapier für Arbeit, die nicht im Leistungsverzeichnis steht.**

Alles, was nicht über Einheitspreise abgerechnet wird, sondern über _tatsächliche Stunden + tatsächliches Material._

**Klassische Anlässe:**
- Nachträge vom Bauherrn („mach mir die Tür breiter")
- Schäden, die ein anderes Gewerk verursacht hat
- Untersuchungsarbeit („Wand öffnen, gucken, schließen")
- Altbau-Überraschungen
- Spontane Sonderwünsche, die keiner vorher kalkulieren konnte

**Pflicht-Inhalt:**
- Datum, Baustelle, Auftraggeber
- Name jedes Mannes + Stunden je Mann
- Konkrete Tätigkeitsbeschreibung (nicht „Sonstiges")
- Material: Art + Menge
- Eingesetzte Geräte/Maschinen mit Stunden
- **Unterschrift Auftraggeber / Bauleitung / Architekt** ← der teure Punkt
- Polier-Unterschrift

**Bauplatz-Gesetz:**
> _„Was nicht auf einem Zettel steht, ist nicht passiert."_

Ohne unterschriebenen Regiezettel = kein Geld. Häufigster Streitpunkt zwischen GU und Sub. Wer zu spät einreicht, von der falschen Person unterschreiben lässt, oder die Tätigkeit zu schwammig beschreibt — verliert. Vier- bis fünfstellig pro Bau, regelmäßig.

---

## Wer ist betroffen — die zwei Datenflüsse

Andreas's Frage am 9.6. klärte den Hauptirrtum: **„geht es um Abschlagsrechnungen für eigene Mitarbeiter oder Subunternehmer?"** — **Antwort: beides, aber auf unterschiedlichen Wegen.**

### Eigene Mitarbeiter

Sie selbst stellen **keine** Rechnung — sie bekommen Lohn. Aber **deine Firma** rechnet ihre Regie-Stunden an den Auftraggeber (Bauherr oder GU) ab — **genau auf der Abschlagsrechnung.** Der Regiezettel ist der **Beleg darunter.**

Beispiel: Maurer Karl macht 6h Wanddurchbruch außerhalb LV.
→ Karl kriegt seinen normalen Stundenlohn (interne Lohnabrechnung).
→ Polier schreibt Regiezettel: _„Karl Müller, 6h, Wanddurchbruch Achse B/3, 1× Sturz, 0,5h Mini-Bagger"_.
→ Bauleiter unterschreibt **noch am gleichen Tag** (sonst Theater).
→ Landet als Position in **deiner nächsten Abschlagsrechnung an den Bauherrn**, Regiezettel als Anlage.

### Subunternehmer

Der Sub stellt **selbst** eine Rechnung — an dich. Wenn er Regie-Arbeit macht: er führt **seinen eigenen** Regiezettel, lässt ihn von **deinem Polier unterschreiben** (= du bestätigst die Tat), legt ihn seiner Abschlagsrechnung an dich bei.

Du wiederum: reichst denselben Beleg **weiter** in deine Abschlagsrechnung an den Bauherrn — ggf. mit GU-Zuschlag.

### Die Mechanik in einem Bild

```
        Bauherr / GU
            ▲
            │  deine Abschlagsrechnung
            │  (mit Regiezetteln als Anlage)
            │
        DEINE FIRMA
        ▲       ▲
        │       │
   eigene     Sub-Rechnung
   Regie-     (mit Sub-Regiezetteln)
   Zettel
```

**Regiezettel = Fundament. Abschlagsrechnung = Dach. Ohne Fundament kein Dach.**

---

## Warum iMOPS das braucht — vier Gründe

1. **Polier ist eh vor Ort** — er ist der einzige, der wirklich weiß, was gemacht wurde und von wem. Wer sonst soll den Zettel schreiben?
2. **Daten liegen schon halb in iMOPS** — Mannschaft? Da. Material? Da (BuildIQ klassifiziert seit dem 9.6. via Prof). Baustelle? Da. Du fügst eigentlich nur Tätigkeit + Stunden + Unterschrift hinzu.
3. **Streitfall-Tilgung in Euro** — digitaler Beleg + digitale Unterschrift (PencilKit / Foto-mit-Unterschrift) löst genau die Geld-Lecks, die jeder Polier kennt. **Direkter Nutzen, sofort messbar.**
4. **Klarer Use-Case, kein Mammut-Paket** — andere Wellen sind groß; Regiezettel ist scharf abgegrenzt. Eine kleine, abgeschlossene Welle mit Tageserfolg.

---

## iMOPS-Datenmodell — erster Wurf (Skizze)

Same Beleg-Typ, **zwei Datenflüsse:**

| Quelle | Eingabe | Unterschrift | Ziel |
|---|---|---|---|
| **Eigene Crew** | Polier tippt / füllt direkt | Bauleiter/Architekt (extern) | Deine Abschlagsrechnung an Bauherr |
| **Sub** | Polier scannt eingehenden Zettel oder erfasst neu | Polier selbst (du!) | Sub-Rechnung an dich → weiter an Bauherr |

**Vorgeschlagenes Modell:**

```swift
struct Regiezettel {
    let id: UUID
    let baustelle: Baustelle.ID
    let datum: Date
    let quelle: Quelle  // .eigeneCrew | .subunternehmer(Sub.ID)
    let anlass: String
    let leistungen: [Leistung]    // (Mitarbeiter | Sub-Mitarbeiter, Stunden, Tätigkeit)
    let material: [MaterialPosten]  // wiederverwendet aus BuildIQ
    let geraete: [GeraetePosten]
    let unterschriften: [Unterschrift]  // PencilKit-Bytes + Name + Rolle + Zeitstempel
    let status: Status  // .entwurf | .unterschrieben | .abgerechnet
    let zugehoerigeAbschlagsrechnung: Abschlagsrechnung.ID?
}
```

**Pflichtfelder = Anti-Streit-Schutz** (analog zur Lösch-Sicherheit-Memory):
- Anlass darf nicht leer sein
- Mindestens 1 Leistung
- Unterschrift mit Rolle + Zeitstempel (nicht nachträglich änderbar)
- _„Roter Punkt"-Logik_: erst grün, wenn alle Pflichtfelder + mindestens eine externe Unterschrift da sind

---

## Wo im Wellen-Plan?

**Empfehlung: eigene Welle.** Nicht Sub von 5.x.

**Begründung:**
- Welle 5.x ist _Soll-vs-Ist auf LV-Basis_ (Aufmaß, Fortschritt, Mengen)
- Regiezettel ist **anderer Datenfluss** — _Zusatz-Erfassung neben dem LV_, mit Unterschrift als Pflicht-Artefakt
- Andere Datenklasse, andere Geste, andere Abrechnungs-Logik

**Nummer: offen.** Vorschlag morgen mit Andreas klären — vermutlich Welle 7 oder 8.

---

## Cluster-Erkenntnis: „Nicht-LV-Belege" als neue Halb-Etage

Heute (9.6.) sind **zwei neue Konzepte** aufgepoppt, die ein gemeinsames Muster zeigen:

| Konzept | Aufgekommen | Wesen |
|---|---|---|
| **Genehmigungs-Mappe** | 9.6. nachmittags | Pflicht-Belege, die _vor_ dem Baubeginn da sein müssen |
| **Regiezettel** | 9.6. abends | Pflicht-Belege, die _während_ der Bau-Ausführung anfallen |

Beide sind **keine LV-Positionen**, aber **ohne sie geht kein Geld / kein Bau.**

**Hypothese:** iMOPS bekommt eine eigene Konzept-Etage **„Nicht-LV-Belege"** — Welle 7 oder 8 — die Genehmigungen, Regiezettel, möglicherweise auch Stundennachweise allgemein, BG-Belege, Sicherheits-Unterweisungen u.ä. zusammenfasst.

Architektur-Klarheit: Wellen 1–6 = LV-getriebene Arbeit. Welle 7+ = Belege-getriebene Pflichten. Welle 9 = Ampel/Roter Punkt-Logik. Das ist ein sauberes geistiges Bild.

→ **Vertiefung am Donnerstag oder später besprechen.**

---

## Folge-Welle: Abschlagsrechnung

**Regiezettel ist Fundament. Abschlagsrechnung ist Dach.** Logische Reihenfolge:

1. **Erst:** Regiezettel-Welle (Erfassung + Unterschrift + Sammlung)
2. **Dann:** Abschlagsrechnung-Welle (Sammlungs-Bildschirm → Vorbereitung Rechnung → Export PDF/GAEB/X-Rechnung)

Beide Schritte zusammen wären eine Mammut-Welle. Getrennt sind sie zwei klare, jeweils mit Tageserfolg.

---

## Offene Fragen für Donnerstag (oder später)

1. **Wave-Nummer** — Welle 7 oder 8? Wie verträgt sich das mit dem bestehenden Wellen-Plan?
2. **Existiert das Konzept schon irgendwo im Repo?** (Mops hat nicht im gesamten Repo gegrept — Wunsch-Day-Schonung)
3. **Datenmodell-Detail:** sollen eigene Mitarbeiter aus einem bestehenden Personal-Stamm gepickt werden, oder freitext? (Wenn Stamm: dann ist auch Stunden-Statistik pro Mann denkbar — Bonus-Feature)
4. **PencilKit vs. Foto-Unterschrift** — was ist robuster im Baustellen-Alltag (Handschuhe, Nässe, Kälte)?
5. **Sub-Regiezettel:** scannen + OCR (Tesseract/Vision) oder manuell? — OCR-Pipeline existiert ja schon.
6. **Datenhoheit:** Regiezettel enthält Namen von Mitarbeitern + Bauherr. DSGVO-Schicht denken (Cloud vs. lokal).

---

## Status: geparkt

Andreas kann das vergessen. Liegt sicher im Repo. Wird Donnerstag oder später aufgegriffen — auf jeden Fall **nicht morgen** (Wunsch-Day bleibt frei).

Polier-Gesetz: **Erfasst, notiert, geplant → kann aus dem Kopf raus.**

🐶
