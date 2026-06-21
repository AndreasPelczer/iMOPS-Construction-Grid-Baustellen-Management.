//
//  EmployeeDetailView.swift
//  iMOPS-Construction-Grid-Baustellen-Management
//
//  Created by Andreas Pelczer on 21.06.26.
//  Ausgelagerter Baustein zur Einhaltung der 500-Zeilen-Regel.
//

import SwiftUI
import CoreData

struct EmployeeDetailView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var employee: Employee

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editRolle: String = ""
    @State private var editTelefon: String = ""
    @State private var editNotiz: String = ""
    @State private var editPin: String = ""
    
    @State private var employeeJobs: [Auftrag] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profilCard

                if !employeeJobs.isEmpty {
                    jobsCard
                }

                if !(employee.notiz ?? "").isEmpty || isEditing {
                    notizCard
                }
            }
            .padding()
        }
        .navigationTitle(employee.name ?? "Mitarbeiter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Speichern" : "Bearbeiten") {
                    if isEditing { saveChanges() } else { startEditing() }
                }
                .disabled(isEditing && (editRolle == "Polier" || editRolle == "GOAT") && editPin.count != 4)
            }
        }
        .onAppear {
            loadFields()
            loadOpenJobs()
        }
    }

    // MARK: - Subviews

    private var profilCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .tintColor).opacity(0.15))
                        .frame(width: 64, height: 64)
                    Text(initials)
                        .font(.title.bold())
                        .foregroundStyle(Color(uiColor: .tintColor))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if isEditing {
                        TextField("Name", text: $editName)
                            .font(.title2.bold())
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(employee.name ?? "")
                            .font(.title2.bold())
                    }

                    if isEditing {
                        TextField("Rolle", text: $editRolle)
                            .font(.subheadline)
                            .textFieldStyle(.roundedBorder)
                    } else if let rolle = employee.rolle, !rolle.isEmpty {
                        Text(rolle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isEditing {
                TextField("Telefon", text: $editTelefon)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.phonePad)
            } else if let tel = employee.telefon, !tel.isEmpty {
                Label(tel, systemImage: "phone.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // PIN-Schutz-Zeile
            if isEditing {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundStyle((editRolle == "Polier" || editRolle == "GOAT") ? .red : .secondary)
                    TextField("4-stelliger PIN", text: $editPin)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .onChange(of: editPin) { _, newValue in
                            if newValue.count > 4 { editPin = String(newValue.prefix(4)) }
                        }
                }
            } else if let bestehenderPin = employee.pin, !bestehenderPin.isEmpty {
                Label("Sicherheits-PIN: ****", systemImage: "lock.shield.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Label("Kein PIN vergeben", systemImage: "lock.open.fill")
                    .font(.footnote)
                    .foregroundStyle(.gray)
            }

            HStack(spacing: 16) {
                statBadge(label: "Offen", count: employeeJobs.count, color: .orange)
                statBadge(label: "Status", text: employee.isActive ? "Aktiv" : "Inaktiv",
                         color: employee.isActive ? .green : .gray)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Offene Aufträge (\(employeeJobs.count))")
                .font(.headline)

            ForEach(employeeJobs, id: \.objectID) { job in
                NavigationLink {
                    AuftragDetailView(job: job)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(job.status.color)
                            .frame(width: 10, height: 10)
                        Text(job.processingDetails ?? "Auftrag")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(job.status.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var notizCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notiz")
                .font(.headline)

            if isEditing {
                TextEditor(text: $editNotiz)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(employee.notiz ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers & Data Logic

    private func statBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)").font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statBadge(label: String, text: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(text).font(.caption.bold()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8).background(color.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var initials: String {
        let parts = (employee.name ?? "?").split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String((employee.name ?? "?").prefix(2)).uppercased()
    }

    private func loadOpenJobs() {
        let name = employee.name ?? ""
        guard !name.isEmpty else { employeeJobs = []; return }
        let req: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        req.predicate = NSPredicate(format: "employeeName == %@ AND isCompleted == NO", name)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Auftrag.statusRawValue, ascending: true)]
        employeeJobs = (try? ctx.fetch(req)) ?? []
    }

    private func loadFields() {
        editName = employee.name ?? ""
        editRolle = employee.rolle ?? ""
        editTelefon = employee.telefon ?? ""
        editNotiz = employee.notiz ?? ""
        editPin = employee.pin ?? ""
    }

    private func startEditing() { loadFields(); isEditing = true }

    private func saveChanges() {
        employee.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        employee.rolle = editRolle
        employee.telefon = editTelefon
        employee.notiz = editNotiz
        employee.pin = editPin.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editPin
        try? ctx.save()
        isEditing = false
    }
}

