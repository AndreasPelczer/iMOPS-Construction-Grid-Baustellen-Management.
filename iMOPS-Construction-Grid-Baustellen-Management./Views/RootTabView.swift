//
//  RootTabView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//

import SwiftUI
import Combine

struct RootTabView: View {
    @Environment(AppSession.self) private var session
    @Environment(ImportedFileHandler.self) private var fileHandler
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        @Bindable var handler = fileHandler
        TabView(selection: $handler.selectedTab) {
            // TAB 1: Baustellen
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("Baustellen", systemImage: "building.2")
            }
            .tag("baustellen")

            // TAB 2: Suche
            NavigationStack {
                GlobalSearchView()
            }
            .tabItem {
                Label("Suche", systemImage: "magnifyingglass")
            }
            .tag("suche")

            // Irgendwo in deiner RootTabView.swift innerhalb der TabView:
            HouseConfiguratorView()
                .tabItem {
                    Label("iMOPS Planer", systemImage: "pencil.and.ruler")
                }
                .tag("planer") // Optional, falls du Tags nutzt

            // TAB 4: Katalog (Material-Lexikon)
            NavigationStack {
                MaterialLexikonView()
            }
            .tabItem {
                Label("Katalog", systemImage: "books.vertical")
            }
            .tag("katalog")

            // TAB 5: Crew (nur für Disponent / Leitung)
            if session.role == .dispatcher || session.role == .director {
                NavigationStack {
                    CrewPlanningView()
                }
                .tabItem {
                    Label("Mitarbeiter", systemImage: "person.2.fill")
                }
                .tag("mitarbeiter")
            }

            // TAB 6: BauWissen (Mops/Prof – Bau-Fachwissen-KI)
            NavigationStack {
                BauWissenView()
            }
            .tabItem {
                Label("BauWissen", systemImage: "book.and.wrench")
            }
            .tag("bauwissen")

            // TAB 7: BuildIQ KI-Scanner (nur iOS-Gerät).
            // #if schließt Mac Catalyst compile-seitig aus; der Laufzeit-Check blendet ihn
            // zusätzlich am „Mac (Designed for iPad)" aus (dort ist macCatalyst FALSE, sonst
            // erschiene der Kamera-Scanner-Tab am Mac, der dort nicht sinnvoll läuft).
            #if !targetEnvironment(macCatalyst)
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                NavigationStack {
                    BuildIQLandingView()
                }
                .tabItem {
                    Label("BuildIQ", systemImage: "brain.head.profile")
                }
                .tag("buildiq")
            }
            #endif

            // TAB 8: Settings
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag("settings")
        }
        .tint(.orange)
        .environment(\.locale, session.locale)
        .universalFileDropTarget { url in
            fileHandler.handleIncomingFile(url: url)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasCompletedOnboarding },
            set: { if !$0 { hasCompletedOnboarding = true } }
        )) {
            OnboardingView()
        }
    }
}
