//
//  QuelleBadge.swift
//  Der „Woher kommt die Zahl?"-Nachweis. Jeder Kalkulations-Wert trägt eine Herkunft;
//  das Badge zeigt sie auf den ersten Blick, ehrlich abgestuft — belegt vs. ausgedacht.
//  (Tao: Nachweis statt Behauptung. „Wer behauptet das?" muss beantwortbar sein.)
//

import SwiftUI

/// Herkunft eines Kalkulations-Werts.
enum Kostenquelle {
    case raffi        // firmeneigen, belegt (aufwandswerte.yaml, quelle: RAFFI)
    case praxis       // öffentlicher Praxis-Richtwert (YAML)
    case katalog      // Maschinenkatalog (mit Quellenangabe)
    case startwert    // Demo-/Platzhalter, NICHT belegt
    case eigen        // in der App selbst eingetragen/überschrieben
    case unbekannt

    init(_ raw: String?) {
        switch (raw ?? "").lowercased().trimmingCharacters(in: .whitespaces) {
        case "raffi":                                   self = .raffi
        case "praxis":                                  self = .praxis
        case "katalog":                                 self = .katalog
        case "startwert", "demo", "seed", "schätzung", "schaetzung": self = .startwert
        case "eigen", "erfahrung":                      self = .eigen
        default:                                        self = .unbekannt
        }
    }

    var kurz: String {
        switch self {
        case .raffi:     return "RAFFI"
        case .praxis:    return "Praxis"
        case .katalog:   return "Katalog"
        case .startwert: return "Startwert – prüfen"
        case .eigen:     return "dein Wert"
        case .unbekannt: return "Herkunft offen"
        }
    }

    var farbe: Color {
        switch self {
        case .raffi:            return .green
        case .praxis, .katalog: return .blue
        case .startwert:        return .orange   // echter Platzhalter → Warnung
        case .eigen:            return .purple
        case .unbekannt:        return .gray      // Alt-Daten ohne Herkunft → ruhig, kein Alarm
        }
    }

    /// Belegt = aus einer nachvollziehbaren Quelle (nicht ausgedacht).
    var belegt: Bool {
        switch self { case .raffi, .praxis, .katalog, .eigen: return true; default: return false }
    }

    var hinweis: String {
        switch self {
        case .raffi:     return "Firmeneigener Erfahrungswert (RAFFI) aus der Wissensbasis — von euch belegt."
        case .praxis:    return "Öffentlicher Praxis-Richtwert aus der Wissensbasis (aufwandswerte.yaml) — Quelle nachvollziehbar."
        case .katalog:   return "Aus dem Maschinenkatalog (maschinenkatalog.yaml) mit Quellenangabe."
        case .startwert: return "Demo-/Startwert — als Platzhalter gesetzt, NICHT belegt. Zum Ändern: Zeile nach links wischen → löschen, dann mit deinem Wert neu hinzufügen."
        case .eigen:     return "Von dir selbst eingetragen — dein Wert."
        case .unbekannt: return "Herkunft (noch) nicht hinterlegt — diese Position wurde angelegt, bevor der Mops die Quelle mitgeführt hat. Der Wert ist nicht falsch, nur unbeschriftet. Neu berechnen (Mops fass) trägt die Quelle nach; ändern: Zeile wischen → löschen → neu."
        }
    }
}

/// Kleines, antippbares Herkunfts-Badge.
struct QuelleBadge: View {
    let quelle: Kostenquelle
    var onTap: (() -> Void)? = nil

    var body: some View {
        let inhalt = HStack(spacing: 3) {
            Circle().fill(quelle.farbe).frame(width: 7, height: 7)
            Text(quelle.kurz).font(.caption2.weight(.semibold))
            if onTap != nil { Image(systemName: "info.circle").font(.system(size: 9)) }
        }
        .foregroundStyle(quelle.farbe)
        .padding(.horizontal, 7).padding(.vertical, 2)
        .background(quelle.farbe.opacity(0.13))
        .clipShape(Capsule())

        if let onTap {
            Button(action: onTap) { inhalt }.buttonStyle(.plain)
        } else {
            inhalt
        }
    }
}
