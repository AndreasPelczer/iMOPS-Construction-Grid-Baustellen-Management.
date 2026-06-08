import SwiftUI
import CoreData

// Welle 5.2 — Eingabe eines neuen Aufmaßes. istMenge ist Pflicht, alles andere
// optional. quelle = .manuell und erstelltAm = jetzt werden automatisch gesetzt
// (Buch Kap 11 — kein Auswahl-Dialog für etwas, das in 5.2 immer manuell ist).
struct NeuesAufmassSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var position: LVPosition

    @State private var istMengeText = ""
    @State private var istEinheit: String
    @State private var notiz = ""

    init(position: LVPosition) {
        self.position = position
        _istEinheit = State(initialValue: position.einheit ?? "")
    }

    private var istValid: Bool {
        Double(istMengeText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0,00", text: $istMengeText)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                        TextField("Einheit", text: $istEinheit)
                            .frame(maxWidth: 90)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Gemessene Menge *")
                } footer: {
                    Text("Soll laut LV: \(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                }

                Section("Notiz (optional)") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("z. B. EG, Treppenhaus West", text: $notiz, axis: .vertical)
                            .lineLimit(2...4)
                        VoiceInputButton(text: $notiz).padding(.top, 2)
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        PhilosophieTooltip(
                            buchKapitel: "Buch Kap 5",
                            text: "Dieser Zustand ist jetzt fest. Mit Datum und Quelle. Der nächste Polier weiß Bescheid."
                        )
                        Text("Wird automatisch mit Datum und Quelle manuell festgehalten.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Neues Aufmaß")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }.disabled(!istValid).tint(.orange)
                }
            }
        }
    }

    private func save() {
        let a = Aufmass(context: viewContext)
        a.id = UUID()
        a.istMenge = Double(istMengeText.replacingOccurrences(of: ",", with: ".")) ?? 0
        a.istEinheit = istEinheit.isEmpty ? nil : istEinheit
        a.notiz = notiz.isEmpty ? nil : notiz
        a.quelle = .manuell
        a.erstelltAm = Date()
        a.lvPosition = position
        try? viewContext.save()
        dismiss()
    }
}
