import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct AddEventView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    // --- Baustelle aus GAEB: die Datei gebiert die Baustelle ---
    @State private var gaebItems: [GAEBImportItem] = []
    @State private var gaebProjektName: String = ""
    @State private var gaebDateiName: String = ""
    @State private var zeigeGAEBPicker = false
    @State private var gaebFehler: String?
    
    // --- Initialisierungs-Helfer ---
    private static func nextFullHour() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())
        if let currentHour = components.hour {
            components.hour = currentHour + 1
        }
        return calendar.date(from: components) ?? Date()
    }
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var eventNumber: String = ""
    @State private var location: String = ""
    @State private var bauherr: String = ""
    // Anschrift des Rechnungsempfaengers.
    //
    // **Eine Rechnung braucht die vollstaendige Anschrift des Leistungsempfaengers**
    // (§ 14 UStG). Bis hierher kannte die Baustelle nur `bauherr` (einen Namen) und
    // `location` — und `location` ist die BAUSTELLE, nicht der Empfaenger. Beides
    // faellt oft zusammen, aber eben nicht immer: Wer fuer einen Bautraeger baut,
    // schickt die Rechnung an dessen Bueros, nicht an die Grube.
    @State private var bauherrStrasse: String = ""
    @State private var bauherrPLZ: String = ""
    @State private var bauherrOrt: String = ""
    @State private var architekt: String = ""
    @State private var baugenehmigungNr: String = ""
    // Maße der Baustelle (optional) — als Text wegen deutschem Komma.
    @State private var grundflaeche: String = ""
    @State private var umfang: String = ""
    @State private var geschosse: String = ""
    @State private var eventStartTime: Date = nextFullHour()
    @State private var setupTime: Date = nextFullHour().addingTimeInterval(-3600)
    @State private var eventEndTime: Date = nextFullHour().addingTimeInterval(3600 * 3)

    var body: some View {
        NavigationStack {
            Form {
                // --- Aus GAEB anlegen: die Ausschreibung gebiert die Baustelle ---
                Section {
                    Button {
                        gaebFehler = nil
                        zeigeGAEBPicker = true
                    } label: {
                        Label(gaebItems.isEmpty ? "Aus GAEB-Datei anlegen" : "Andere GAEB-Datei",
                              systemImage: "doc.badge.plus")
                    }
                    .tint(.orange)

                    if !gaebItems.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("📄 \(gaebDateiName)").font(.caption).foregroundStyle(.secondary)
                            Text("\(gaebItems.count) Positionen — werden beim Speichern als LV angelegt")
                                .font(.caption2).foregroundStyle(.green)
                        }
                    }
                    if let f = gaebFehler {
                        Text(f).font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("Aus Ausschreibung (GAEB)")
                } footer: {
                    Text("Titel, Auftraggeber und das ganze LV kommen aus der Datei. Nimmst du den Auftrag nicht an, löschst du die Baustelle einfach wieder — das LV verschwindet mit.")
                }

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
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        Text("m²").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Umfang").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $umfang)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                        Text("m").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Geschosse").foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", text: $geschosse)
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
                    }
                } header: {
                    Text("Maße der Baustelle")
                } footer: {
                    Text("Optional. Für Kleinaufträge reicht ein Maß. Die Menge wird daraus vorerst nicht automatisch gerechnet.")
                }

                Section(header: Text("Notizen")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                        .border(Color.gray.opacity(0.3), width: 1)
                        .cornerRadius(5)
                }

                Section(header: Text("Zeitplan")) {
                    DatePicker("Baustelleneinrichtung", selection: $setupTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Baubeginn", selection: $eventStartTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Fertigstellung", selection: $eventEndTime, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Neue Baustelle")
            .fileImporter(isPresented: $zeigeGAEBPicker,
                          allowedContentTypes: [.data, .xml],
                          allowsMultipleSelection: false) { ergebnis in
                switch ergebnis {
                case .success(let urls):
                    if let url = urls.first { ladeGAEB(url) }
                case .failure(let err):
                    gaebFehler = "Datei konnte nicht geöffnet werden: \(err.localizedDescription)"
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        saveEvent()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        } // Ende NavigationView
    } // Ende body
    
    /// GAEB laden: Titel/Auftraggeber vorbefüllen, Positionen für den Speichern-Schritt merken.
    /// Der Picker liefert eine security-scoped URL — Zugriff muss explizit geöffnet werden.
    private func ladeGAEB(_ url: URL) {
        let brauchtScope = url.startAccessingSecurityScopedResource()
        defer { if brauchtScope { url.stopAccessingSecurityScopedResource() } }
        do {
            let result = try GAEBImporter.parse(url: url)
            guard !result.items.isEmpty else {
                gaebFehler = "Keine Positionen in der Datei erkannt."
                return
            }
            gaebItems = result.items
            gaebDateiName = url.lastPathComponent
            gaebProjektName = result.projectName
            gaebFehler = nil
            // Vorbefüllen, aber nichts überschreiben, was schon eingetippt wurde.
            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                title = result.projectName.isEmpty ? result.projectLabel : result.projectName
            }
            if bauherr.trimmingCharacters(in: .whitespaces).isEmpty {
                bauherr = result.ownerName
            }
        } catch {
            gaebFehler = "GAEB konnte nicht gelesen werden: \(error.localizedDescription)"
        }
    }

    private func saveEvent() {
        let newEvent = Event(context: viewContext)
        newEvent.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.notes = notes
        newEvent.eventNumber = eventNumber
        newEvent.location = location
        newEvent.bauherr = bauherr.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.bauherrStrasse = leerAlsNil(bauherrStrasse)
        newEvent.bauherrPLZ = leerAlsNil(bauherrPLZ)
        newEvent.bauherrOrt = leerAlsNil(bauherrOrt)
        newEvent.architekt = architekt.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.baugenehmigungNr = baugenehmigungNr.trimmingCharacters(in: .whitespacesAndNewlines)
        newEvent.eventStartTime = eventStartTime
        newEvent.setupTime = setupTime
        newEvent.eventEndTime = eventEndTime
        newEvent.grundflaeche = Double(grundflaeche.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
        newEvent.umfang = Double(umfang.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? 0
        newEvent.geschosse = Int16(geschosse.trimmingCharacters(in: .whitespaces)) ?? 0
        newEvent.timeStamp = Date()

        // Aus GAEB angelegt? → das ganze LV als Positionen anhängen (wie beim GAEB-Import).
        // Kein Preis: der kommt später über „Mops fass". Löschen der Baustelle nimmt das LV
        // per Cascade (Event.lvPositionen) mit.
        for item in gaebItems {
            let pos = LVPosition(context: viewContext)
            pos.posNr              = item.posNr
            pos.bezeichnung        = item.kurztext
            pos.langtext           = item.langtext
            pos.menge              = item.menge
            pos.einheit            = item.einheit
            pos.kostenGruppeNummer = item.guessedKG
            pos.event              = newEvent
        }

        do {
            try viewContext.save()
            // Stufe 3: für die neue Baustelle gleich den iCloud-Ordner (mit Fächern) anlegen.
            // Namen als String einsammeln, Datei-Arbeit im Hintergrund (nil-sicher ohne iCloud).
            let baustelleName = newEvent.title ?? ""
            DispatchQueue.global(qos: .utility).async {
                _ = MopsAblage.ordnerFuerBaustelle(baustelleName)
            }
            dismiss()
        } catch {
            print("Fehler beim Speichern: \(error.localizedDescription)")
        }
    }

    /// Leeres Feld = **nicht gesetzt**, nicht "".
    private func leerAlsNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
} // Ende struct
