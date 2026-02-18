import SwiftUI
import CoreData

struct EditEventView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var event: Event
    
    @State private var title: String
    @State private var notes: String
    @State private var eventNumber: String
    @State private var location: String
    @State private var setupTime: Date
    @State private var eventStartTime: Date
    @State private var eventEndTime: Date
    
    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _eventNumber = State(initialValue: event.eventNumber ?? "")
        _location = State(initialValue: event.location ?? "")
        _setupTime = State(initialValue: event.setupTime ?? Date())
        _eventStartTime = State(initialValue: event.eventStartTime ?? Date())
        _eventEndTime = State(initialValue: event.eventEndTime ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Baustelle")) {
                    TextField("Bezeichnung", text: $title)
                    TextField("Baustellennummer", text: $eventNumber)
                    TextField("Adresse / Standort", text: $location)
                }
                
                Section(header: Text("Notizen")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section(header: Text("Zeitplan")) {
                    DatePicker("Baustelleneinrichtung", selection: $setupTime)
                    DatePicker("Baubeginn", selection: $eventStartTime)
                    DatePicker("Fertigstellung", selection: $eventEndTime)
                }
            }
            .navigationTitle("Baustelle bearbeiten")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        } // Ende NavigationView
    } // Ende body
    
    private func saveChanges() {
        event.title = title
        event.notes = notes
        event.eventNumber = eventNumber
        event.location = location
        event.setupTime = setupTime
        event.eventStartTime = eventStartTime
        event.eventEndTime = eventEndTime
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Update: \(error)")
        }
    }
} // Ende struct
