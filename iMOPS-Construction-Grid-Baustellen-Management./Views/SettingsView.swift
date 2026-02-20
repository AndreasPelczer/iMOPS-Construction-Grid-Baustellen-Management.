//
//  SettingsView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import SwiftUI

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @State private var serverURL: String = SKPConversionService.shared.serverURL
    @State private var serverStatus: String = ""
    @State private var isCheckingServer = false

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

            Section("SKP-Konvertierungsserver") {
                TextField("Server-URL", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onChange(of: serverURL) { _, newValue in
                        SKPConversionService.shared.serverURL = newValue
                    }

                HStack {
                    Button {
                        checkServer()
                    } label: {
                        Label("Verbindung testen", systemImage: "network")
                    }
                    .disabled(isCheckingServer)

                    Spacer()

                    if isCheckingServer {
                        ProgressView()
                    } else if !serverStatus.isEmpty {
                        Text(serverStatus)
                            .font(.caption)
                            .foregroundStyle(serverStatus.contains("OK") ? .green : .red)
                    }
                }

                Text("Der Server konvertiert SKP-Dateien (SketchUp) automatisch in USDZ fuer den CAD-Viewer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Baustelle = Event (CoreData). Auftraege werden pro Baustelle verwaltet. CAD-Viewer und Gewerke-Vorlagen sind integriert.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private func checkServer() {
        isCheckingServer = true
        serverStatus = ""

        Task {
            let health = await SKPConversionService.shared.checkHealth()

            await MainActor.run {
                isCheckingServer = false
                if let health = health {
                    if health.blenderAvailable {
                        serverStatus = "OK - Blender verfuegbar"
                    } else {
                        serverStatus = "OK - Blender fehlt!"
                    }
                } else {
                    serverStatus = "Nicht erreichbar"
                }
            }
        }
    }
}
