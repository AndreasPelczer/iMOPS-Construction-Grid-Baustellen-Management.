import Foundation
import CoreData

struct MarktbreitSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let key = "marktbreit_efh_schwarz_seeded_v3"  // v3: Mengen aus Statik-Detaildaten

        let fetch: NSFetchRequest<Event> = Event.fetchRequest()
        fetch.predicate = NSPredicate(format: "eventNumber == %@", "I-25_448-GO")

        if let existing = try? context.fetch(fetch).first {
            // Event existiert schon — nur Mengen patchen wenn v3 noch nicht gelaufen
            guard !UserDefaults.standard.bool(forKey: key) else { return }
            patchPositionen(of: existing, in: context)
            saveAndMark(context: context, key: key, msg: "Mengen aus Statik-Detail aktualisiert (v3)")
            return
        }

        // Event existiert noch nicht — komplett neu anlegen
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        createEventWithPositionen(in: context)
        saveAndMark(context: context, key: key, msg: "EFH Schwarz Marktbreit: Event + 15 LV-Positionen angelegt (v3)")
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
            pos.posNr = daten.posNr
            pos.kostenGruppeNummer = daten.kg
            pos.bezeichnung = daten.bezeichnung
            pos.einheit = daten.einheit
            pos.menge = daten.menge
            pos.event = event
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
            if let pos = byPosNr[daten.posNr] {
                pos.bezeichnung = daten.bezeichnung
                pos.einheit = daten.einheit
                pos.menge = daten.menge
                pos.kostenGruppeNummer = daten.kg
            } else {
                let pos = LVPosition(context: context)
                pos.posNr = daten.posNr
                pos.kostenGruppeNummer = daten.kg
                pos.bezeichnung = daten.bezeichnung
                pos.einheit = daten.einheit
                pos.menge = daten.menge
                pos.event = event
            }
        }

        let v3Marker = "[v3-Statik-Detail]"
        if !(event.notes ?? "").contains(v3Marker) {
            event.notes = (event.notes ?? "") + "\n\n\(v3Marker) Mengen am \(Self.heute()) aus Statik-Detaildaten aktualisiert: " +
                "Decke 60,62 m² (mit Treppen-Aussparung), AW Keller 73 m², neue Position 3.30.2b für d=36,5cm-Bereich, " +
                "Stürze als laufende Meter (4,57 m gesamt)."
        }
    }

    // MARK: - LV-Daten (zentrale Quelle)

    private struct LVDaten {
        let posNr: String
        let kg: String
        let bezeichnung: String
        let einheit: String
        let menge: Double
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
                    einheit: "psch", menge: 1)
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
