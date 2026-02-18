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
        }
    }
}
