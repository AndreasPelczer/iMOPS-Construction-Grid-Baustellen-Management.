//
//  RootTabView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//


import SwiftUI

/// Root Tabs: Mission (Events), Crew, RCA, Scan, Settings.
/// Mission = Event (test25B).
struct RootTabView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        TabView {
            // TAB 1: Mission Control (Events)
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("Zu erledigen", systemImage: "target")
            }

            // TAB 2: Crew (Planung / Zuweisung) – Platzhalter für MVP
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    CrewPlanningView()
                }
                .tabItem {
                    Label("Mitarbeiter", systemImage: "person.2.fill")
                }
            }

            // TAB 3: RCA (Remote Chef Annotation) – Platzhalter für MVP
            NavigationStack {
                RCAHubView()
            }
            .tabItem {
                Label("RCA", systemImage: "pencil.and.scribble")
            }

            // TAB 4: Vision-Kit Scan – Platzhalter für MVP
            NavigationStack {
                VisionScanView()
            }
            .tabItem {
                Label("Scan", systemImage: "viewfinder")
            }

            NavigationStack {
                KnowledgeHomeView()
            }
            .tabItem {
                Label("Wissen", systemImage: "book.fill")
            }

            // TAB 5: Settings (Rolle/Sprache)
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
