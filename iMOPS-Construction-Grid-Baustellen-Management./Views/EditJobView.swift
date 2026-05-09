import SwiftUI
import CoreData

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
    @State private var selectedKG: DIN276KostenGruppe?

    init(job: Auftrag) {
        self.job = job
        _employeeName = State(initialValue: job.employeeName ?? "")
        _status = State(initialValue: job.status)
        _storageLocation = State(initialValue: job.storageLocation ?? "FischKühlhaus")
        _processingDetails = State(initialValue: job.processingDetails ?? "")
        _isHotDelivery = State(initialValue: job.deliveryTemperature)
        _isCompleted = State(initialValue: job.isCompleted)
        _storageNote = State(initialValue: job.storageNote ?? "1/1 Schwarz")

        let gespeicherteNummer = job.kostenGruppeNummer
        let initial = DIN276KostenGruppe.alle.first { $0.nummer == gespeicherteNummer }
        _selectedKG = State(initialValue: initial)
    }

    private var displayTitle: String {
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
                            Text(s.displayName).tag(s)
                        }
                    }
                }

                Section(header: Text("DIN 276 Kostengruppe")) {
                    NavigationLink {
                        KostenGruppePickerView(selection: $selectedKG)
                    } label: {
                        HStack {
                            Text("Kostengruppe")
                            Spacer()
                            Text(selectedKG?.anzeige ?? "Keine")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section(header: Text("Aktionen")) {
                    Button(action: saveChanges) {
                        HStack {
                            Spacer()
                            Text("Änderungen Speichern").bold()
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
        job.kostenGruppeNummer = selectedKG?.nummer
        job.kostenGruppeBezeichnung = selectedKG?.bezeichnung

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
}
