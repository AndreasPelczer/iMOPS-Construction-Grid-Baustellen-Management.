// Views/ContentView.swift

import SwiftUI
import CoreData

// MARK: - Haupt-View

struct ContentView: View {

    @EnvironmentObject var eventListVM: EventListViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: EventFilter = .upcoming
    @State private var showingAddEventSheet = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        List {
            Section {
                EventFilterPicker(selectedFilter: $selectedFilter)
            }
            Section {
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
                .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: selectedFilter) { _, newFilter in
            withAnimation { eventListVM.applyFilter(filter: newFilter) }
        }
        .onAppear {
            DebugSeeder.seedIfNeeded(context: viewContext)
            eventListVM.applyFilter(filter: selectedFilter)
        }
        .alert(
            "Datenfehler",
            isPresented: Binding(
                get: { eventListVM.lastError != nil },
                set: { if !$0 { eventListVM.lastError = nil } }
            )
        ) {
            Button("OK") { eventListVM.lastError = nil }
        } message: {
            if let err = eventListVM.lastError {
                Text(err)
            }
        }
    }

    private func deleteEvents(offsets: IndexSet) {
        eventListVM.deleteEvents(offsets: offsets)
    }

    // MARK: - Preview

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            let persistenceController = PersistenceController.preview
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(EventListViewModel(context: persistenceController.container.viewContext))
        }
    }
}
