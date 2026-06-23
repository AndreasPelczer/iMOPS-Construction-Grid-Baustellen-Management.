import SwiftUI
import UIKit

struct LVShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
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

