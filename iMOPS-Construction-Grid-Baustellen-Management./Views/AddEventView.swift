import SwiftUI
internal import CoreData

struct AddEventView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    
    // --- Initialisierungs-Helfer ---
    private static func nextFullHour() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
        if let currentHour = components.hour {
            components.hour = currentHour + 1
        }
        return calendar.date(from: components) ?? Date()
    }
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var eventNumber: String = ""
    @State private var location: String = ""
    @State private var eventStartTime: Date = nextFullHour()
    @State private var setupTime: Date = nextFullHour().addingTimeInterval(-3600)
    @State private var eventEndTime: Date = nextFullHour().addingTimeInterval(3600 * 3)
    
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
                        .border(Color.gray.opacity(0.3), width: 1)
                        .cornerRadius(5)
                }
                
                Section(header: Text("Zeitplan")) {
                    DatePicker("Baustelleneinrichtung", selection: $setupTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Baubeginn", selection: $eventStartTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Fertigstellung", selection: $eventEndTime, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Neue Baustelle")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        } // Ende NavigationView
    } // Ende body
    
    private func saveEvent() {
        let newEvent = Event(context: viewContext)
        newEvent.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.notes = notes
        newEvent.eventNumber = eventNumber
        newEvent.location = location
        newEvent.eventStartTime = eventStartTime
        newEvent.setupTime = setupTime
        newEvent.eventEndTime = eventEndTime
        newEvent.timeStamp = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error.localizedDescription)")
        }
    }
} // Ende struct
