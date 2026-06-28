import SwiftUI
import SafariServices
import CoreData
import Combine
import UniformTypeIdentifiers


// MARK: - Helpers: Extras JSON (Checkliste)

struct EventExtrasPayload: Codable {
    var checklist: [EventChecklistItem] = []
    var pinnedProductIDs: [String] = []
    var pinnedLexikonCodes: [String] = []
    var houseProject: HouseProject? = nil
}

struct EventChecklistItem: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var isDone: Bool = false
}

// MARK: - Filter für Jobs
enum JobFilter: String, CaseIterable, Identifiable {
    case open = "Offene Aufträge"
    case all  = "Alle Aufträge"
    var id: String { rawValue }
}

// -------------------------------------------------------------
// MARK: - HAUPT VIEW: EventDetailView
// -------------------------------------------------------------
struct EventDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @StateObject private var fortStore = LVFortschrittStore.shared
    @State private var manualOkbp: String = ""

    @State private var showingEditSheet = false
    @State private var showingAddJobSheet = false
    @State private var showingCADPicker = false
    @State private var showingMaterialPicker = false
    @State private var selectedJobFilter: JobFilter = .all
    @State private var extras = EventExtrasPayload()
    @State private var cadFiles: [CADFileInfo] = []
    @State private var pinnedMaterials: [CDLexikonEntry] = []
    @State private var newStepText: String = ""
    @State private var showingMaengelListe = false
    @State private var showMangelErfassen  = false
    @State private var refreshID = UUID()
    @State private var showHelp = false
    @State private var lvPDFURL: URL?
    @State private var lvCSVURL: URL?
    @State private var showBautagesbericht = false
    @State private var zeigeLVAbriss = false
    @State private var isConverting = false
    @State private var conversionError: String?
    @State private var showConversionError = false
    @State private var showSketchUpWeb = false
    @State private var showingKausalKette = false // 🚀 Steuert das neue Ketten-Fenster

    // Welle 7: Gelände/DXF Upload
    @State private var showingDXFPicker = false
    @State private var isCalculatingGelaende = false
    @State private var gelaendeError: String = ""
    @State private var gelaendeResult: GelaendeResult? = nil
    @State private var reportPDFURL: URL?

    // MARK: Jobs: gefiltert + sortiert
    private var filteredJobs: [Auftrag] {
        _ = refreshID
        guard let jobsSet = event.jobs,
              var allJobs = jobsSet.allObjects as? [Auftrag] else { return [] }
        if selectedJobFilter == .open {
            allJobs = allJobs.filter { !$0.isCompleted }
        }
        return allJobs.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted }
            return (a.employeeName ?? "") < (b.employeeName ?? "")
        }
    }

    // MARK: Checklist Progress
    private var checklistDoneCount: Int  { extras.checklist.filter { $0.isDone }.count }
    private var checklistTotalCount: Int { extras.checklist.count }
    private var checklistProgress: Double {
        guard checklistTotalCount > 0 else { return 0 }
        return Double(checklistDoneCount) / Double(checklistTotalCount)
    }

    private var lvPositionenCount: Int { event.lvPositionen?.count ?? 0 }

    private var housePlanningResult: HouseProjectResult? {
        guard let houseProject = extras.houseProject else { return nil }
        return HouseProjectGenerator.generate(from: houseProject)
    }

    private var lvGesamtFortschritt: Double {
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition] ?? [])
            .filter { !LVPositionHelper.isAlternative($0) }
        guard !positionen.isEmpty else { return 0 }
        let total = positionen.reduce(0) { sum, pos in
            sum + (fortStore.fortschritt(for: pos.objectID.uriRepresentation().absoluteString)?.prozent ?? 0)
        }
        return Double(total) / Double(positionen.count) / 100.0
    }
    
    // MARK: Mängel-Kennzahlen
    private var maengelAnzahl: Int { event.maengel?.count ?? 0 }
    private var maengelOffen: Int {
        (event.maengel?.allObjects as? [Mangel] ?? []).filter { $0.status == .offen }.count
    }
    private var maengelInArbeit: Int {
        (event.maengel?.allObjects as? [Mangel] ?? []).filter { $0.status == .inArbeit }.count
    }
    private var maengelBehoben: Int {
        (event.maengel?.allObjects as? [Mangel] ?? [])
            .filter { $0.status == .behoben || $0.status == .abgenommen }.count
    }
    private var maengelUeberfaellig: Int {
        (event.maengel?.allObjects as? [Mangel] ?? []).filter { $0.istUeberfaellig }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                if housePlanningResult != nil {
                    grundplanungCard
                }
                Button {
                    let offeneMaengel = (event.maengel?.allObjects as? [Mangel] ?? []).filter { $0.status == .offen || $0.status == .inArbeit }.count
                    if offeneMaengel > 0 {
                        showingMaengelListe = true
                    } else {
                        showingAddJobSheet = true
                    }
                } label: {
                    // 🚥 Klick auf die Ampel öffnet jetzt direkt die interaktive Kausalbaukette!
                    Button {
                        showingKausalKette = true
                    } label: {
                        AmpelCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showingKausalKette) {
                        KausalbauketteView(event: event)
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
                .buttonStyle(.plain)
                WetterKarteView(ort: event.location ?? "")
                cadCard
                materialCard
                geländeCard
                lvCard
                kalkulationCard
                checklistCard
                maengelCard
                jobsCard
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(event.title ?? "Baustelle")
        .navigationBarTitleDisplayMode(.inline)
        .cadDropTarget { url in
            let ext = url.pathExtension.lowercased()
            let fm = FileManager.default
            let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            let cadDir = docsDir.appendingPathComponent("CADFiles", isDirectory: true)
            try? fm.createDirectory(at: cadDir, withIntermediateDirectories: true)
            let destURL = cadDir.appendingPathComponent(url.lastPathComponent)
            try? fm.removeItem(at: destURL)
            if (try? fm.copyItem(at: url, to: destURL)) != nil {
                let info = CADFileInfo(fileName: destURL.lastPathComponent, relativePath: destURL.lastPathComponent)
                cadFiles.append(info)
                saveCADFiles()
                if ext == "skp" || ["fbx", "gltf", "glb"].contains(ext) {
                    convertFileToUSDZ(destURL)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        generateLVPDF()
                    } label: {
                        Label("LV als PDF", systemImage: "doc.text")
                    }
                    .disabled(lvPositionenCount == 0)

                    Button {
                        generateLVCSV()
                    } label: {
                        Label("LV als CSV", systemImage: "tablecells")
                    }
                    .disabled(lvPositionenCount == 0)

                    Button {
                        showBautagesbericht = true
                    } label: {
                        Label("Bautagesbericht", systemImage: "calendar.badge.clock")
                    }
                } label: {
                    Image(systemName: "arrow.up.doc")
                }
                .tint(.orange)
            }
            // 🚀 NEU: Der dedizierte iMOPS Planer-Button innerhalb der Baustelle
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    // Hier übergeben wir das aktuelle Event an den Konfigurator!
                    // Dadurch springt die Weiche sofort auf Zustand B (Die 4 Reiter mitsamt Zeitstrahl)
                    HouseConfiguratorView(spezielesEvent: event)
                } label: {
                    Label("Soll-Übersicht", systemImage: "pencil.and.rulers")
                }
                .tint(.orange)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bearbeiten") { showingEditSheet = true }
            }
        }
        .onAppear {
            extras = loadExtras()
            cadFiles = loadCADFiles()
            pinnedMaterials = fetchPinnedMaterials()
        }
        .sheet(isPresented: $showHelp) { EventDetailHelpView() }
        .sheet(isPresented: $showingEditSheet, onDismiss: { refreshID = UUID() }) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingAddJobSheet, onDismiss: { refreshID = UUID() }) {
            AddJobView(event: event, viewContext: viewContext)
        }
        .sheet(isPresented: $zeigeLVAbriss) {
            LVAbrissSheet(event: event, baustellenName: event.title ?? "Unbenannt")
        }
        .sheet(isPresented: $showingCADPicker) {
            CADDocumentPicker(
                onPicked: { importedURL in
                    let info = CADFileInfo(fileName: importedURL.lastPathComponent, relativePath: importedURL.lastPathComponent)
                    cadFiles.append(info)
                    saveCADFiles()
                },
                onServerConvert: { fileURL in convertFileToUSDZ(fileURL) },
                onSKPPicked: { skpFileURL in
                    if let url = skpFileURL {
                        let info = CADFileInfo(fileName: url.lastPathComponent, relativePath: url.lastPathComponent)
                        cadFiles.append(info)
                        saveCADFiles()
                    }
                }
            )
        }
        .sheet(item: $lvPDFURL) { url in
            PDFPreviewView(url: url).ignoresSafeArea()
        }
        .sheet(item: $lvCSVURL) { url in
            LVShareSheet(url: url).ignoresSafeArea()
        }
        .sheet(isPresented: $showBautagesbericht) {
            BautagesberichtView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingMaengelListe) {
            MangelListeView(event: event).environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showMangelErfassen) {
            MangelErfassenView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .overlay {
            if isConverting {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("Wird konvertiert...").font(.headline)
                        Text("Datei wird an den Server gesendet\nund automatisch in USDZ umgewandelt.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .background(.ultraThickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .alert("Konvertierung fehlgeschlagen", isPresented: $showConversionError) {
            Button("OK") {}
        } message: {
            Text(conversionError ?? "Unbekannter Fehler")
        }
        .sheet(isPresented: $showSketchUpWeb) {
            if let url = URL(string: "https://app.sketchup.com") {
                SafariView(url: url).ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showingMaterialPicker, onDismiss: { pinnedMaterials = fetchPinnedMaterials() }) {
            MaterialPickerSheet(
                pinnedCodes: Binding(
                    get: { extras.pinnedLexikonCodes },
                    set: { newCodes in
                        extras.pinnedLexikonCodes = newCodes
                        saveExtras(extras)
                    }
                )
            )
        }
        .sheet(item: $reportPDFURL) { url in
            LVShareSheet(url: url).ignoresSafeArea()
        }
    }

    // MARK: - GELÄNDE CARD (Welle 7)
    private var geländeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Geländebrücke (Welle 7)").font(.headline)
                Spacer()
                Button { showingDXFPicker = true } label: {
                    Label("DXF auswerten", systemImage: "square.and.arrow.down").font(.subheadline)
                }
                .disabled(isCalculatingGelaende)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("OK-BP fixieren:")
                        .font(.caption)
                    TextField("Auto (Mittelwert)", text: $manualOkbp)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                    Text("m ü.NN")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Leer lassen = Auto (berechnet Mittelwert unterm Haus für Massenausgleich).\nWert eingeben = feste OK-Bodenplatte laut Plan (z.B. bei Keller).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            if isCalculatingGelaende {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Rechne Cut/Fill...").font(.subheadline).foregroundStyle(.secondary)
                }
            } else if !gelaendeError.isEmpty {
                Text(gelaendeError).font(.caption).foregroundColor(.red)
            } else if let r = gelaendeResult {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "mountain.2.fill").font(.title3).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("OK-Bodenplatte: \(String(format: "%.2f", r.okbp)) m ü.NN").font(.subheadline)
                            Text("Gelände: \(String(format: "%.2f", r.gelaende_min))–\(String(format: "%.2f", r.gelaende_max)) m").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider().opacity(0.4)
                    
                    HStack(spacing: 0) {
                        geländeStat(label: "Abtrag", wert: r.cut, einheit: "m³", farbe: .red)
                        Divider().frame(height: 32)
                        geländeStat(label: "Auftrag", wert: r.fill, einheit: "m³", farbe: .blue)
                        Divider().frame(height: 32)
                        geländeStat(label: "Schotter", wert: r.schotter_t, einheit: "t", farbe: .brown)
                        Divider().frame(height: 32)
                        geländeStat(label: "LKW-Fuhren", wert: Double(r.sens_lkw), einheit: "", farbe: .orange) // KORRIGIERT: Übergibt gerundeten LKW-Wert als Double
                    }
                    Divider().opacity(0.4)
                    
                    Button {
                        insertGelaendeIntoLV(result: r)
                    } label: {
                        Label("Ins LV übernehmen", systemImage: "doc.badge.plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Button {
                        generateReportPDF(result: r)
                    } label: {
                        Label("PDF-Report erstellen", systemImage: "doc.richtext")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Text(r.meldung).font(.caption2).foregroundStyle(.secondary).italic()
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "map").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Keine Geländedaten").font(.subheadline)
                        Text("Vermessungs-DXF hochladen für Cut/Fill-Schätzung").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .fileImporter(
            isPresented: $showingDXFPicker,
            allowedContentTypes: [UTType(filenameExtension: "dxf") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleDXFPick(result: result)
        }
    }

    private func geländeStat(label: String, wert: Double, einheit: String, farbe: Color) -> some View {
        VStack(spacing: 2) {
            // Hier wird gerundet ausgegeben
            Text(String(format: "%.1f", wert))
                .font(.title3.weight(.semibold))
                .foregroundStyle(farbe)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if !einheit.isEmpty {
                Text(einheit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - LV Insert (Welle 7)
    private func insertGelaendeIntoLV(result: GelaendeResult) {
        let context = viewContext
        
        let currentCount = event.lvPositionen?.count ?? 0
        var nextPos = currentCount + 1
        
        // 1. Aushub (Abtrag)
        if result.cut > 0 {
            let pos = LVPosition(context: context)
            pos.posNr = String(format: "07.%02d", nextPos)
            pos.bezeichnung = "Aushub (Massenausgleich)"
            pos.einheit = "m³"
            pos.menge = result.cut
            pos.kostenGruppeNummer = "311"
            pos.event = event
            nextPos += 1
        }
        
        // 2. Schotter
        if result.schotter_t > 0 {
            let pos = LVPosition(context: context)
            pos.posNr = String(format: "07.%02d", nextPos)
            pos.bezeichnung = "Schotter 0/45 (30 cm Tragschicht)"
            pos.einheit = "t"
            pos.menge = result.schotter_t
            pos.kostenGruppeNummer = "322"
            pos.event = event
            nextPos += 1
        }
        
        // 3. Trennvlies
        if result.vlies_m2 > 0 {
            let pos = LVPosition(context: context)
            pos.posNr = String(format: "07.%02d", nextPos)
            pos.bezeichnung = "Trennvlies"
            pos.einheit = "m²"
            pos.menge = result.vlies_m2 // KORRIGIERT: Nutzt direkt den vlies_m2 Wert ohne Cast-Verschachtelung
            pos.kostenGruppeNummer = "322"
            pos.event = event
            nextPos += 1
        }
        
        do {
            try context.save()
            gelaendeError = ""
            gelaendeResult = nil
        } catch {
            gelaendeError = "Fehler beim Speichern ins LV: \(error.localizedDescription)"
        }
    }

    // MARK: - PDF Report (Welle 7)
    private func generateReportPDF(result: GelaendeResult) {
        var plotImage: UIImage?
        if let b64 = result.plot_image, let data = Data(base64Encoded: b64) {
            plotImage = UIImage(data: data)
        }
        
        let pageSize = CGSize(width: 595, height: 842) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        
        let name = "Gelaende-Report-\(event.title ?? "Baustelle").pdf".replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        
        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()
                
                let title = "Geländebrücke-Report: \(event.title ?? "Baustelle")"
                title.draw(at: CGPoint(x: 40, y: 40), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)])
                
                var y: CGFloat = 80
                let bodyFont = UIFont.systemFont(ofSize: 14)
                let lines = [
                    "OK-Bodenplatte: \(String(format: "%.2f", result.okbp)) m ü.NN",
                    "Gelände: \(String(format: "%.2f", result.gelaende_min)) - \(String(format: "%.2f", result.gelaende_max)) m",
                    "Abtrag (Cut): \(String(format: "%.1f", result.cut)) m³",
                    "Auftrag (Fill): \(String(format: "%.1f", result.fill)) m³",
                    "Schotter: \(String(format: "%.1f", result.schotter_t)) t",
                    "Trennvlies: \(result.vlies_m2) m²",
                    "LKW-Fuhren (Schätzung): \(result.sens_lkw)",
                    "",
                    result.meldung
                ]
                
                for line in lines {
                    line.draw(at: CGPoint(x: 40, y: y), withAttributes: [.font: bodyFont])
                    y += 20
                }
                
                if let image = plotImage {
                    let imgWidth = pageSize.width - 80
                    let imgHeight = image.size.height * (imgWidth / image.size.width)
                    let imgRect = CGRect(x: 40, y: y + 20, width: imgWidth, height: imgHeight)
                    image.draw(in: imgRect)
                }
            }
            reportPDFURL = url
        } catch {
            gelaendeError = "PDF Fehler: \(error.localizedDescription)"
        }
    }

    // MARK: - DXF Upload (Welle 7)
    private func handleDXFPick(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                gelaendeError = "Keine Berechtigung für die Datei."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let dxfData = try Data(contentsOf: url)
                uploadDXF(dxfData: dxfData)
            } catch {
                gelaendeError = "Fehler beim Lesen: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            gelaendeError = "Fehler: \(error.localizedDescription)"
        }
    }

    private func uploadDXF(dxfData: Data) {
        isCalculatingGelaende = true
        gelaendeError = ""
        gelaendeResult = nil
        
        // Nutzt dieselbe Server-Einstellung wie der Chat (Default: mops.baumops.com-Tunnel,
        // in Settings überschreibbar) — damit die Geländebrücke auch von unterwegs läuft.
        var urlString = MopsConfig.host + "/gelaendebruecke/calculate"
        if let okbpValue = Double(manualOkbp.replacingOccurrences(of: ",", with: ".")), okbpValue > 0 {
            urlString += "?fix_okbp=\(okbpValue)"
        }
        guard let url = URL(string: urlString) else {
            gelaendeError = "Ungültige Server-URL"
            isCalculatingGelaende = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dxf_file\"; filename=\"upload.dxf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(dxfData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            DispatchQueue.main.async {
                isCalculatingGelaende = false
                
                if let error = error {
                    gelaendeError = "Netzwerkfehler: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    gelaendeError = "Keine Antwort vom Server."
                    return
                }
                
                let rawResponse = String(data: data, encoding: .utf8) ?? "Unlesbare Daten"
                
                do {
                    gelaendeResult = try JSONDecoder().decode(GelaendeResult.self, from: data)
                    gelaendeError = ""
                } catch {
                    gelaendeError = "Server sagt:\n\(rawResponse)"
                }
            }
        }.resume()
    }

    // MARK: - HEADER CARD
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(event.title ?? "Unbenannte Baustelle").font(.title2.bold())
                    HStack(spacing: 10) {
                        if let nr = event.eventNumber, !nr.isEmpty {
                            Label(nr, systemImage: "number").font(.footnote).foregroundStyle(.secondary)
                        }
                        if let loc = event.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.and.ellipse").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(checklistProgress * 100))%").font(.headline.monospacedDigit())
                    Text("Checkliste").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                if let setup = event.setupTime   { timeRow(icon: "timer",                          title: "Setup", date: setup, color: .orange) }
                if let start = event.eventStartTime { timeRow(icon: "calendar.day.timeline.leading", title: "Start", date: start, color: Color(uiColor: .tintColor)) }
                if let end   = event.eventEndTime   { timeRow(icon: "clock.badge.checkmark",          title: "Ende",  date: end,   color: .green) }
                EventTimelineBar(event: event)
            }
            let beteiligte: [(String, String)] = [
                ("person.crop.square", event.bauherr ?? ""),
                ("pencil.and.ruler",   event.architekt ?? ""),
                ("doc.badge.gearshape",event.baugenehmigungNr ?? "")
            ].filter { !$0.1.isEmpty }
            if !beteiligte.isEmpty {
                Divider().opacity(0.4)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(beteiligte, id: \.0) { icon, wert in
                        Label(wert, systemImage: icon).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            if let notes = event.notes, !notes.isEmpty {
                Divider().opacity(0.4)
                Text(notes).font(.subheadline).foregroundStyle(.secondary).lineLimit(4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timeRow(icon: String, title: String, date: Date, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text("\(title):").font(.footnote.weight(.semibold))
            Text(date, style: .date).font(.footnote).foregroundStyle(.secondary)
            Text("•").foregroundStyle(.secondary)
            Text(date, style: .time).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - GRUNDPLANUNG CARD
    private var grundplanungCard: some View {
        Group {
            if let result = housePlanningResult {
                NavigationLink {
                    HouseProjectResultView(
                        result: result,
                        allowsCreateEvent: false
                    )
                    .environment(\.managedObjectContext, viewContext)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "house.and.flag.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Grundplanung").font(.headline).foregroundStyle(.primary)
                            Text("\(Int(result.project.wohnflaeche)) m² · \(result.project.geschosse) Geschoss(e) · \(formatCurrencyShort(result.gesamtkosten))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatCurrencyShort(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "EUR"
        fmt.locale = Locale(identifier: "de_DE")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "\(Int(value)) EUR"
    }

    // MARK: - CAD CARD
    private var cadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Plaene & CAD").font(.headline)
                Spacer()
                Button { showingCADPicker = true } label: {
                    Label("Importieren", systemImage: "doc.badge.plus").font(.subheadline)
                }
            }
            if cadFiles.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "cube.transparent").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Keine Plaene importiert").font(.subheadline)
                        Text("USDZ, OBJ, DAE, FBX, STL oder glTF importieren").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                let grouped = Dictionary(grouping: cadFiles, by: { $0.planType })
                let sortedKeys = grouped.keys.sorted()
                ForEach(sortedKeys, id: \.self) { planType in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if let pt = PlanType(rawValue: planType) {
                                Image(systemName: pt.icon).font(.caption).foregroundStyle(.secondary)
                            }
                            Text(planType).font(.subheadline.bold()).foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                        ForEach(grouped[planType] ?? []) { file in cadFileRow(file) }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func isSKPFile(_ file: CADFileInfo) -> Bool { file.fileName.lowercased().hasSuffix(".skp") }

    @ViewBuilder
    private func cadFileRow(_ file: CADFileInfo) -> some View {
        if let url = file.fullURL {
            Group {
                if isSKPFile(file) {
                    Button { showSketchUpWeb = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "safari.fill").font(.title3).foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.fileName).font(.body)
                                Text("Oeffnet in SketchUp Web (Safari)").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .contextMenu {
                        Button { showSketchUpWeb = true } label: { Label("In SketchUp Web oeffnen", systemImage: "safari") }
                        Button { ExternalAppLauncher.shared.openInExternalApp(fileURL: url) } label: { Label("Teilen / Andere App", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) { cadFiles.removeAll { $0.id == file.id }; saveCADFiles() } label: { Label("Loeschen", systemImage: "trash") }
                    }
                } else {
                    NavigationLink { CADViewerView(fileURL: url, fileName: file.fileName) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "cube.fill").font(.title3).foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.fileName).font(.body)
                                Text(file.importDate.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .contextMenu {
                        Button { showSketchUpWeb = true } label: { Label("In SketchUp Web oeffnen", systemImage: "safari") }
                        Button { ExternalAppLauncher.shared.openInExternalApp(fileURL: url) } label: { Label("Teilen / Andere App", systemImage: "square.and.arrow.up") }
                        Button(role: .destructive) { cadFiles.removeAll { $0.id == file.id }; saveCADFiles() } label: { Label("Loeschen", systemImage: "trash") }
                    }
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    cadFiles.removeAll { $0.id == file.id }
                    saveCADFiles()
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - MATERIAL CARD
    private var materialCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Materialien").font(.headline)
                Spacer()
                Button { showingMaterialPicker = true } label: {
                    Label("Zuordnen", systemImage: "plus.circle").font(.subheadline)
                }
            }
            if pinnedMaterials.isEmpty && extras.pinnedLexikonCodes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text("Keine Materialien zugeordnet").font(.subheadline)
                        Text("Materialien aus dem Katalog dieser Baustelle zuweisen").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(pinnedMaterials, id: \.objectID) { mat in
                        HStack(spacing: 12) {
                            Image(systemName: iconForKategorie(mat.kategorie)).font(.title3).foregroundStyle(.orange).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mat.name ?? "").font(.body)
                                HStack(spacing: 6) {
                                    Text(mat.code ?? "").font(.caption).foregroundStyle(.secondary)
                                    Text("•").foregroundStyle(.secondary)
                                    Text(mat.kategorie ?? "").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button { unpinMaterial(code: mat.code ?? "") } label: {
                                Image(systemName: "minus.circle.fill").foregroundStyle(.red.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 8).padding(.horizontal, 10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func iconForKategorie(_ kat: String?) -> String {
        switch kat {
        case "Rohbau":     return "building.2"
        case "Trockenbau": return "square.split.2x2"
        case "Elektro":    return "bolt.fill"
        case "Sanitaer":   return "drop.fill"
        case "Daemmung":   return "shield.fill"
        case "Ausbau":     return "paintbrush.fill"
        default:           return "shippingbox"
        }
    }

    private func unpinMaterial(code: String) {
        extras.pinnedLexikonCodes.removeAll { $0 == code }
        saveExtras(extras)
        pinnedMaterials = fetchPinnedMaterials()
    }

    private func fetchPinnedMaterials() -> [CDLexikonEntry] {
        guard !extras.pinnedLexikonCodes.isEmpty else { return [] }
        let req: NSFetchRequest<CDLexikonEntry> = CDLexikonEntry.fetchRequest()
        req.predicate = NSPredicate(format: "code IN %@", extras.pinnedLexikonCodes)
        req.sortDescriptors = [NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)]
        return (try? viewContext.fetch(req)) ?? []
    }

    // MARK: - LV CARD
    private var lvCard: some View {
        HStack(spacing: 14) {
            NavigationLink {
                LVView(event: event)
                    .environment(\.managedObjectContext, viewContext)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Leistungsverzeichnis").font(.headline).foregroundStyle(.primary)
                        Text(lvPositionenCount == 0
                             ? "Noch keine Positionen"
                             : "\(lvPositionenCount) Position\(lvPositionenCount == 1 ? "" : "en")")
                            .font(.caption).foregroundStyle(.secondary)
                        if lvPositionenCount > 0 && lvGesamtFortschritt > 0 {
                            HStack(spacing: 6) {
                                ProgressView(value: lvGesamtFortschritt)
                                    .tint(lvGesamtFortschritt >= 1.0 ? .green : .orange)
                                Text("\(Int(lvGesamtFortschritt * 100)) %")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                            .padding(.top, 2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if lvPositionenCount > 0 {
                Button { generateLVPDF() } label: {
                    Image(systemName: "arrow.up.doc")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // --- NEU: Context Menu für Laptop (Rechtsklick) & iPad (Langes Drücken) ---
        .contextMenu {
            Button(role: .destructive) {
                zeigeLVAbriss = true
            } label: {
                Label("Gesamtes LV löschen", systemImage: "trash")
            }
        }
    }
    
    // MARK: - KALKULATION CARD (Welle 6)
    private var kalkulationCard: some View {
        NavigationLink {
            LVKalkulationView(event: event)
                .environment(\.managedObjectContext, viewContext)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "eurosign.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kalkulation (Welle 6)").font(.headline).foregroundStyle(.primary)
                    Text("Preise eingeben und Angebotssumme berechnen")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func generateLVPDF() {
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition] ?? [])
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
        let data = LVPDFExporter.generate(event: event, positionen: positionen)
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-")
            .appending(".pdf")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if (try? data.write(to: url)) != nil {
            lvPDFURL = url
        }
    }

    private func generateLVCSV() {
        let positionen = (event.lvPositionen?.allObjects as? [LVPosition] ?? [])
            .sorted { ($0.posNr ?? "") < ($1.posNr ?? "") }
        let data = LVCSVExporter.generate(event: event, positionen: positionen)
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-")
            .appending(".csv")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if (try? data.write(to: url)) != nil {
            lvCSVURL = url
        }
    }

    // MARK: - CHECKLIST CARD
    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Schritte / Checkliste").font(.headline)
                Spacer()
                Menu {
                    ForEach(AuftragTemplate.allCases) { tpl in
                        Button("Vorlage: \(tpl.rawValue)") {
                            extras.checklist.append(contentsOf: tpl.steps.map { EventChecklistItem(title: $0) })
                            saveExtras(extras)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        extras.checklist.removeAll()
                        saveExtras(extras)
                    } label: {
                        Label("Checkliste leeren", systemImage: "trash")
                    }
                } label: { Image(systemName: "wand.and.stars") }
            }
            HStack(spacing: 10) {
                TextField("Neuer Schritt...", text: $newStepText).textFieldStyle(.roundedBorder)
                Button { addChecklistItem(title: newStepText) } label: {
                    Image(systemName: "plus.circle.fill").font(.title3)
                }
                .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                Text("\(checklistDoneCount)/\(checklistTotalCount) erledigt").font(.caption).foregroundStyle(.secondary)
                Spacer()
                ProgressView(value: checklistProgress).frame(width: 140)
            }
            if extras.checklist.isEmpty {
                Text("Noch keine Schritte.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(extras.checklist) { item in checklistRow(item) }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func checklistRow(_ item: EventChecklistItem) -> some View {
        HStack(spacing: 12) {
            Button { toggleChecklist(itemID: item.id) } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title3)
            }
            Text(item.title).font(.body).strikethrough(item.isDone).foregroundStyle(item.isDone ? .secondary : .primary)
            Spacer()
            Button(role: .destructive) { deleteChecklist(itemID: item.id) } label: {
                Image(systemName: "trash").foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - MÄNGEL CARD
    private var maengelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mängel (\(maengelAnzahl))").font(.headline)
                Spacer()
                Button { showMangelErfassen = true } label: {
                    Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(.orange)
                }
                Button { showingMaengelListe = true } label: {
                    Label("Alle", systemImage: "list.bullet").font(.subheadline)
                }
            }
            if maengelAnzahl == 0 {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal").font(.title2).foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Keine Mängel erfasst").font(.subheadline)
                        Text("Tippe auf + um einen Mangel direkt zu erfassen.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            } else {
                HStack(spacing: 0) {
                    maengelStatZelle(label: "Gesamt",      wert: maengelAnzahl,      farbe: .primary)
                    Divider().frame(height: 32)
                    maengelStatZelle(label: "Offen",      wert: maengelOffen,       farbe: .orange)
                    Divider().frame(height: 32)
                    maengelStatZelle(label: "In Arbeit",  wert: maengelInArbeit,    farbe: .blue)
                    Divider().frame(height: 32)
                    maengelStatZelle(label: "Behoben",    wert: maengelBehoben,     farbe: .green)
                    Divider().frame(height: 32)
                    maengelStatZelle(label: "Überfällig", wert: maengelUeberfaellig, farbe: .red)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func maengelStatZelle(label: String, wert: Int, farbe: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(wert)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(wert > 0 ? farbe : Color.secondary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - JOBS CARD
    private var jobsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Auftraege (\(filteredJobs.count))").font(.headline)
                Spacer()
                Menu {
                    Picker("Filter", selection: $selectedJobFilter) {
                        ForEach(JobFilter.allCases) { filter in Text(filter.rawValue).tag(filter) }
                    }
                } label: { Image(systemName: "slider.horizontal.3") }
                Button { showingAddJobSheet = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            }
            if filteredJobs.isEmpty {
                Text("Keine Auftraege gefunden.").font(.subheadline).foregroundStyle(.secondary).padding(.top, 2)
            } else {
                VStack(spacing: 10) {
                    ForEach(filteredJobs, id: \.objectID) { job in
                        NavigationLink { AuftragDetailView(job: job) } label: {
                            AuftragRowView(auftrag: job) { refreshID = UUID() }
                                .padding(12)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(radius: 1, y: 1)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .id(refreshID)
    }

    // MARK: - Extras Load/Save
    private func loadExtras() -> EventExtrasPayload {
        guard let s = event.extras, let data = s.data(using: .utf8) else { return EventExtrasPayload() }
        return (try? JSONDecoder().decode(EventExtrasPayload.self, from: data)) ?? EventExtrasPayload()
    }

    private func saveExtras(_ payload: EventExtrasPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            event.extras = String(data: data, encoding: .utf8)
            try viewContext.save()
        } catch {
            print("Fehler beim Speichern der Extras: \(error)")
        }
    }

    // MARK: - Checklist Actions
    private func addChecklistItem(title: String) {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        extras.checklist.append(EventChecklistItem(title: t))
        newStepText = ""
        saveExtras(extras)
    }
    private func toggleChecklist(itemID: String) {
        guard let idx = extras.checklist.firstIndex(where: { $0.id == itemID }) else { return }
        extras.checklist[idx].isDone.toggle()
        saveExtras(extras)
    }
    private func deleteChecklist(itemID: String) {
        extras.checklist.removeAll { $0.id == itemID }
        saveExtras(extras)
    }

    // MARK: - CAD Files Load/Save
    private var cadStorageKey: String { "cadFiles_\(event.eventNumber ?? "unknown")" }
    private func loadCADFiles() -> [CADFileInfo] {
        guard let data = UserDefaults.standard.data(forKey: cadStorageKey),
              let payload = try? JSONDecoder().decode(CADFilesPayload.self, from: data) else { return [] }
        return payload.files
    }
    private func saveCADFiles() {
        let payload = CADFilesPayload(files: cadFiles)
        if let data = try? JSONEncoder().encode(payload) { UserDefaults.standard.set(data, forKey: cadStorageKey) }
    }

    // MARK: - Server-Konvertierung
    private func convertFileToUSDZ(_ fileURL: URL) {
        let service = SKPConversionService.shared
        if service.canConvertLocally(fileURL: fileURL) {
            do {
                let usdzURL = try service.convertLocally(fileURL: fileURL)
                let info = CADFileInfo(fileName: usdzURL.lastPathComponent, relativePath: usdzURL.lastPathComponent)
                cadFiles.append(info); saveCADFiles(); return
            } catch {}
        }
        isConverting = true; conversionError = nil
        Task {
            do {
                let usdzURL = try await service.convert(fileURL: fileURL)
                await MainActor.run {
                    let info = CADFileInfo(fileName: usdzURL.lastPathComponent, relativePath: usdzURL.lastPathComponent)
                    cadFiles.append(info); saveCADFiles(); isConverting = false
                }
            } catch {
                await MainActor.run { isConverting = false; conversionError = error.localizedDescription; showConversionError = true }
            }
        }
    }
}

// -------------------------------------------------------------
// MARK: - Material Picker Sheet
// -------------------------------------------------------------
struct MaterialPickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Binding var pinnedCodes: [String]

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \CDLexikonEntry.kategorie, ascending: true),
            NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)
        ]
    ) private var allMaterials: FetchedResults<CDLexikonEntry>

    @State private var searchText = ""

    private var filtered: [CDLexikonEntry] {
        if searchText.isEmpty { return Array(allMaterials) }
        let q = searchText.lowercased()
        return allMaterials.filter {
            ($0.name ?? "").lowercased().contains(q) ||
            ($0.kategorie ?? "").lowercased().contains(q) ||
            ($0.code ?? "").lowercased().contains(q)
        }
    }

    private var grouped: [(String, [CDLexikonEntry])] {
        Dictionary(grouping: filtered, by: { $0.kategorie ?? "Sonstige" }).sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { category, materials in
                    Section(category) {
                        ForEach(materials, id: \.objectID) { mat in
                            Button { togglePin(code: mat.code ?? "") } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(mat.name ?? "").font(.body)
                                        Text(mat.code ?? "").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: pinnedCodes.contains(mat.code ?? "") ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(pinnedCodes.contains(mat.code ?? "") ? .green : .secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Material suchen...")
            .navigationTitle("Material zuordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
    }

    private func togglePin(code: String) {
        guard !code.isEmpty else { return }
        if let idx = pinnedCodes.firstIndex(of: code) { pinnedCodes.remove(at: idx) } else { pinnedCodes.append(code) }
    }
}

// -------------------------------------------------------------
// MARK: - ZEIT-FORTSCHRITT HELPERS
// -------------------------------------------------------------
struct EventTimeProgress {
    let event: Event
    var progressRatio: Double {
        guard let setupTime = event.setupTime, let endTime = event.eventEndTime, setupTime < endTime else { return 0.0 }
        let totalDuration = endTime.timeIntervalSince(setupTime)
        let elapsedTime = Date().timeIntervalSince(setupTime)
        return min(1.0, max(0.0, elapsedTime / totalDuration))
    }
    var statusText: String {
        guard let setupTime = event.setupTime, let endTime = event.eventEndTime else { return "Zeit unvollstaendig" }
        let now = Date()
        if now < setupTime { return "Geplant" }
        if now >= endTime  { return "Beendet" }
        return "Im Gange (\(Int(progressRatio * 100))%)"
    }
    var progressColor: Color {
        if let setupTime = event.setupTime, Date() < setupTime { return .blue }
        return progressRatio >= 1.0 ? .green : .orange
    }
}

struct EventTimelineBar: View {
    @ObservedObject var event: Event
    @State private var now = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    var progressData: EventTimeProgress { EventTimeProgress(event: event) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Baustellen-Status: \(progressData.statusText)").font(.caption).foregroundColor(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color(.systemGray5)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 6).fill(progressData.progressColor)
                        .frame(width: geometry.size.width * CGFloat(progressData.progressRatio), height: 10)
                        .animation(.linear, value: progressData.progressRatio)
                }
            }
            .frame(height: 10)
        }
        .frame(height: 30)
        .onReceive(timer) { _ in now = Date() }
    }
}

// -------------------------------------------------------------
// MARK: - Hilfe: Baustellen-Detail
// -------------------------------------------------------------
struct EventDetailHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Übersicht") {
                    Text("Die Baustellen-Detail-Ansicht ist die Schaltzentrale für ein Projekt. Alle Informationen, Aufträge, Mängel und Pläne sind hier gebündelt.")
                }
                Section("Karten im Überblick") {
                    Label("Header: Name, Ort, Zeitraum, Bauherr, Architekt, Baugenehmigung", systemImage: "info.circle")
                    Label("Wetter: Aktuelle Bedingungen + Bau-Ampel für den Standort", systemImage: "cloud.sun.fill")
                    Label("Pläne & CAD: 3D-Modelle (USDZ, OBJ, FBX) und SketchUp-Dateien", systemImage: "cube.fill")
                    Label("Materialien: Verknüpfte Materialien aus dem Katalog", systemImage: "shippingbox")
                    Label("LV: Leistungsverzeichnis mit Positionen und Bestellliste", systemImage: "doc.text.fill")
                    Label("Checkliste: Schrittweise Arbeitsfortschritt abhaken", systemImage: "checkmark.square")
                    Label("Mängel: Qualitätsprobleme erfassen und verfolgen", systemImage: "exclamationmark.triangle")
                    Label("Aufträge: Einzelaufgaben anlegen und Mitarbeitern zuweisen", systemImage: "list.bullet.clipboard")
                }
                Section("LV & Export") {
                    Label("Tippe auf die LV-Karte um das Leistungsverzeichnis zu öffnen", systemImage: "arrow.right.circle")
                    Label("↑-Menü in der Toolbar: LV als PDF, LV als CSV oder Bautagesbericht exportieren", systemImage: "arrow.up.doc")
                    Label("CSV eignet sich für Excel/Numbers: PosNr, Bezeichnung, Menge, Einheit, KG-Nr, ArtikelNr, Lieferant", systemImage: "tablecells")
                }
                Section("Mängel") {
                    Label("Tippe auf + direkt in der Mängel-Karte zum schnellen Erfassen", systemImage: "plus.circle.fill")
                    Label("5 Kennzahlen: Gesamt, Offen, In Arbeit, Behoben, Überfällig", systemImage: "chart.bar.fill")
                    Label("Tippe auf 'Alle' für vollständige Liste mit Filter + PDF-Export", systemImage: "list.bullet")
                }
                Section("Bautagesbericht") {
                    Label("Toolbar-Menü (↑) → Bautagesbericht: Datum, Notizen, Aufträge/LV/Mängel als PDF", systemImage: "calendar.badge.clock")
                    Label("Spracheingabe: Notizen per Mikrofon diktieren", systemImage: "mic.fill")
                }
            }
            .navigationTitle("Hilfe: Baustellen-Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}
