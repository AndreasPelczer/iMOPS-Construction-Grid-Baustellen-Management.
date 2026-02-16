import SwiftUI
import CoreData

struct LexikonKnowledgeDetailView: View {
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var entry: CDLexikonEntry

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedBeschreibung: String = ""
    @State private var editedDetails: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // HEADER
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if isEditing {
                            TextField("Name", text: $editedName)
                                .font(.title2.bold())
                                .textFieldStyle(.roundedBorder)
                        } else {
                            Text(entry.name ?? "")
                                .font(.title2.bold())
                        }

                        Spacer()

                        Button {
                            if isEditing { saveChanges() } else { startEditing() }
                        } label: {
                            Label(isEditing ? "Speichern" : "Bearbeiten",
                                  systemImage: isEditing ? "checkmark.circle.fill" : "pencil.circle.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isEditing ? Color.green.opacity(0.22) : Color.blue.opacity(0.12))
                                )
                        }
                        .foregroundStyle(isEditing ? .green : .blue)
                    }

                    if let code = entry.code {
                        Text(code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let kat = entry.kategorie {
                        Text(kat)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // BESCHREIBUNG
                if isEditing || (entry.beschreibung != nil && !entry.beschreibung!.isEmpty) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Beschreibung")
                            .font(.headline)

                        if isEditing {
                            TextEditor(text: $editedBeschreibung)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text(entry.beschreibung ?? "")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // DETAILS
                if isEditing || (entry.details != nil && !entry.details!.isEmpty) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)

                        if isEditing {
                            TextEditor(text: $editedDetails)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            Text(entry.details ?? "")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
        .navigationTitle("Lexikon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editedName = entry.name ?? ""
            editedBeschreibung = entry.beschreibung ?? ""
            editedDetails = entry.details ?? ""
        }
    }

    private func startEditing() {
        editedName = entry.name ?? ""
        editedBeschreibung = entry.beschreibung ?? ""
        editedDetails = entry.details ?? ""
        isEditing = true
    }

    private func saveChanges() {
        entry.name = editedName
        entry.beschreibung = editedBeschreibung
        entry.details = editedDetails
        do { try ctx.save() } catch { print("Lexikon save Fehler: \(error)") }
        isEditing = false
    }
}
