import SwiftUI
import CoreData

struct AddMaterialView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var code = ""
    @State private var kategorie = "Rohbau"
    @State private var beschreibung = ""
    @State private var details = ""

    private let kategorien = [
        "Rohbau", "Trockenbau", "Elektro", "Sanitaer",
        "Daemmung", "Ausbau", "Sonstiges"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Grunddaten") {
                    TextField("Bezeichnung", text: $name)
                    TextField("Artikelcode", text: $code)
                    Picker("Kategorie", selection: $kategorie) {
                        ForEach(kategorien, id: \.self) { kat in
                            Text(kat).tag(kat)
                        }
                    }
                }
                Section("Beschreibung") {
                    TextField("Kurzbeschreibung", text: $beschreibung)
                }
                Section("Technische Details") {
                    TextEditor(text: $details)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Material hinzufuegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let entry = CDLexikonEntry(context: viewContext)
        entry.name = name.trimmingCharacters(in: .whitespaces)
        entry.code = code.trimmingCharacters(in: .whitespaces)
        entry.kategorie = kategorie
        entry.beschreibung = beschreibung.trimmingCharacters(in: .whitespaces)
        entry.details = details.trimmingCharacters(in: .whitespaces)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error)")
        }
    }
}
