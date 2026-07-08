import SwiftUI
import CoreData

struct EditJobView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var job: Auftrag

    let storageLocations = [
        "Baustelle EG", "Baustelle OG", "Materiallager",
        "Container", "Werkstatt", "Bauhof"
    ]
    let storageNotes = [
        "Palette", "Gitterbox", "Sack/Gebinde",
        "Einzelteile", "Europalette", "Big Bag"
    ]

    @State private var employeeName: String
    @State private var status: JobStatus
    @State private var storageLocation: String
    @State private var processingDetails: String
    @State private var isHotDelivery: Bool
    @State private var isCompleted: Bool
    @State private var storageNote: String
    @State private var selectedKG: DIN276KostenGruppe?
    @State private var showHelp = false

    init(job: Auftrag) {
        self.job = job
        _employeeName = State(initialValue: job.employeeName ?? "")
        _status = State(initialValue: job.status)
        _storageLocation = State(initialValue: job.storageLocation ?? "Baustelle EG")
        _processingDetails = State(initialValue: job.processingDetails ?? "")
        _isHotDelivery = State(initialValue: job.deliveryTemperature)
        _isCompleted = State(initialValue: job.isCompleted)
        _storageNote = State(initialValue: job.storageNote ?? "Palette")

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .tint(.orange)
                }
            }
            .sheet(isPresented: $showHelp) {
                EditJobHelpView()
                    .presentationSizing(.page)
            }
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

// MARK: - Hilfe

struct EditJobHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Zuweisung & Status") {
                    Label("Mitarbeiter: wer ist aktuell für diesen Auftrag zuständig", systemImage: "person")
                    Label("Status – Bedeutung der Stufen:", systemImage: "arrow.right.circle")
                    VStack(alignment: .leading, spacing: 6) {
                        statusRow("Offen", desc: "Auftrag angelegt, noch nicht begonnen", color: .secondary)
                        statusRow("In Bearbeitung", desc: "Arbeiten laufen aktiv", color: .orange)
                        statusRow("Abgeschlossen", desc: "Alle Arbeiten fertiggestellt", color: .green)
                    }
                    .padding(.vertical, 4)
                }
                Section("DIN 276 Kostengruppe") {
                    Text("Die Kostengruppe ordnet den Auftrag in die DIN 276 Baukostenstruktur ein. Wichtig für Abrechnung, Controlling und Nachunternehmer-Zuordnung.")
                    Label("KG 300 – Baukonstruktion (z.B. Wände, Decken)", systemImage: "building.2")
                    Label("KG 400 – Technische Anlagen (z.B. Elektro, Sanitär)", systemImage: "bolt")
                    Label("KG 500 – Außenanlagen", systemImage: "leaf")
                }
                Section("Hinweise") {
                    Label("Änderungen werden sofort in CoreData gespeichert", systemImage: "icloud")
                    Label("BuildIQ kann die Kostengruppe automatisch per KI vorschlagen", systemImage: "brain.head.profile")
                }
            }
            .navigationTitle("Hilfe: Auftrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .tint(.orange)
                }
            }
        }
    }

    private func statusRow(_ name: String, desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8).padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.subheadline).bold()
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
