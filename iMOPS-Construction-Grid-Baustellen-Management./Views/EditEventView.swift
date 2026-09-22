import SwiftUI
import CoreData

struct EditEventView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss
    @ObservedObject var event: Event
    
    @State private var title: String
    @State private var notes: String
    @State private var eventNumber: String
    @State private var location: String
    @State private var bauherr: String
    // Anschrift des Rechnungsempfaengers.
    //
    // **Eine Rechnung braucht die vollstaendige Anschrift des Leistungsempfaengers**
    // (§ 14 UStG). Bis hierher kannte die Baustelle nur `bauherr` (einen Namen) und
    // `location` — und `location` ist die BAUSTELLE, nicht der Empfaenger. Beides
    // faellt oft zusammen, aber eben nicht immer: Wer fuer einen Bautraeger baut,
    // schickt die Rechnung an dessen Bueros, nicht an die Grube.
    @State private var bauherrStrasse: String
    @State private var bauherrPLZ: String
    @State private var bauherrOrt: String
    @State private var architekt: String
    @State private var baugenehmigungNr: String
    @State private var setupTime: Date
    @State private var eventStartTime: Date
    @State private var eventEndTime: Date
    // Maße der Baustelle — als Text, damit deutsches Komma sauber durchgeht.
    @State private var grundflaeche: String
    @State private var umfang: String
    @State private var geschosse: String

    init(event: Event) {
        self.event = event
        _title = State(initialValue: event.title ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _eventNumber = State(initialValue: event.eventNumber ?? "")
        _location = State(initialValue: event.location ?? "")
        _bauherr = State(initialValue: event.bauherr ?? "")
        _bauherrStrasse = State(initialValue: event.bauherrStrasse ?? "")
        _bauherrPLZ = State(initialValue: event.bauherrPLZ ?? "")
        _bauherrOrt = State(initialValue: event.bauherrOrt ?? "")
        _architekt = State(initialValue: event.architekt ?? "")
        _baugenehmigungNr = State(initialValue: event.baugenehmigungNr ?? "")
        _setupTime = State(initialValue: event.setupTime ?? Date())
        _eventStartTime = State(initialValue: event.eventStartTime ?? Date())
        _eventEndTime = State(initialValue: event.eventEndTime ?? Date())
        _grundflaeche = State(initialValue: event.grundflaeche > 0 ? Self.zahl(event.grundflaeche) : "")
        _umfang = State(initialValue: event.umfang > 0 ? Self.zahl(event.umfang) : "")
        _geschosse = State(initialValue: event.geschosse > 0 ? String(event.geschosse) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Baustelle")) {
                    TextField("Bezeichnung", text: $title)
                    TextField("Baustellennummer", text: $eventNumber)
                    TextField("Adresse / Standort", text: $location)
                }

                Section(header: Text("Beteiligte")) {
                    TextField("Bauherr / Auftraggeber", text: $bauherr)
                    TextField("Straße & Hausnummer", text: $bauherrStrasse)
                        .textContentType(.streetAddressLine1)
                    HStack(spacing: 8) {
                        TextField("PLZ", text: $bauherrPLZ)
                            .frame(maxWidth: 80)
                            .keyboardType(.numberPad)
                            .textContentType(.postalCode)
                        TextField("Ort", text: $bauherrOrt)
                            .textContentType(.addressCity)
                    }
                    TextField("Architekt / Planungsbuero", text: $architekt)
                    TextField("Baugenehmigungsnummer", text: $baugenehmigungNr)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    HStack {
                        Text("Grundfläche").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $grundflaeche)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        Text("m²").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Umfang").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $umfang)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                        Text("m").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Geschosse").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $geschosse)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                    }
                } header: {
                    Text("Maße der Baustelle")
                } footer: {
                    Text("Optional. Grundfläche/Umfang/Geschosse für größere Bauten; für Kleinaufträge reicht ein Maß (z.B. Umfang für laufende Meter). Die Menge wird daraus vorerst NICHT automatisch gerechnet — das ist der nächste Schritt.")
                }

                Section(header: Text("Notizen")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section(header: Text("Zeitplan")) {
                    DatePicker("Baustelleneinrichtung", selection: $setupTime)
                    DatePicker("Baubeginn", selection: $eventStartTime)
                    DatePicker("Geplante Fertigstellung", selection: $eventEndTime)
                }
            }
            .navigationTitle("Baustelle bearbeiten")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveChanges()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveChanges() {
        event.title = title
        event.notes = notes
        event.eventNumber = eventNumber
        event.location = location
        event.bauherr = bauherr.trimmingCharacters(in: .whitespacesAndNewlines)
        event.bauherrStrasse = leerAlsNil(bauherrStrasse)
        event.bauherrPLZ = leerAlsNil(bauherrPLZ)
        event.bauherrOrt = leerAlsNil(bauherrOrt)
        event.architekt = architekt.trimmingCharacters(in: .whitespacesAndNewlines)
        event.baugenehmigungNr = baugenehmigungNr.trimmingCharacters(in: .whitespacesAndNewlines)
        event.setupTime = setupTime
        event.eventStartTime = eventStartTime
        event.eventEndTime = eventEndTime
        event.grundflaeche = Self.parse(grundflaeche) ?? 0
        event.umfang = Self.parse(umfang) ?? 0
        event.geschosse = Int16(geschosse.trimmingCharacters(in: .whitespaces)) ?? 0

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Fehler beim Update: \(error)")
        }
    }

    /// Leeres Feld = **nicht gesetzt**, nicht "".
    ///
    /// `bauherrAnschrift` und `anschriftIstVollstaendig` pruefen auf leer; ein
    /// gespeicherter Leerstring und `nil` verhalten sich dort zwar gleich, aber
    /// in Core Data sind sie zweierlei — und ein Fetch auf `== nil` faende den
    /// Leerstring nicht.
    private func leerAlsNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    // MARK: - Maße-Zahlen (deutsches Komma)

    private static func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private static func zahl(_ d: Double) -> String {
        d.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
} // Ende struct
