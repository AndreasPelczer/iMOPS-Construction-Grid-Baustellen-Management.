import SwiftUI

enum AuftragStatus: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }

    case pending
    case inProgress
    case onHold
    case completed

    var displayName: String {
        switch self {
        case .pending: return "Offen"
        case .inProgress: return "In Arbeit"
        case .onHold: return "Pausiert"
        case .completed: return "Fertig"
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "play.circle.fill"
        case .onHold: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .gray
        case .inProgress: return .accentColor
        case .onHold: return .orange
        case .completed: return .green
        }
    }
}

// Kompatibilität
typealias JobStatus = AuftragStatus
