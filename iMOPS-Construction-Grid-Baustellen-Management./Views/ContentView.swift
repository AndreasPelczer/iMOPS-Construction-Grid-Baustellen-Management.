// Views/ContentView.swift

import SwiftUI
import CoreData

// MARK: - Haupt-View

struct ContentView: View {
    
    @EnvironmentObject var eventListVM: EventListViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: EventFilter = .upcoming
    @State private var showingAddEventSheet = false // Korrekt hinzugefügt
    
    // DateFormatter, um Compiler-Probleme in der View zu vermeiden
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
        
    }()
    
    var body: some View {
        List {
            Section {
                // DER FILTER IST HIER: EventFilterPicker ist in der ersten Section
                EventFilterPicker(selectedFilter: $selectedFilter)
            }

            Section {
                // Aufruf der ausgelagerten View
                EventListView(
                    events: $eventListVM.events,
                    onDelete: deleteEvents
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    DemoSeeder.seedIfNeeded(into: viewContext)
                } label: {
                    Label("Demo", systemImage: "wand.and.stars")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEventSheet = true }) {
                    Label("Neue Baustelle", systemImage: "plus.circle.fill")
                }
            }
        }
        
        .sheet(isPresented: $showingAddEventSheet) {
            AddEventView()
                .environment(\.managedObjectContext, viewContext) // Context muss übergeben werden
        }
        
        // Listener für den Filter
        .onChange(of: selectedFilter) { _, newFilter in
            withAnimation {
                eventListVM.applyFilter(filter: newFilter)
            }
        }
        .onAppear {
            DebugSeeder.seedIfNeeded(context: viewContext)
            eventListVM.applyFilter(filter: selectedFilter)
        }

    }
    
    // KORREKTE POSITION für Methoden
    private func deleteEvents(offsets: IndexSet) {
        eventListVM.deleteEvents(offsets: offsets)
    }
    
    
    
    // MARK: - Preview
    
    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            let persistenceController = PersistenceController.preview
            
            // Simuliere die Environment-Objekte für die Preview
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(EventListViewModel(context: persistenceController.container.viewContext))
        }
    }
}
