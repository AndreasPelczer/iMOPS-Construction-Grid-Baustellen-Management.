import Foundation
import CoreData

struct MarktbreitSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let key = "marktbreit_efh_schwarz_seeded_v4"  // v4: + Goldschmitt-Zusatzarbeiten (KG 390/500)

        let fetch: NSFetchRequest<Event> = Event.fetchRequest()
        fetch.predicate = NSPredicate(format: "eventNumber == %@", "I-25_448-GO")

        if let existing = try? context.fetch(fetch).first {
            // Event existiert schon — Positionen idempotent abgleichen, wenn v4 noch nicht gelaufen
            guard !UserDefaults.standard.bool(forKey: key) else { return }
            patchPositionen(of: existing, in: context)
            saveAndMark(context: context, key: key, msg: "EFH Schwarz Marktbreit: Goldschmitt-Zusatzarbeiten ergänzt (v4)")
            return
        }

        // Event existiert noch nicht — komplett neu anlegen
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        createEventWithPositionen(in: context)
        saveAndMark(context: context, key: key, msg: "EFH Schwarz Marktbreit: Event + 24 LV-Positionen angelegt (v4)")
    }

    // MARK: - Event neu anlegen

    private static func createEventWithPositionen(in context: NSManagedObjectContext) {
        let event = Event(context: context)
        event.title = "EFH T&C Aura 125 – Marktbreit"
        event.name = "EFH Schwarz Marktbreit"
        event.eventNumber = "I-25_448-GO"
        event.location = "Neuenbergstraße 1, 97340 Marktbreit"
        event.bauherr = "Angelika Schwarz, Bahnhofstr. 40, 97346 Iphofen"
        event.architekt = "ProLa GmbH, Bismarckstraße 40 D, 72764 Reutlingen"
        event.baugenehmigungNr = ""
        event.notes = """
            Typenhaus T&C Aura 125. Tragwerksplanung Neubauer Ingenieurgesellschaft. \
            Statik vom 05.03.2026. Projekt-Nr. I-25_448-GO / TC 67774. \
            Decke (Pos 6.1): 10,26 x 6,26 m mit Treppen-Aussparung ~3,6 m², d=20cm. \
            Satteldach 20°/20°, UG+EG+DG. Standort: WZ 1, SLZ 1, sk=0,65 kN/m². \
            Bayern, Gemeinde 09675147. \
            HINWEIS: Zwei Keller-AW-Stärken — d=24cm (Pos 7.2) UND d=36,5cm (Pos 7.3)! \
            BourdainGuard: Mauerwerk-Typen unterscheiden, drei deckengleiche Stürze nicht vergessen.
            """
        event.timeStamp = Date()
        event.eventStartTime = Date()

        for daten in lvDaten() {
            let pos = LVPosition(context: context)
            pos.event = event
            applyDaten(daten, to: pos, in: context)
        }
    }

    // MARK: - Bestehende Positionen patchen

    private static func patchPositionen(of event: Event, in context: NSManagedObjectContext) {
        let bestehende = (event.lvPositionen as? Set<LVPosition>) ?? []
        var byPosNr: [String: LVPosition] = [:]
        for pos in bestehende {
            if let nr = pos.posNr { byPosNr[nr] = pos }
        }

        for daten in lvDaten() {
            let pos = byPosNr[daten.posNr] ?? {
                let neu = LVPosition(context: context)
                neu.event = event
                return neu
            }()
            applyDaten(daten, to: pos, in: context)
        }

        let v3Marker = "[v3-Statik-Detail]"
        if !(event.notes ?? "").contains(v3Marker) {
            event.notes = (event.notes ?? "") + "\n\n\(v3Marker) Mengen am \(Self.heute()) aus Statik-Detaildaten aktualisiert: " +
                "Decke 60,62 m² (mit Treppen-Aussparung), AW Keller 73 m², neue Position 3.30.2b für d=36,5cm-Bereich, " +
                "Stürze als laufende Meter (4,57 m gesamt)."
        }

        let v4Marker = "[v4-Goldschmitt]"
        if !(event.notes ?? "").contains(v4Marker) {
            event.notes = (event.notes ?? "") + "\n\n\(v4Marker) Goldschmitt-Zusatzarbeiten (Angebot 24.03.2026, BV 2026-011) " +
                "als KG-390/500-Pauschalen ergänzt: 9 Titel, 59.132,61 € netto / 70.367,81 € brutto."
        }
    }

    // MARK: - Felder + Pauschal-Unterposition setzen (idempotent)

    private static let nuMaterialName = "Fremdleistung NU Goldschmitt"

    /// Überträgt LV-Daten auf eine Position. Bei Pauschalpositionen (`pauschalNetto != nil`)
    /// wird der Betrag als NU-Material-Unterposition hinterlegt (Preisträger für den
    /// `LVKalkulator`) und Wagnis+Gewinn / BGK auf 0 gesetzt — ein NU-Endpreis bekommt
    /// keinen Eigen-Aufschlag. Idempotent: vorhandene NU-Unterposition wird wiederverwendet,
    /// nicht dupliziert.
    private static func applyDaten(_ daten: LVDaten, to pos: LVPosition, in context: NSManagedObjectContext) {
        pos.posNr = daten.posNr
        pos.kostenGruppeNummer = daten.kg
        pos.bezeichnung = daten.bezeichnung
        pos.einheit = daten.einheit
        pos.menge = daten.menge

        guard let netto = daten.pauschalNetto else { return }

        // Nachunternehmer-Durchleitung: bewusst OHNE Zuschlag. `zuschlagEigen` muss
        // dazu gesetzt sein, sonst greifen die Firmenwerte und die Pauschale bekaeme
        // stillschweigend 20 % aufgeschlagen.
        pos.zuschlagEigen = true
        pos.wagnisGewinnProzent = 0
        pos.bgkProzent = 0

        let material = pos.materialArray.first { $0.materialName == nuMaterialName }
            ?? {
                let m = PositionMaterial(context: context)
                m.id = UUID()
                m.materialName = nuMaterialName
                m.position = pos
                return m
            }()
        material.mengeProEinheit = 1
        material.einzelpreis = netto
        material.verschnittProzent = 0
        material.einheit = "psch"
    }

    // MARK: - LV-Daten (zentrale Quelle)

    private struct LVDaten {
        let posNr: String
        let kg: String
        let bezeichnung: String
        let einheit: String
        let menge: Double
        /// Netto-Pauschalbetrag (€) für Fremdleistungs-/NU-Positionen.
        /// nil = klassische Mengen-Position ohne hinterlegten Preis.
        var pauschalNetto: Double? = nil
    }

    private static func lvDaten() -> [LVDaten] {
        return [
            // KG 320 – Gründung
            LVDaten(posNr: "3.20.1", kg: "320",
                    bezeichnung: "Streifenfundament Außenwand bewehrt, b=37cm, d=16cm",
                    einheit: "m", menge: 33.0),
            LVDaten(posNr: "3.20.2", kg: "320",
                    bezeichnung: "Streifenfundament Innenwand bewehrt (Pos 8.2 + 8.3)",
                    einheit: "m", menge: 15.0),
            LVDaten(posNr: "3.20.3", kg: "320",
                    bezeichnung: "Sohlplatte Stahlbeton d=16cm (mit Treppen-Aussparung)",
                    einheit: "m²", menge: 60.62),

            // KG 330 – Außenwände
            LVDaten(posNr: "3.30.1", kg: "330",
                    bezeichnung: "Außenmauerwerk Porenbeton PP 2-0.35, d=24cm (EG + Kniestock + Giebel)",
                    einheit: "m²", menge: 113.0),
            LVDaten(posNr: "3.30.2", kg: "330",
                    bezeichnung: "Kelleraußenwand PP 4-0.55, d=24cm (Pos 7.2, lokal)",
                    einheit: "m²", menge: 35.0),
            LVDaten(posNr: "3.30.2b", kg: "330",
                    bezeichnung: "Kelleraußenwand PP 4-0.55 verstärkt, d=36,5cm (Pos 7.3)",
                    einheit: "m²", menge: 31.0),
            LVDaten(posNr: "3.30.3", kg: "330",
                    bezeichnung: "Stahlbetonstütze in Keller-Außenwand (Pos 7.2.1 + 7.3.1)",
                    einheit: "Stk", menge: 2),

            // KG 340 – Innenwände
            LVDaten(posNr: "3.40.1", kg: "340",
                    bezeichnung: "Innenmauerwerk Porenbeton PP 4-0.50, d=17,5cm",
                    einheit: "m²", menge: 67.0),

            // KG 350 – Decken & Ringbalken
            LVDaten(posNr: "3.50.1", kg: "350",
                    bezeichnung: "Filigran-Elementdecke über UG, d=20cm (mit Treppen-Aussparung)",
                    einheit: "m²", menge: 60.62),
            LVDaten(posNr: "3.50.2", kg: "350",
                    bezeichnung: "Ringbalken Stahlbeton C 20/25, d=17cm + XPS-Schalung 7cm",
                    einheit: "m", menge: 33.0),
            LVDaten(posNr: "3.50.3", kg: "350",
                    bezeichnung: "Deckengleicher Balken als Fenstersturz (Pos 6.2: 1,69m / 6.3: 1,19m / 6.4: 1,69m)",
                    einheit: "m", menge: 4.57),

            // KG 360 – Dach
            LVDaten(posNr: "3.60.1", kg: "360",
                    bezeichnung: "Fachwerkbinder Dachstuhl Satteldach 20°/20°",
                    einheit: "Stk", menge: 14),
            LVDaten(posNr: "3.60.2", kg: "360",
                    bezeichnung: "Dacheindeckung inkl. Lattung",
                    einheit: "m²", menge: 82.0),
            LVDaten(posNr: "3.60.3", kg: "360",
                    bezeichnung: "Untergurt-Ausbau: Holzwerkstoffplatte + Mineralwolldämmung 24cm + GK + Dampfbremse",
                    einheit: "m²", menge: 60.62),

            // KG 440 – PV-Vorrüstung
            LVDaten(posNr: "4.40.1", kg: "440",
                    bezeichnung: "PV-Vorrüstung Dachfläche (statisch berücksichtigt, 0,20 kN/m²)",
                    einheit: "psch", menge: 1),

            // KG 390/500 – Goldschmitt-Zusatzarbeiten (Außenanlagen + Erdbau)
            // Angebot G. Goldschmitt Bau GmbH vom 24.03.2026 (BV-Nr. 2026-011), VOB-Ausführung.
            // Als Fremdleistungs-Pauschalen modelliert: NU-Endpreis netto, daher wg=0 / bgk=0
            // (kein Eigen-Aufschlag auf einen fremd kalkulierten Festpreis).
            // Titel 05 + 09 fehlen in Goldschmitts Original-Nummerierung — vermutlich aus der
            // Standard-LV-Vorlage ausgelassen, kein Grund im Angebot vermerkt.
            // Summe der 9 Titel = 59.132,61 € netto (= 70.367,81 € brutto).
            // Baustelleneinrichtung → KG 390 (KG 391 existiert nicht im DIN276-Katalog der App).
            LVDaten(posNr: "3.90.1", kg: "390",
                    bezeichnung: "Baustelleneinrichtung (An-/Abfuhr, Bau-WC, Bauzaun 21m, 5 Monate)",
                    einheit: "psch", menge: 1, pauschalNetto: 1549.21),
            LVDaten(posNr: "5.10.1", kg: "510",
                    bezeichnung: "Erdarbeiten allgemein (Mutterboden, Schnurgerüst, Aushub BK 3-5, Verfüllung, Schotterpolster)",
                    einheit: "psch", menge: 1, pauschalNetto: 15164.77),
            LVDaten(posNr: "5.50.1", kg: "550",
                    bezeichnung: "Entwässerung außerhalb (DN100/150 PVC, Schächte, Drainage, Sickergrube, Birco-Rinne)",
                    einheit: "psch", menge: 1, pauschalNetto: 7798.17),
            LVDaten(posNr: "5.31.1", kg: "531",
                    bezeichnung: "Terrasse + Weg (Schotter 0/32, Keramikplatten 60×60×2 beige, Leistensteine, Kabuflex)",
                    einheit: "psch", menge: 1, pauschalNetto: 4833.34),
            LVDaten(posNr: "5.30.1", kg: "530",
                    bezeichnung: "Spritzschutz (Leistensteine 18m, Mainkies 16/32)",
                    einheit: "psch", menge: 1, pauschalNetto: 1841.94),
            LVDaten(posNr: "5.50.2", kg: "550",
                    bezeichnung: "Hausanschlüsse (Rohrgrabenaushub, MSE 4-fach, 60m Leerrohre DN100)",
                    einheit: "psch", menge: 1, pauschalNetto: 4875.10),
            LVDaten(posNr: "5.43.1", kg: "543",
                    bezeichnung: "Stützmauer Carport (Statik + Fundament + Stb-Wand 24cm 2-schalig FT, Ortbeton C25/30 XC4/XF1, ~650kg Stahl)",
                    einheit: "psch", menge: 1, pauschalNetto: 13842.01),
            LVDaten(posNr: "5.33.1", kg: "533",
                    bezeichnung: "Stellplatz pflastern (Ausstellungspflaster Muschelkalk Nr. 3, 36 m²)",
                    einheit: "psch", menge: 1, pauschalNetto: 3101.38),
            LVDaten(posNr: "5.43.2", kg: "543",
                    bezeichnung: "Mauerscheiben (7 Stück: Typ 80/105/155/180/230×2/305, je 99cm breit)",
                    einheit: "psch", menge: 1, pauschalNetto: 6126.69)
        ]
    }

    // MARK: - Helpers

    private static func saveAndMark(context: NSManagedObjectContext, key: String, msg: String) {
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print(msg)
        } catch {
            print("MarktbreitSeeder Fehler: \(error)")
        }
    }

    private static func heute() -> String {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: Date())
    }
}
