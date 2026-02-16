import SwiftUI
import CoreData

struct JobHelpSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var job: Auftrag
    var onSaved: () -> Void

    @State private var issueType: IssueType = .unclear
    @State private var message: String = ""
    @State private var markOnHold: Bool = true

    enum IssueType: String, CaseIterable, Identifiable {
        case unclear = "Unklar"
        case missing = "Fehlt"
        case blocked = "Blockiert"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schnell auswählen") {
                    Picker("Art", selection: $issueType) {
                        ForEach(IssueType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Auftrag pausieren (On Hold)", isOn: $markOnHold)
                }

                Section("Kurz beschreiben") {
                    TextField("Was genau ist unklar / was fehlt?", text: $message, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button {
                        saveHelpRequest()
                    } label: {
                        Text("Hilfe speichern")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Hilfe")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .onAppear {
            // falls storageNote bei dir Pflicht ist: besser vorfüllen statt leer lassen
            if let existing = job.storageNote, !existing.isEmpty, message.isEmpty {
                message = existing
            }
        }
    }

    private func saveHelpRequest() {
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        let prefix = "HILFE (\(issueType.rawValue)) – \(stamp): "

        let existing = job.storageNote ?? ""
        let newText = (existing.isEmpty ? "" : existing + "\n") + prefix + message

        // In deinem Log steht: storageNote is a required value -> also immer setzen!
        job.storageNote = newText

        if markOnHold {
            job.status = .onHold
        }

        do {
            try viewContext.save()
            onSaved()
            dismiss()
        } catch {
            print("❌ JobHelpSheet save error:", error)
        }
    }
}
