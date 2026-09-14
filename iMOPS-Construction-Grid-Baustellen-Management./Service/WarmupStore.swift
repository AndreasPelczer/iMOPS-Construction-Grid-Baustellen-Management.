//
//  WarmupStore.swift
//  Merkt sich pro Baustelle + Tag, ob das 5-Minuten-Warm-up (Sortier-Spiel) schon
//  erledigt (oder übersprungen) ist. Bewusst leichtgewichtig (UserDefaults) und
//  gerätelokal — es ist ein spielerischer Schubs, kein Nachweis und kein hartes Tor.
//
//  „Gute Systeme sind still" (Tao Kap 10): der Mops erinnert einmal, dann Ruhe.
//

import Foundation
import CoreData

enum WarmupStore {

    private static func schluessel(_ eventID: NSManagedObjectID, _ datum: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE"); df.dateFormat = "yyyy-MM-dd"
        return "warmup_\(eventID.uriRepresentation().absoluteString)_\(df.string(from: datum))"
    }

    /// Für heute (oder ein gegebenes Datum) schon erledigt/übersprungen?
    static func istErledigt(_ event: Event, am datum: Date = Date()) -> Bool {
        UserDefaults.standard.bool(forKey: schluessel(event.objectID, datum))
    }

    /// Als erledigt markieren (nach Gewinn ODER Überspringen — beides beruhigt den Schubs).
    static func erledigen(_ event: Event, am datum: Date = Date()) {
        UserDefaults.standard.set(true, forKey: schluessel(event.objectID, datum))
    }

    /// Zum Wieder-Üben freigeben (z. B. „nochmal spielen").
    static func zuruecksetzen(_ event: Event, am datum: Date = Date()) {
        UserDefaults.standard.removeObject(forKey: schluessel(event.objectID, datum))
    }
}
