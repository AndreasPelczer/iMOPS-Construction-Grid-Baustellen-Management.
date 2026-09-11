import SwiftUI
import CoreData

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
    @State private var bauherr: String = ""
    // Anschrift des Rechnungsempfaengers.
    //
    // **Eine Rechnung braucht die vollstaendige Anschrift des Leistungsempfaengers**
    // (§ 14 UStG). Bis hierher kannte die Baustelle nur `bauherr` (einen Namen) und
    // `location` — und `location` ist die BAUSTELLE, nicht der Empfaenger. Beides
    // faellt oft zusammen, aber eben nicht immer: Wer fuer einen Bautraeger baut,
    // schickt die Rechnung an dessen Bueros, nicht an die Grube.
    @State private var bauherrStrasse: String = ""
    @State private var bauherrPLZ: String = ""
    @State private var bauherrOrt: String = ""
    @State private var architekt: String = ""
    @State private var baugenehmigungNr: String = ""
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

                Section(header: Text("Beteiligte")) {
                    TextField("Bauherr / Auftraggeber", text: $bauherr)
                    TextField("Straße & Hausnummer", text: $bauherrStrasse)
                        .textContentType(.streetAddressLine1)
                    HStack(spacing: 8) {
                        TextField("PLZ", text: $bauherrPLZ)
                            .frame(maxWidth: 80)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                        TextField("Ort", text: $bauherrOrt)
                            .textContentType(.addressCity)
                    }
                    TextField("Architekt / Planungsbuero", text: $architekt)
                    TextField("Baugenehmigungsnummer", text: $baugenehmigungNr)
                        .textInputAutocapitalization(.never)
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
        newEvent.bauherr = bauherr.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.bauherrStrasse = leerAlsNil(bauherrStrasse)
        newEvent.bauherrPLZ = leerAlsNil(bauherrPLZ)
        newEvent.bauherrOrt = leerAlsNil(bauherrOrt)
        newEvent.architekt = architekt.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.baugenehmigungNr = baugenehmigungNr.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Leeres Feld = **nicht gesetzt**, nicht "".
    private func leerAlsNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
} // Ende struct
