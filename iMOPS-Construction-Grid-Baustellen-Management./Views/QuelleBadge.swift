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
    case ki           // KI-Schätzung: vom Modell geraten, KEINE Quelle
    case eigen        // in der App selbst eingetragen/überschrieben
    case unbekannt

    init(_ raw: String?) {
        switch (raw ?? "").lowercased().trimmingCharacters(in: .whitespaces) {
        case "raffi":                                   self = .raffi
        case "praxis":                                  self = .praxis
        case "katalog":                                 self = .katalog
        case "startwert", "demo", "seed", "schätzung", "schaetzung": self = .startwert
        case "ki", "kigeneriert", "prof", "geraten":    self = .ki
        case "eigen", "erfahrung":                      self = .eigen
        default:                                        self = .unbekannt
        }
    }

    var kurz: String {
        switch self {
        case .raffi:     return "Firmenwert"
        case .praxis:    return "Richtwert"
        case .katalog:   return "Richtwert"
        case .startwert: return "Startwert"
        case .ki:        return "KI geraten"
        case .eigen:     return "dein Wert"
        case .unbekannt: return "offen"
        }
    }

    var farbe: Color {
        switch self {
        case .raffi, .eigen:    return .green     // euer eigener Wert — der Mops hat ihn
        case .praxis, .katalog: return .blue      // geliehener Richtwert, nicht eurer
        case .startwert:        return .orange    // Platzhalter, ausgedacht → Warnung
        case .ki:               return .purple    // KI geraten → keine Quelle, unbedingt prüfen
        case .unbekannt:        return .gray      // (noch) nicht hinterlegt → ruhig, kein Alarm
        }
    }

    /// Belegt = aus einer nachvollziehbaren Quelle (nicht ausgedacht).
    /// KI zählt NICHT als belegt — sie hat keine Quelle.
    var belegt: Bool {
        switch self { case .raffi, .praxis, .katalog, .eigen: return true; default: return false }
    }

    /// Ein von der KI geratener Wert, der noch nicht von einem Menschen bestätigt wurde.
    /// Darf nicht unbemerkt ins Angebot an die Stadt.
    var istKIUngeprueft: Bool { self == .ki }

    var hinweis: String {
        switch self {
        case .raffi:     return "Firmenwert — euer eigener Wert, in der Wissensbasis hinterlegt. Der Mops hat ihn."
        case .praxis:    return "Richtwert — ein öffentlicher Orientierungswert, nicht euer eigener. Quelle nachvollziehbar. Wenn ihr's besser wisst: überschreiben."
        case .katalog:   return "Richtwert aus dem Maschinenkatalog (mit Quellenangabe) — Orientierung, nicht euer eigener."
        case .startwert: return "Demo-/Startwert — als Platzhalter gesetzt, NICHT belegt. Zum Ändern: Zeile nach links wischen → löschen, dann mit deinem Wert neu hinzufügen."
        case .ki:        return "KI geraten — das hat die KI erfunden (generiert). Plausibel, aber OHNE Quelle und ohne Gewähr: kein gemessener Wert, nirgends nachschlagbar. Nur ein Startwert. Prüfen, nicht glauben. Bestätige oder überschreibe ihn, bevor das Angebot rausgeht — sonst geht eine geratene Zahl an die Stadt."
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
