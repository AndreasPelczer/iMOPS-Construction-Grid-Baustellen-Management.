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
    @Environment(\.managedObjectContext) private var ctx
    let event: Event

    /// Gesetzt, wenn dieser Bericht die Korrektur eines freigegebenen ist.
    /// Das Original wird NICHT geändert — es bleibt stehen, und der neue
    /// Bericht trägt den Bezug darauf. So bleibt nachvollziehbar, was
    /// ursprünglich dokumentiert wurde und was später richtiggestellt wurde.
    private let korrekturVon: Bautagesbericht?

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

    init(event: Event, korrekturVon: Bautagesbericht? = nil) {
        self.event = event
        self.korrekturVon = korrekturVon
        // Bei einer Korrektur startet das Formular mit den Werten des
        // Originals — geändert wird nur, was wirklich falsch war.
        _datum      = State(initialValue: korrekturVon?.datum ?? Date())
        _witterung  = State(initialValue: Witterung(rawValue: korrekturVon?.witterung ?? "") ?? .bewoelkt)
        _temperatur = State(initialValue: korrekturVon?.temperatur ?? "")
        _personalAnzahl = State(initialValue: korrekturVon.map { String($0.personalAnzahl) } ?? "1")
        _geraete    = State(initialValue: korrekturVon?.geraete ?? "")
        _ausgefuehrteArbeiten = State(initialValue: korrekturVon?.ausgefuehrteArbeiten ?? "")
        _behinderungen = State(initialValue: korrekturVon?.behinderungen ?? "")
        _notizen    = State(initialValue: korrekturVon?.notizen ?? "")
    }

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
            .navigationTitle(korrekturVon == nil ? "Bautagesbericht" : "Korrektur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern & PDF") { speichernUndPDF() }.tint(.orange)
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

    /// Legt den Bericht als Datensatz an und friert die Zaehlstaende ein.
    ///
    /// Warum eingefroren: Ein Bautagesbericht weist einen bestimmten Tag nach.
    /// Zoege er seine Zahlen spaeter frisch aus der Baustelle, zeigte ein
    /// Bericht vom Juli heute die Maengel von heute — die App schriebe still
    /// die Vergangenheit um. Deshalb wird hier gezaehlt, einmal, jetzt.
    @discardableResult
    private func berichtSpeichern() -> Bautagesbericht? {
        let auftraege = (event.jobs?.allObjects as? [Auftrag]) ?? []
        let maengel   = (event.maengel?.allObjects as? [Mangel]) ?? []
        let lv        = (event.lvPositionen?.allObjects as? [LVPosition]) ?? []

        let b = Bautagesbericht(context: ctx)
        b.id        = UUID()
        b.datum     = datum
        b.erstelltAm = Date()
        b.witterung = witterung.rawValue
        b.temperatur = temperatur
        b.personalAnzahl = Int16(Int(personalAnzahl) ?? 1)
        b.geraete   = geraete
        b.ausgefuehrteArbeiten = ausgefuehrteArbeiten
        b.behinderungen = behinderungen
        b.notizen   = notizen

        b.snapAuftraegeGesamt = Int16(auftraege.count)
        b.snapAuftraegeOffen  = Int16(auftraege.filter { !$0.isCompleted }.count)
        b.snapLVPositionen    = Int16(lv.count)
        b.snapMaengel         = Int16(maengel.count)

        b.korrigiertVonID = korrekturVon?.id

        event.addToBautagesberichte(b)
        do {
            try ctx.save()
            return b
        } catch {
            // Nicht still verschlucken: ohne Datensatz waere das PDF ein
            // Dokument ohne Nachweis dahinter.
            print("Bautagesbericht konnte nicht gespeichert werden: \(error)")
            ctx.rollback()
            return nil
        }
    }

    /// Erst speichern, dann drucken — das PDF entsteht aus dem Datensatz,
    /// damit Bericht und Ausdruck nie auseinanderlaufen.
    private func speichernUndPDF() {
        let bericht = berichtSpeichern()
        createPDF(aus: bericht)
    }

    private func createPDF(aus bericht: Bautagesbericht? = nil) {
        let config = BautagesberichtConfig(
            datum:               datum,
            witterung:           witterung.rawValue,
            witterungSymbol:     witterung.symbol,
            temperatur:          temperatur,
            personalAnzahl:      Int(personalAnzahl) ?? 1,
            geraete:             geraete,
            ausgefuehrteArbeiten: ausgefuehrteArbeiten,
            behinderungen:       behinderungen,
            notizen:             notizen,
            // Nur wenn der Bericht gespeichert wurde, tragen wir die
            // eingefrorenen Zahlen ein. Ohne Datensatz bleibt es eine
            // Vorschau mit dem aktuellen Stand.
            snapAuftraegeGesamt: bericht.map { Int($0.snapAuftraegeGesamt) },
            snapAuftraegeOffen:  bericht.map { Int($0.snapAuftraegeOffen) },
            snapLVPositionen:    bericht.map { Int($0.snapLVPositionen) },
            snapMaengel:         bericht.map { Int($0.snapMaengel) }
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
