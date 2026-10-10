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
        #expect(v.angebotText?.contains("30.926") == true)
    }

    @Test func betragWirdFeldKeineNotiz() {
        var extras = EventExtrasPayload()
        JarvisEingang.Vorgabe(["angebot_betrag": "30926"]).uebertrage(in: &extras)
        #expect(extras.angebotSumme == 30926 && extras.angebotFrist == nil)
        var frist = EventExtrasPayload()
        JarvisEingang.Vorgabe(["angebot_bis": "2026-10-30"]).uebertrage(in: &frist)
        #expect(frist.angebotFrist != nil && frist.angebotSumme == nil)
    }

    @Test func flaecheStehtDaAuchWennNichtGesagt() {
        #expect(JarvisEingang.Vorgabe(["vorlage": "hofeinfahrt"]).vorlageText == "Hofeinfahrt · Fläche 100 m² (Standard aus dem Planer)")
        #expect(JarvisEingang.Vorgabe(["vorlage": "hofeinfahrt", "flaeche": "120"]).vorlageText == "Hofeinfahrt · Fläche 120 m²")
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

    @Test func nichtAngekommeneQuittungWirdGemerktNichtGruenGemalt() throws {
        let vorher = JarvisEingang.ausstehend
        defer { JarvisEingang.ausstehend = vorher }
        let e = try entwurf()
        let b = try #require(e.baustelle)
        JarvisEingang.ausstehend = []
        #expect(!JarvisEingang.istAusstehend(e, b))
        JarvisEingang.merke(.init(entwurf: e.id, schritt: b.nr, zustand: "uebernommen", baustelleID: "HK-1"))
        JarvisEingang.merke(.init(entwurf: e.id, schritt: b.nr, zustand: "uebernommen", baustelleID: "HK-1"))   // doppelt getippt
        #expect(JarvisEingang.istAusstehend(e, b))
        #expect(JarvisEingang.ausstehend.count == 1)
        #expect(b.zustand == "offen")   // der Zustand selbst bleibt der der Box
    }
}

struct AbwesenheitenTests {
    private func store() -> AbwesenheitenStore {
        AbwesenheitenStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("abw-\(UUID().uuidString).json"))
    }

    @Test func doppeltUebernommenBleibtEinEintrag() {
        let s = store()
        let a = Abwesenheit(name: "Paolo", von: Date(), bis: Date().addingTimeInterval(4 * 86_400))
        s.hinzu(a)
        s.hinzu(Abwesenheit(name: "paolo", von: a.von, bis: a.bis))
        #expect(s.von("Paolo").count == 1)
    }

    @Test func meldungKenntKeinenGrund() throws {
        let s = store()
        s.hinzu(Abwesenheit(name: "Tim", von: Date(), bis: Date(), art: .abwesend))
        let daten = try #require(s.meldung())
        let obj = try #require(try JSONSerialization.jsonObject(with: daten) as? [String: Any])
        let e = try #require((obj["eintraege"] as? [[String: String]])?.first)
        #expect(Set(e.keys) == ["name", "von", "bis", "art"])
        #expect(e["art"] == "abwesend")
    }

    @Test func ueberlebtNeustart() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("abw-\(UUID().uuidString).json")
        AbwesenheitenStore(fileURL: url).hinzu(Abwesenheit(name: "Paolo", von: Date(), bis: Date()))
        #expect(AbwesenheitenStore(fileURL: url).von("Paolo").count == 1)
    }
}

struct KatalogMeldungTests {
    private let controller = PersistenceController(inMemory: true)

    @Test @MainActor func meldetRezepteUndMaterialpreise() throws {
        let ctx = controller.container.viewContext
        let b = Leistungsbaustein(context: ctx)
        b.id = UUID(); b.leistung = "Pflaster verlegen"; b.einheit = "m²"; b.einheitspreisVK = 48.5
        b.maurerStunden = 0.5; b.helferStunden = 0.3; b.kostenGruppeNummer = "520"; b.quelle = "firma-katalog"
        let m = KalkMaterial(context: ctx)
        m.id = UUID(); m.name = "Schotter 0/32"; m.einheit = "t"; m.preisProEinheit = 7.9; m.lieferant = "SHB"
        let s = KatalogMeldung.stand(in: ctx)
        let l = try #require(s.leistungen.first)
        #expect(l.ep == 48.5 && abs(l.stunden - 0.8) < 0.0001 && l.einheit == "m²")
        #expect(s.material.first?.lieferant == "SHB" && s.material.first?.preis == 7.9)
    }
}

struct KalkulationZuweisenTests {
    private let controller = PersistenceController(inMemory: true)

    @Test @MainActor func positionenLandenImLVUndHolenIhrRezept() throws {
        let ctx = controller.container.viewContext
        let b = Leistungsbaustein(context: ctx)
        b.id = UUID(); b.leistung = "Pflaster verlegen"; b.einheit = "m²"; b.einheitspreisVK = 48.5; b.maurerStunden = 0.8
        let result = ProjektGenerator.generate(typ: .hofeinfahrt, haus: HouseProject(), flaeche: 100)
        let event = HouseProjectGenerator.createEvent(from: result, into: ctx)
        let vorher = event.lvPositionen?.count ?? 0
        let felder = ["positionen": #"[{"text":"Pflaster","menge":30,"einheit":"m2","rezept":"Pflaster verlegen"},{"text":"Zauberstein","menge":2,"einheit":"stk","rezept":""}]"#,
                      "satz": "30 m² Pflaster, 2 Stk Zauberstein"]
        let r = JarvisEingang.legeKalkulation(felder, in: event, ctx: ctx)
        #expect(r.angelegt == 2 && r.mitRezept == 1)
        let neu = (event.lvPositionen as? Set<LVPosition> ?? []).filter { $0.quellDatei == "Jarvis-Schnellkalkulation" }
        #expect((event.lvPositionen?.count ?? 0) == vorher + 2)
        let pflaster = try #require(neu.first { $0.bezeichnung == "Pflaster verlegen" })
        #expect(pflaster.einheit == "m²" && pflaster.menge == 30 && pflaster.mengenQuelle == .schaetzung)
        #expect(neu.contains { $0.bezeichnung == "Zauberstein" && $0.einheit == "Stk" })
    }
}

struct OfflineUnterlagenTests {
    private func d(_ pfad: String, _ groesse: Int = 10, _ zeit: String = "2026-10-10T12:00:00+00:00") -> OfflineUnterlagen.Datei {
        OfflineUnterlagen.Datei(name: (pfad as NSString).lastPathComponent, fach: (pfad as NSString).pathComponents.first ?? "",
                                pfad: pfad, groesse: groesse, geaendert: zeit)
    }

    @Test func abgleichHoltNurNeuesUndGeaendertesUndRaeumtGeloeschtes() {
        let alt = [d("Statik/v1.pdf"), d("Statik/plan.pdf", 10), d("Bilder/weg.jpg")]
        let neu = [d("Statik/v1.pdf"), d("Statik/plan.pdf", 99), d("Vermessung/neu.dxf")]
        let p = OfflineUnterlagen.abgleich(alt: alt, neu: neu)
        #expect(Set(p.holen.map { $0.pfad }) == ["Statik/plan.pdf", "Vermessung/neu.dxf"])
        #expect(p.gleich.map { $0.pfad } == ["Statik/v1.pdf"])
        #expect(p.weg.map { $0.pfad } == ["Bilder/weg.jpg"])
    }

    @Test func erstesMitnehmenHoltAlles() {
        let p = OfflineUnterlagen.abgleich(alt: [], neu: [d("a.pdf"), d("b.pdf")])
        #expect(p.holen.count == 2 && p.weg.isEmpty)
    }

    @Test func jedeBaustelleHatIhrenEigenenOrt() {
        let basis = FileManager.default.temporaryDirectory
        #expect(OfflineUnterlagen.ordner(fuer: "HK-1", basis: basis) != OfflineUnterlagen.ordner(fuer: "HK-2", basis: basis))
        #expect(OfflineUnterlagen.ordner(fuer: "a/b", basis: basis).lastPathComponent == "a_b")
        #expect(OfflineUnterlagen.stand(fuer: "gibts-nicht-\(UUID())", basis: basis) == nil)
    }
}
