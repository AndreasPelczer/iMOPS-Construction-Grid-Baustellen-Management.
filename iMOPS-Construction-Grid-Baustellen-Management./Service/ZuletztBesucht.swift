//
//  ZuletztBesucht.swift
//
//  Der Bildschirm heisst „Wo war ich?" — und konnte die Frage nicht beantworten.
//
//  Gemessen am 21.09.2026 in der echten Datenbank: `Event.startTime` war leer, und
//  von 34 Aufträgen hatte KEIN EINZIGER eine `lastStartTime`. Beides wird nur gesetzt,
//  wenn jemand einen Auftrag wirklich startet. Wer plant, startet nichts — also blieb
//  der Wiedereinstieg für eine Baustelle in Planung immer leer.
//
//  Die Lösung braucht kein Feld in der Datenbank: „wo war ich" ist keine Eigenschaft
//  der Baustelle, sondern eine des Menschen davor. Sie gehört diesem Gerät, nicht dem
//  Projekt — und überlebt deshalb in den UserDefaults, nicht im Modell.
//
//  🔴 Bewusst NICHT synchronisiert: wo Raphi zuletzt war, geht Andreas nichts an,
//  und umgekehrt. Siehe docs/WESEN-DES-MOPS.md — der Mops passt auf, er beobachtet nicht.
//

import Foundation
import CoreData

enum ZuletztBesucht {

    private static let schluesselID = "mops.zuletztBesucht.id"
    private static let schluesselName = "mops.zuletztBesucht.name"
    private static let schluesselWann = "mops.zuletztBesucht.wann"

    /// Merkt sich diese Baustelle als die zuletzt geöffnete.
    @MainActor
    static func merken(_ event: Event) {
        guard !event.objectID.isTemporaryID else { return }
        let d = UserDefaults.standard
        d.set(event.objectID.uriRepresentation().absoluteString, forKey: schluesselID)
        d.set(event.title ?? "Baustelle", forKey: schluesselName)
        d.set(Date(), forKey: schluesselWann)
    }

    /// Die zuletzt geöffnete Baustelle — oder nil, wenn es sie nicht mehr gibt.
    ///
    /// Eine gelöschte Baustelle darf hier nicht als Karteileiche stehen bleiben;
    /// deshalb wird die Kennung jedes Mal gegen den Speicher geprüft.
    @MainActor
    static func lesen(in ctx: NSManagedObjectContext) -> (event: Event, name: String, wann: Date)? {
        let d = UserDefaults.standard
        guard let roh = d.string(forKey: schluesselID),
              let url = URL(string: roh),
              let koordinator = ctx.persistentStoreCoordinator,
              let id = koordinator.managedObjectID(forURIRepresentation: url),
              let event = try? ctx.existingObject(with: id) as? Event,
              !event.isDeleted
        else { return nil }

        let name = event.title ?? d.string(forKey: schluesselName) ?? "Baustelle"
        let wann = d.object(forKey: schluesselWann) as? Date ?? Date()
        return (event, name, wann)
    }

    /// Für Tests und für den Fall, dass jemand alles löscht.
    static func vergessen() {
        let d = UserDefaults.standard
        [schluesselID, schluesselName, schluesselWann].forEach { d.removeObject(forKey: $0) }
    }
}
