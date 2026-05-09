import Foundation
import SwiftUI

// MARK: - Baustellenrelevante Wetterwarnung

struct BauWarnung: Identifiable, Equatable {
    let id = UUID()
    let stufe: Stufe
    let titel: String
    let detail: String
    let betroffeneKGs: [String]   // DIN 276 KGs die betroffen sind

    enum Stufe: Int, Comparable {
        case info = 0
        case vorsicht = 1
        case stopp = 2

        static func < (lhs: Stufe, rhs: Stufe) -> Bool { lhs.rawValue < rhs.rawValue }

        var farbe: Color {
            switch self {
            case .info:    return .blue
            case .vorsicht: return .orange
            case .stopp:   return .red
            }
        }
        var symbol: String {
            switch self {
            case .info:    return "info.circle.fill"
            case .vorsicht: return "exclamationmark.triangle.fill"
            case .stopp:   return "xmark.octagon.fill"
            }
        }
        var label: String {
            switch self {
            case .info:    return "Hinweis"
            case .vorsicht: return "Vorsicht"
            case .stopp:   return "Stopp"
            }
        }
    }
}

// MARK: - Auftrag-Empfehlung bei schlechtem Wetter

struct WetterEmpfehlung {
    let gewerk: String
    let bevorzugteKGs: [String]
    let grund: String
}

// MARK: - Regel-Engine

struct BauWetterRegeln {

    static func warnungen(fuer wetter: BaustellenWetter) -> [BauWarnung] {
        var result: [BauWarnung] = []

        // FROST
        if wetter.temperatur <= 0 {
            result.append(.init(
                stufe: .stopp,
                titel: "Frost: \(wetter.temperaturText)",
                detail: "Kein Beton gießen, kein Mauerwerk, kein Außenputz. DIN 1045/VOB Teil C.",
                betroffeneKGs: ["320", "322", "323", "331", "341", "335"]
            ))
        } else if wetter.temperatur <= 3 {
            result.append(.init(
                stufe: .vorsicht,
                titel: "Frostgefahr: \(wetter.temperaturText)",
                detail: "Frischbeton und Mörtel schützen. Frostschutzmaßnahmen einleiten.",
                betroffeneKGs: ["320", "322", "331", "341"]
            ))
        }

        // HITZE
        if wetter.temperatur >= 35 {
            result.append(.init(
                stufe: .stopp,
                titel: "Hitze: \(wetter.temperaturText)",
                detail: "Pflichtpausen alle 45 Min. Trinkwasser bereitstellen. ArbSchG §3.",
                betroffeneKGs: []
            ))
        } else if wetter.temperatur >= 30 {
            result.append(.init(
                stufe: .vorsicht,
                titel: "Starke Hitze: \(wetter.temperaturText)",
                detail: "Regelmäßige Pausen, Sonnenschutz. Betonieren nur früh morgens.",
                betroffeneKGs: ["320", "322", "331"]
            ))
        }

        // STARKREGEN
        if wetter.niederschlag1h >= 10 {
            result.append(.init(
                stufe: .stopp,
                titel: "Starkregen: \(String(format: "%.0f mm/h", wetter.niederschlag1h))",
                detail: "Keine Erdarbeiten, kein Außenputz, Baugrube sichern.",
                betroffeneKGs: ["310", "311", "320", "335", "530", "531"]
            ))
        } else if wetter.niederschlag1h >= 2 {
            result.append(.init(
                stufe: .vorsicht,
                titel: "Regen: \(String(format: "%.0f mm/h", wetter.niederschlag1h))",
                detail: "Frischen Beton abdecken. Außenputz und Malerarbeiten verschieben.",
                betroffeneKGs: ["322", "335", "345", "363"]
            ))
        }

        // STURM
        if wetter.windGeschwindigkeit >= 17.2 {  // Beaufort 8
            result.append(.init(
                stufe: .stopp,
                titel: "Sturm: \(wetter.windText)",
                detail: "Kran- und Gerüstarbeiten sofort einstellen. BG Bau DGUV 201-056.",
                betroffeneKGs: ["330", "331", "332", "340", "360", "361"]
            ))
        } else if wetter.windGeschwindigkeit >= 10.8 {  // Beaufort 6
            result.append(.init(
                stufe: .vorsicht,
                titel: "Starker Wind: \(wetter.windText)",
                detail: "Kranführer informieren. Freistehende Elemente sichern.",
                betroffeneKGs: ["330", "332", "360"]
            ))
        }

        // SCHNEE / GLÄTTE
        if wetter.temperatur <= 2 && wetter.luftfeuchtigkeit >= 85 {
            result.append(.init(
                stufe: .vorsicht,
                titel: "Glättegefahr",
                detail: "Zugangswege streuen. Gerüste auf Eisfreiheit prüfen.",
                betroffeneKGs: []
            ))
        }

        return result.sorted { $0.stufe > $1.stufe }
    }

    // MARK: - Indoor-Empfehlung bei schlechtem Wetter

    static func indoorEmpfehlung(fuer wetter: BaustellenWetter) -> WetterEmpfehlung? {
        let hatStopp = warnungen(fuer: wetter).contains { $0.stufe == .stopp }
        guard hatStopp else { return nil }

        return WetterEmpfehlung(
            gewerk: "Innenausbau",
            bevorzugteKGs: ["342", "344", "345", "351", "352", "353", "440", "444", "445"],
            grund: "Außenarbeiten wetterbedingt gestoppt → auf Innengewerke umstellen"
        )
    }

    // MARK: - Kurztext für UI

    static func ampelFarbe(fuer wetter: BaustellenWetter) -> Color {
        let stufen = warnungen(fuer: wetter).map { $0.stufe }
        if stufen.contains(.stopp)    { return .red }
        if stufen.contains(.vorsicht) { return .orange }
        return .green
    }

    // MARK: - Strukturierte Validierung (RuleViolation-Pattern)
    //
    // Gibt nur bei echten STOPP-Bedingungen .failure zurück.
    // VORSICHT-Warnungen bleiben in warnungen() — die sind UI-Hinweise, kein Blocker.

    static func validateArbeitsbedingungen(wetter: BaustellenWetter) -> ValidationResult {
        // Sturm → sofortiger SHE-Stopp (höchste Priorität)
        if wetter.windGeschwindigkeit >= 17.2 {
            return BauValidator.validateWindsicherheit(windGeschwindigkeit: wetter.windGeschwindigkeit)
        }

        // Frost oder Extremhitze → Betonage/Arbeitsschutz-Stopp
        let tempResult = BauValidator.validateBetonage(temperatur: wetter.temperatur)
        if case .failure = tempResult { return tempResult }

        // Starkregen → Erdarbeiten-Stopp
        if wetter.niederschlag1h >= 10 {
            return .failure(RuleViolation(
                ruleId: "BAU-W-03",
                reason: "Starkregen (\(String(format: "%.0f", wetter.niederschlag1h)) mm/h): Keine Erdarbeiten, Baugrube sichern.",
                fields: ["niederschlag1h"]
            ))
        }

        return .success(())
    }
}
