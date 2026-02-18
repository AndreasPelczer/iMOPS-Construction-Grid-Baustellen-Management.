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
                Section(header: Text("Hauptdetails")) {
                    TextField("Titel", text: $title)
                    TextField("Eventnummer", text: $eventNumber)
                    TextField("Veranstaltungsort (Location)", text: $location)
                }
                
                Section(header: Text("Notizen")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                Section(header: Text("Zeitplan")) {
                    DatePicker("Setup Beginn", selection: $setupTime)
                    DatePicker("Event Start", selection: $eventStartTime)
                    DatePicker("Event Ende", selection: $eventEndTime)
                }
            }
            .navigationTitle("Event bearbeiten")
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
