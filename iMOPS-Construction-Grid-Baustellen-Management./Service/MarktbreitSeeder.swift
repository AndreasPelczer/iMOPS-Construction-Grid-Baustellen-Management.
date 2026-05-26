import Foundation
import CoreData

struct MarktbreitSeeder {

    static func seedIfNeeded(context: NSManagedObjectContext) {
        let key = "marktbreit_efh_schwarz_seeded_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let fetch: NSFetchRequest<Event> = Event.fetchRequest()
        fetch.predicate = NSPredicate(format: "eventNumber == %@", "I-25_448-GO")
        if (try? context.count(for: fetch)) ?? 0 > 0 { return }

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
            Gebaeude 6,50 x 10,50 m, Satteldach 20°/20°, UG+EG+DG. \
            Standort: WZ 1, SLZ 1, sk=0,65 kN/m². Bayern, Gemeinde 09675147.
            """
        event.timeStamp = Date()
        event.eventStartTime = Date()

        let positionen: [(String, String, String, String, Double)] = [
            ("3.20.1", "320", "Streifenfundament Aussenwand bewehrt, b=37cm, d=16cm", "m", 0),
            ("3.20.2", "320", "Streifenfundament Innenwand bewehrt", "m", 0),
            ("3.20.3", "320", "Sohlplatte Stahlbeton d=16cm", "m²", 0),
            ("3.30.1", "330", "Aussenmauerwerk Porenbeton PP 2-0.35, d=24cm", "m²", 0),
            ("3.30.2", "330", "Aussenmauerwerk verstaerkt PP 4-0.55, d=24cm (lokal nach Statik)", "m²", 0),
            ("3.30.3", "330", "Stahlbetonstuetze in Keller-Aussenwand", "Stk", 0),
            ("3.40.1", "340", "Innenmauerwerk Porenbeton PP 4-0.50, d=17,5cm", "m²", 0),
            ("3.50.1", "350", "Filigran-Elementdecke ueber UG", "m²", 0),
            ("3.50.2", "350", "Ringbalken Stahlbeton C 20/25, d=17cm + XPS-Schalung", "m", 0),
            ("3.50.3", "350", "Deckengleicher Balken als Fenstersturz", "Stk", 0),
            ("3.60.1", "360", "Fachwerkbinder Dachstuhl Satteldach 20°/20°", "Stk", 0),
            ("3.60.2", "360", "Dacheindeckung inkl. Lattung", "m²", 0),
            ("3.60.3", "360", "Untergurt-Ausbau: Holzwerkstoffplatte + Mineralwolldaemmung 24cm + GK + Dampfbremse", "m²", 0),
            ("4.40.1", "440", "PV-Vorruestung Dachflaeche", "psch", 1),
        ]

        for (posNr, kg, bezeichnung, einheit, menge) in positionen {
            let pos = LVPosition(context: context)
            pos.posNr = posNr
            pos.kostenGruppeNummer = kg
            pos.bezeichnung = bezeichnung
            pos.einheit = einheit
            pos.menge = menge
            pos.event = event
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            print("EFH Schwarz Marktbreit: Event + 14 LV-Positionen angelegt")
        } catch {
            print("MarktbreitSeeder Fehler: \(error)")
        }
    }
}
