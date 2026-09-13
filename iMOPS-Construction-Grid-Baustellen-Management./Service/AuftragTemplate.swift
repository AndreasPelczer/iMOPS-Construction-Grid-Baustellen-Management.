//
//  AuftragTemplate.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//

import Foundation

/// Vorlagen fuer Baustellen-Auftraege (Gewerke).
enum AuftragTemplate: String, CaseIterable, Identifiable {
    case rohbau = "Rohbau"
    case elektro = "Elektroinstallation"
    case sanitaer = "Sanitaer & Heizung"
    case trockenbau = "Trockenbau"
    case estrich = "Estrich & Boden"
    case maler = "Malerarbeiten"

    // Tiefbau / Pflaster (Aussenanlagen) — z. B. fuer eine Hofeinfahrt.
    case baustelleneinrichtung = "Baustelleneinrichtung"
    case tragschicht = "Tragschicht / Schotter"
    case pflasterbett = "Splittbettung"
    case pflasterverlegen = "Pflaster verlegen"
    case randeinfassung = "Randeinfassung / Leistensteine"

    var id: String { rawValue }

    var steps: [String] {
        switch self {

        case .rohbau:
            return [
                "Schalung vorbereiten / pruefen",
                "Bewehrung einbauen (Stahlplan beachten)",
                "Bewehrung abnehmen lassen (Bauleiter)",
                "Beton bestellen (Menge + Guete pruefen)",
                "Betonieren + Verdichten",
                "Aushaertezeit einhalten / dokumentieren",
                "Schalung entfernen / Nachbehandlung",
                "Qualitaetskontrolle + Fotos"
            ]

        case .elektro:
            return [
                "Schlitze / Durchbrueche markieren",
                "Leerrohre verlegen",
                "Kabel einziehen (nach Plan)",
                "Dosen / Verteiler setzen",
                "Anschluss / Verdrahtung",
                "Durchgangspruefung / Isolationstest",
                "Abnahme durch Elektrofachkraft",
                "Dokumentation (Stromlaufplan aktualisieren)"
            ]

        case .sanitaer:
            return [
                "Rohrleitungen vormontieren",
                "Wandschlitze / Kernbohrungen",
                "Leitungen verlegen (Warm/Kalt/Abwasser)",
                "Druckpruefung durchfuehren",
                "Daemmung anbringen",
                "Sanitaerobjekte montieren",
                "Dichtheitspruefung / Abnahme",
                "Dokumentation + Fotos"
            ]

        case .trockenbau:
            return [
                "UW-/CW-Profile montieren (Unterkonstruktion)",
                "Daemmung einlegen",
                "Beplankung erste Seite (Gipskarton)",
                "Installationen pruefen (Elektro/Sanitaer)",
                "Beplankung zweite Seite",
                "Fugen verspachteln + schleifen",
                "Qualitaetskontrolle Ebenheit",
                "Freigabe fuer Maler"
            ]

        case .estrich:
            return [
                "Untergrund pruefen / reinigen",
                "Randdaemmstreifen verlegen",
                "Folie / Trennlage auslegen",
                "Heizungsrohre pruefen (bei Fussbodenheizung)",
                "Estrich einbringen + abziehen",
                "Trocknungszeit einhalten (Feuchtemessung)",
                "Schleifen / Grundierung",
                "Freigabe fuer Bodenbelag"
            ]

        case .maler:
            return [
                "Untergrund pruefen (Risse, Unebenheiten)",
                "Spachteln + Schleifen",
                "Grundierung auftragen",
                "Abkleben / Abdecken",
                "1. Anstrich / Beschichtung",
                "2. Anstrich (nach Trocknungszeit)",
                "Abkleben entfernen / Nacharbeiten",
                "Endkontrolle + Freigabe"
            ]

        case .baustelleneinrichtung:
            return [
                "Verkehrssicherung / Absperrung stellen",
                "Lagerflaeche + Container einrichten",
                "Maschinen + Geraete antransportieren",
                "Hoehenbolzen / Vermessung pruefen",
                "Ver- und Entsorgung klaeren",
                "Bestand + Nachbargrenzen fotografieren"
            ]

        case .tragschicht:
            return [
                "Erdplanum abziehen + auf Hoehe bringen",
                "Planum verdichten + Tragfaehigkeit pruefen",
                "Mineralgemisch 0/32 antransportieren",
                "Schotter lagenweise einbauen",
                "Hoehen + Gefaelle pruefen (Nivellier)",
                "Verdichten bis 95 % (Ev2 / Plattendruck pruefen)",
                "Oberflaeche feinplanieren + abziehen",
                "Freigabe fuer Bettung"
            ]

        case .pflasterbett:
            return [
                "Randeinfassung als Hoehenbezug pruefen",
                "Abziehlehren nach Gefaelle setzen",
                "Splitt 2/5 bzw. 8/16 auftragen",
                "Bettung gleichmaessig abziehen (ca. 3-5 cm)",
                "Ebenheit pruefen (Richtscheit)",
                "Fertige Bettung nicht mehr betreten"
            ]

        case .pflasterverlegen:
            return [
                "Verlegemuster / Verband festlegen",
                "Steine aus mehreren Paletten mischen (Farbspiel)",
                "Vom festen Rand her verlegen",
                "Fugenbreite 3-5 mm einhalten",
                "Passsteine / Halbsteine einpassen (nass schneiden)",
                "Hoehe + Flucht laufend pruefen (Schnur)",
                "Fugen mit Fugensplitt einfegen",
                "Abruetteln (mit Gummimatte) + nachfegen"
            ]

        case .randeinfassung:
            return [
                "Schnur: Hoehe, Flucht + Gefaelle abstecken",
                "Betonbett (Fundament) herstellen",
                "Leistensteine / Bordsteine setzen",
                "Ausrichten (Hoehe, Flucht, Radien)",
                "Rueckenstuetze aus Beton anlegen",
                "Fugen schliessen",
                "Aushaertezeit einhalten (vor Belastung)"
            ]
        }
    }
}
