//
//  iMOPSApp.swift
//  test25B
//
//  App Entry Point
//

import SwiftUI
import CoreData
import Combine

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

@main
struct iMOPSApp: App {
    let persistence = PersistenceController.shared
    @State private var session = AppSession()
    @State private var importedFileHandler = ImportedFileHandler()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environment(session)
                .environment(importedFileHandler)
                .environmentObject(
                    EventListViewModel(context: persistence.container.viewContext)
                )
                .task {
                    // Scharf gestellt: nur noch ECHTE Fach-/Lieferantendaten beim Start.
                    // Lieferanten-Sortiment (Scharpegge, aus Bundle-CSV).
                    ScharpeggeSeeder.seedIfNeeded(context: persistence.container.viewContext)
                    // Öffentliche Ytong-Bedarfswerte je m³ als Mauerwerks-Rezepte
                    // (Mengen fest, Preis 0 → in den Stammdaten nachtragen).
                    YtongBedarf.seedIfNeeded(context: persistence.container.viewContext)
                    // Tiefbau-/Außenanlagen-Rezepte (Hofeinfahrt): Material-Richtwerte +
                    // Bagger-Stunden; Lohn/Preis bleiben offen (Aufwandswert per Prof).
                    TiefbauRezepte.seedIfNeeded(context: persistence.container.viewContext)
                    // Preise/Projekte kommen jetzt aus dem echten Import (Firma-Katalog-CSV),
                    // nicht mehr aus Demo-Seedern. Frischer Mops = leer bis zum Import.
                    NotificationService.shared.requestAuthorization()
                    NotificationService.shared.updateBadge(context: persistence.container.viewContext)

                    // Stufe 2+3: den sichtbaren „iMOPS"-Ordner in iCloud Drive vorbereiten
                    // (Grundstruktur _Firma + Baustellen) UND für jede vorhandene Baustelle
                    // einen Ordner (mit Fächern) sicherstellen. Namen hier auf dem Main-
                    // Context einsammeln, die Datei-Arbeit läuft im Hintergrund (nil-sicher —
                    // ohne iCloud-Login passiert nichts).
                    let baustellenNamen: [String] = {
                        let req = NSFetchRequest<Event>(entityName: "Event")
                        let events = (try? persistence.container.viewContext.fetch(req)) ?? []
                        return events.compactMap { $0.title }
                    }()
                    MopsAblage.synchronisiereBaustellen(baustellenNamen)
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    NotificationService.shared.updateBadge(context: persistence.container.viewContext)
                }
                .onOpenURL { url in
                    importedFileHandler.handleIncomingFile(url: url)
                }
                .sheet(isPresented: $importedFileHandler.showFileInspection,
                       onDismiss: { importedFileHandler.executePendingAction() }) {
                    FileInspectionSheet()
                        .environment(importedFileHandler)
                        .presentationSizing(.page)
                }
                .sheet(isPresented: $importedFileHandler.showImportedSKPSheet) {
                    NavigationStack {
                        VStack(spacing: 20) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.green)

                            Text("SKP-Datei importiert")
                                .font(.title2.bold())

                            Text(importedFileHandler.importedFileName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("Die Datei wurde gespeichert.\nOeffne sie in SketchUp Web und exportiere als OBJ oder DAE fuer den 3D-Viewer.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button {
                                importedFileHandler.showSketchUpWeb = true
                            } label: {
                                Label("In SketchUp Web oeffnen", systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.horizontal, 32)
                            

                            if let fileURL = importedFileHandler.lastImportedFileURL {
                                Button {
                                    ExternalAppLauncher.shared.openInExternalApp(fileURL: fileURL)
                                } label: {
                                    Label("Teilen / Andere App", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .padding(.horizontal, 32)
                            }

                            Spacer()
                        }
                        .padding(.top, 40)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") {
                                    importedFileHandler.showImportedSKPSheet = false
                                }
                            }
                        }
                        .sheet(isPresented: $importedFileHandler.showSketchUpWeb) {
                            if let url = URL(string: "https://app.sketchup.com") {
                                SafariView(url: url)
                                    .ignoresSafeArea()
                            }
                        }
                    }
                    .presentationSizing(.page)
                }
                .sheet(isPresented: $importedFileHandler.showImportedCADViewer) {
                    NavigationStack {
                        if let fileURL = importedFileHandler.lastImportedFileURL {
                            CADViewerView(fileURL: fileURL, fileName: importedFileHandler.importedFileName)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Schliessen") {
                                            importedFileHandler.showImportedCADViewer = false
                                        }
                                    }
                                }
                        }
                    }
                    .presentationSizing(.page)
                }
                .sheet(item: $importedFileHandler.pendingGAEBURL) { url in
                    GAEBEventPickerSheet(gaebURL: url)
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                        .presentationSizing(.page)
                }
        }
    }
}

// MARK: - Imported File Handler

@Observable
final class ImportedFileHandler {
    var showFileInspection = false
    var showImportedSKPSheet = false
    var showImportedCADViewer = false
    var showSketchUpWeb = false
    var importedFileName = ""
    var lastImportedFileURL: URL?
    var pendingGAEBURL: URL?
    var selectedTab = "baustellen"

    enum FileAction {
        case none, openSKP, openCADViewer, importGAEB
    }
    var pendingAction: FileAction = .none

    func handleIncomingFile(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let fileManager = FileManager.default
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cadDir = docsDir.appendingPathComponent("CADFiles", isDirectory: true)

        do {
            if !fileManager.fileExists(atPath: cadDir.path) {
                try fileManager.createDirectory(at: cadDir, withIntermediateDirectories: true)
            }

            let destURL = cadDir.appendingPathComponent(url.lastPathComponent)

            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }

            try fileManager.copyItem(at: url, to: destURL)

            importedFileName = url.lastPathComponent
            lastImportedFileURL = destURL
            showFileInspection = true
            MopsGruss.winke()   // Datei eingelesen → Bau-Mops grüßt
        } catch {
            print("Datei-Import Fehler: \(error)")
        }
    }

    func executePendingAction() {
        switch pendingAction {
        case .none:
            break
        case .openSKP:
            showImportedSKPSheet = true
        case .openCADViewer:
            showImportedCADViewer = true
        case .importGAEB:
            pendingGAEBURL = lastImportedFileURL
        }
        pendingAction = .none
    }
}
