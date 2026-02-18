//
//  iMOPSApp.swift
//  test25B
//
//  App Entry Point
//

import SwiftUI
import CoreData

@main
struct iMOPSApp: App {
    let persistence = PersistenceController.shared
    @State private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environment(session)
                .environmentObject(
                    EventListViewModel(context: persistence.container.viewContext)
                )
        }
    }
}
