//
//  GAEBAnkunftsPruefung.swift
//
//  TAO: Nachweis statt Behauptung — und zwar für die Daten selbst, nicht für den Vorgang.
//
//  Am 20.09.2026 hat ein GAEB-Import 109 Positionen angelegt und „fertig" gemeldet. In der
//  Datei standen 109 Einheitspreise, zusammen 263.304,97 €. Angekommen ist KEIN EINZIGER.
//  Die Meldung war trotzdem freundlich, weil sie zählte, was der Import zu tun glaubte —
//  nicht, was hinterher wirklich abrufbar war. Gefunden wurde es erst, als jemand die
//  Endsumme auf dem Bildschirm nicht wiedererkannte.
//
//  Diese Prüfung liest nach dem Speichern ZURÜCK, und zwar über denselben Weg, den das LV
//  und die Angebotssumme gehen (`LVKalkulator.effektiverEP`). Was hier nicht erscheint,
//  erscheint auch dort nicht. Ein Zähler aus der Schreibschleife wäre kein Beleg — er
//  zählt Absichten.
//
//  Schwesterregel im Repo: der Ankunfts-Bericht des Preislisten-Imports
//  (`PreisImportBerichtView`). Gleiche Idee, anderer Weg herein.
//

import Foundation
import CoreData

enum GAEBAnkunftsPruefung {

    /// Eine Position, deren Preis in der Datei stand, nach dem Speichern aber nicht
    /// abrufbar ist. Genau diese Liste ist der Befund — nicht die Zahl darüber.
    struct Vermisst: Identifiable {
        let id = UUID()
        let posNr: String
        let bezeichnung: String
        let preisInDatei: Double
        let menge: Double
        var betrag: Double { preisInDatei * menge }
    }

    struct Bericht {
        var positionen        = 0     // übernommene Positionen
        var preiseInDatei     = 0     // Items mit UP > 0
        var preiseAbrufbar    = 0     // nach dem Speichern über effektiverEP erreichbar
        var ausKatalog        = 0     // kein UP, aber ein Rezept griff
        var ohnePreis         = 0     // bewusste Lücke: kein UP, kein Rezept
        var summeInDatei      = 0.0
        var summeAbrufbar     = 0.0
        var vermisst: [Vermisst] = []

        /// Alles, was in der Datei stand, ist auch wirklich da.
        var vollstaendig: Bool { vermisst.isEmpty }
        /// Der Fall, der heute passiert ist: Preise in der Datei, keiner angekommen.
        var totalausfall: Bool { preiseInDatei > 0 && preiseAbrufbar == 0 }
        var fehlbetrag: Double { max(0, summeInDatei - summeAbrufbar) }
    }

    /// Liest für jedes Paar (angelegte Position, gelesenes Item) den Preis so zurück, wie
    /// ihn später auch das LV liest. `positionen` muss NACH dem `save()` übergeben werden —
    /// vorher ist die objectID temporär und der Angebotsspeicher findet nichts.
    static func pruefe(_ paare: [(pos: LVPosition, item: GAEBImportItem)],
                       store: AngebotsStore = .shared) -> Bericht {
        var b = Bericht()
        for (pos, item) in paare {
            b.positionen += 1
            let inDatei = item.unitPrice ?? 0
            let abrufbar = LVKalkulator.effektiverEP(for: pos, store: store)

            if inDatei > 0 {
                b.preiseInDatei += 1
                b.summeInDatei += inDatei * item.menge
                if abrufbar > 0 {
                    b.preiseAbrufbar += 1
                    b.summeAbrufbar += abrufbar * item.menge
                } else {
                    b.vermisst.append(Vermisst(posNr: item.posNr,
                                               bezeichnung: item.kurztext,
                                               preisInDatei: inDatei,
                                               menge: item.menge))
                }
            } else if abrufbar > 0 {
                b.ausKatalog += 1
                b.summeAbrufbar += abrufbar * item.menge
            } else {
                b.ohnePreis += 1
            }
        }
        // Die teuerste Lücke zuerst — danach schaut man als Erstes.
        b.vermisst.sort { $0.betrag > $1.betrag }
        return b
    }

    /// Wie viele LV-Positionen hängen schon an dieser Baustelle? Ein GAEB-Import HÄNGT AN,
    /// er ersetzt nicht. Wer dieselbe Datei zweimal einliest, hat alles doppelt und eine
    /// Summe, die niemand mehr nachvollziehen kann (20.09.: 162 Positionen statt 109,
    /// 17 Positionsnummern doppelt).
    static func bestandVorImport(event: Event, in ctx: NSManagedObjectContext) -> Int {
        let r = NSFetchRequest<NSNumber>(entityName: "LVPosition")
        r.resultType = .countResultType
        r.predicate = NSPredicate(format: "event == %@", event)
        return (try? ctx.count(for: r)) ?? 0
    }
}
