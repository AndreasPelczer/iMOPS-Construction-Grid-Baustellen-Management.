import SwiftUI

/// Editor für eine manuell geplante Bauphase (Zeitplan der Ist-Übersicht).
/// Neu anlegen oder bestehende bearbeiten/löschen.
struct BauphaseEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: IstBauphase
    let istNeu: Bool
    let onSave: (IstBauphase) -> Void
    let onDelete: (() -> Void)?

    init(phase: IstBauphase, istNeu: Bool,
         onSave: @escaping (IstBauphase) -> Void,
         onDelete: (() -> Void)? = nil) {
        _phase = State(initialValue: phase)
        self.istNeu = istNeu
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bauphase") {
                    TextField("Name (z.B. Rohbau)", text: $phase.name)
                    TextField("Gewerk / KG (optional)", text: Binding(
                        get: { phase.gewerk ?? "" },
                        set: { phase.gewerk = $0.isEmpty ? nil : $0 }
                    ))
                }
                Section("Zeitraum") {
                    DatePicker("Start", selection: $phase.start, displayedComponents: .date)
                    DatePicker("Ende", selection: $phase.ende, in: phase.start..., displayedComponents: .date)
                }
                Section("Notiz") {
                    TextField("optional", text: Binding(
                        get: { phase.notiz ?? "" },
                        set: { phase.notiz = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(1...3)
                }
                if let onDelete {
                    Section {
                        Button(role: .destructive) { onDelete(); dismiss() } label: {
                            Label("Bauphase löschen", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(istNeu ? "Neue Bauphase" : "Bauphase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { onSave(phase); dismiss() }
                        .disabled(phase.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
