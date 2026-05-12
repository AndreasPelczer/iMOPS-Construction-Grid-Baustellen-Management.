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

            // TAB 2: Suche
            NavigationStack {
                GlobalSearchView()
            }
            .tabItem {
                Label("Suche", systemImage: "magnifyingglass")
            }

            // TAB 3: Haus-Konfigurator (nur fuer Disponent / Leitung)
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    HouseConfiguratorView()
                }
                .tabItem {
                    Label("Planer", systemImage: "house.and.flag")
                }
            }

            // TAB 4: Katalog (Material-Lexikon)
            NavigationStack {
                MaterialLexikonView()
            }
            .tabItem {
                Label("Katalog", systemImage: "books.vertical")
            }

            // TAB 5: Crew (nur für Disponent / Leitung)
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    CrewPlanningView()
                }
                .tabItem {
                    Label("Mitarbeiter", systemImage: "person.2.fill")
                }
            }

            // TAB 6: BuildIQ KI-Scanner (nur iOS, kein macCatalyst)
            #if !targetEnvironment(macCatalyst)
            NavigationStack {
                BuildIQLandingView()
            }
            .tabItem {
                Label("BuildIQ", systemImage: "brain.head.profile")
            }
            #endif

            // TAB 7: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.orange)
        .environment(\.locale, session.locale)
    }
}
