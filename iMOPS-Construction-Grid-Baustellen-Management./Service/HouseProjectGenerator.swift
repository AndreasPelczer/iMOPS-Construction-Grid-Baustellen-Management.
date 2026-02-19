//
//  HouseProjectGenerator.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Generiert automatisch Massen, Materialien, Kosten und Bauzeitenplan
//  aus einer HouseProject-Konfiguration.
//

import Foundation
import CoreData

enum HouseProjectGenerator {

    // MARK: - Hauptfunktion

    static func generate(from project: HouseProject) -> HouseProjectResult {
        let massen = berechneMassen(project)
        let materialien = berechneMaterialien(project, massen: massen)
        let baukosten = berechneBaukosten(project)
        let nebenkosten = berechneBaunebenkosten(project, baukosten: baukosten.gesamtBaukosten)
        let phasen = berechneBauzeitenplan(project)

        return HouseProjectResult(
            project: project,
            massen: massen,
            materialien: materialien,
            baukosten: baukosten,
            baunebenkosten: nebenkosten,
            phasen: phasen
        )
    }

    // MARK: - Massenermittlung

    private static func berechneMassen(_ p: HouseProject) -> [MassenPosition] {
        var massen: [MassenPosition] = []
        let gf = p.grundflaecheProGeschoss
        let umfang = sqrt(gf) * 4  // Vereinfacht: quadratischer Grundriss
        let geschosshoehe: Double = 2.75

        // Bodenplatte / Fundament
        if p.kellerGeplant {
            massen.append(MassenPosition(
                bezeichnung: "Kellerwand-Aushub",
                menge: gf * 3.0,       // ~3m tief
                einheit: "m\u{00B3}",
                gewerk: "Erdarbeiten",
                details: "Baugrubenaushub fuer Keller"
            ))
            massen.append(MassenPosition(
                bezeichnung: "Kellerboden (Bodenplatte)",
                menge: gf * 0.25,
                einheit: "m\u{00B3}",
                gewerk: "Rohbau",
                details: "Stahlbeton C25/30, d=25cm"
            ))
            massen.append(MassenPosition(
                bezeichnung: "Kellerwaende",
                menge: umfang * 2.5 * 0.24,
                einheit: "m\u{00B3}",
                gewerk: "Rohbau",
                details: "WU-Beton oder KS-Mauerwerk, h=2,50m"
            ))
        } else {
            massen.append(MassenPosition(
                bezeichnung: "Bodenplatte",
                menge: gf * 0.20,
                einheit: "m\u{00B3}",
                gewerk: "Rohbau",
                details: "Stahlbeton C25/30, d=20cm auf Sauberkeitsschicht"
            ))
        }

        // Aussenwaende pro Geschoss
        for g in 1...p.geschosse {
            massen.append(MassenPosition(
                bezeichnung: "Aussenwaende \(geschossBezeichnung(g))",
                menge: umfang * geschosshoehe,
                einheit: "m\u{00B2}",
                gewerk: "Rohbau",
                details: "Mauerwerk 36,5cm (Poroton / KS mit WDVS)"
            ))
        }

        // Innenwaende (ca. 60% der Aussenwandflaeche)
        let innenwandFlaeche = umfang * geschosshoehe * 0.6 * Double(p.geschosse)
        massen.append(MassenPosition(
            bezeichnung: "Innenwaende (gesamt)",
            menge: innenwandFlaeche,
            einheit: "m\u{00B2}",
            gewerk: "Rohbau",
            details: "KS 11,5cm / Poroton 17,5cm"
        ))

        // Geschossdecken
        for g in 1..<p.geschosse {
            massen.append(MassenPosition(
                bezeichnung: "Geschossdecke ueber \(geschossBezeichnung(g))",
                menge: gf,
                einheit: "m\u{00B2}",
                gewerk: "Rohbau",
                details: "Stahlbetondecke d=20cm"
            ))
        }

        // Dach
        let dachflaeche = berechneDachflaeche(gf, dachform: p.dachform)
        massen.append(MassenPosition(
            bezeichnung: "Dachflaeche (\(p.dachform.rawValue))",
            menge: dachflaeche,
            einheit: "m\u{00B2}",
            gewerk: "Dach",
            details: "inkl. Dachstuhl, Eindeckung, Daemmung"
        ))

        // Fenster (ca. 1 Fenster pro 8m² Wohnflaeche)
        let anzahlFenster = max(6, Int(p.wohnflaeche / 8))
        massen.append(MassenPosition(
            bezeichnung: "Fenster",
            menge: Double(anzahlFenster),
            einheit: "Stk",
            gewerk: "Fenster & Tueren",
            details: "3-fach Verglasung, Kunststoff/Alu"
        ))

        // Tueren
        let anzahlTueren = p.anzahlZimmer + p.anzahlBaeder + p.anzahlGaesteWC + 2
        massen.append(MassenPosition(
            bezeichnung: "Innentueren",
            menge: Double(anzahlTueren),
            einheit: "Stk",
            gewerk: "Fenster & Tueren"
        ))
        massen.append(MassenPosition(
            bezeichnung: "Haustuer",
            menge: 1,
            einheit: "Stk",
            gewerk: "Fenster & Tueren",
            details: "Sicherheitstuer RC2"
        ))

        // Elektro
        let steckdosen = p.anzahlZimmer * 6 + p.anzahlBaeder * 3 + (p.kueche ? 12 : 0) + 10
        massen.append(MassenPosition(
            bezeichnung: "Steckdosen",
            menge: Double(steckdosen),
            einheit: "Stk",
            gewerk: "Elektro"
        ))
        massen.append(MassenPosition(
            bezeichnung: "Lichtschalter",
            menge: Double(p.anzahlZimmer + p.anzahlBaeder + p.anzahlGaesteWC + 4),
            einheit: "Stk",
            gewerk: "Elektro"
        ))
        massen.append(MassenPosition(
            bezeichnung: "Elektro-Kabel (NYM)",
            menge: p.wohnflaeche * 3.5,
            einheit: "lfm",
            gewerk: "Elektro",
            details: "NYM-J 3x1,5 + 5x2,5"
        ))

        // Sanitaer
        massen.append(MassenPosition(
            bezeichnung: "Waschtische",
            menge: Double(p.anzahlBaeder + p.anzahlGaesteWC),
            einheit: "Stk",
            gewerk: "Sanitaer"
        ))
        massen.append(MassenPosition(
            bezeichnung: "WC-Anlagen",
            menge: Double(p.anzahlBaeder + p.anzahlGaesteWC),
            einheit: "Stk",
            gewerk: "Sanitaer"
        ))
        massen.append(MassenPosition(
            bezeichnung: "Badewanne / Dusche",
            menge: Double(p.anzahlBaeder),
            einheit: "Stk",
            gewerk: "Sanitaer"
        ))
        massen.append(MassenPosition(
            bezeichnung: "Abwasserleitungen (HT-Rohr)",
            menge: p.wohnflaeche * 0.8,
            einheit: "lfm",
            gewerk: "Sanitaer",
            details: "DN50 + DN100"
        ))
        massen.append(MassenPosition(
            bezeichnung: "Trinkwasserleitungen",
            menge: p.wohnflaeche * 0.6,
            einheit: "lfm",
            gewerk: "Sanitaer",
            details: "Kupfer 15x1 / 22x1"
        ))

        // Estrich
        massen.append(MassenPosition(
            bezeichnung: "Estrich",
            menge: p.wohnflaeche,
            einheit: "m\u{00B2}",
            gewerk: "Estrich & Boden",
            details: p.fussbodenheizung ? "Heizestrich CT-C25-F5, d=65mm" : "Zementestrich CT-C25-F4, d=45mm"
        ))

        // Trockenbau (Decken + evtl. Waende)
        let trockenbauFlaeche = p.wohnflaeche * 0.3
        if trockenbauFlaeche > 0 {
            massen.append(MassenPosition(
                bezeichnung: "Trockenbau (Abhaengdecken / Vorsatzschalen)",
                menge: trockenbauFlaeche,
                einheit: "m\u{00B2}",
                gewerk: "Trockenbau"
            ))
        }

        // Putz / Maler
        let wandflaeche = (umfang * geschosshoehe + innenwandFlaeche / Double(p.geschosse) * 2) * Double(p.geschosse)
        massen.append(MassenPosition(
            bezeichnung: "Innenputz / Malerarbeiten",
            menge: wandflaeche,
            einheit: "m\u{00B2}",
            gewerk: "Malerarbeiten",
            details: "Kalkzementputz + 2x Dispersionsfarbe"
        ))

        // Fussbodenheizung
        if p.fussbodenheizung {
            massen.append(MassenPosition(
                bezeichnung: "Fussbodenheizung",
                menge: p.wohnflaeche * 0.85,
                einheit: "m\u{00B2}",
                gewerk: "Heizung",
                details: "Verlegeabstand 15cm, Noppenplatte"
            ))
        }

        // Garage
        if p.garage {
            massen.append(MassenPosition(
                bezeichnung: "Garage (Fertiggarage)",
                menge: 1,
                einheit: "Stk",
                gewerk: "Aussenanlagen",
                details: "Betonfertiggarage ca. 6x3m"
            ))
        }

        return massen
    }

    // MARK: - Materialien

    private static func berechneMaterialien(_ p: HouseProject, massen: [MassenPosition]) -> [MaterialPosition] {
        var mat: [MaterialPosition] = []
        let gf = p.grundflaecheProGeschoss

        // Beton
        let betonMenge = massen.filter { $0.gewerk == "Rohbau" && $0.einheit == "m\u{00B3}" }
            .reduce(0) { $0 + $1.menge }
        if betonMenge > 0 {
            mat.append(MaterialPosition(
                titel: "Transportbeton C25/30",
                menge: ceil(betonMenge),
                einheit: "m\u{00B3}",
                einzelpreis: 95,
                gewerk: "Rohbau",
                notiz: "inkl. Pumpe, Lieferung"
            ))
        }

        // Bewehrungsstahl (ca. 80 kg/m³ Beton)
        if betonMenge > 0 {
            mat.append(MaterialPosition(
                titel: "Betonstahl BSt 500 S",
                menge: ceil(betonMenge * 80 / 1000),
                einheit: "t",
                einzelpreis: 950,
                gewerk: "Rohbau"
            ))
        }

        // Mauerwerk Aussen
        let aussenwandFlaeche = massen.filter { $0.bezeichnung.starts(with: "Aussenwaende") }
            .reduce(0) { $0 + $1.menge }
        if aussenwandFlaeche > 0 {
            mat.append(MaterialPosition(
                titel: "Poroton-Ziegel T8 (36,5cm)",
                menge: ceil(aussenwandFlaeche),
                einheit: "m\u{00B2}",
                einzelpreis: 45,
                gewerk: "Rohbau",
                notiz: "Planhochlochziegel mit Daemmfuellung"
            ))
            mat.append(MaterialPosition(
                titel: "Duennbettmoertel",
                menge: ceil(aussenwandFlaeche * 3 / 1000),
                einheit: "t",
                einzelpreis: 280,
                gewerk: "Rohbau"
            ))
        }

        // Mauerwerk Innen
        let innenwandFlaeche = massen.first { $0.bezeichnung.starts(with: "Innenwaende") }?.menge ?? 0
        if innenwandFlaeche > 0 {
            mat.append(MaterialPosition(
                titel: "Kalksandstein KS 12-1.4 (11,5cm)",
                menge: ceil(innenwandFlaeche),
                einheit: "m\u{00B2}",
                einzelpreis: 22,
                gewerk: "Rohbau"
            ))
        }

        // Dach
        let dachFlaeche = massen.first { $0.gewerk == "Dach" }?.menge ?? 0
        if dachFlaeche > 0 {
            mat.append(MaterialPosition(
                titel: "Dachziegel (Tondachstein)",
                menge: ceil(dachFlaeche),
                einheit: "m\u{00B2}",
                einzelpreis: 35,
                gewerk: "Dach"
            ))
            mat.append(MaterialPosition(
                titel: "Dachlatten + Konterlattung",
                menge: ceil(dachFlaeche * 3),
                einheit: "lfm",
                einzelpreis: 2.5,
                gewerk: "Dach"
            ))
            mat.append(MaterialPosition(
                titel: "Zwischensparrendaemmung 200mm",
                menge: ceil(dachFlaeche),
                einheit: "m\u{00B2}",
                einzelpreis: 28,
                gewerk: "Dach"
            ))
            mat.append(MaterialPosition(
                titel: "Unterspannbahn (diffusionsoffen)",
                menge: ceil(dachFlaeche * 1.1),
                einheit: "m\u{00B2}",
                einzelpreis: 3.5,
                gewerk: "Dach"
            ))
        }

        // Fenster
        let fensterAnzahl = massen.first { $0.bezeichnung == "Fenster" }?.menge ?? 0
        if fensterAnzahl > 0 {
            let fensterPreis: Double = p.ausstattung == .gehoben ? 850 : (p.ausstattung == .mittel ? 600 : 450)
            mat.append(MaterialPosition(
                titel: "Fenster 3-fach Verglasung",
                menge: fensterAnzahl,
                einheit: "Stk",
                einzelpreis: fensterPreis,
                gewerk: "Fenster & Tueren",
                notiz: "Uw \u{2264} 0,95 W/(m\u{00B2}K)"
            ))
        }

        // Innentueren
        let tuerenAnzahl = massen.first { $0.bezeichnung == "Innentueren" }?.menge ?? 0
        if tuerenAnzahl > 0 {
            let tuerPreis: Double = p.ausstattung == .gehoben ? 450 : (p.ausstattung == .mittel ? 280 : 180)
            mat.append(MaterialPosition(
                titel: "Zimmertuer (Roehrenspan)",
                menge: tuerenAnzahl,
                einheit: "Stk",
                einzelpreis: tuerPreis,
                gewerk: "Fenster & Tueren"
            ))
        }

        // Haustuer
        let haustuerPreis: Double = p.ausstattung == .gehoben ? 3500 : (p.ausstattung == .mittel ? 2200 : 1500)
        mat.append(MaterialPosition(
            titel: "Haustuer (RC2 Sicherheit)",
            menge: 1,
            einheit: "Stk",
            einzelpreis: haustuerPreis,
            gewerk: "Fenster & Tueren"
        ))

        // Elektro
        let kabelMenge = massen.first { $0.bezeichnung.starts(with: "Elektro-Kabel") }?.menge ?? 0
        if kabelMenge > 0 {
            mat.append(MaterialPosition(
                titel: "NYM-J 3x1,5mm\u{00B2}",
                menge: ceil(kabelMenge * 0.6),
                einheit: "lfm",
                einzelpreis: 0.85,
                gewerk: "Elektro"
            ))
            mat.append(MaterialPosition(
                titel: "NYM-J 5x2,5mm\u{00B2}",
                menge: ceil(kabelMenge * 0.4),
                einheit: "lfm",
                einzelpreis: 1.90,
                gewerk: "Elektro"
            ))
        }
        let steckdosenAnzahl = massen.first { $0.bezeichnung == "Steckdosen" }?.menge ?? 0
        if steckdosenAnzahl > 0 {
            mat.append(MaterialPosition(
                titel: "Schalterprogramm (Steckdosen + Schalter)",
                menge: steckdosenAnzahl,
                einheit: "Stk",
                einzelpreis: p.ausstattung == .gehoben ? 18 : 8,
                gewerk: "Elektro"
            ))
            mat.append(MaterialPosition(
                titel: "Leerrohr M20 flexibel",
                menge: ceil(kabelMenge * 0.8),
                einheit: "lfm",
                einzelpreis: 0.65,
                gewerk: "Elektro"
            ))
            mat.append(MaterialPosition(
                titel: "Unterputz-Verteilung (Sicherungskasten)",
                menge: Double(p.geschosse),
                einheit: "Stk",
                einzelpreis: p.ausstattung == .gehoben ? 450 : 250,
                gewerk: "Elektro"
            ))
        }

        // Sanitaer
        let waschtische = massen.first { $0.bezeichnung == "Waschtische" }?.menge ?? 0
        if waschtische > 0 {
            let waschtischPreis: Double = p.ausstattung == .gehoben ? 650 : (p.ausstattung == .mittel ? 350 : 180)
            mat.append(MaterialPosition(
                titel: "Waschtisch inkl. Armatur",
                menge: waschtische,
                einheit: "Stk",
                einzelpreis: waschtischPreis,
                gewerk: "Sanitaer"
            ))
        }
        let wcAnzahl = massen.first { $0.bezeichnung == "WC-Anlagen" }?.menge ?? 0
        if wcAnzahl > 0 {
            let wcPreis: Double = p.ausstattung == .gehoben ? 800 : (p.ausstattung == .mittel ? 450 : 280)
            mat.append(MaterialPosition(
                titel: "WC-Anlage (Vorwand + Keramik)",
                menge: wcAnzahl,
                einheit: "Stk",
                einzelpreis: wcPreis,
                gewerk: "Sanitaer"
            ))
        }
        let baederAnzahl = massen.first { $0.bezeichnung == "Badewanne / Dusche" }?.menge ?? 0
        if baederAnzahl > 0 {
            let badPreis: Double = p.ausstattung == .gehoben ? 1200 : (p.ausstattung == .mittel ? 700 : 400)
            mat.append(MaterialPosition(
                titel: "Dusche / Badewanne inkl. Armatur",
                menge: baederAnzahl,
                einheit: "Stk",
                einzelpreis: badPreis,
                gewerk: "Sanitaer"
            ))
        }
        let abwasserMenge = massen.first { $0.bezeichnung.starts(with: "Abwasserleitungen") }?.menge ?? 0
        if abwasserMenge > 0 {
            mat.append(MaterialPosition(
                titel: "HT-Rohr DN50",
                menge: ceil(abwasserMenge * 0.6),
                einheit: "lfm",
                einzelpreis: 4.50,
                gewerk: "Sanitaer"
            ))
            mat.append(MaterialPosition(
                titel: "HT-Rohr DN100",
                menge: ceil(abwasserMenge * 0.4),
                einheit: "lfm",
                einzelpreis: 7.80,
                gewerk: "Sanitaer"
            ))
        }
        let trinkwasserMenge = massen.first { $0.bezeichnung.starts(with: "Trinkwasserleitungen") }?.menge ?? 0
        if trinkwasserMenge > 0 {
            mat.append(MaterialPosition(
                titel: "Kupferrohr 15x1mm",
                menge: ceil(trinkwasserMenge),
                einheit: "lfm",
                einzelpreis: 6.50,
                gewerk: "Sanitaer"
            ))
        }

        // Estrich
        mat.append(MaterialPosition(
            titel: p.fussbodenheizung ? "Heizestrich CT-C25-F5" : "Zementestrich CT-C25-F4",
            menge: ceil(p.wohnflaeche * (p.fussbodenheizung ? 0.065 : 0.045)),
            einheit: "m\u{00B3}",
            einzelpreis: 95,
            gewerk: "Estrich & Boden"
        ))

        // Trockenbau
        let tbFlaeche = massen.first { $0.gewerk == "Trockenbau" }?.menge ?? 0
        if tbFlaeche > 0 {
            mat.append(MaterialPosition(
                titel: "Gipskartonplatte GKB 12,5mm",
                menge: ceil(tbFlaeche * 2.1), // 2 Seiten + Verschnitt
                einheit: "m\u{00B2}",
                einzelpreis: 5.50,
                gewerk: "Trockenbau"
            ))
            mat.append(MaterialPosition(
                titel: "CW-Profil 75/50",
                menge: ceil(tbFlaeche / 0.625), // alle 62,5cm ein Profil
                einheit: "Stk",
                einzelpreis: 4.20,
                gewerk: "Trockenbau"
            ))
            mat.append(MaterialPosition(
                titel: "Mineralwolle 60mm WLG 035",
                menge: ceil(tbFlaeche),
                einheit: "m\u{00B2}",
                einzelpreis: 8.50,
                gewerk: "Trockenbau"
            ))
        }

        // Innenputz / Maler
        let malerFlaeche = massen.first { $0.gewerk == "Malerarbeiten" }?.menge ?? 0
        if malerFlaeche > 0 {
            mat.append(MaterialPosition(
                titel: "Kalkzement-Maschinenputz",
                menge: ceil(malerFlaeche * 0.015), // 15mm Putzdicke
                einheit: "t",
                einzelpreis: 180,
                gewerk: "Malerarbeiten"
            ))
            mat.append(MaterialPosition(
                titel: "Dispersionsfarbe (weiss)",
                menge: ceil(malerFlaeche / 6), // 6m²/Liter, 2x streichen
                einheit: "Liter",
                einzelpreis: 4.50,
                gewerk: "Malerarbeiten"
            ))
        }

        // Heizung
        if p.fussbodenheizung {
            mat.append(MaterialPosition(
                titel: "Fussbodenheizung Noppenplatte",
                menge: ceil(p.wohnflaeche * 0.85),
                einheit: "m\u{00B2}",
                einzelpreis: 22,
                gewerk: "Heizung"
            ))
            mat.append(MaterialPosition(
                titel: "Heizrohr PE-Xa 17x2mm",
                menge: ceil(p.wohnflaeche * 0.85 / 0.15 * 1.1),
                einheit: "lfm",
                einzelpreis: 1.20,
                gewerk: "Heizung"
            ))
        }
        if p.waermepumpe {
            mat.append(MaterialPosition(
                titel: "Luft-Wasser-Waermepumpe",
                menge: 1,
                einheit: "Stk",
                einzelpreis: p.ausstattung == .gehoben ? 18000 : 12000,
                gewerk: "Heizung",
                notiz: "inkl. Pufferspeicher"
            ))
        } else {
            mat.append(MaterialPosition(
                titel: "Gas-Brennwertkessel",
                menge: 1,
                einheit: "Stk",
                einzelpreis: p.ausstattung == .gehoben ? 6500 : 4500,
                gewerk: "Heizung"
            ))
        }

        // Solaranlage
        if p.solaranlage {
            let panelAnzahl = max(8, Int(p.wohnflaeche / 15))
            mat.append(MaterialPosition(
                titel: "PV-Module (400Wp)",
                menge: Double(panelAnzahl),
                einheit: "Stk",
                einzelpreis: 280,
                gewerk: "Elektro",
                notiz: "\(panelAnzahl * 400 / 1000) kWp Anlage"
            ))
            mat.append(MaterialPosition(
                titel: "Wechselrichter + Montagesystem",
                menge: 1,
                einheit: "Stk",
                einzelpreis: 3500,
                gewerk: "Elektro"
            ))
        }

        // SmartHome
        if p.smartHome {
            mat.append(MaterialPosition(
                titel: "SmartHome-Zentrale + Aktoren",
                menge: 1,
                einheit: "Pauschal",
                einzelpreis: p.ausstattung == .gehoben ? 8000 : 4000,
                gewerk: "Elektro",
                notiz: "KNX / Loxone inkl. Programmierung"
            ))
        }

        // Garage
        if p.garage {
            mat.append(MaterialPosition(
                titel: "Betonfertiggarage 6x3m",
                menge: 1,
                einheit: "Stk",
                einzelpreis: 8500,
                gewerk: "Aussenanlagen",
                notiz: "inkl. Lieferung + Aufstellung"
            ))
        }

        return mat
    }

    // MARK: - Baukosten (nach Gewerk aufgeschluesselt)

    private static func berechneBaukosten(_ p: HouseProject) -> Kostenaufstellung {
        let gesamt = p.wohnflaeche * p.ausstattung.kostenProQm
        var k = Kostenaufstellung()

        // Prozentuale Aufteilung nach BKI (Baukostenindex)
        k.rohbau = gesamt * (p.kellerGeplant ? 0.32 : 0.28)
        k.dach = gesamt * 0.08
        k.fensterTueren = gesamt * 0.07
        k.elektro = gesamt * 0.10
        k.sanitaer = gesamt * 0.08
        k.heizung = gesamt * 0.08
        k.trockenbau = gesamt * 0.05
        k.estrich = gesamt * 0.04
        k.maler = gesamt * 0.05
        k.aussenanlagen = gesamt * 0.04

        // Zuschlaege
        if p.waermepumpe { k.heizung += 6000 }
        if p.solaranlage { k.elektro += Double(max(8, Int(p.wohnflaeche / 15))) * 280 + 3500 }
        if p.smartHome { k.elektro += (p.ausstattung == .gehoben ? 8000 : 4000) }
        if p.garage { k.aussenanlagen += 8500 }

        return k
    }

    // MARK: - Baunebenkosten

    private static func berechneBaunebenkosten(_ p: HouseProject, baukosten: Double) -> [Nebenkostenposition] {
        var nk: [Nebenkostenposition] = []

        nk.append(Nebenkostenposition(
            bezeichnung: "Architektenhonorar (HOAI)",
            betrag: baukosten * 0.10,
            details: "Leistungsphasen 1-9 nach HOAI"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Statiker / Tragwerksplaner",
            betrag: max(4000, baukosten * 0.015),
            details: "Standsicherheitsnachweis + Positionsplaene"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Baugenehmigung",
            betrag: max(500, baukosten * 0.005),
            details: "Gebuehren Bauamt / Bauaufsicht"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Vermessung",
            betrag: 2800,
            details: "Lageplan + Einmessung + Gebaeudeschlussvermessung"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Baugrundgutachten",
            betrag: 2000,
            details: "Bodengutachten mit Bohrungen"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Energieberater / EnEV-Nachweis",
            betrag: 2500,
            details: "GEG-Nachweis + Blower-Door-Test"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Pruefstatiker",
            betrag: max(1500, baukosten * 0.005),
            details: "Pruefingenieur fuer Standsicherheit"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Baustrom / Bauwasser",
            betrag: 800,
            details: "Anschluss + Verbrauch waehrend Bauphase"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Versicherungen",
            betrag: 1800,
            details: "Bauherrenhaftpflicht + Bauleistungsversicherung + Feuerrohbau"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Erschliessung",
            betrag: 8000,
            details: "Kanal, Wasser, Strom, Gas/Fernwaerme, Telekom"
        ))
        nk.append(Nebenkostenposition(
            bezeichnung: "Aussen- und Gartenanlage",
            betrag: max(5000, baukosten * 0.03),
            details: "Zufahrt, Terrasse, Bepflanzung"
        ))

        return nk
    }

    // MARK: - Bauzeitenplan

    private static func berechneBauzeitenplan(_ p: HouseProject) -> [Bauphase] {
        var phasen: [Bauphase] = []
        var woche = 0

        // Erdarbeiten / Keller
        if p.kellerGeplant {
            phasen.append(Bauphase(
                name: "Erdarbeiten + Keller",
                gewerk: "Rohbau",
                dauerWochen: 4,
                startWoche: woche,
                beschreibung: "Aushub, Bodenplatte, Kellerwaende, Abdichtung"
            ))
            woche += 4
        } else {
            phasen.append(Bauphase(
                name: "Erdarbeiten + Bodenplatte",
                gewerk: "Rohbau",
                dauerWochen: 2,
                startWoche: woche,
                beschreibung: "Aushub, Sauberkeitsschicht, Bodenplatte"
            ))
            woche += 2
        }

        // Rohbau
        let rohbauDauer = p.geschosse * 3 + 1
        phasen.append(Bauphase(
            name: "Rohbau (Mauerwerk + Decken)",
            gewerk: "Rohbau",
            dauerWochen: rohbauDauer,
            startWoche: woche,
            beschreibung: "Mauern, Betonieren, Ringbalken, Stuerze"
        ))
        woche += rohbauDauer

        // Dach
        let dachDauer = p.dachform == .flachdach ? 2 : 3
        phasen.append(Bauphase(
            name: "Dachstuhl + Eindeckung",
            gewerk: "Dach",
            dauerWochen: dachDauer,
            startWoche: woche,
            beschreibung: "Dachstuhl aufstellen, Lattung, Eindeckung, Daemmung"
        ))
        woche += dachDauer

        // Fenster (parallel zum Innenausbau-Start)
        phasen.append(Bauphase(
            name: "Fenster + Haustuer",
            gewerk: "Fenster & Tueren",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Fenstereinbau, Abdichtung, Haustuer"
        ))

        // Rohinstallation Elektro (parallel)
        let elektroStart = woche
        phasen.append(Bauphase(
            name: "Elektro Rohinstallation",
            gewerk: "Elektro",
            dauerWochen: 3,
            startWoche: elektroStart,
            beschreibung: "Schlitze, Leerrohre, Kabel, Dosen, Verteiler"
        ))

        // Rohinstallation Sanitaer (parallel zu Elektro)
        phasen.append(Bauphase(
            name: "Sanitaer Rohinstallation",
            gewerk: "Sanitaer",
            dauerWochen: 3,
            startWoche: elektroStart,
            beschreibung: "Abwasser, Trinkwasser, Druckpruefung"
        ))

        // Heizung
        phasen.append(Bauphase(
            name: "Heizungsinstallation",
            gewerk: "Heizung",
            dauerWochen: 2,
            startWoche: elektroStart + 1,
            beschreibung: p.fussbodenheizung
                ? "Fussbodenheizung verlegen, Heizkreisverteiler"
                : "Heizkoerper montieren, Rohrleitungen"
        ))
        woche = elektroStart + 3

        // Innenputz
        phasen.append(Bauphase(
            name: "Innenputz",
            gewerk: "Malerarbeiten",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Kalkzement-Maschinenputz alle Raeume"
        ))
        woche += 2

        // Estrich
        phasen.append(Bauphase(
            name: "Estrich + Trocknungszeit",
            gewerk: "Estrich & Boden",
            dauerWochen: p.fussbodenheizung ? 5 : 4,
            startWoche: woche,
            beschreibung: p.fussbodenheizung
                ? "Heizestrich einbringen, 4 Wochen Trocknung, Aufheizprotokoll"
                : "Zementestrich einbringen, 3-4 Wochen Trocknung"
        ))
        woche += (p.fussbodenheizung ? 5 : 4)

        // Trockenbau
        phasen.append(Bauphase(
            name: "Trockenbau",
            gewerk: "Trockenbau",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Vorsatzschalen, Abhaengdecken, Spachteln"
        ))
        woche += 2

        // Fliesen
        phasen.append(Bauphase(
            name: "Fliesen (Baeder + Kueche)",
            gewerk: "Ausbau",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Abdichtung, Fliesen Wand + Boden"
        ))

        // Bodenbelag (parallel zu Fliesen)
        phasen.append(Bauphase(
            name: "Bodenbelaege (Parkett / Laminat)",
            gewerk: "Ausbau",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Trittschalldaemmung, Bodenbelag verlegen"
        ))
        woche += 2

        // Innentueren
        phasen.append(Bauphase(
            name: "Innentueren",
            gewerk: "Fenster & Tueren",
            dauerWochen: 1,
            startWoche: woche,
            beschreibung: "Zargen + Tuerblaetter montieren"
        ))
        woche += 1

        // Malerarbeiten
        phasen.append(Bauphase(
            name: "Malerarbeiten (Finish)",
            gewerk: "Malerarbeiten",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Spachteln, Schleifen, 2x Anstrich"
        ))

        // Sanitaer Feininstallation (parallel zu Maler)
        phasen.append(Bauphase(
            name: "Sanitaer Feininstallation",
            gewerk: "Sanitaer",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Waschtische, WCs, Armaturen montieren"
        ))

        // Elektro Feininstallation (parallel)
        phasen.append(Bauphase(
            name: "Elektro Feininstallation",
            gewerk: "Elektro",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Steckdosen, Schalter, Leuchten, Abnahme"
        ))
        woche += 2

        // Aussenanlagen
        phasen.append(Bauphase(
            name: "Aussenanlagen",
            gewerk: "Aussenanlagen",
            dauerWochen: 2,
            startWoche: woche,
            beschreibung: "Zufahrt, Terrasse, Gartenanlage"
        ))

        // Solaranlage (falls geplant)
        if p.solaranlage {
            phasen.append(Bauphase(
                name: "Photovoltaik-Anlage",
                gewerk: "Elektro",
                dauerWochen: 1,
                startWoche: woche,
                beschreibung: "PV-Module + Wechselrichter montieren"
            ))
        }

        // Endreinigung + Abnahme
        woche += 2
        phasen.append(Bauphase(
            name: "Endreinigung + Abnahme",
            gewerk: "Allgemein",
            dauerWochen: 1,
            startWoche: woche,
            beschreibung: "Baureinigung, Maengelprotokoll, Abnahme"
        ))

        return phasen
    }

    // MARK: - Hilfsfunktionen

    private static func geschossBezeichnung(_ g: Int) -> String {
        switch g {
        case 1: return "EG"
        case 2: return "OG"
        case 3: return "2.OG"
        default: return "\(g - 1).OG"
        }
    }

    private static func berechneDachflaeche(_ grundflaeche: Double, dachform: Dachform) -> Double {
        switch dachform {
        case .satteldach:  return grundflaeche * 1.4
        case .walmdach:    return grundflaeche * 1.5
        case .flachdach:   return grundflaeche * 1.05
        case .pultdach:    return grundflaeche * 1.25
        }
    }

    // MARK: - Baustelle aus Ergebnis erzeugen

    static func createEvent(
        from result: HouseProjectResult,
        into context: NSManagedObjectContext
    ) -> Event {
        let event = Event(context: context)
        event.title = result.project.projektName.isEmpty
            ? "\(result.project.haustyp.rawValue) – Neubau"
            : result.project.projektName
        event.eventNumber = "HK-\(String(result.project.id.prefix(8)).uppercased())"
        event.location = ""
        event.timeStamp = Date()

        // Zeitplan aus Bauphasen berechnen
        let now = Date()
        let cal = Calendar.current
        event.setupTime = cal.date(byAdding: .weekOfYear, value: -1, to: now)
        event.eventStartTime = now
        let gesamtWochen = result.phasen.map { $0.endeWoche }.max() ?? 40
        event.eventEndTime = cal.date(byAdding: .weekOfYear, value: gesamtWochen, to: now)

        // Notes mit Kostenuebersicht
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "EUR"
        fmt.locale = Locale(identifier: "de_DE")

        let bk = fmt.string(from: NSNumber(value: result.baukosten.gesamtBaukosten)) ?? ""
        let nk = fmt.string(from: NSNumber(value: result.baunebenkosten.reduce(0) { $0 + $1.betrag })) ?? ""
        let gk = fmt.string(from: NSNumber(value: result.gesamtkosten)) ?? ""

        event.notes = """
        Generiert aus Haus-Konfigurator
        Typ: \(result.project.haustyp.rawValue)
        Flaeche: \(Int(result.project.wohnflaeche)) m\u{00B2}, \(result.project.geschosse) Geschoss(e)
        Ausstattung: \(result.project.ausstattung.rawValue)

        Baukosten: \(bk)
        Nebenkosten: \(nk)
        Gesamt: \(gk)
        """

        // Checklist aus Bauphasen
        var extras = EventExtrasPayload()
        extras.checklist = result.phasen.map { phase in
            EventChecklistItem(title: "\(phase.name) (KW+\(phase.startWoche)–\(phase.endeWoche))")
        }

        // Materialien aus Katalog verlinken
        let bekannteCodeMap: [String: String] = [
            "Transportbeton C25/30": "BET-C25",
            "Betonstahl BSt 500 S": "BST-500",
            "Kalksandstein KS 12-1.4 (11,5cm)": "KS-1214",
            "Gipskartonplatte GKB 12,5mm": "GKB-125",
            "CW-Profil 75/50": "CW-7550",
            "Mineralwolle 60mm WLG 035": "MW-60",
            "NYM-J 3x1,5mm\u{00B2}": "NYM-315",
            "NYM-J 5x2,5mm\u{00B2}": "NYM-525",
            "Leerrohr M20 flexibel": "LR-M20",
            "HT-Rohr DN50": "HT-50",
            "HT-Rohr DN100": "HT-100",
            "Kupferrohr 15x1mm": "CU-15"
        ]
        for mat in result.materialien {
            if let code = bekannteCodeMap[mat.titel] {
                extras.pinnedLexikonCodes.append(code)
            }
        }

        do {
            let data = try JSONEncoder().encode(extras)
            event.extras = String(data: data, encoding: .utf8)
        } catch {
            print("HouseProjectGenerator: Konnte extras nicht encoden: \(error)")
        }

        // Auftraege pro Gewerk erstellen
        let gewerke = Dictionary(grouping: result.materialien, by: { $0.gewerk })
        for (gewerk, materialien) in gewerke.sorted(by: { $0.key < $1.key }) {
            let job = Auftrag(context: context)
            job.event = event
            job.employeeName = ""
            job.status = .pending
            job.isCompleted = false
            job.storageLocation = ""
            job.storageNote = ""
            job.deliveryTemperature = false
            job.processingDetails = "\(gewerk) – Neubau \(result.project.haustyp.rawValue)"
            job.totalProcessingTime = 0

            var jobExtras = AuftragExtrasPayload()
            jobExtras.gewerk = gewerk

            // Materialien als LineItems
            jobExtras.lineItems = materialien.map { mat in
                AuftragLineItem(
                    title: mat.titel,
                    amount: formatMenge(mat.menge),
                    unit: mat.einheit,
                    note: mat.notiz
                )
            }

            // Passende Vorlage finden und als Checkliste verwenden
            if let template = templateFuerGewerk(gewerk) {
                jobExtras.checklist = template.steps.map { AuftragChecklistItem(title: $0) }
            }

            // Passende Bauphase fuer Deadline finden
            if let phase = result.phasen.first(where: { $0.gewerk == gewerk }) {
                jobExtras.station = phase.name
                let cal = Calendar.current
                jobExtras.deadline = cal.date(byAdding: .weekOfYear, value: phase.endeWoche, to: now)
            }

            jobExtras.orderNumber = "\(gewerk.prefix(3).uppercased())-\(String(UUID().uuidString.prefix(4)))"
            job.extras = jobExtras.toJSONString()
        }

        return event
    }

    private static func templateFuerGewerk(_ gewerk: String) -> AuftragTemplate? {
        switch gewerk {
        case "Rohbau": return .rohbau
        case "Elektro": return .elektro
        case "Sanitaer": return .sanitaer
        case "Trockenbau": return .trockenbau
        case "Estrich & Boden": return .estrich
        case "Malerarbeiten": return .maler
        default: return nil
        }
    }

    private static func formatMenge(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
