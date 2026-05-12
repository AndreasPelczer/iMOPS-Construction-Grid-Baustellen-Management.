// Views/ContentView.swift

import SwiftUI
import CoreData

// MARK: - Haupt-View

struct ContentView: View {

    @EnvironmentObject var eventListVM: EventListViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: EventFilter = .upcoming
    @State private var searchText = ""
    @State private var showingAddEventSheet = false
    @State private var showHelp = false

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
        .searchable(text: $searchText, prompt: "Baustelle, Ort, Bauherr...")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                EditButton()
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
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
        .sheet(isPresented: $showHelp) {
            BaustellenListeHelpView()
        }
        .onChange(of: selectedFilter) { _, newFilter in
            withAnimation { eventListVM.applyFilterAndSearch(filter: newFilter, query: searchText) }
        }
        .onChange(of: searchText) { _, q in
            eventListVM.applyFilterAndSearch(filter: selectedFilter, query: q)
        }
        .onAppear {
            DebugSeeder.seedIfNeeded(context: viewContext)
            eventListVM.applyFilterAndSearch(filter: selectedFilter, query: searchText)
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

// MARK: - Hilfe

struct BaustellenListeHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Baustellen-Übersicht") {
                    Text("Hier siehst du alle deine Baustellen (Projekte). Jede Baustelle enthält Aufträge, Mängel, Pläne, Checklisten und Wetterdaten.")
                }
                Section("Suche") {
                    Label("Suchfeld oben: filtert nach Name, Ort, Bauherr und Projektnummer", systemImage: "magnifyingglass")
                    Label("Suche und Filterreiter arbeiten zusammen", systemImage: "slider.horizontal.3")
                }
                Section("Filter") {
                    Label("Aktiv – laufende und geplante Baustellen (Standard)", systemImage: "play.circle.fill")
                    Label("Abgeschlossen – beendete Projekte", systemImage: "checkmark.circle.fill")
                    Label("Alle – gesamte Übersicht ohne Zeitfilter", systemImage: "list.bullet")
                }
                Section("Neue Baustelle") {
                    Label("Tippe auf das + rechts oben um eine neue Baustelle anzulegen", systemImage: "plus.circle.fill")
                    Label("Felder: Name, Ort, Bauherr, Architekt, Baugenehmigungsnummer, Zeitraum", systemImage: "doc.text")
                }
                Section("Demo-Daten") {
                    Label("Der Zauberstab-Button lädt Beispiel-Baustellen zum Ausprobieren", systemImage: "wand.and.stars")
                    Label("Demo-Daten können jederzeit gelöscht werden (Wischen nach links)", systemImage: "trash")
                }
                Section("Löschen") {
                    Label("Wische eine Baustelle nach links → Löschen", systemImage: "trash")
                    Label("Oder tippe auf Bearbeiten (links oben) für Mehrfach-Auswahl", systemImage: "pencil")
                }
                Section("Navigation") {
                    Label("Tippe auf eine Baustelle → Detailansicht mit allen Informationen", systemImage: "chevron.right")
                    Label("BuildIQ-Tab: KI-Scanner für Baumaterialien → DIN 276 Zuordnung", systemImage: "brain.head.profile")
                }
            }
            .navigationTitle("Hilfe: Baustellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .tint(.orange)
                }
            }
        }
    }
}
