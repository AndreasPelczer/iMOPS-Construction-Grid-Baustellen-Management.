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
    @State private var bauherr: String
    @State private var architekt: String
    @State private var baugenehmigungNr: String
    @State private var setupTime: Date
    @State private var eventStartTime: Date
    @State private var eventEndTime: Date

    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _eventNumber = State(initialValue: event.eventNumber ?? "")
        _location = State(initialValue: event.location ?? "")
        _bauherr = State(initialValue: event.bauherr ?? "")
        _architekt = State(initialValue: event.architekt ?? "")
        _baugenehmigungNr = State(initialValue: event.baugenehmigungNr ?? "")
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

                Section(header: Text("Beteiligte")) {
                    TextField("Bauherr / Auftraggeber", text: $bauherr)
                    TextField("Architekt / Planungsbuero", text: $architekt)
                    TextField("Baugenehmigungsnummer", text: $baugenehmigungNr)
                        .textInputAutocapitalization(.never)
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
        }
    }

    private func saveChanges() {
        event.title = title
        event.notes = notes
        event.eventNumber = eventNumber
        event.location = location
        event.bauherr = bauherr.trimmingCharacters(in: .whitespacesAndNewlines)
        event.architekt = architekt.trimmingCharacters(in: .whitespacesAndNewlines)
        event.baugenehmigungNr = baugenehmigungNr.trimmingCharacters(in: .whitespacesAndNewlines)
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
