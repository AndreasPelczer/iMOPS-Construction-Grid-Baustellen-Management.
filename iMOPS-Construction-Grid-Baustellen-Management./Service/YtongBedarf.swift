//
//  YtongBedarf.swift
//  Ytong-Bedarfswerte je m³ Mauerwerk (Steine Stück/m³ + Dünnbettmörtel kg/m³ je
//  Wanddicke). Quelle: öffentlicher Ytong/Xella-Vordruck („Bedarfswerte je m³
//  Mauerwerk", Höhe 249, Länge 599). Öffentliche Hersteller-Werte — keine
//  Kundendaten, dürfen in den Code (im Gegensatz zu Goldschmitts Preisen).
//
//  Damit werden Mauerwerks-Rezepte gebaut: die MENGE Material je m³ steht fest, der
//  PREIS je Stein/Sack ist Betriebswissen und wird gerätelokal in den Stammdaten
//  nachgetragen (Rezept-Preis bleibt hier bewusst 0).
//

import Foundation
import CoreData

enum YtongBedarf {

    struct Zeile {
        let wanddickeMm: Int
        let steineProM3: Double        // Stück/m³
        let moertelKgProM3: Double      // kg/m³ Dünnbettmörtel (DBM)
        let mitStossfuge: Bool          // Stoßfugenvermörtelung nötig?
    }

    /// Höhe 249 mm, Länge 599 mm (der Regelfall). Werte aus dem Ytong-Vordruck.
    static let werte: [Zeile] = [
        Zeile(wanddickeMm:  50, steineProM3: 133.3, moertelKgProM3: 15.4, mitStossfuge: true),
        Zeile(wanddickeMm:  75, steineProM3:  88.9, moertelKgProM3: 15.4, mitStossfuge: true),
        Zeile(wanddickeMm: 100, steineProM3:  66.7, moertelKgProM3: 15.4, mitStossfuge: true),
        Zeile(wanddickeMm: 115, steineProM3:  58.0, moertelKgProM3: 14.0, mitStossfuge: false),
        Zeile(wanddickeMm: 150, steineProM3:  44.4, moertelKgProM3: 13.2, mitStossfuge: false),
        Zeile(wanddickeMm: 175, steineProM3:  38.1, moertelKgProM3: 12.7, mitStossfuge: false),
        Zeile(wanddickeMm: 200, steineProM3:  33.3, moertelKgProM3: 12.4, mitStossfuge: false),
        Zeile(wanddickeMm: 240, steineProM3:  27.8, moertelKgProM3: 12.0, mitStossfuge: false),
        Zeile(wanddickeMm: 300, steineProM3:  22.3, moertelKgProM3: 11.6, mitStossfuge: false),
        Zeile(wanddickeMm: 365, steineProM3:  18.4, moertelKgProM3: 11.3, mitStossfuge: false),
        Zeile(wanddickeMm: 400, steineProM3:  16.8, moertelKgProM3: 11.2, mitStossfuge: false),
        Zeile(wanddickeMm: 425, steineProM3:  15.8, moertelKgProM3: 11.1, mitStossfuge: false),
        Zeile(wanddickeMm: 480, steineProM3:  14.0, moertelKgProM3: 11.0, mitStossfuge: false),
    ]

    static func zeile(wanddickeMm: Int) -> Zeile? { werte.first { $0.wanddickeMm == wanddickeMm } }

    /// Material-Rezept je m³ Mauerwerk: Steine + Dünnbettmörtel. Preis 0 (Stammdaten).
    static func rezept(fuer z: Zeile) -> LeistungskatalogService.Rezept {
        LeistungskatalogService.Rezept(
            material: [
                .init(name: "Ytong Planstein \(z.wanddickeMm) mm",
                      mengeProEinheit: z.steineProM3, einzelpreis: 0,
                      verschnittProzent: 0, einheit: "Stück"),
                .init(name: "Ytong Dünnbettmörtel",
                      mengeProEinheit: z.moertelKgProM3, einzelpreis: 0,
                      verschnittProzent: 0, einheit: "kg"),
            ],
            geraet: [])
    }

    /// Name des Bausteins zu einer Wanddicke: „Mauerwerk Ytong 24 cm".
    static func bausteinName(_ z: Zeile) -> String {
        let cm = (Double(z.wanddickeMm) / 10.0)
            .formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))
        return "Mauerwerk Ytong \(cm) cm"
    }

    /// Seedet je Wanddicke einen Leistungsbaustein (Einheit m³) mit dem Material-Rezept.
    /// Idempotent: vorhandene Bausteine werden NICHT überschrieben, nur das Material-
    /// Rezept aufgefrischt (öffentliche Mengen). Lohn bleibt, was der Prof/Katalog gesetzt
    /// hat — der Aufwandswert steht nicht im Vordruck.
    @discardableResult
    static func seedIfNeeded(context ctx: NSManagedObjectContext) -> Int {
        var gesetzt = 0
        for z in werte {
            let name = bausteinName(z)
            let baustein: Leistungsbaustein
            if let vorhanden = LeistungskatalogService.finde(leistung: name, einheit: "m³", in: ctx) {
                baustein = vorhanden
            } else {
                baustein = Leistungsbaustein(context: ctx)
                baustein.id = UUID()
                baustein.leistung = name
                baustein.einheit = "m³"
                baustein.maurerStunden = 0
                baustein.helferStunden = 0
                baustein.kostenGruppeNummer = "330"   // Außenwände/Mauerwerk
                baustein.quelle = "ytong"
                baustein.verwendungen = 0
                baustein.erstelltAm = Date()
            }
            if let data = try? JSONEncoder().encode(rezept(fuer: z)) {
                baustein.rezeptJSON = String(decoding: data, as: UTF8.self)   // öffentliche Mengen auffrischen
            }
            gesetzt += 1
        }
        if ctx.hasChanges { try? ctx.save() }
        return gesetzt
    }
}
