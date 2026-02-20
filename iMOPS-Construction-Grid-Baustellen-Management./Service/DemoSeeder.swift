import Foundation
import CoreData
import SceneKit

/// Legt eine Demo-Baustelle an, damit das System realistisch getestet werden kann.
enum DemoSeeder {

    private static let demoEventNumber = "DEMO-BAU-001"

    static func seedIfNeeded(into context: NSManagedObjectContext) {
        seedMaterialsIfNeeded(into: context)
        seedDemoCADFile()

        let req: NSFetchRequest<Event> = Event.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "eventNumber == %@", demoEventNumber)

        if (try? context.fetch(req))?.first != nil {
            return
        }

        let now = Date()
        let event = Event(context: context)
        event.setupTime = now
        event.eventStartTime = Calendar.current.date(byAdding: .day, value: 1, to: now)
        event.eventEndTime = Calendar.current.date(byAdding: .day, value: 90, to: now)

        event.title = "Neubau Mehrfamilienhaus Lindenstrasse 12"
        event.eventNumber = demoEventNumber
        event.location = "Lindenstrasse 12, 60325 Frankfurt"
        event.notes = """
Demo-Baustelle: 6 Wohneinheiten, 3 Geschosse.
Bauherr: Mustermann GmbH
Architekt: Planbuero Schmidt
"""
        event.timeStamp = now

        var extras = EventExtrasPayload()
        extras.checklist = [
            EventChecklistItem(title: "Baugenehmigung pruefen"),
            EventChecklistItem(title: "Baustromkasten anschliessen"),
            EventChecklistItem(title: "Bauzaun aufstellen"),
            EventChecklistItem(title: "Container (Buero + Sanitaer) liefern"),
            EventChecklistItem(title: "Sicherheitsunterweisung alle Gewerke")
        ]
        extras.pinnedLexikonCodes = ["BET-C25", "BST-500", "GKB-125", "NYM-315"]

        do {
            let data = try JSONEncoder().encode(extras)
            event.extras = String(data: data, encoding: .utf8)
        } catch {
            print("DemoSeeder: Konnte Event.extras nicht encoden: \(error)")
        }

        // Auftrag 1: Rohbau EG
        addJob(
            into: context,
            event: event,
            employeeName: "Meier",
            status: .inProgress,
            storageLocation: "Baustelle EG",
            storageNote: "Palette",
            isHotDelivery: false,
            processingDetails: """
Rohbau EG – Aussenmauern + Innenwände

- Schalung pruefen
- Bewehrung nach Stahlplan
- Betonieren Decke EG
- Aushaertezeit dokumentieren
"""
        )

        // Auftrag 2: Elektro EG
        addJob(
            into: context,
            event: event,
            employeeName: "Schmidt",
            status: .pending,
            storageLocation: "Materiallager",
            storageNote: "Gitterbox",
            isHotDelivery: false,
            processingDetails: """
Elektroinstallation EG

- Schlitze nach Plan fraesen
- Leerrohre + Dosen setzen
- Kabel einziehen (NYM 3x1,5 / 5x2,5)
- Verteilung anschliessen
"""
        )

        // Auftrag 3: Sanitaer OG
        addJob(
            into: context,
            event: event,
            employeeName: "Weber",
            status: .pending,
            storageLocation: "Container",
            storageNote: "Einzelteile",
            isHotDelivery: true,
            processingDetails: """
Sanitaer OG – Baeder + Kueche

- Rohrleitungen vormontieren
- Warm-/Kaltwasser verlegen
- Abwasseranschluesse
- Druckpruefung durchfuehren
"""
        )

        do {
            try context.save()
            print("DemoSeeder: Demo-Baustelle + Auftraege angelegt.")
        } catch {
            print("DemoSeeder: Fehler beim Speichern: \(error)")
        }
    }

    // MARK: - Demo CAD-Datei (SceneKit Grundriss)

    private static func seedDemoCADFile() {
        let key = "cadFiles_\(demoEventNumber)"
        if UserDefaults.standard.data(forKey: key) != nil { return }

        let scene = SCNScene()

        // Bodenplatte
        let floor = SCNBox(width: 12, height: 0.3, length: 10, chamferRadius: 0)
        let floorMat = SCNMaterial()
        floorMat.diffuse.contents = UIColor.systemGray4
        floor.materials = [floorMat]
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, 0.15, 0)
        scene.rootNode.addChildNode(floorNode)

        // Waende
        let wallMat = SCNMaterial()
        wallMat.diffuse.contents = UIColor.systemGray2

        func addWall(w: CGFloat, h: CGFloat, l: CGFloat, x: Float, y: Float, z: Float) {
            let wall = SCNBox(width: w, height: h, length: l, chamferRadius: 0)
            wall.materials = [wallMat]
            let node = SCNNode(geometry: wall)
            node.position = SCNVector3(x, y, z)
            scene.rootNode.addChildNode(node)
        }

        addWall(w: 12, h: 3, l: 0.3, x: 0, y: 1.8, z: -5)  // Hinterwand
        addWall(w: 12, h: 3, l: 0.3, x: 0, y: 1.8, z: 5)    // Vorderwand
        addWall(w: 0.3, h: 3, l: 10, x: -6, y: 1.8, z: 0)   // Links
        addWall(w: 0.3, h: 3, l: 10, x: 6, y: 1.8, z: 0)    // Rechts
        addWall(w: 0.3, h: 3, l: 4.5, x: 0, y: 1.8, z: -2.5) // Innenwand

        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cadDir = docsDir.appendingPathComponent("CADFiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: cadDir, withIntermediateDirectories: true)
        let fileURL = cadDir.appendingPathComponent("Demo_Grundriss_EG.scn")

        scene.write(to: fileURL, options: nil, delegate: nil, progressHandler: nil)

        let info = CADFileInfo(
            fileName: "Demo_Grundriss_EG.scn",
            relativePath: "Demo_Grundriss_EG.scn",
            planType: "Grundriss"
        )
        let payload = CADFilesPayload(files: [info])
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
        print("DemoSeeder: Demo-CAD-Datei erzeugt.")
    }

    // MARK: - Baumaterialien seeden

    private static func seedMaterialsIfNeeded(into context: NSManagedObjectContext) {
        let req: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        req.fetchLimit = 1
        if let results = try? context.fetch(req), !results.isEmpty { return }

        let materials: [(String, String, String, String, String)] = [
            ("Transportbeton C25/30",       "BET-C25",  "Rohbau",     "Beton Druckfestigkeitsklasse C25/30",          "Verwendung: Fundamente, Decken, Waende. Expositionsklasse: XC1-XC4"),
            ("Betonstahl BSt 500 S",        "BST-500",  "Rohbau",     "Bewehrungsstahl, warmgewalzt",                 "Durchmesser: 6-28mm, Streckgrenze 500 N/mm\u{00B2}"),
            ("Kalksandstein KS 12-1.4",     "KS-1214",  "Rohbau",     "Kalksandstein fuer tragendes Mauerwerk",       "Masse: 240x115x71mm, Druckfestigkeit 12 N/mm\u{00B2}"),
            ("Poroton-Ziegel T8",           "POR-T8",   "Rohbau",     "Planhochlochziegel mit Daemmfuellung",         "Masse: 248x365x249mm, U-Wert 0,18 W/(m\u{00B2}K)"),
            ("Gipskartonplatte GKB 12,5mm", "GKB-125",  "Trockenbau", "Standard-Gipskartonplatte fuer Waende",        "Masse: 1250x2000mm, Gewicht ~9kg/m\u{00B2}, Brandklasse A2"),
            ("CW-Profil 75/50",             "CW-7550",  "Trockenbau", "Staenderprofil fuer Trockenbauwaende",         "Staerke: 0,6mm, Laenge: 2600-4000mm"),
            ("UW-Profil 75/40",             "UW-7540",  "Trockenbau", "Anschlussprofil Boden/Decke",                  "Staerke: 0,6mm, Laenge: 3000/4000mm"),
            ("Mineralwolle 60mm WLG 035",   "MW-60",    "Daemmung",   "Klemmfilz fuer Trockenbau-Daemmung",           "Lambda: 0,035 W/(mK), Brandklasse A1, Rolle 7,2m\u{00B2}"),
            ("NYM-J 3x1,5mm\u{00B2}",      "NYM-315",  "Elektro",    "Mantelleitung fuer Innenverdrahtung",          "Farbe: grau, Ring 100m, bis 16A absicherbar"),
            ("NYM-J 5x2,5mm\u{00B2}",      "NYM-525",  "Elektro",    "Mantelleitung fuer Steckdosen/Herd",           "Farbe: grau, Ring 50m, bis 20A absicherbar"),
            ("Leerrohr M20 flexibel",       "LR-M20",   "Elektro",    "Flexibles Installationsrohr fuer Unterputz",   "Durchmesser: 20mm, Bund 50m, halogenfrei"),
            ("HT-Rohr DN50",               "HT-50",    "Sanitaer",   "Abwasserrohr fuer Innenentwasserung",          "Durchmesser: 50mm, Laenge: 250-2000mm, Steckmuffe"),
            ("HT-Rohr DN100",              "HT-100",   "Sanitaer",   "Abwasser-Fallleitung und Sammelleitung",       "Durchmesser: 100mm, Laenge: 250-3000mm"),
            ("Kupferrohr 15x1mm",           "CU-15",    "Sanitaer",   "Trinkwasserleitung (Kalt-/Warmwasser)",        "Durchmesser: 15mm, Wandstaerke 1mm, Stange 5m"),
            ("Estrich CT-C25-F4",           "EST-C25",  "Ausbau",     "Zementestrich als schwimmender Estrich",       "Druckfestigkeit C25, Biegezugfestigkeitsklasse F4, Mindestdicke 45mm")
        ]

        for m in materials {
            let entry = CDLexikonEntry(context: context)
            entry.name = m.0
            entry.code = m.1
            entry.kategorie = m.2
            entry.beschreibung = m.3
            entry.details = m.4
        }

        do {
            try context.save()
            print("DemoSeeder: 15 Baumaterialien angelegt.")
        } catch {
            print("DemoSeeder: Fehler beim Material-Seeding: \(error)")
        }
    }

    // MARK: - Helper

    private static func addJob(
        into context: NSManagedObjectContext,
        event: Event,
        employeeName: String,
        status: JobStatus,
        storageLocation: String,
        storageNote: String,
        isHotDelivery: Bool,
        processingDetails: String
    ) {
        let job = Auftrag(context: context)
        job.event = event
        job.employeeName = employeeName
        job.status = status
        job.isCompleted = (status == .completed)
        job.storageLocation = storageLocation
        job.storageNote = storageNote
        job.deliveryTemperature = isHotDelivery
        job.processingDetails = processingDetails
        job.totalProcessingTime = 0
        job.lastStartTime = nil
    }
}
