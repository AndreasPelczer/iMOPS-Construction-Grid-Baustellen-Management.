import SwiftUI
internal import CoreData

struct EditJobView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var job: Auftrag
    
    let storageLocations = ["FischKühlhaus", "Molkerei", "Fleisch", "Bereitstelle", "VorkühlerFk", "TK Oben", "TK- Fingerfood"]
    let storageNotes = ["1/1 Schwarz", "1/1 Silber", "1/2 Schwarz", "1/2 Silber", "1/1 Silber 10er", "1/1 Silber 6,5 cm", "30cm 1/2 Silber 10,30"]
    
    @State private var employeeName: String
    @State private var status: JobStatus
    @State private var storageLocation: String
    @State private var processingDetails: String
    @State private var isHotDelivery: Bool
    @State private var isCompleted: Bool
    @State private var storageNote: String
    
    init(job: Auftrag) {
        self.job = job
        _employeeName = State(initialValue: job.employeeName ?? "")
        _status = State(initialValue: job.status)
        _storageLocation = State(initialValue: job.storageLocation ?? "FischKühlhaus")
        _processingDetails = State(initialValue: job.processingDetails ?? "")
        _isHotDelivery = State(initialValue: job.deliveryTemperature)
        _isCompleted = State(initialValue: job.isCompleted)
        _storageNote = State(initialValue: job.storageNote ?? "1/1 Schwarz")
    }
    
    private var displayTitle: String {
        // Wenn es KEIN title-Feld gibt, nehmen wir processingDetails oder zur Not "Auftrag"
        if let d = job.processingDetails, !d.isEmpty { return d }
        if let n = job.employeeName, !n.isEmpty { return "Auftrag für \(n)" }
        return "Auftrag"
    }

    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Zuweisung & Status")) {
                    TextField("Mitarbeitername", text: $employeeName)
                    Picker("Status", selection: $status) {
                        ForEach(JobStatus.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                }
                
                Section(header: Text("Lagerung")) {
                    Picker("Lagerort", selection: $storageLocation) {
                        ForEach(storageLocations, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Lagerhinweis", selection: $storageNote) {
                        ForEach(storageNotes, id: \.self) { Text($0).tag($0) }
                    }
                }
                
                Section(header: Text("Aktionen")) {
                    Button(action: saveChanges) {
                        HStack {
                            Spacer()
                            Text("Änderungen Speichern")
                                .bold()
                            Spacer()
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button(action: { dismiss() }) {
                        HStack {
                            Spacer()
                            Text("Abbrechen")
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Auftrag bearbeiten")
        }
    }

    private func saveChanges() {
        job.employeeName = employeeName
        job.status = status
        job.storageLocation = storageLocation
        job.processingDetails = processingDetails
        job.deliveryTemperature = isHotDelivery
        job.isCompleted = isCompleted
        job.storageNote = storageNote
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
}
