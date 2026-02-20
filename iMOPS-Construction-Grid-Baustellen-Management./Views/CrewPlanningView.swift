//
//  CrewPlanningView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//  Phase 5: Crew-Tab – Mitarbeiter verwalten + Auslastung sehen
//

import SwiftUI
import CoreData

// MARK: - Crew Planning (Hauptansicht)

struct CrewPlanningView: View {
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employee.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    )
    private var activeEmployees: FetchedResults<Employee>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employee.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == NO"),
        animation: .default
    )
    private var inactiveEmployees: FetchedResults<Employee>

    @State private var showAddSheet = false
    @State private var showInactive = false

    var body: some View {
        Group {
            if activeEmployees.isEmpty && inactiveEmployees.isEmpty {
                emptyState
            } else {
                crewList
            }
        }
        .navigationTitle("Crew")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddEmployeeSheet()
                .environment(\.managedObjectContext, ctx)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Keine Mitarbeiter")
                .font(.title3.bold())

            Text("Lege dein Team an, um Aufträge gezielt\nzuweisen und die Auslastung zu sehen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button { showAddSheet = true } label: {
                Label("Mitarbeiter anlegen", systemImage: "person.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    // MARK: - Crew List

    private var crewList: some View {
        List {
            // Auslastungs-Header
            if !activeEmployees.isEmpty {
                Section {
                    CrewLoadSummary()
                        .environment(\.managedObjectContext, ctx)
                }
            }

            // Aktive Mitarbeiter
            Section("Aktiv (\(activeEmployees.count))") {
                ForEach(activeEmployees) { emp in
                    NavigationLink {
                        EmployeeDetailView(employee: emp)
                    } label: {
                        EmployeeRowView(employee: emp)
                    }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        let emp = activeEmployees[idx]
                        emp.isActive = false
                        try? ctx.save()
                    }
                }
            }

            // Inaktive (toggle)
            if !inactiveEmployees.isEmpty {
                Section {
                    DisclosureGroup("Inaktiv (\(inactiveEmployees.count))", isExpanded: $showInactive) {
                        ForEach(inactiveEmployees) { emp in
                            HStack {
                                EmployeeRowView(employee: emp)
                                    .opacity(0.6)
                                Spacer()
                                Button("Aktivieren") {
                                    emp.isActive = true
                                    try? ctx.save()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                        .onDelete { offsets in
                            for idx in offsets {
                                ctx.delete(inactiveEmployees[idx])
                            }
                            try? ctx.save()
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Employee Row

struct EmployeeRowView: View {
    @ObservedObject var employee: Employee
    @Environment(\.managedObjectContext) private var ctx

    private var openJobCount: Int {
        let name = employee.name ?? ""
        guard !name.isEmpty else { return 0 }
        let req: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
        req.predicate = NSPredicate(format: "employeeName == %@ AND isCompleted == NO", name)
        return (try? ctx.count(for: req)) ?? 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(employee.isActive ? Color(uiColor: .tintColor).opacity(0.15) : Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.headline)
                    .foregroundStyle(employee.isActive ? Color(uiColor: .tintColor) : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(employee.name ?? "Unbenannt")
                    .font(.body.weight(.medium))

                HStack(spacing: 8) {
                    if let rolle = employee.rolle, !rolle.isEmpty {
                        Text(rolle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if openJobCount > 0 {
                        Label("\(openJobCount) offen", systemImage: "tray.full")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var initials: String {
        let parts = (employee.name ?? "?").split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String((employee.name ?? "?").prefix(2)).uppercased()
    }
}

// MARK: - Add Employee Sheet

struct AddEmployeeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx

    @State private var name: String = ""
    @State private var rolle: String = ""
    @State private var telefon: String = ""
    @State private var notiz: String = ""

    private let rollenVorschlaege = ["Koch", "Beistand", "Azubi", "Servicekraft", "Küchenchef", "Spüle", "Logistik"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Name *", text: $name)
                    TextField("Telefon", text: $telefon)
                        .keyboardType(.phonePad)
                }

                Section("Rolle") {
                    Picker("Rolle", selection: $rolle) {
                        Text("Keine").tag("")
                        ForEach(rollenVorschlaege, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Notiz") {
                    TextField("Optional: Allergien, Einschränkungen, etc.", text: $notiz, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Neuer Mitarbeiter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") { saveAndDismiss() }
                        .bold()
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveAndDismiss() {
        let emp = Employee(context: ctx)
        emp.id = UUID()
        emp.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        emp.rolle = rolle
        emp.telefon = telefon
        emp.notiz = notiz
        emp.isActive = true
        do { try ctx.save() } catch { print("Employee save Fehler: \(error)") }
        dismiss()
    }
}

// MARK: - Employee Detail

struct EmployeeDetailView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var employee: Employee

    @State private var isEditing = false
    @State private var editName: String = ""
    @State private var editRolle: String = ""
    @State private var editTelefon: String = ""
    @State private var editNotiz: String = ""
    @State private var employeeJobs: [Auftrag] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Profil-Card
                profilCard

                // Offene Aufträge
                if !employeeJobs.isEmpty {
                    jobsCard
                }

                // Notiz
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
            }
        }
        .onAppear {
            loadFields()
            loadOpenJobs()
        }
    }

    // MARK: - Profil Card

    private var profilCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Avatar groß
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

            // Stats
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

    // MARK: - Offene Jobs Card

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

    // MARK: - Notiz Card

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

    // MARK: - Helpers

    private func statBadge(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statBadge(label: String, text: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var initials: String {
        let parts = (employee.name ?? "?").split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
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
    }

    private func startEditing() {
        loadFields()
        isEditing = true
    }

    private func saveChanges() {
        employee.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        employee.rolle = editRolle
        employee.telefon = editTelefon
        employee.notiz = editNotiz
        do { try ctx.save() } catch { print("Employee save Fehler: \(error)") }
        isEditing = false
    }
}

// MARK: - Crew Load Summary (Auslastungs-Überblick)

struct CrewLoadSummary: View {
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Employee.name, ascending: true)],
        predicate: NSPredicate(format: "isActive == YES")
    )
    private var employees: FetchedResults<Employee>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Brigade-Auslastung", systemImage: "chart.bar.fill")
                .font(.headline)

            let data = loadData()
            if data.isEmpty {
                Text("Noch keine Aufträge zugewiesen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(data, id: \.name) { item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.caption.weight(.medium))
                            .frame(width: 80, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .frame(height: 12)

                                Capsule()
                                    .fill(item.count > 3 ? Color.red : (item.count > 1 ? Color.orange : Color.green))
                                    .frame(width: geo.size.width * min(CGFloat(item.count) / 5.0, 1.0), height: 12)
                            }
                        }
                        .frame(height: 12)

                        Text("\(item.count)")
                            .font(.caption.monospacedDigit().bold())
                            .frame(width: 24)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private struct LoadItem {
        let name: String
        let count: Int
    }

    private func loadData() -> [LoadItem] {
        employees.compactMap { emp -> LoadItem? in
            guard let name = emp.name, !name.isEmpty else { return nil }
            let req: NSFetchRequest<Auftrag> = Auftrag.fetchRequest()
            req.predicate = NSPredicate(format: "employeeName == %@ AND isCompleted == NO", name)
            let count = (try? ctx.count(for: req)) ?? 0
            return LoadItem(name: name, count: count)
        }
    }
}
