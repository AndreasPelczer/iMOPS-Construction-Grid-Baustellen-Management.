//
//  RaphaelStammdatenSeeder.swift
//  Echte Preise aus Raphaels Kalkulations-Software — VERTRAULICH.
//
//  ⚠️ Diese Werte sind reale Einkaufs- und Kalkulationspreise eines Betriebs.
//     Sie gehören in dieses firmeneigene Werkzeug und nirgendwo sonst hin:
//     nicht in Beispiele, nicht in Screenshots für Dritte, nicht nach außen.
//
//  ── Was hier bewiesen wird ───────────────────────────────────────────────────
//  Raphaels Software rechnet: **Li-Preis (roh) × Zuschlag = Kalkpreis.**
//  Nach diesem Seed rechnet der Mops dieselben Zahlen — mit denselben Eingangs-
//  werten. Das ist der Nachweis, dass die Kalkulationskette trägt.
//
//  ── Drei Modelle, drei verschiedene Wege (nachgemessen) ──────────────────────
//
//  Der Auftrag ging von einem einheitlichen Prinzip aus. Das Modell macht es
//  aber an drei Stellen verschieden:
//
//  **Lohn** trägt seinen Zuschlag SELBST:
//      Lohnsatz.berechnungBruttoEK = stundenlohn * zuschlagFaktor
//  Raphaels ZG 1 (175 %) gehört genau hierhin: 26,91 × 2,75 = 74,00 €/h.
//
//  **Material** trägt keinen eigenen Zuschlag. `preisProEinheit` ist der EK;
//  der Aufschlag kommt später über `FirmenSettings.zuschlagMaterial` im
//  `LVKalkulator`. Also 10,00 eintragen, damit der Mops 11,50 ausrechnet.
//
//  **Gerät** rechnet über Abschreibung, nicht über Zuschlag:
//      Geraet.kostenProStunde = anschaffungsKosten / nutzungsdauerStunden
//  Es gibt **kein Feld für einen Stundensatz**. Siehe die Notlösung unten.
//
//  ── ⚠️ Warum `zuschlagLohn` NICHT auf 1,75 gesetzt wird ──────────────────────
//
//  Der Auftrag nannte `zuschlagLohnProzent = 175`. Das wäre doppelt: Der
//  Lohnsatz trägt die 175 % bereits in seinem `zuschlagFaktor`. Käme der
//  Firmenzuschlag noch einmal darauf, rechnete der Mops
//
//      74,00 × 2,75 = 203,50 €/h
//
//  Die beiden sind verschiedene Ebenen. `Lohnsatz.zuschlagFaktor` sind die
//  Lohnnebenkosten (Raphaels ZG 1), `FirmenSettings.zuschlagLohn` ist der
//  Aufschlag auf die fertigen Selbstkosten. Hier steht er auf 0, weil 74,00 €/h
//  bereits Raphaels **Kalkpreis** ist — was darüber hinaus an Wagnis und Gewinn
//  aufzuschlagen wäre, ist eine offene Frage (Raphaels Werte dafür fehlen noch).
//
//  ── Was der Mops noch nicht kann ─────────────────────────────────────────────
//  Er kennt **drei** Zuschlagsgruppen. Raphael arbeitet mit **rund acht**:
//  zusätzlich Transport (0 %), Schalung (0 %), Sonstiges (5 %/0 %),
//  **Fremdleistung (10 %/0 %)** und mehrere Material-Gruppen (15 %/5 %/0 %).
//  Das nachzubauen ist eine Modell-Änderung und ein eigener Schritt — hier
//  werden nur die drei vorhandenen gefüllt.
//

import Foundation
import CoreData

enum RaphaelStammdatenSeeder {

    /// Legt die echten Stammdaten an, überschreibt aber nichts Bestehendes.
    ///
    /// Idempotent **über die Bezeichnung**, nicht über die Anzahl: Der
    /// `StammdatenSeeder` legt Demo-Werte an (Polier 32,00 €, Bagger 3t …).
    /// Die bleiben stehen; hier kommen Raphaels Sätze daneben. Ein Lauf über
    /// die Anzahl (`count == 0`) würde bei gefüllter Datenbank gar nichts tun.
    static func seedIfNeeded(context: NSManagedObjectContext) {
        seedZuschlaege()
        seedLohnsaetze(context: context)
        seedMaterialien(context: context)
        seedGeraete(context: context)

        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            context.rollback()
            print("RaphaelStammdatenSeeder: konnte nicht sichern — \(error)")
        }
    }

    // MARK: - Die Firmen-Zuschläge

    /// Raphaels Zuschlagsgruppen, soweit der Mops sie kennt.
    ///
    /// **`zuschlagJeKostenart` muss an sein**, sonst greifen die drei Sätze gar
    /// nicht — dann rechnet der `LVKalkulator` stattdessen Wagnis & Gewinn auf
    /// die Summe. Nachgemessen in `LVKalkulator.zuschlaege`.
    ///
    /// BGK und Wagnis & Gewinn bleiben unangetastet: Raphaels Werte dafür sind
    /// noch offen, und ein geratener Wert wäre schlimmer als der bisherige.
    private static func seedZuschlaege() {
        let d = UserDefaults.standard
        d.set(true, forKey: FirmenSettings.Keys.zuschlagJeKostenart)
        // ZG 6 „Material 1"
        d.set(0.15, forKey: FirmenSettings.Keys.zuschlagMaterial)
        // ZG 4/5 „Geräte"
        d.set(0.10, forKey: FirmenSettings.Keys.zuschlagGeraet)
        // Bewusst 0: die 175 % stecken schon im Lohnsatz (siehe Dateikopf).
        d.set(0.0,  forKey: FirmenSettings.Keys.zuschlagLohn)
    }

    // MARK: - Lohn

    /// Li-Preis und Faktor, nicht der fertige Kalkpreis.
    ///
    /// `berechnungBruttoEK = stundenlohn × zuschlagFaktor` liefert daraus den
    /// Wert, mit dem gerechnet wird. Der Faktor 2,75 ist Raphaels ZG 1
    /// (Betriebsmittellohn 1, 175 %).
    ///
    /// ⚠️ **Die Zahlen gehen auf ±1 Cent auf, nicht exakt.** Mit Faktor 2,75:
    /// 27,64 → 76,01 (angezeigt 76,00), 16,36 → 44,99 (angezeigt 45,00). Die
    /// Li-Preise sind offenbar gerundet dargestellt; die wahren Faktoren lägen
    /// bei 2,7496 bis 2,7506. Ein einheitlicher Faktor 2,75 ist ehrlicher als
    /// drei krumme Werte, die eine Genauigkeit vortäuschen. Wer centgenau gegen
    /// Raphaels Software abgleichen will, muss dort die Nachkommastellen prüfen.
    private static let loehne: [(name: String, li: Double, faktor: Double)] = [
        ("Meisterstunden",        27.64, 2.75),   // → 76,00
        ("Polierstunden",         27.64, 2.75),   // → 76,00
        ("Vorarbeiterstunden",    27.64, 2.75),   // → 76,00
        ("Spezialfacharbeiter",   26.91, 2.75),   // → 74,00
        ("Facharbeiter (Raphael)", 26.91, 2.75),  // → 74,00
        ("Lehrling 3. Lehrjahr",  16.36, 2.75),   // → 45,00
    ]

    private static func seedLohnsaetze(context: NSManagedObjectContext) {
        for l in loehne {
            let req: NSFetchRequest<Lohnsatz> = Lohnsatz.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "qualifikation == %@", l.name)
            guard (try? context.fetch(req))?.first == nil else { continue }

            let satz = Lohnsatz(context: context)
            satz.id = UUID()
            satz.qualifikation = l.name
            satz.stundenlohn = l.li
            satz.zuschlagFaktor = l.faktor
        }
    }

    // MARK: - Material

    /// `preisProEinheit` ist der **Li-Preis (EK)**, nicht der Kalkpreis.
    ///
    /// Nachgemessen: `MaterialHinzufuegenView` übernimmt ihn 1:1 als
    /// `PositionMaterial.einzelpreis`, und der Aufschlag kommt erst im
    /// `LVKalkulator` über `FirmenSettings.zuschlagMaterial` (0,15). Aus 10,00
    /// werden so die 11,50, die Raphaels Software zeigt.
    ///
    /// Trüge man hier den Kalkpreis ein, schlüge der Mops ein zweites Mal auf.
    private static let materialien: [(name: String, einheit: String, li: Double)] = [
        ("Schotter 0/32",                   "to", 10.00),   // → 11,50
        ("Schotter 16/32",                  "to", 25.00),   // → 28,75
        ("Splitt 2/8",                      "to",  2.90),   // →  3,34
        ("Mainsand 0/2",                    "m³", 95.29),   // → 109,58
        ("Beton B15",                       "m³", 104.58),  // → 120,27
        ("Auffüllmaterial Mineralgemisch",  "m²",  0.65),   // →  0,75
        ("Mutterboden",                     "m³", 15.00),   // → 17,25
    ]

    private static func seedMaterialien(context: NSManagedObjectContext) {
        for m in materialien {
            let req: NSFetchRequest<KalkMaterial> = KalkMaterial.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "name == %@", m.name)
            guard (try? context.fetch(req))?.first == nil else { continue }

            let mat = KalkMaterial(context: context)
            mat.id = UUID()
            mat.name = m.name
            mat.einheit = m.einheit
            mat.preisProEinheit = m.li
            mat.verbrauchProM2 = 0
            mat.verschnittProzent = 0      // Verschnitt gehört an die Position, nicht an den Stammsatz
            mat.letzteAktualisierung = Date()
        }
    }

    // MARK: - Gerät

    /// ⚠️ **Notlösung — das Modell hat kein Feld für einen Stundensatz.**
    ///
    /// `Geraet.kostenProStunde` ist berechnet:
    ///
    ///     anschaffungsKosten / nutzungsdauerStunden
    ///
    /// Raphaels Werte sind aber **Verrechnungssätze je Stunde**, keine
    /// Anschaffungspreise. Damit der Quotient stimmt, steht der Satz in
    /// `anschaffungsKosten` und die Nutzungsdauer auf **1**. Das ist keine
    /// Abschreibung mehr, sondern ein sichtbarer Platzhalter — absichtlich so
    /// gewählt, damit niemand die Zahl für einen echten Anschaffungspreis hält.
    ///
    /// Der bestehende `StammdatenSeeder` behilft sich anders und trägt
    /// Tagesmieten mit 8 Stunden ein (`Kran 450 € / 8 h`). Beides sind Krücken;
    /// ein eigenes Feld für den Verrechnungssatz fehlt.
    ///
    /// Die Li-Sätze stehen hier roh. Die 10 % (ZG 4/5) kommen über
    /// `FirmenSettings.zuschlagGeraet` obendrauf — 45,60 wird so zu 50,16.
    private static let geraete: [(name: String, li: Double)] = [
        ("Minibagger JCB 802, 2,9to", 37.20),   // → 40,92
        ("Bagger 9to",                45.60),   // → 50,16
        ("LKW 18to",                  45.60),   // → 50,16
        ("LKW mit Hänger",            55.20),   // → 60,72
        ("Rüttelplatte AT2000",       27.60),   // → 30,36
        ("Wackerstampfer",            25.00),   // → 27,50
        ("Autokran",                 115.00),   // → 126,50
    ]

    private static func seedGeraete(context: NSManagedObjectContext) {
        for g in geraete {
            let req: NSFetchRequest<Geraet> = Geraet.fetchRequest()
            req.fetchLimit = 1
            req.predicate = NSPredicate(format: "name == %@", g.name)
            guard (try? context.fetch(req))?.first == nil else { continue }

            let ger = Geraet(context: context)
            ger.id = UUID()
            ger.name = g.name
            ger.anschaffungsKosten = g.li          // siehe Hinweis oben: kein Anschaffungspreis
            ger.nutzungsdauerStunden = 1           // Platzhalter, damit der Quotient = Stundensatz
            ger.notiz = "Verrechnungssatz je Stunde (Li). "
                      + "Das Modell hat kein Feld dafür — Nutzungsdauer 1 ist ein Platzhalter."
        }
    }
}
