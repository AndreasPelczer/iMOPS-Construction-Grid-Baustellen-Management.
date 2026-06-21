//
//   CrewPlanningView.swift
//   test25B
//
//   Created by Andreas Pelczer on 12.01.26.
//
//   Phase 5: Crew-Tab – Mitarbeiter verwalten + Auslastung sehen
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
        VStack(spacing: 0) {
            // Kernel-Banner immer sichtbar — Schicht-Status gilt auch ohne Crew-Members
            KernelGuardStatusView()
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

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
            if !activeEmployees.isEmpty {
                Section {
                    CrewLoadSummary()
                        .environment(\.managedObjectContext, ctx)
                }
            }

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
    @State private var rolle: String = "Bauhelfer"
    @State private var telefon: String = ""
    @State private var notiz: String = ""
    @State private var pin: String = ""

    private let rollenVorschlaege = ["Polier", "Vorarbeiter", "Maurer", "Stahlbetonbauer", "Eisenflechter", "Geräteführer", "Bauhelfer", "Azubi", "Logistik", "GOAT"]

    private var istEingabeValide: Bool {
        let gesäuberterName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gesäuberterName.isEmpty else { return false }
        
        if rolle == "Polier" || rolle == "Vorarbeiter" || rolle == "GOAT" {
            return pin.count == 4 && Int(pin) != nil
        }
        return pin.isEmpty || (pin.count == 4 && Int(pin) != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    TextField("Name *", text: $name)
                    TextField("Telefon", text: $telefon)
                        .keyboardType(.phonePad)
                }

                Section("Rolle & Berechtigung") {
                    Picker("Rolle", selection: $rolle) {
                        ForEach(rollenVorschlaege, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle((rolle == "Polier" || rolle == "GOAT") ? .red : .secondary)
                        
                        TextField(
                            (rolle == "Polier" || rolle == "GOAT") ? "4-stelliger PIN (Erforderlich) *" : "4-stelliger PIN (Optional)",
                            text: $pin
                        )
                        .keyboardType(.numberPad)
                        .onChange(of: pin) { _, newValue in
                            if newValue.count > 4 {
                                pin = String(newValue.prefix(4))
                            }
                        }
                    }
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
                        .disabled(!istEingabeValide)
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
        
        if !pin.isEmpty {
            emp.pin = pin
        }
        
        try? ctx.save()
        dismiss()
    }
}

// MARK: - Crew Load Summary

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
