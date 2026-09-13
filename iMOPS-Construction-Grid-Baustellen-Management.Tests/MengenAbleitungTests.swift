//
//  MengenAbleitungTests.swift
//  Leitstand-Schritt 2: die Menge aus der Baustellengröße ableiten.
//
//  Prüft die Zuordnung nach Einheit (m²→Grundfläche, m/lfm→Umfang) und dass alles
//  andere ehrlich nil bleibt (→ Handeingabe). Reine Werte, kein Netz.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct MengenAbleitungTests {

    private let controller = PersistenceController(inMemory: true)

    @MainActor
    private var ctx: NSManagedObjectContext { controller.container.viewContext }

    @Test @MainActor func einheitBestimmtDieHerkunft() throws {
        let event = Event(context: ctx)
        event.grundflaeche = 120
        event.umfang = 44

        // Fläche → Grundfläche
        let flaeche = try #require(MengenAbleitung.ausGroesse(einheit: "m²", event: event))
        #expect(flaeche.menge == 120)
        #expect(flaeche.quelle == "Grundfläche")

        // Laufende Meter → Umfang (mehrere Schreibweisen)
        #expect(MengenAbleitung.ausGroesse(einheit: "m", event: event)?.menge == 44)
        #expect(MengenAbleitung.ausGroesse(einheit: "lfm", event: event)?.menge == 44)
        #expect(MengenAbleitung.ausGroesse(einheit: "m²", event: event)?.menge == 120)

        // Nicht ableitbar → nil (bleibt Handeingabe)
        #expect(MengenAbleitung.ausGroesse(einheit: "Pau", event: event) == nil)
        #expect(MengenAbleitung.ausGroesse(einheit: "m³", event: event) == nil)
        #expect(MengenAbleitung.ausGroesse(einheit: "Stück", event: event) == nil)
    }

    @Test @MainActor func ohneGroesseOderEventKeinVorschlag() throws {
        let leer = Event(context: ctx)   // grundflaeche/umfang = 0
        #expect(MengenAbleitung.ausGroesse(einheit: "m²", event: leer) == nil)
        #expect(MengenAbleitung.ausGroesse(einheit: "m", event: leer) == nil)
        #expect(MengenAbleitung.ausGroesse(einheit: "m", event: nil) == nil)
    }
}
