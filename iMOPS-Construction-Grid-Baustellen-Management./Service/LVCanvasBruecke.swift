import Foundation
import CoreData

// MARK: - LVCanvasBruecke
//
// Die Brücke zwischen dem Baustellen-LV und dem Grap8-Canvas (Knoten = `Auftrag`).
// Beide Richtungen, idempotent über die VORHANDENE Beziehung `Auftrag.lvPosition` —
// nichts wird verdoppelt: ein Knoten und seine LV-Position sind dasselbe Ding, doppelt
// sichtbar.
//
// Verbinden statt erfinden: die Beziehung, das Event↔LVPosition-Set und die
// Auftrag-Erzeugung gab es schon; hier wird nur der fehlende Weg in beide Richtungen gelegt.
//
// FALLE beachtet: `Auftrag` hat Pflichtfelder ohne Default (`statusRawValue`, `storageNote`) —
// ein „nackter" Auftrag crasht `save()`. Darum werden sie beim Anlegen gesetzt.
enum LVCanvasBruecke {

    /// LV → Canvas: für jede LVPosition der Baustelle OHNE Knoten einen Auftrag anlegen
    /// und verlinken (damit sie auf dem Grap8-Canvas als Knoten erscheint und dort
    /// kalkuliert werden kann → dabei entsteht der Baustein). Gibt die Zahl neuer Knoten.
    @discardableResult
    static func lvAufDenCanvas(event: Event, in ctx: NSManagedObjectContext) -> Int {
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []
        let schonVerknuepft = Set(auftraege(event: event, in: ctx).compactMap { $0.lvPosition?.objectID })
        var neu = 0
        for pos in positionen where !schonVerknuepft.contains(pos.objectID) {
            erzeugeKnoten(fuer: pos, event: event, in: ctx)
            neu += 1
        }
        return neu
    }

    /// Canvas → LV: für jeden Knoten der Baustelle OHNE LVPosition eine anlegen und
    /// verlinken (damit er im LV auftaucht). Gibt die Zahl neuer LV-Positionen.
    @discardableResult
    static func canvasInsLV(event: Event, in ctx: NSManagedObjectContext) -> Int {
        var neu = 0
        for a in auftraege(event: event, in: ctx) where a.lvPosition == nil {
            erzeugeLVPosition(fuer: a, event: event, in: ctx)
            neu += 1
        }
        return neu
    }

    // MARK: - Bausteine (einzeln, testbar)

    /// Neuen Knoten (Auftrag) für eine LV-Position anlegen — mit gesetzten Pflichtfeldern.
    @discardableResult
    static func erzeugeKnoten(fuer pos: LVPosition, event: Event,
                              in ctx: NSManagedObjectContext) -> Auftrag {
        let a = Auftrag(context: ctx)
        a.event = event
        a.status = .pending            // setzt statusRawValue (Pflicht ohne Default)
        a.storageNote = ""             // Pflicht ohne Default
        a.storageLocation = ""
        a.employeeName = ""
        a.processingDetails = pos.bezeichnung ?? ""
        a.totalProcessingTime = 0
        a.lastStartTime = nil
        a.kostenGruppeNummer = pos.kostenGruppeNummer
        a.lvPosition = pos             // die Brücke
        return a
    }

    /// Neue LV-Position für einen Knoten anlegen. Einheit/Menge kennt der Knoten nicht →
    /// bleiben offen (0 / leer), damit sichtbar ist, dass hier noch Mengen fehlen.
    @discardableResult
    static func erzeugeLVPosition(fuer a: Auftrag, event: Event,
                                  in ctx: NSManagedObjectContext) -> LVPosition {
        let pos = LVPosition(context: ctx)
        pos.event = event
        pos.bezeichnung = a.processingDetails
        pos.einheit = ""
        pos.menge = 0
        pos.kostenGruppeNummer = a.kostenGruppeNummer
        a.lvPosition = pos
        return pos
    }

    private static func auftraege(event: Event, in ctx: NSManagedObjectContext) -> [Auftrag] {
        let req: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        req.predicate = NSPredicate(format: "event == %@", event)
        return (try? ctx.fetch(req)) ?? []
    }
}
