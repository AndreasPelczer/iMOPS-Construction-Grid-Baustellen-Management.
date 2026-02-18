import SwiftUI
import CoreData

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

                
                // Zettelkopf
                Section("Zettelkopf") {
                    TextField("Auftragsnummer (9779-04)", text: $viewModel.orderNumber)
                        .textInputAutocapitalization(.never)

                    TextField("Station/Ort (Torhaus E2)", text: $viewModel.station)

                    HStack {
                        Stepper(value: $viewModel.persons, in: 0...5000) {
                            Text("Personen")
                        }
                        Spacer()
                        Text(viewModel.persons == 0 ? "—" : "\(viewModel.persons)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Toggle("Deadline", isOn: $viewModel.hasDeadline)
                        if viewModel.hasDeadline {
                            DatePicker("", selection: $viewModel.deadline, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                        }
                    }
                }


                // 2) WAS IST ZU TUN? (1 Satz wie auf dem Zettel)
                Section("Was ist zu tun?") {
                    TextField("z.B. Bulgur 6× Rezept – 10:30 schicken", text: $viewModel.taskSummary)
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
                            TextField("Position (z.B. Bulgur, Chili, Wurst…)", text: $item.title)

                            HStack {
                                TextField("Menge", text: $item.amount)
                                    .frame(maxWidth: 90)
                                TextField("Einheit (z.B. Rezept/GN/Port.)", text: $item.unit)
                            }
                            HStack(spacing: 8) {
                                Button("Rezept") { item.unit = "Rezept" }
                                Button("Port.") { item.unit = "Port." }
                                Button("GN 1/1") { item.unit = "GN 1/1" }
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)


                            TextField("Notiz (z.B. 12 Min Dampf, auflockern)", text: $item.note)
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
                    Text("Produktionsliste (Positionen)")
                }

                // 4) SOP / MODUS / TEMPLATE
                Section("Modus & Vorlage") {
                    Toggle("Ausbildung (Schritte abhaken)", isOn: $viewModel.trainingMode)

                    Picker("Vorlage", selection: $viewModel.selectedTemplate) {
                        Text("Keine").tag(Optional<AuftragTemplate>.none)
                        ForEach(AuftragTemplate.allCases) { tpl in
                            Text(tpl.rawValue).tag(Optional(tpl))
                        }
                    }
                }

                // 5) ORGA (deine bestehenden Felder)
                Section("Orga / Behälter / Auslieferung") {
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

                    Toggle("Heiß ausliefern?", isOn: $viewModel.isHotDelivery)
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
