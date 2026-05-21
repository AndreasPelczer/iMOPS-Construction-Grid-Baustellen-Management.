import SwiftUI

// MARK: - Status

enum MangelStatus: String, CaseIterable, Identifiable {
    case offen       = "offen"
    case inArbeit    = "inArbeit"
    case behoben     = "behoben"
    case erledigt    = "erledigt"
    case abgenommen  = "abgenommen"
    case abgelehnt   = "abgelehnt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .offen:      return "Offen"
        case .inArbeit:   return "In Arbeit"
        case .behoben:    return "Behoben"
        case .erledigt:   return "Erledigt"
        case .abgenommen: return "Abgenommen"
        case .abgelehnt:  return "Abgelehnt"
        }
    }

    var symbol: String {
        switch self {
        case .offen:      return "exclamationmark.circle.fill"
        case .inArbeit:   return "wrench.and.screwdriver.fill"
        case .behoben:    return "checkmark.circle.fill"
        case .erledigt:   return "checkmark.circle.fill"
        case .abgenommen: return "checkmark.seal.fill"
        case .abgelehnt:  return "xmark.circle.fill"
        }
    }

    var farbe: Color {
        switch self {
        case .offen:      return .red
        case .inArbeit:   return .orange
        case .behoben:    return .blue
        case .erledigt:   return .green
        case .abgenommen: return .green
        case .abgelehnt:  return .gray
        }
    }
}

// MARK: - Schwere

enum MangelSchwere: String, CaseIterable, Identifiable {
    case gering        = "gering"
    case mittel        = "mittel"
    case kritisch      = "kritisch"
    case schwerwiegend = "schwerwiegend"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gering:        return "Gering"
        case .mittel:        return "Mittel"
        case .kritisch:      return "Kritisch"
        case .schwerwiegend: return "Schwerwiegend"
        }
    }

    var farbe: Color {
        switch self {
        case .gering:        return .yellow
        case .mittel:        return .orange
        case .kritisch:      return .red
        case .schwerwiegend: return .red
        }
    }

    var symbol: String {
        switch self {
        case .gering:        return "minus.circle"
        case .mittel:        return "exclamationmark.circle"
        case .kritisch:      return "exclamationmark.triangle.fill"
        case .schwerwiegend: return "exclamationmark.octagon.fill"
        }
    }
}

// MARK: - Convenience Extension auf NSManagedObject

extension Mangel {
    var status: MangelStatus {
        get { MangelStatus(rawValue: statusRawValue ?? "offen") ?? .offen }
        set { statusRawValue = newValue.rawValue }
    }

    var mangelSchwere: MangelSchwere {
        get { MangelSchwere(rawValue: schwere ?? "mittel") ?? .mittel }
        set { schwere = newValue.rawValue }
    }

    var fotoURL: URL? {
        guard let pfad = fotoPfad else { return nil }
        return URL(fileURLWithPath: pfad)
    }

    var istUeberfaellig: Bool {
        guard let f = frist, status != .abgenommen && status != .abgelehnt else { return false }
        return f < Date()
    }
}
