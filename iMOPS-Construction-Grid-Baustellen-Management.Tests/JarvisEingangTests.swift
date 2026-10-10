//
//  JarvisEingangTests.swift
//  Der Rückweg der Brücke (10.10.2026): Entwürfe von Jarvis abholen und im Planer anlegen.
//
//  Prüft: der Entwurf von der Box wird gelesen, die Vorlage ist nur ein Name und wird hier
//  aufgelöst, der genannte Start trägt die ganze Baustelle, das Alter steht im Hinweis.
//  Reine Werte, kein Netz.
//

import Testing
import Foundation
import CoreData
@testable import iMOPS_Construction_Grid_Baustellen_Management_

struct JarvisEingangTests {

    private let controller = PersistenceController(inMemory: true)

    /// So kommt Andreas' Telefon-Satz von der Box (mops-api /entwuerfe).
    private let vonDerBox = """
    [{"id":"20261010-112000-ab12","erstellt":"2026-10-10T11:20:00+00:00","von":"Jarvis","satz":"Lege eine neue Baustelle an, Name Müller …",
      "zustand":"offen","schritte":[
        {"nr":0,"art":"baustelle","felder":{"name":"Müller","ort":"Sachsenhausen","start":"2027-03-12","vorlage":"hofeinfahrt","angebot_betrag":"30926"},
         "zustand":"offen","quittiert":null,"baustelle_id":""},
        {"nr":1,"art":"termin","felder":{"titel":"Treffen vor Ort – Müller","tag":"2026-10-13","ort":"Sachsenhausen"},"zustand":"offen","quittiert":null,"baustelle_id":""},
        {"nr":2,"art":"canvas","felder":{},"zustand":"offen","quittiert":null,"baustelle_id":""}]}]
    """

    private func entwurf() throws -> JarvisEingang.Entwurf {
        let liste = try JSONDecoder().decode([JarvisEingang.Entwurf].self, from: Data(vonDerBox.utf8))
        return try #require(liste.first)
    }

    @Test func entwurfVonDerBoxWirdGelesen() throws {
        let e = try entwurf()
        #expect(e.kurz == "Müller, Sachsenhausen")
        #expect(e.schritte.map { $0.art } == ["baustelle", "termin", "canvas"])
        #expect(e.schritte.allSatisfy { $0.offen })
        #expect(e.erstelltDatum != nil)
    }

    @Test func vorlageNurAlsNameWirdHierAufgeloest() throws {
        let e = try entwurf()
        let v = JarvisEingang.Vorgabe(try #require(e.baustelle).felder)
        #expect(v.vorlage == .hofeinfahrt)
        #expect(v.name == "Müller" && v.ort == "Sachsenhausen")
        #expect(v.angebotBetrag == 30926 && v.angebotBis == nil)
        #expect(v.angebotNotiz?.contains("30.926") == true)
    }

    @Test func terminOhneUhrzeitIstGanztags() throws {
        let t = try #require(JarvisEingang.termin(["tag": "2026-10-13"]))
        #expect(t.ganztags)
        #expect(Calendar.current.component(.weekday, from: t.start) == 3)   // Dienstag
        let mit = try #require(JarvisEingang.termin(["tag": "2026-10-13", "uhrzeit": "14:00"]))
        #expect(!mit.ganztags && Calendar.current.component(.hour, from: mit.start) == 14)
    }

    @Test func alterStehtImHinweis() {
        let jetzt = Date()
        #expect(JarvisEingang.alter(jetzt, jetzt: jetzt).hasPrefix("von heute"))
        #expect(JarvisEingang.alter(jetzt.addingTimeInterval(-86_400), jetzt: jetzt).hasPrefix("von gestern"))
        #expect(JarvisEingang.alter(jetzt.addingTimeInterval(-7 * 86_400), jetzt: jetzt).hasPrefix("vom "))
    }

    @Test func genannterStartTraegtDieBaustelle() throws {
        let e = try entwurf()
        let v = JarvisEingang.Vorgabe(try #require(e.baustelle).felder)
        let ctx = controller.container.viewContext
        let result = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100)
        let start = try #require(v.start)
        let event = HouseProjectGenerator.createEvent(from: result, into: ctx, start: start, ort: v.ort, titel: "Müller – Hofeinfahrt")
        #expect(event.title == "Müller – Hofeinfahrt")
        #expect(event.location == "Sachsenhausen")
        #expect(event.eventStartTime == start)
        #expect((event.eventEndTime ?? .distantPast) > start)
    }
}
