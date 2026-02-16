//
//  SettingsView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        @Bindable var session = session
        Form {
            Section("Rolle") {
                Picker("Aktive Rolle", selection: $session.role) {
                    ForEach(AppSession.Role.allCases) { role in
                        Label(role.title, systemImage: role.sfSymbol).tag(role)
                    }
                }
                .pickerStyle(.inline)
            }

            Section("Sprache") {
                Picker("Language", selection: $session.languageCode) {
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("العربية").tag("ar")
                }
            }

            Section {
                Text("Mission = Event (CoreData). Crew/RCA/Scan sind als MVP-Platzhalter angebunden und werden als nächstes gefüllt.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }
}
