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

        // Bootstrap-Logik lebt jetzt in HierarchieHelfer (auch für neue Events/Importe
        // im laufenden Betrieb genutzt) — hier nur einmalig über alle Alt-Baustellen.
        var needsSave = false
        for event in events {
            let (_, geaendert) = HierarchieHelfer.sichereDefaultGeschoss(for: event, in: context)
            needsSave = needsSave || geaendert
        }

        if needsSave {
            try? context.save()
        }

        UserDefaults.standard.set(true, forKey: "welle9_hierarchie_migrated")
    }
}
