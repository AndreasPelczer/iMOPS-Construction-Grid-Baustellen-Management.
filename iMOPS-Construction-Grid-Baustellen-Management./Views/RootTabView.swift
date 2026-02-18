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
            // TAB 1: Aufträge / Events
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("Zu erledigen", systemImage: "target")
            }

            // TAB 2: Crew (nur für Disponent / Leitung)
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    CrewPlanningView()
                }
                .tabItem {
                    Label("Mitarbeiter", systemImage: "person.2.fill")
                }
            }

            // TAB 3: Settings
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
