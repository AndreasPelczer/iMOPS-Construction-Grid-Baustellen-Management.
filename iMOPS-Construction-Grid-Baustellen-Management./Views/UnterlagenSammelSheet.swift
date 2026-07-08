import SwiftUI

/// Sammel-Ansicht vor der Dokument-Auswertung: PDFs aus MEHREREN Ordnern nacheinander
/// hinzufügen (der iOS-Datei-Dialog kann pro Öffnen nur EINEN Ordner), dann alle auf
/// einmal auswerten. Die Dateien sind bereits tmp-Kopien (siehe `PDFDocumentPicker`),
/// bleiben also über mehrere Picks gültig.
struct UnterlagenSammelSheet: View {
    /// Startet die Auswertung mit der gesammelten Liste (der Aufrufer räumt weiter auf).
    let onStart: ([URL]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dateien: [URL] = []
    @State private var zeigePicker = false

    var body: some View {
        NavigationStack {
            List {
                if dateien.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Noch keine Unterlagen gewählt",
                            systemImage: "tray",
                            description: Text("Füge PDFs hinzu — auch aus mehreren Ordnern nacheinander.")
                        )
                    }
                } else {
                    Section {
                        ForEach(dateien, id: \.self) { url in
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text").foregroundStyle(.orange)
                                Text(url.lastPathComponent)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(role: .destructive) { entferne(url) } label: {
                                    Image(systemName: "trash").font(.subheadline)
                                }
                                .buttonStyle(.borderless)   // Tap trifft den Button, nicht die Zeile (auch am Mac)
                                .tint(.red)
                            }
                        }
                        .onDelete { dateien.remove(atOffsets: $0) }   // Swipe fürs iPad
                    } header: {
                        Text("Gewählte Unterlagen (\(dateien.count))")
                    }
                }

                Section {
                    Button { zeigePicker = true } label: {
                        Label("Weitere Dateien hinzufügen", systemImage: "plus.circle")
                            .font(.subheadline)
                    }
                    .tint(.orange)
                } footer: {
                    Text("Der Datei-Dialog zeigt immer nur einen Ordner. Wiederhole „Weitere hinzufügen\u{201C} "
                         + "für jeden Ordner — die Auswahl sammelt sich hier.")
                }
            }
            .navigationTitle("Unterlagen sammeln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Auswerten (\(dateien.count))") {
                        let liste = dateien
                        dismiss()
                        onStart(liste)
                    }
                    .tint(.orange)
                    .disabled(dateien.isEmpty)
                }
            }
            .sheet(isPresented: $zeigePicker) {
                PDFDocumentPicker { neue in
                    // Duplikate (gleicher Dateiname) nicht doppelt sammeln.
                    let vorhanden = Set(dateien.map { $0.lastPathComponent })
                    dateien.append(contentsOf: neue.filter { !vorhanden.contains($0.lastPathComponent) })
                }
                .ignoresSafeArea()
            }
        }
    }

    private func entferne(_ url: URL) {
        dateien.removeAll { $0 == url }
    }
}
