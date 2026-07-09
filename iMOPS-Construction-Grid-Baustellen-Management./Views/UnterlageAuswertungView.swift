import SwiftUI

// MARK: - Flach ausgeklappte Feld-Zeile

/// Eine Zeile im Review — der `felder`-Baum wird generisch flachgeklappt, damit
/// **alle vier Doctypes + der Fallback** ohne Sonderbehandlung lesbar werden.
private struct FeldZeile: Identifiable {
    let id = UUID()
    let ebene: Int        // Einrücktiefe
    let label: String?    // Schlüssel bzw. Listen-Index; nil = reine Wert-Zeile
    let wert: String?     // Skalarwert; nil = Überschrift eines Unterbaums
}

// MARK: - Review-Screen für /extract-doc

/// Zeigt die Stufe-2-Extraktion mehrerer Unterlagen als prüfbaren Entwurf.
///
/// Zwei Modi:
/// - **Speichern** (`onSpeichern != nil`): frische Auswertung — pro Dokument ein Häkchen
///   (initial alle an), Toolbar-Button „Speichern" legt die gewählten Fakten am Event ab.
/// - **Nur ansehen** (`onSpeichern == nil`): schon gespeicherte Fakten wieder aufrufen —
///   ohne Häkchen, ohne Mops-Aufruf.
struct UnterlageAuswertungView: View {
    let ergebnisse: [ExtractDocResult]
    let fehler: [String]
    /// Gesetzt → Speichern-Modus (Häkchen + „Speichern"-Button). nil → reine Ansicht.
    let onSpeichern: (([ExtractDocResult]) -> Void)?
    /// Gesetzt → gespeicherte Auswertung kann gelöscht werden (falsche geladen).
    let onLoeschen: ((ExtractDocResult) -> Void)?

    @State private var selektiert: Set<String>
    @State private var angezeigte: [ExtractDocResult]
    @State private var loeschKandidat: ExtractDocResult?
    @Environment(\.dismiss) private var dismiss

    init(ergebnisse: [ExtractDocResult],
         fehler: [String],
         onSpeichern: (([ExtractDocResult]) -> Void)? = nil,
         onLoeschen: ((ExtractDocResult) -> Void)? = nil) {
        self.ergebnisse = ergebnisse
        self.fehler = fehler
        self.onSpeichern = onSpeichern
        self.onLoeschen = onLoeschen
        // Speichern-Modus: initial alle Dokumente ausgewählt.
        _selektiert = State(initialValue: Set(ergebnisse.map(\.quelle)))
        _angezeigte = State(initialValue: ergebnisse)
    }

    private var speichernModus: Bool { onSpeichern != nil }
    private var loeschbar: Bool { onLoeschen != nil }

    /// Entfernt die Auswertung aus der Ansicht UND persistent (Callback). Leert → schließen.
    private func loesche(_ res: ExtractDocResult) {
        angezeigte.removeAll { $0.quelle == res.quelle }
        onLoeschen?(res)
        if angezeigte.isEmpty { dismiss() }
    }

    var body: some View {
        NavigationStack {
            List {
                hinweisSection

                ForEach(angezeigte, id: \.quelle) { res in
                    dokumentSection(res)
                }

                if !fehler.isEmpty {
                    fehlerSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Unterlagen-Auswertung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if speichernModus {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fertig") { dismiss() }   // schließen ohne Speichern
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            let gewaehlt = ergebnisse.filter { selektiert.contains($0.quelle) }
                            onSpeichern?(gewaehlt)
                            dismiss()
                        }
                        .tint(.orange)
                        .disabled(selektiert.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { dismiss() }.tint(.orange)
                    }
                }
            }
            .alert("Auswertung löschen?",
                   isPresented: Binding(get: { loeschKandidat != nil },
                                        set: { if !$0 { loeschKandidat = nil } }),
                   presenting: loeschKandidat) { res in
                Button("Löschen", role: .destructive) { loesche(res); loeschKandidat = nil }
                Button("Abbrechen", role: .cancel) { loeschKandidat = nil }
            } message: { res in
                Text("Die gespeicherten Fakten aus \(res.quelle) werden von der Baustelle entfernt. Das PDF bleibt. Rückgängig nur durch erneutes Auswerten.")
            }
        }
    }

    // MARK: Abschnitte

    private var hinweisSection: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("KI-Entwurf aus der PDF-Textebene — vor Verwendung prüfen. "
                     + "Ersetzt kein Gutachten und keinen Vermesser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func dokumentSection(_ res: ExtractDocResult) -> some View {
        Section {
            // Kopf: Doctype + Konfidenz + Modell (im Speichern-Modus mit Häkchen)
            HStack(spacing: 10) {
                if speichernModus {
                    Button {
                        if selektiert.contains(res.quelle) { selektiert.remove(res.quelle) }
                        else { selektiert.insert(res.quelle) }
                    } label: {
                        Image(systemName: selektiert.contains(res.quelle) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selektiert.contains(res.quelle) ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(selektiert.contains(res.quelle) ? "Ausgewählt" : "Nicht ausgewählt")
                }
                Image(systemName: res.doctypeSymbol)
                    .font(.title3).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(res.doctypeLabel).font(.subheadline.bold())
                    HStack(spacing: 6) {
                        konfidenzChip(res.confidence)
                        Text(res.model)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if loeschbar {
                    Button(role: .destructive) { loeschKandidat = res } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Auswertung löschen")
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if loeschbar {
                    Button(role: .destructive) { loeschKandidat = res } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
            .contextMenu {
                if loeschbar {
                    Button(role: .destructive) { loeschKandidat = res } label: {
                        Label("Auswertung löschen", systemImage: "trash")
                    }
                }
            }

            // Kurz-Zusammenfassung: die wichtigsten Fakten auf einen Blick (vor dem Detail)
            let kern = zusammenfassung(res)
            if !kern.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(kern, id: \.self) { fakt in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2).foregroundStyle(.green)
                            Text(fakt).font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }

            // Felder generisch ausgeklappt
            ForEach(zeilen(fuer: res.felder, label: nil, ebene: 0)) { zeile in
                feldRow(zeile)
            }
        } header: {
            Text(res.quelle)
        }
    }

    /// Die 2–4 wichtigsten Fakten eines Dokuments (für die Kurz-Zusammenfassung oben).
    /// Feldnamen = Backend-Schema (`api/services/doc_extract.py`). Fehlt ein Feld → weglassen.
    private func zusammenfassung(_ res: ExtractDocResult) -> [String] {
        let f = res.felder
        var fakten: [String] = []
        func hat(_ s: String?) -> String? { (s == nil || s == "—") ? nil : s }

        switch res.doctypeErkannt {
        case "bodengutachten":
            if let bkl = hat(f["bodenklassen"]?.erstesArrayElement?.skalarText) { fakten.append("Bodenklasse \(bkl)") }
            if let ft  = hat(f["frosttiefe_m"]?.skalarText) { fakten.append("Frosttiefe \(ft) m") }
            if let gw  = hat(f["grundwasser"]?["angetroffen"]?.skalarText) { fakten.append("Grundwasser: \(gw)") }
            if let ab  = hat(f["abdichtung_lastfall"]?.skalarText) { fakten.append("Abdichtung \(ab)") }
        case "wohnflaeche":
            if let wf = hat(f["wohnflaeche_gesamt_m2"]?.skalarText) { fakten.append("Wohnfläche \(wf) m²") }
            if let nf = hat(f["nutzflaeche_m2"]?.skalarText) { fakten.append("Nutzfläche \(nf) m²") }
            if let br = hat(f["bri_m3"]?.skalarText) { fakten.append("BRI \(br) m³") }
        case "bebauungsplan":
            if let z = hat(f["zone"]?.skalarText) { fakten.append("Zone \(z)") }
            if let g = hat(f["grz"]?.skalarText) { fakten.append("GRZ \(g)") }
            if let gf = hat(f["gfz"]?.skalarText) { fakten.append("GFZ \(gf)") }
        case "erschliessung":
            if let n = f["medien"]?.arrayAnzahl, n > 0 { fakten.append("\(n) Medien erschlossen") }
            if let warn = hat(f["besonderheiten"]?.erstesArrayElement?.skalarText) { fakten.append("⚠︎ \(warn)") }
        default:
            break
        }
        return Array(fakten.prefix(4))
    }

    private var fehlerSection: some View {
        Section {
            ForEach(Array(fehler.enumerated()), id: \.offset) { _, msg in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption).foregroundStyle(.red)
                    Text(msg).font(.caption).foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Übersprungen (\(fehler.count))")
        } footer: {
            Text("Zeichnungen ohne Textebene gehören zur Vision-Auswertung (Stufe 3) "
                 + "und werden hier bewusst übersprungen.")
        }
    }

    // MARK: Bausteine

    @ViewBuilder
    private func feldRow(_ zeile: FeldZeile) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let label = zeile.label {
                Text(label)
                    .font(zeile.wert == nil ? .subheadline.bold() : .caption)
                    .foregroundStyle(zeile.wert == nil ? .primary : .secondary)
            }
            if let wert = zeile.wert {
                Spacer(minLength: 6)
                Text(wert)
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.leading, CGFloat(zeile.ebene) * 14)
    }

    private func konfidenzChip(_ conf: Double) -> some View {
        let hoch = conf >= 0.5
        return HStack(spacing: 3) {
            Image(systemName: hoch ? "checkmark.seal.fill" : "questionmark.circle")
            Text("Typ-Sicherheit \(Int(conf * 100)) %")
        }
        .font(.caption2)
        .foregroundStyle(hoch ? .green : .secondary)
    }

    // MARK: Generisches Ausklappen des felder-Baums

    private func zeilen(fuer value: JSONValue, label: String?, ebene: Int) -> [FeldZeile] {
        var out: [FeldZeile] = []
        switch value {
        case .object(let dict):
            if let label { out.append(FeldZeile(ebene: ebene, label: label, wert: nil)) }
            let kindEbene = label == nil ? ebene : ebene + 1
            for key in dict.keys.sorted() {
                out += zeilen(fuer: dict[key]!, label: schoenerKey(key), ebene: kindEbene)
            }
        case .array(let arr):
            if arr.isEmpty {
                out.append(FeldZeile(ebene: ebene, label: label, wert: "—"))
            } else {
                if let label { out.append(FeldZeile(ebene: ebene, label: label, wert: nil)) }
                let kindEbene = label == nil ? ebene : ebene + 1
                for (i, el) in arr.enumerated() {
                    switch el {
                    case .object, .array:
                        out.append(FeldZeile(ebene: kindEbene, label: "\(i + 1).", wert: nil))
                        out += zeilen(fuer: el, label: nil, ebene: kindEbene + 1)
                    default:
                        out.append(FeldZeile(ebene: kindEbene, label: "\(i + 1).", wert: el.skalarText))
                    }
                }
            }
        default:
            out.append(FeldZeile(ebene: ebene, label: label, wert: value.skalarText ?? "—"))
        }
        return out
    }

    /// `wohnflaeche_gesamt_m2` → `Wohnflaeche gesamt m2` (Unterstriche raus, Initial groß).
    private func schoenerKey(_ key: String) -> String {
        let ersetzt = key.replacingOccurrences(of: "_", with: " ")
        return ersetzt.prefix(1).uppercased() + ersetzt.dropFirst()
    }
}
