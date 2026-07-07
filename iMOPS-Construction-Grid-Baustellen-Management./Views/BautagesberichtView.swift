import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Witterung

enum Witterung: String, CaseIterable, Identifiable {
    case sonnig    = "Sonnig"
    case bewoelkt  = "Bewölkt"
    case regen     = "Regen"
    case schnee    = "Schnee"
    case frost     = "Frost"
    case sturm     = "Sturm"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .sonnig:   return "sun.max.fill"
        case .bewoelkt: return "cloud.fill"
        case .regen:    return "cloud.rain.fill"
        case .schnee:   return "cloud.snow.fill"
        case .frost:    return "thermometer.snowflake"
        case .sturm:    return "wind"
        }
    }
    var farbe: Color {
        switch self {
        case .sonnig:   return .yellow
        case .bewoelkt: return .gray
        case .regen:    return .blue
        case .schnee:   return .cyan
        case .frost:    return .mint
        case .sturm:    return .purple
        }
    }
}

// MARK: - BautagesberichtView

struct BautagesberichtView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var datum              = Date()
    @State private var witterung: Witterung = .bewoelkt
    @State private var temperatur         = ""
    @State private var personalAnzahl     = "1"
    @State private var geraete            = ""
    @State private var ausgefuehrteArbeiten = ""
    @State private var behinderungen      = ""
    @State private var notizen            = ""
    @State private var showShare          = false
    @State private var pdfURL: URL?
    // Mac: echter „Speichern"-Dialog (fileExporter) statt Teilen-Sheet.
    @State private var showSaveDialog     = false
    @State private var pdfData: Data?
    @State private var saveFilename       = "Bautagesbericht"

    private var auftraege: [Auftrag]  { (event.jobs?.allObjects as? [Auftrag]) ?? [] }
    private var lvAnzahl:  Int        { event.lvPositionen?.count ?? 0 }
    private var maengel:   Int        { event.maengel?.count ?? 0 }
    private var offene:    Int        { auftraege.filter { !$0.isCompleted }.count }

    var body: some View {
        NavigationStack {
            Form {
                // --- Datum ---
                Section("Datum") {
                    DatePicker("Berichts-Datum", selection: $datum, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                // --- Witterung ---
                Section("Witterung") {
                    Picker("Wetter", selection: $witterung) {
                        ForEach(Witterung.allCases) { w in
                            Label(w.rawValue, systemImage: w.symbol).tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Text("Temperatur").foregroundStyle(.secondary)
                        Spacer()
                        TextField("z.B. 12 °C", text: $temperatur)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }

                // --- Personal ---
                Section("Personal") {
                    HStack {
                        Stepper(value: Binding(
                            get:  { Int(personalAnzahl) ?? 1 },
                            set:  { personalAnzahl = "\($0)" }
                        ), in: 0...99) {
                            Text("Arbeiter auf der Baustelle")
                        }
                    }
                    HStack {
                        Text("Anzahl").foregroundStyle(.secondary)
                        Spacer()
                        Text(personalAnzahl)
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }

                // --- Maschinen/Geräte ---
                Section("Maschinen & Geräte") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("z.B. Bagger, Rüttler, Betonmischer...",
                                  text: $geraete, axis: .vertical)
                            .lineLimit(2...4)
                        VoiceInputButton(text: $geraete).padding(.top, 2)
                    }
                }

                // --- Ausgeführte Arbeiten ---
                Section("Ausgeführte Arbeiten") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Was wurde heute gemacht?",
                                  text: $ausgefuehrteArbeiten, axis: .vertical)
                            .lineLimit(3...8)
                        VoiceInputButton(text: $ausgefuehrteArbeiten).padding(.top, 2)
                    }
                }

                // --- Behinderungen ---
                Section("Behinderungen / Besonderheiten") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Lieferverzögerungen, Behinderungen, Störungen...",
                                  text: $behinderungen, axis: .vertical)
                            .lineLimit(2...4)
                        VoiceInputButton(text: $behinderungen).padding(.top, 2)
                    }
                }

                // --- Sonstige Notizen ---
                Section("Sonstige Notizen") {
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Weitere Anmerkungen...", text: $notizen, axis: .vertical)
                            .lineLimit(2...4)
                        VoiceInputButton(text: $notizen).padding(.top, 2)
                    }
                }

                // --- Bericht-Statistik ---
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
            .fileExporter(
                isPresented: $showSaveDialog,
                document: PDFFileDocument(data: pdfData ?? Data()),
                contentType: .pdf,
                defaultFilename: saveFilename
            ) { result in
                if case .success = result { dismiss() }
            }
        }
    }

    private func createPDF() {
        let config = BautagesberichtConfig(
            datum:               datum,
            witterung:           witterung.rawValue,
            witterungSymbol:     witterung.symbol,
            temperatur:          temperatur,
            personalAnzahl:      Int(personalAnzahl) ?? 1,
            geraete:             geraete,
            ausgefuehrteArbeiten: ausgefuehrteArbeiten,
            behinderungen:       behinderungen,
            notizen:             notizen
        )
        let data = BautagesberichtPDFExporter.generate(event: event, config: config)
        let fmt  = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let base = "Bautagesbericht-\(fmt.string(from: datum))-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")   // Slash im Titel bricht sonst den Pfad
        // Laufzeit-Prüfung deckt BEIDE Mac-Varianten ab: Mac Catalyst UND
        // „Mac (Designed for iPad)" (iOS-App auf Apple Silicon). Ein reines
        // #if targetEnvironment(macCatalyst) würde die zweite Variante verpassen.
        let laeuftAmMac = ProcessInfo.processInfo.isiOSAppOnMac
            || ProcessInfo.processInfo.isMacCatalystApp
        if laeuftAmMac {
            // Mac: echter „Speichern unter…"-Dialog — der iOS-Teilen-Sheet legt am Mac keine Datei ab.
            pdfData = data
            saveFilename = base
            showSaveDialog = true
        } else {
            // iPhone/iPad: Teilen-Sheet (AirDrop, In Dateien sichern, …).
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(base + ".pdf")
            if (try? data.write(to: url)) != nil {
                pdfURL = url
                showShare = true
            }
        }
    }
}
