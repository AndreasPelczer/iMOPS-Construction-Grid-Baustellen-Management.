//
//  Persistence.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.12.25.
//

import CoreData
import Combine

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newEvent = Event(context: viewContext)
            newEvent.timeStamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    /// Das Datenmodell wird genau EINMAL geladen und von allen Containern geteilt.
    /// Ohne das lädt jeder `NSPersistentContainer(name:)` eine eigene Kopie des
    /// Modells; sobald zwei Stacks parallel existieren (z.B. App-Stack + In-Memory-
    /// Stack im Test-Host) entstehen doppelte NSEntityDescriptions für dieselbe
    /// NSManagedObject-Subklasse → Crash in `Event(context:)`.
    private static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "test25B", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("CoreData-Modell 'test25B.momd' nicht im Bundle gefunden")
        }
        return model
    }()

    // Persistence.swift (Ausschnitt der init-Methode)

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "test25B",
                                          managedObjectModel: Self.managedObjectModel)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Verbesserung: Migration Optionen hinzufügen, falls Ihr Modell geändert wurde
        // Dies hilft Core Data, das alte Schema an das neue anzupassen, ohne abzustürzen.
        let description = container.persistentStoreDescriptions.first
        // 1. Schalten Sie die automatische Migration ein:
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        // 2. Schalten Sie die automatische Inferenz des Mapping Models ein:
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // ... (Ihre Fehlerbehandlung)
                
                // Loggen Sie den Fehler für die Fehlersuche
                print("❌ Fehler beim Laden des Persistent Stores: \(error), \(error.userInfo)")

                // Beachten Sie: Wenn Sie diesen Fehler in einer Produktions-App sehen,
                // müssen Sie möglicherweise eine manuelle Migration durchführen oder
                // den Store löschen und neu erstellen.
                
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // NEU: Migration für Welle 9 Hierarchie aufrufen
        HierarchieMigration.run(in: container.viewContext)

        // Zuschlagssätze: markiert einmalig, welche Bestandspositionen von den
        // Firmenwerten abweichen — damit die Umstellung keine Preise verschiebt.
        // Im In-Memory-Store (Tests, Snapshots) bewusst NICHT: dort gibt es keine
        // Altdaten, und die Tests setzen ihre Sätze selbst.
        if !inMemory {
            ZuschlagMigration.run(in: container.viewContext)
        }
    
    }
    }
