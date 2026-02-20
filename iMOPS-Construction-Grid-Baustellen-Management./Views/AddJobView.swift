import SwiftUI
internal import CoreData

struct AddJobView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employee.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES")
    )
    private var employees: FetchedResults<Employee>

    @State private var viewModel: AddJobViewModel

    init(event: Event, viewContext: NSManagedObjectContext) {
        _viewModel = State(initialValue: AddJobViewModel(event: event, context: viewContext))
    }

    var body: some View {
        NavigationStack {
            Form {

                
                // Auftragskopf
                Section("Auftragskopf") {
                    TextField("Auftragsnummer (B-2026-042)", text: $viewModel.orderNumber)
                        .textInputAutocapitalization(.never)

                    TextField("Bereich / Stockwerk (EG Wohnung 3)", text: $viewModel.station)

                    HStack {
                        Stepper(value: $viewModel.persons, in: 0...100) {
                            Text("Arbeiter")
                        }
                        Spacer()
                        Text(viewModel.persons == 0 ? "—" : "\(viewModel.persons)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Toggle("Termin", isOn: $viewModel.hasDeadline)
                        if viewModel.hasDeadline {
                            DatePicker("", selection: $viewModel.deadline, displayedComponents: [.date, .hourAndMinute])
                                .labelsHidden()
                        }
                    }
                }


                // 2) WAS IST ZU TUN?
                Section("Aufgabe") {
                    TextField("z.B. Elektro EG verlegen, Estrich OG", text: $viewModel.taskSummary)
                        .font(.headline)
                }
                // 3) PRODUKTIONSPOSITIONEN (wie auf Papier)
                Section {
                    if viewModel.lineItems.isEmpty {
                        Text("Noch keine Positionen. Tippe auf „Position hinzufügen“.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach($viewModel.lineItems) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Material (z.B. Gipskarton, Kabel NYM…)", text: $item.title)

                            HStack {
                                TextField("Menge", text: $item.amount)
                                    .frame(maxWidth: 90)
                                TextField("Einheit (m2 / Stueck / lfm)", text: $item.unit)
                            }
                            HStack(spacing: 8) {
                                Button("m2") { item.unit = "m2" }
                                Button("Stueck") { item.unit = "Stueck" }
                                Button("lfm") { item.unit = "lfm" }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            TextField("Hinweis (z.B. Brandschutz F90)", text: $item.note)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.removeLineItem(item)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        viewModel.addLineItem()
                    } label: {
                        Label("Position hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Material / Positionen")
                }

                // 4) GEWERK / VORLAGE
                Section("Gewerk & Vorlage") {
                    Toggle("Schritte einzeln abhaken", isOn: $viewModel.trainingMode)

                    Picker("Vorlage", selection: $viewModel.selectedTemplate) {
                        Text("Keine").tag(Optional<AuftragTemplate>.none)
                        ForEach(AuftragTemplate.allCases) { tpl in
                            Text(tpl.rawValue).tag(Optional(tpl))
                        }
                    }
                }

                // 5) ORGA
                Section("Zuweisung & Lager") {
                    if employees.isEmpty {
                        TextField("Mitarbeiter (optional)", text: $viewModel.employeeName)
                    } else {
                        Picker("Mitarbeiter", selection: $viewModel.employeeName) {
                            Text("Nicht zugewiesen").tag("")
                            ForEach(employees) { emp in
                                Text(emp.name ?? "?").tag(emp.name ?? "")
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Picker("Status", selection: $viewModel.jobStatus) {
                        ForEach(JobStatus.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Lagerort", selection: $viewModel.storageLocation) {
                        ForEach(viewModel.storageLocations, id: \.self) { loc in
                            Text(loc)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Behälter/Hinweis", selection: $viewModel.storageNote) {
                        ForEach(viewModel.storageNotes, id: \.self) { note in
                            Text(note)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Eilauftrag", isOn: $viewModel.isHotDelivery)
                }
            }
            .navigationTitle("Neuer Auftrag")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        if viewModel.saveNewJob() {
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isSaveButtonDisabled)
                }
            }
        }
    }
}
