import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Vorschau für die Aufwands-Eingaben (Lohn/Material/Geräte): zeigt die Kosten JE Einheit
/// UND — entscheidend — den Positions-Gesamtbetrag, damit die `× Menge`-Multiplikation schon
/// bei der Eingabe sichtbar wird. Plausi-Prüfung: „480 h?! — falsch" fällt sofort auf.
struct AufwandVorschau: View {
    let proEinheit: Double      // Kosten je Positions-Einheit (aus berechneVorschau())
    let menge: Double           // position.menge
    let einheit: String         // position.einheit ?? "Einheit"
    let mengenGesamt: String?   // optional: "60 h" / "84,0 kg" — der Mengen-Gesamtwert
    let farbe: Color            // .green (Lohn) / .orange (Material) / .purple (Geräte)

    private func zeile(_ label: String, _ wert: String, bold: Bool) -> some View {
        HStack {
            Text(label)
                .font(bold ? .subheadline.bold() : .caption)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(wert)
                .font((bold ? Font.subheadline.bold() : .caption).monospacedDigit())
                .foregroundStyle(bold ? farbe : .secondary)
        }
    }

    private var mengeText: String {
        menge.formatted(.number.precision(.fractionLength(0...2)))
    }

    var body: some View {
        VStack(spacing: 4) {
            zeile("Kosten je \(einheit)", proEinheit.formatted(.currency(code: "EUR")), bold: false)
            if let mg = mengenGesamt { zeile("Menge gesamt", mg, bold: false) }
            Divider()
            zeile("Gesamt für \(mengeText) \(einheit)",
                  (proEinheit * menge).formatted(.currency(code: "EUR")), bold: true)
        }
    }
}

/// PDF-Dokument für den `.fileExporter` (Mac-„Speichern"-Dialog). Der iOS-Teilen-Sheet
/// legt am Mac keine Datei ab — dort braucht es einen echten Save-Panel.
struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Generisches Export-Dokument (Daten von einer URL) für den Mac-„Speichern"-Dialog —
/// funktioniert für PDF, CSV, … (contentType kommt getrennt in den fileExporter).
struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .pdf, .commaSeparatedText] }
    var data: Data
    init(url: URL?) { data = (url.flatMap { try? Data(contentsOf: $0) }) ?? Data() }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Läuft die App am Mac (Catalyst ODER „Designed for iPad" auf Apple Silicon)?
/// Nur so erkennt man beide Mac-Varianten — `#if targetEnvironment(macCatalyst)` verpasst die zweite.
private var laeuftAmMac: Bool {
    ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp
}

private func exportContentType(_ url: URL?) -> UTType {
    switch url?.pathExtension.lowercased() {
    case "csv": return .commaSeparatedText
    case "pdf": return .pdf
    default:    return .data
    }
}

/// iPhone/iPad: Teilen-Sheet. Mac: echter „Speichern unter…"-Dialog (der Teilen-Sheet
/// legt am Mac keine Datei ab). Muster via `item: Binding<URL?>`.
struct TeilenOderSpeichernModifier: ViewModifier {
    @Binding var datei: URL?
    func body(content: Content) -> some View {
        if laeuftAmMac {
            content.fileExporter(
                isPresented: Binding(get: { datei != nil }, set: { if !$0 { datei = nil } }),
                document: ExportFileDocument(url: datei),
                contentType: exportContentType(datei),
                defaultFilename: datei?.deletingPathExtension().lastPathComponent
            ) { _ in datei = nil }
        } else {
            content.sheet(item: $datei) { url in LVShareSheet(url: url).ignoresSafeArea() }
        }
    }
}

extension View {
    /// iPhone: Teilen-Sheet, Mac: Speichern-Dialog — für eine per `item:` gebundene Datei-URL.
    func teilenOderSpeichern(datei: Binding<URL?>) -> some View {
        modifier(TeilenOderSpeichernModifier(datei: datei))
    }
    /// Variante mit Bool + fester URL (für Views, die die URL schon halten).
    @ViewBuilder
    func teilenOderSpeichern(isPresented: Binding<Bool>, url: URL) -> some View {
        if laeuftAmMac {
            fileExporter(
                isPresented: isPresented,
                document: ExportFileDocument(url: url),
                contentType: exportContentType(url),
                defaultFilename: url.deletingPathExtension().lastPathComponent
            ) { _ in }
        } else {
            sheet(isPresented: isPresented) { LVShareSheet(url: url).ignoresSafeArea() }
        }
    }
}

struct LVShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        ankern(vc)
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {
        ankern(vc)
    }

    /// iPad / Mac Catalyst: UIActivityViewController wird als Popover präsentiert und braucht
    /// einen Anker (sourceView/sourceRect), sonst erscheint der Teilen-/Speichern-Dialog GAR
    /// NICHT — auf iPhone (modal) wird der Anker ignoriert. (Gleiches Muster wie ExternalAppLauncher.)
    private func ankern(_ vc: UIActivityViewController) {
        guard let pop = vc.popoverPresentationController else { return }
        pop.sourceView = vc.view
        pop.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
        pop.permittedArrowDirections = []
    }
}

struct LVHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Was ist das LV?") {
                    Text("Das Leistungsverzeichnis listet alle Bauleistungen strukturiert auf — mit Nummer, Beschreibung, Menge und Einheit.")
                }
                Section("Positionen") {
                    Label("+  anlegen, Swipe-links bearbeiten, Swipe-rechts löschen", systemImage: "hand.point.left")
                    Label("Swipe-links: 'Alternative' erstellt Alternativposition (.A1, .A2 …)", systemImage: "doc.on.doc")
                    Label("Swipe-links: 'Fortschritt' → Fertigstellungsgrad 0–100 %", systemImage: "chart.bar")
                    Label("Sortierung: DIN 276 Kostengruppe → Pos.-Nr.", systemImage: "list.number")
                }
                Section("Fortschrittserfassung") {
                    Label("Fortschritt pro Position: Slider + Schnell-Buttons (0/25/50/75/100 %)", systemImage: "chart.bar.fill")
                    Label("Gesamtfortschritt-Banner oben in der Liste (Ø aller Positionen)", systemImage: "gauge.open.with.lines.needle.33percent")
                    Label("Ø-Fortschritt pro KG im Abschnitts-Header", systemImage: "list.number")
                }
                Section("Kostenzusammenfassung") {
                    Label("⋯ → 'Kostenzusammenfassung': Netto/MwSt/Brutto + KG-Balken", systemImage: "chart.pie")
                    Label("MwSt-Satz aus Settings (Standard: 19 %)", systemImage: "percent")
                    Label("Fehlende Preise werden rot markiert", systemImage: "exclamationmark.triangle")
                }
                Section("GAEB DA XML 3.3") {
                    Label("⋯ → 'GAEB X83 importieren': Angebotsaufforderung einlesen", systemImage: "doc.badge.arrow.up")
                    Label("⋯ → 'GAEB X84 exportieren': bepreistes Angebot rausschreiben", systemImage: "signature")
                    Label("Preisquelle für X84: günstigster Eintrag im Angebotsvergleich", systemImage: "tag.fill")
                }
                Section("XRechnung (E-Rechnung)") {
                    Label("⋯ → 'XRechnung exportieren': CII XML nach EN 16931 / XRechnung 2.2", systemImage: "eurosign.circle")
                    Label("Firmendaten & MwSt-Satz in Settings konfigurierbar", systemImage: "gearshape")
                }
                Section("PDF Import & Export") {
                    Label("⋯ → 'Aus PDF importieren': Heuristik-Parser für LV-PDFs", systemImage: "doc.text.magnifyingglass")
                    Label("⋯ → 'LV als PDF': formatiertes PDF nach DIN 276", systemImage: "arrow.up.doc")
                }
                Section("Bestellliste & Angebotsvergleich") {
                    Label("Bestellliste: vorausgefüllte Preisanfrage-Mail pro Lieferant", systemImage: "envelope.badge")
                    Label("Angebotsvergleich: EP/GP erfassen, günstigster grün markiert", systemImage: "chart.bar.doc.horizontal")
                }
            }
            .navigationTitle("Hilfe: Leistungsverzeichnis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

