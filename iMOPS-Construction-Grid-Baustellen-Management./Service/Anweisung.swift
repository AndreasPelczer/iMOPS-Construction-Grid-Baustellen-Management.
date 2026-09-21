//
//  Anweisung.swift
//
//  Arbeitsschritte mit HERKUNFT — und mit der Markierung, welcher Schritt einen Wert
//  trägt, den nur ein Fachmann abnehmen darf.
//
//  Andreas, 21.09.2026, über die 91 vorhandenen Schritte:
//  „Haben wir die erfunden oder ist das die Beschreibung der Packungsbeilage? Da ist
//  glaube ich noch der Wurm drin."
//
//  War er. Keine Quelle, kein Prüfer, kein Datum — und die Liste geht an einen
//  Lehrling. Ab jetzt trägt jeder Schritt, woher er kommt und wer ihn abgenommen hat.
//
//  🔴 Die Trennlinie, die Andreas selbst gezogen hat:
//  Reihenfolge und Logik kann er beurteilen (Schalung vor Beton, Bewehrung vor dem
//  Verschließen — das erkennt man mit Verstand). ZAHLEN nicht: „95 % Ev2",
//  „Fugenbreite 3–5 mm", „nach 28 Tagen" sehen immer plausibel aus. Genau dort lag der
//  Fehler. Also: ein Schritt ohne Wert darf jeder abnehmen; ein Schritt MIT Wert bleibt
//  gelb, bis ein Fachmann draufgeschaut hat.
//

import Foundation

/// Woher ein Arbeitsschritt stammt.
enum SchrittHerkunft: String, Codable, CaseIterable {
    case prof      // vom Mops-Server gefragt (lokale KI oder Prof-Rückfall)
    case vorlage   // aus einer der eingebauten AuftragTemplate-Vorlagen
    case rezept    // aus dem Rezept der Position abgeleitet (Material/Gerät/Aufmaß)
    case katalog   // schon einmal geschrieben und gemerkt
    case selbst    // von Hand getippt

    var kurz: String {
        switch self {
        case .prof:    return "vom Mops vorgeschlagen"
        case .vorlage: return "aus einer Vorlage"
        case .rezept:  return "aus dem Rezept"
        case .katalog: return "schon einmal abgenommen"
        case .selbst:  return "selbst geschrieben"
        }
    }

    /// Von Hand Geschriebenes braucht keine zweite Abnahme — wer tippt, steht dafür.
    var brauchtAbnahme: Bool { self != .selbst }
}

/// Ein Arbeitsschritt mit Herkunft und Abnahme.
struct AnweisungsSchritt: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var text: String
    var herkunft: SchrittHerkunft

    /// Wer den Schritt inhaltlich abgenommen hat (nicht: wer ihn ausgeführt hat).
    var abgenommenVon: String?
    var abgenommenAm: Date?

    /// Modell/Quelle, falls vom Server — damit später nachvollziehbar ist, wen man
    /// gefragt hat. `MopsResponse` liefert das mit.
    var modell: String?

    /// 🔴 Trägt dieser Schritt einen Zahlenwert oder Normverweis?
    /// Dann reicht „klingt plausibel" nicht als Prüfung.
    var traegtWert: Bool = false

    var istAbgenommen: Bool { abgenommenVon != nil }

    /// Was auf dem Bildschirm steht, solange niemand unterschrieben hat.
    var ampel: String {
        if !herkunft.brauchtAbnahme || istAbgenommen { return "🟢" }
        return traegtWert ? "🔴" : "🟡"
    }
}

// MARK: - Werte erkennen

enum Werterkennung {

    /// Normverweise — dahinter steckt immer ein Wert, auch ohne Ziffer im Satz.
    private static let normen = [
        "din ", "en 1", "en 2", " iso", "dguv", "vob/", " atv", "ev1", "ev2", "dpr",
        "stlb", "dwa", "fgsv", "rstо", "zwischenlage"
    ]

    /// Steht eine Zahl im Schritt, muss jemand draufschauen. So einfach.
    ///
    /// 🔴 Der erste Versuch war zu clever: eine Liste von Einheiten und Kürzeln, bei
    /// der „en " (für EN-Normen) JEDES deutsche Wort auf -en traf — „vorbereiten ",
    /// „lassen ", „mehreren ". Fünf harmlose Handgriffe wurden rot, und „Mineralgemisch
    /// 0/32" (eine Körnung, also sehr wohl ein Wert) blieb grün. Genau verkehrt herum.
    ///
    /// Die einfache Regel trägt weiter: **eine Ziffer ist eine Behauptung.**
    /// „Fugenbreite 3-5 mm", „95 % Ev2", „Ytong PP2-0,35", „Mineralgemisch 0/32",
    /// „C25/30", „28 Tage" — alles Werte, die Andreas nach eigener Aussage nicht
    /// beurteilen kann, weil sie immer plausibel aussehen. Eine bloße
    /// Aufzählungsnummer am Zeilenanfang zählt nicht mit.
    static func traegtWert(_ text: String) -> Bool {
        let klein = text.lowercased()
        if normen.contains(where: { klein.contains($0) }) { return true }

        let ohneNummer = text.replacingOccurrences(
            of: #"^\s*\d{1,2}[.)]\s*"#, with: "", options: .regularExpression)
        return ohneNummer.rangeOfCharacter(from: .decimalDigits) != nil
    }
}
