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

    @State private var selektiert: Set<String>
    @Environment(\.dismiss) private var dismiss

    init(ergebnisse: [ExtractDocResult],
         fehler: [String],
         onSpeichern: (([ExtractDocResult]) -> Void)? = nil) {
        self.ergebnisse = ergebnisse
        self.fehler = fehler
        self.onSpeichern = onSpeichern
        // Speichern-Modus: initial alle Dokumente ausgewählt.
        _selektiert = State(initialValue: Set(ergebnisse.map(\.quelle)))
    }

    private var speichernModus: Bool { onSpeichern != nil }

    var body: some View {
        NavigationStack {
            List {
                hinweisSection

                ForEach(Array(ergebnisse.enumerated()), id: \.offset) { _, res in
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
            }

            // Felder generisch ausgeklappt
            ForEach(zeilen(fuer: res.felder, label: nil, ebene: 0)) { zeile in
                feldRow(zeile)
            }
        } header: {
            Text(res.quelle)
        }
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
