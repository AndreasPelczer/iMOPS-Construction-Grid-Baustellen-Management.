import SwiftUI

struct BautagesberichtView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var datum = Date()
    @State private var notizen = ""
    @State private var showShare = false
    @State private var pdfURL: URL?

    private var auftraege: [Auftrag]  { (event.jobs?.allObjects        as? [Auftrag]) ?? [] }
    private var lvAnzahl:  Int        { event.lvPositionen?.count      ?? 0 }
    private var maengel:   Int        { event.maengel?.count           ?? 0 }
    private var offene:    Int        { auftraege.filter { !$0.isCompleted }.count }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datum") {
                    DatePicker("Berichts-Datum", selection: $datum, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("Notizen (optional)") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Besonderheiten, Vorkommnisse...", text: $notizen, axis: .vertical)
                            .lineLimit(3...6)
                        VoiceInputButton(text: $notizen)
                            .padding(.top, 2)
                    }
                }

                Section("Bericht-Inhalt") {
                    LabeledContent("Aufträge",      value: "\(auftraege.count) (\(offene) offen)")
                    LabeledContent("LV-Positionen", value: "\(lvAnzahl)")
                    LabeledContent("Mängel",        value: "\(maengel)")
                }
            }
            .navigationTitle("Bautagesbericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("PDF erstellen") { createPDF() }.tint(.orange)
                }
            }
            .sheet(isPresented: $showShare) {
                if let url = pdfURL { LVShareSheet(url: url).ignoresSafeArea() }
            }
        }
    }

    private func createPDF() {
        let data = BautagesberichtPDFExporter.generate(event: event, datum: datum, notizen: notizen)
        let fmt  = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let name = "Bautagesbericht-\(fmt.string(from: datum))-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-")
            .appending(".pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if (try? data.write(to: url)) != nil {
            pdfURL = url
            showShare = true
        }
    }
}
