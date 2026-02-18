//
//  AuftragTemplate.swift
//  test25B
//
//  Created by Andreas Pelczer on 15.01.26.
//


import Foundation

/// Vorlagen, die du im Auftrag-Detail per Menü auswählen kannst.
enum AuftragTemplate: String, CaseIterable, Identifiable {
    case setzarbeiten = "Setzarbeiten (MEP + SOP)"
    case spaetzleKantine = "Spätzle Kantine (MEP + SOP)"
    case bulgur = "Bulgur (Rezept-Workflow)"
    case buffetFrankfurter = "Buffet: Frankfurter/Wurst"

    var id: String { rawValue }

    /// Die Schritte (MEP + SOP) als reine Texte.
    var steps: [String] {
        switch self {

        case .setzarbeiten:
            return [
                "MEP: Weg & Station prüfen",
                "MEP: GN-Bleche bereitstellen",
                "MEP: Etiketten / Stift / Klebeband",
                "MEP: Handschuhe / Tücher / Reiniger",
                "SOP: Ware holen (Menge + Charge prüfen)",
                "SOP: Bleche belegen (Raster/Abstände Standard)",
                "SOP: Beschriften (Datum/Uhrzeit/Allergene/Charge)",
                "SOP: In Kühlung zurück (Ziel + Stellplatz)",
                "SOP: Übergabe markieren",
                "SOP: Foto (optional)"
            ]

        case .spaetzleKantine:
            return [
                "MEP: Pfanne/Kipper + Fett/Butter bereitstellen",
                "MEP: GN 1/1 6,5 cm bereitstellen",
                "MEP: Transportwagen prüfen",
                "SOP: Spätzle leicht in Butter anbraten",
                "SOP: Auf GN füllen (ca. 5 cm hoch)",
                "SOP: Temperatur prüfen / dokumentieren",
                "SOP: In Kantine bringen / Übergabe"
            ]

        case .bulgur:
            return [
                "MEP: Zutaten abwiegen (Wasser, Salz, Chili, Koriander, Kreuzkümmel, Brühe)",
                "SOP: Wasser aufsetzen / würzen",
                "SOP: Bulgur einrühren",
                "SOP: 12 Minuten dämpfen",
                "SOP: Anschließend auflockern (!!)",
                "SOP: Gewicht prüfen / Portionieren",
                "SOP: Beschriften / Datum / Charge"
            ]

        case .buffetFrankfurter:
            return [
                "MEP: Partybrötchen bereitstellen",
                "MEP: Senf & Ketchup bereitstellen",
                "SOP: Frankfurter Würstchen vorbereiten",
                "SOP: Warmhalten nach Standard",
                "SOP: Transport / Übergabe"
            ]
        }
    }
}
