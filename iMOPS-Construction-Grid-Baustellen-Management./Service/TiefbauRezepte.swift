//
//  TiefbauRezepte.swift
//  Rezept-Vorlagen für die häufigen Tiefbau-/Außenanlagen-Leistungen (Hofeinfahrt).
//  Damit greift der Auto-Match beim Import: eine Position „Betonpflaster verlegen"
//  bekommt ihr Material (Menge je Einheit) und – wo herleitbar – die Gerätestunden.
//
//  EHRLICH markiert (Tao: Folgerung ≠ Fakt):
//   • Material-MENGEN sind gängige Tiefbau-RICHTWERTE (Verschnitt/Verdichtung), keine
//     amtlichen Werte — zum Bestätigen/Anpassen.
//   • Gerätestunden (Bagger) kommen aus `Erdbauleistung` (Menge ÷ Leistung) — nachvollziehbar.
//   • PREISE bleiben 0 und LOHN bleibt 0: der Aufwandswert (h/Einheit) steht in keiner
//     Tabelle — er kommt per Prof/KI (markiert) oder aus Andreas' Erfahrung, gerätelokal.
//     Ein Rezept liefert also erst dann einen Preis, wenn Aufwand + € ergänzt sind.
//

import Foundation
import CoreData

enum TiefbauRezepte {

    struct Mat { let name: String; let menge: Double; let einheit: String; let verschnitt: Double }
    struct Ger { let name: String; let stundenProEinheit: Double }
    struct Vorlage {
        let leistung: String
        let einheit: String
        let kg: String              // DIN-276-Kostengruppe
        let material: [Mat]
        let geraet: [Ger]
    }

    /// Gerätestunden je m³ = 1 ÷ Leistung (Erdbauleistung, Minibagger-Richtwert).
    private static var baggerHJeM3: Double { Erdbauleistung.stunden(menge: 1, leistung: Erdbauleistung.minibagger) }

    static var vorlagen: [Vorlage] {
        [
            Vorlage(leistung: "Oberboden abtragen und lagern", einheit: "m³", kg: "500",
                    material: [], geraet: [Ger(name: "Minibagger", stundenProEinheit: baggerHJeM3)]),
            Vorlage(leistung: "Baugrube/Aushub herstellen", einheit: "m³", kg: "310",
                    material: [], geraet: [Ger(name: "Minibagger", stundenProEinheit: baggerHJeM3)]),
            Vorlage(leistung: "Aushub abfahren und entsorgen", einheit: "m³", kg: "310",
                    material: [Mat(name: "Entsorgung/Deponie", menge: 1.0, einheit: "m³", verschnitt: 0)],
                    geraet: []),
            // Schotter: ~10 % Verdichtungszuschlag (lose → verdichtet)
            Vorlage(leistung: "Frostschutzschicht/Schotter einbauen und verdichten", einheit: "m³", kg: "500",
                    material: [Mat(name: "Schotter 0/32", menge: 1.1, einheit: "m³", verschnitt: 0)],
                    geraet: []),
            // Splitt-Bettung ~4 cm → 0,04 m³ je m²
            Vorlage(leistung: "Splitt-Bettung herstellen", einheit: "m²", kg: "500",
                    material: [Mat(name: "Splitt 2/8", menge: 0.04, einheit: "m³", verschnitt: 0)],
                    geraet: []),
            // Trennvlies: 10 % Überlappung → 1,1 m² je m²
            Vorlage(leistung: "Trennvlies (Geotextil) verlegen", einheit: "m²", kg: "500",
                    material: [Mat(name: "Trennvlies (Geotextil)", menge: 1.1, einheit: "m²", verschnitt: 0)],
                    geraet: []),
            // Pflaster: ~2 % Verschnitt
            Vorlage(leistung: "Betonpflaster verlegen", einheit: "m²", kg: "500",
                    material: [Mat(name: "Betonpflaster", menge: 1.0, einheit: "m²", verschnitt: 0.02)],
                    geraet: []),
            // Randsteine: 1 Stein je lfm + ~0,05 m³ Beton-Rückenstütze
            Vorlage(leistung: "Randsteine setzen", einheit: "lfm", kg: "500",
                    material: [Mat(name: "Randstein", menge: 1.0, einheit: "Stück", verschnitt: 0),
                               Mat(name: "Beton (Rückenstütze)", menge: 0.05, einheit: "m³", verschnitt: 0)],
                    geraet: []),
        ]
    }

    static func rezept(_ v: Vorlage) -> LeistungskatalogService.Rezept {
        LeistungskatalogService.Rezept(
            material: v.material.map {
                .init(name: $0.name, mengeProEinheit: $0.menge, einzelpreis: 0,
                      verschnittProzent: $0.verschnitt, einheit: $0.einheit)
            },
            geraet: v.geraet.map {
                .init(name: $0.name, stunden: $0.stundenProEinheit, kostenProStunde: 0)
            })
    }

    /// Seedet je Vorlage einen Leistungsbaustein. Idempotent: frischt nur das Material/
    /// Gerät-Rezept (Richtwert-Mengen) auf, überschreibt NICHT den Lohn (Aufwandswert
    /// kommt per Prof/Katalog) — sonst wäre Andreas' bestätigter Wert wieder weg.
    @discardableResult
    static func seedIfNeeded(context ctx: NSManagedObjectContext) -> Int {
        var n = 0
        for v in vorlagen {
            let baustein: Leistungsbaustein
            if let vorhanden = LeistungskatalogService.finde(leistung: v.leistung, einheit: v.einheit, in: ctx) {
                baustein = vorhanden
            } else {
                baustein = Leistungsbaustein(context: ctx)
                baustein.id = UUID()
                baustein.leistung = v.leistung
                baustein.einheit = v.einheit
                baustein.maurerStunden = 0
                baustein.helferStunden = 0
                baustein.kostenGruppeNummer = v.kg
                baustein.quelle = "tiefbau-richtwert"
                baustein.verwendungen = 0
                baustein.erstelltAm = Date()
            }
            if let data = try? JSONEncoder().encode(rezept(v)) {
                baustein.rezeptJSON = String(decoding: data, as: UTF8.self)
            }
            n += 1
        }
        if ctx.hasChanges { try? ctx.save() }
        return n
    }
}
