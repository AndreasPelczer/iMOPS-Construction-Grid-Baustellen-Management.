//
//  AppSession.swift
//  test25B
//
//  Globaler App-Zustand: Rolle + Sprache
//

import SwiftUI

@Observable
final class AppSession {

    enum Role: String, CaseIterable, Identifiable {
        case worker
        case dispatcher
        case director

        var id: String { rawValue }

        var title: String {
            switch self {
            case .worker:     return "Mitarbeiter"
            case .dispatcher: return "Disponent"
            case .director:   return "Leitung"
            }
        }

        var sfSymbol: String {
            switch self {
            case .worker:     return "person.fill"
            case .dispatcher: return "person.2.fill"
            case .director:   return "star.fill"
            }
        }
    }

    var role: Role = .dispatcher
    var languageCode: String = "de"

    var locale: Locale {
        Locale(identifier: languageCode)
    }
}
