//
//  RootTabView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//

import SwiftUI

struct RootTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        TabView {
            // TAB 1: Baustellen
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("Baustellen", systemImage: "building.2")
            }

            // TAB 2: Haus-Konfigurator (nur fuer Disponent / Leitung)
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    HouseConfiguratorView()
                }
                .tabItem {
                    Label("Planer", systemImage: "house.and.flag")
                }
            }

            // TAB 3: Katalog (Material-Lexikon)
            NavigationStack {
                MaterialLexikonView()
            }
            .tabItem {
                Label("Katalog", systemImage: "books.vertical")
            }

            // TAB 3: Crew (nur für Disponent / Leitung)
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    CrewPlanningView()
                }
                .tabItem {
                    Label("Mitarbeiter", systemImage: "person.2.fill")
                }
            }

            // TAB 4: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .environment(\.locale, session.locale)
    }
}
