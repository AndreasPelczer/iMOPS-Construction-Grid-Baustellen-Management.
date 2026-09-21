import SwiftUI
import UniformTypeIdentifiers
import CoreData

/// „Die Firma" teilen: Stammdaten + Firmensettings als Datei exportieren (→ über die
/// Box/Tailscale zum Kollegen) und drüben importieren. Keine Cloud, kein Repo — Datenhoheit.
struct FirmaTransferView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var zeigeExport = false
    @State private var zeigeImport = false
    @State private var exportDatei: FirmaDatei?
    @State private var meldung: String?
    @State private var fehler = false

    private var dateiName: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "Firma-Mops-\(f.string(from: Date()))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        exportieren()
                    } label: {
                        Label("Firma exportieren", systemImage: "square.and.arrow.up")
                    }
                    .tint(.orange)
                } header: {
                    Text("Senden")
                } footer: {
                    Text("Schreibt Materialien, Löhne, Geräte, den Leistungskatalog UND die Firmensettings (Zuschläge, "
                       + "Verrechnungssatz, Firmendaten) in eine Datei. Leg sie in den Box-/Tailscale-"
                       + "Ordner, den der Kollege sieht — dann importiert er sie.")
                }

                Section {
                    Button {
                        zeigeImport = true
                    } label: {
                        Label("Firma importieren", systemImage: "square.and.arrow.down")
                    }
                    .tint(.orange)
                } header: {
                    Text("Empfangen")
                } footer: {
                    Text("Liest eine Firma-Datei ein. Vorhandene Einträge werden über ihre Kennung "
                       + "aktualisiert (nichts doppelt). Deine eigenen, zusätzlichen Einträge bleiben.")
                }

                if let m = meldung {
                    Section {
                        Label(m, systemImage: fehler ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .foregroundStyle(fehler ? .orange : .green)
                            .font(.subheadline)
                    }
                }

                Section {
                    Text("Diese echten Zahlen bleiben bei euch — die Datei geht über die Box/Tailscale, "
                       + "nicht ins Repo, nicht in die Cloud. (Das Firmenlogo wird nicht mitgeschickt.)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Firma teilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
            .fileExporter(isPresented: $zeigeExport, document: exportDatei,
                          contentType: .json, defaultFilename: dateiName) { ergebnis in
                switch ergebnis {
                case .success:  setzeMeldung("Firma exportiert. Jetzt in den Box-/Tailscale-Ordner legen.", fehler: false)
                case .failure(let e): setzeMeldung("Export fehlgeschlagen: \(e.localizedDescription)", fehler: true)
                }
            }
            .fileImporter(isPresented: $zeigeImport, allowedContentTypes: [.json, .data]) { ergebnis in
                importieren(ergebnis)
            }
        }
    }

    private func exportieren() {
        do {
            let data = try FirmaTransfer.exportieren(in: ctx)
            exportDatei = FirmaDatei(data: data)
            zeigeExport = true
        } catch {
            setzeMeldung("Export fehlgeschlagen: \(error.localizedDescription)", fehler: true)
        }
    }

    private func importieren(_ ergebnis: Result<URL, Error>) {
        switch ergebnis {
        case .failure(let e):
            setzeMeldung("Import fehlgeschlagen: \(e.localizedDescription)", fehler: true)
        case .success(let url):
            // Datei-Picker liefert eine security-scoped URL — vor dem Lesen freischalten.
            let braucht = url.startAccessingSecurityScopedResource()
            defer { if braucht { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let b = try FirmaTransfer.importieren(data, in: ctx)
                setzeMeldung("Importiert: \(b.materialien) Materialien, \(b.loehne) Löhne, "
                           + "\(b.geraete) Geräte, \(b.leistungen) Leistungen, "
                           + "\(b.settings) Firmenwerte.", fehler: false)
            } catch {
                setzeMeldung("Import fehlgeschlagen: \(error.localizedDescription)", fehler: true)
            }
        }
    }

    private func setzeMeldung(_ text: String, fehler: Bool) {
        self.meldung = text; self.fehler = fehler
    }
}

/// Die Firma-Datei fürs .fileExporter/.fileImporter (JSON drin).
struct FirmaDatei: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
