//
//  HierarchieMigration.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 20.06.26.
//
import Foundation
import CoreData

struct HierarchieMigration {
    static func run(in context: NSManagedObjectContext) {
        let isMigrated = UserDefaults.standard.bool(forKey: "welle9_hierarchie_migrated")
        guard !isMigrated else { return }

        let eventRequest: NSFetchRequest<Event> = Event.fetchRequest()
        guard let events = try? context.fetch(eventRequest), !events.isEmpty else {
            UserDefaults.standard.set(true, forKey: "welle9_hierarchie_migrated")
            return
        }

        var needsSave = false

        for event in events {
            // Prüfen, ob das Event schon Gebäude hat (via KVC, um Compiler-Fehler zu umgehen)
            let existingGebaeude = event.value(forKey: "gebaeude") as? NSSet
            if (existingGebaeude?.count ?? 0) == 0 {
                
                let hauptgebaeude = Gebaeude(context: context)
                hauptgebaeude.id = UUID()
                hauptgebaeude.name = "Hauptgebäude"
                hauptgebaeude.reihenfolge = 0
                hauptgebaeude.setValue(event, forKey: "event") // KVC statt hauptgebaeude.event = event

                let egGeschoss = Geschoss(context: context)
                egGeschoss.id = UUID()
                egGeschoss.name = "Allgemein / EG"
                egGeschoss.reihenfolge = 0
                egGeschoss.setValue(hauptgebaeude, forKey: "gebaeude") // KVC

                // Alle bestehenden LVPositionen diesem Geschoss zuordnen
                if let positions = event.lvPositionen as? Set<LVPosition> {
                    for pos in positions {
                        if pos.value(forKey: "geschoss") == nil {
                            pos.setValue(egGeschoss, forKey: "geschoss") // KVC
                        }
                    }
                }
                needsSave = true
            }
        }

        if needsSave {
            try? context.save()
        }
        
        UserDefaults.standard.set(true, forKey: "welle9_hierarchie_migrated")
    }
}
