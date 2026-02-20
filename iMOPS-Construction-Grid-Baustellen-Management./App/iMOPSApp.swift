//
//  iMOPSApp.swift
//  test25B
//
//  App Entry Point
//

import SwiftUI
import CoreData

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
                .onOpenURL { url in
                    importedFileHandler.handleIncomingFile(url: url)
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
                }
        }
    }
}

// MARK: - Imported File Handler

@Observable
final class ImportedFileHandler {
    var showImportedSKPSheet = false
    var showImportedCADViewer = false
    var showSketchUpWeb = false
    var importedFileName = ""
    var lastImportedFileURL: URL?

    /// Unterstuetzte SceneKit-Formate (direkt anzeigbar)
    private let viewableFormats: Set<String> = ["usdz", "usda", "usdc", "obj", "dae", "scn", "abc", "stl", "ply"]

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

            let ext = url.pathExtension.lowercased()
            importedFileName = url.lastPathComponent
            lastImportedFileURL = destURL

            if ext == "skp" {
                showImportedSKPSheet = true
            } else if viewableFormats.contains(ext) {
                showImportedCADViewer = true
            } else {
                // FBX, glTF etc. - erstmal als importiert anzeigen
                showImportedSKPSheet = true
            }
        } catch {
            print("Datei-Import Fehler: \(error)")
        }
    }
}
