import SwiftUI
import CoreData

// MARK: - MaterialHinzufuegenView
// Fuegt einer LV-Position ein Material aus den Stammdaten hinzu
// oder erlaubt manuelle Eingabe.

struct MaterialHinzufuegenView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let position: LVPosition

    // Der GROSSE Katalog (~2500) zum Durchsuchen — reines Nachschlagewerk, ohne Preis.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)]
    ) private var katalog: FetchedResults<CDLexikonEntry>

    // Die bepreisten Stammdaten — hier holen wir den Preis, wo einer hinterlegt ist.
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \KalkMaterial.name, ascending: true)]
    ) private var preise: FetchedResults<KalkMaterial>

    @State private var gewaehlt = false
    @State private var materialName = ""
    @State private var mengeProEinheit = ""
    @State private var einzelpreis = ""
    @State private var verschnittProzent = "5"
    @State private var einheit = "Stk"
    @State private var manuellMode = false
    @State private var eingabeGesamt = false   // false = Menge je Einheit, true = Gesamt-Materialmenge
    @State private var suche = ""

    private let einheiten = ["Stk", "m²", "m³", "lfm", "kg", "t", "l"]

    /// Treffer der Katalog-Suche (in-memory, gekappt) — 2500 Einträge alle zu rendern ist zäh.
    private var gefiltert: [CDLexikonEntry] {
        let q = suche.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return katalog.filter {
            ($0.name ?? "").lowercased().contains(q) ||
            ($0.kategorie ?? "").lowercased().contains(q) ||
            ($0.code ?? "").lowercased().contains(q)
        }
    }

    /// Der bepreiste Stammdaten-Satz zu einem Namen (für Preis + Einheit), falls hinterlegt.
    private func preisSatz(_ name: String) -> KalkMaterial? {
        let z = name.lowercased().trimmingCharacters(in: .whitespaces)
        return preise.first { ($0.name ?? "").lowercased().trimmingCharacters(in: .whitespaces) == z }
    }

    private var isValid: Bool {
        !materialName.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(mengeProEinheit.replacingOccurrences(of: ",", with: ".")) != nil &&
        Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                kopfBereich          // Google-artige Suchbox + Kontext (LV-Langtext) oben, prominent
                Form {
                    if !manuellMode {
                        stammdatenSection
                    }
                    if manuellMode || gewaehlt {
                        detailSection
                    }
                }
            }
            .navigationTitle("Material hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") { hinzufuegen() }
                        .disabled(!isValid)
                        .tint(.orange)
                }
            }
        }
    }

    // MARK: - Kopfbereich: Google-artige Suchbox + Kontext

    private var kopfBereich: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !manuellMode { suchbox }
            kontextHinweis
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGroupedBackground))
    }

    /// Das große, abgerundete Suchfeld — vertraut wie eine Google-Suche: prominent, oben, mit Lupe.
    /// Bewusst IM Inhalt (nicht die native `.searchable`, die die Navileiste kapert und den
    /// „Hinzufügen"-Knopf verdeckt).
    private var suchbox: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Material im Katalog suchen …", text: $suche)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !suche.isEmpty {
                Button { suche = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(Capsule().fill(Color(.secondarySystemBackground)))
        .overlay(Capsule().strokeBorder(Color(.separator), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    /// Der Kontext: was diese Position braucht — Titel + Langtext (die Info zum Suchen).
    private var kontextHinweis: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(position.bezeichnung ?? "LV-Position")
                .font(.subheadline.weight(.semibold))
            if let lt = position.langtext?.trimmingCharacters(in: .whitespacesAndNewlines),
               !lt.isEmpty, lt != (position.bezeichnung ?? "") {
                Text(lt)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)   // Begriff markieren → in die Suche kopieren
            }
            Text("\(position.menge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "Einheit")")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Stammdaten-Auswahl

    private var stammdatenSection: some View {
        Section {
            if katalog.isEmpty {
                Text("Katalog ist leer")
                    .foregroundStyle(.secondary)
            } else if suche.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Tippe oben ins Suchfeld — der Katalog hat \(katalog.count) Einträge.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if gefiltert.isEmpty {
                Text("Nichts gefunden für „\(suche)\u{201C}. Nutz die manuelle Eingabe unten.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(gefiltert.prefix(60), id: \.objectID) { mat in
                    let k = preisSatz(mat.name ?? "")
                    Button {
                        selectFromStamm(mat)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mat.name ?? "–")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if let k, k.preisProEinheit > 0 {
                                    Text("\(k.preisProEinheit.formatted(.currency(code: "EUR")))/\(k.einheit ?? "") · Preis hinterlegt")
                                        .font(.caption).foregroundStyle(.green)
                                } else {
                                    Text("\(mat.kategorie ?? "Katalog") · kein Preis — du trägst ihn ein")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if !materialName.isEmpty && materialName == (mat.name ?? "") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                if gefiltert.count > 60 {
                    Text("… \(gefiltert.count - 60) weitere — Suche verfeinern.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            Button {
                manuellMode = true
                gewaehlt = false
                materialName = ""
            } label: {
                Label("Manuell eingeben", systemImage: "pencil")
                    .font(.subheadline)
            }
            .tint(.orange)
        } header: {
            Text("Aus dem Katalog suchen")
        }
    }

    // MARK: - Detail-Eingabe

    private var detailSection: some View {
        Section {
            if manuellMode {
                TextField("Materialname", text: $materialName)
                Picker("Einheit", selection: $einheit) {
                    ForEach(einheiten, id: \.self) { Text($0) }
                }
            }

            AufwandEingabeFeld(titel: "Menge",
                               einheit: position.einheit ?? "Einheit",
                               menge: position.menge,
                               text: $mengeProEinheit,
                               gesamt: $eingabeGesamt)

            HStack {
                Text("Einzelpreis")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("0,00 €", text: $einzelpreis)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }

            HStack {
                Text("Verschnitt")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("5", text: $verschnittProzent)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                Text("%")
                    .foregroundStyle(.secondary)
            }

            // Vorschau: Kosten je Einheit UND Positions-Gesamt (macht × Menge sichtbar)
            let vorschau = berechneVorschau()
            if vorschau > 0 {
                let mJe = AufwandEingabeFeld.jeEinheit(text: mengeProEinheit, gesamt: eingabeGesamt, menge: position.menge)
                let gesamtMenge = (mJe * position.menge).formatted(.number.precision(.fractionLength(0...2)))
                AufwandVorschau(proEinheit: vorschau,
                                menge: position.menge,
                                einheit: position.einheit ?? "Einheit",
                                mengenGesamt: "\(gesamtMenge) \(einheit)",   // Material-Einheit (kg/Stk …)
                                farbe: .orange)
            }
        } header: {
            Text("Details")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(eingabeGesamt
                     ? "Gesamt-Materialmenge für die ganze Position (\(mengeText) \(position.einheit ?? "Einheit")) — die App rechnet auf „je Einheit\u{201C} um und speichert das."
                     : "Menge für **eine** \(position.einheit ?? "Einheit") — nicht für die ganze Position. Die Vorschau multipliziert mit der Menge (\(mengeText) \(position.einheit ?? "Einheit")).")
                if let k = preisSatz(materialName), k.verbrauchProM2 > 0 {
                    Text("Richtwert: \(k.verbrauchProM2.formatted(.number.precision(.fractionLength(0...1)))) \(k.einheit ?? "") pro m²")
                }
            }
        }
    }

    /// Positions-Menge lesbar (für den Hinweistext).
    private var mengeText: String {
        position.menge.formatted(.number.precision(.fractionLength(0...2)))
    }

    // MARK: - Actions

    private func selectFromStamm(_ eintrag: CDLexikonEntry) {
        gewaehlt = true
        manuellMode = false
        eingabeGesamt = false   // Richtwert ist je Einheit → Modus zurücksetzen, sonst falsch interpretiert
        materialName = eintrag.name ?? ""
        if let k = preisSatz(materialName) {          // Preis + Einheit aus den bepreisten Stammdaten
            einheit = k.einheit ?? "Stk"
            einzelpreis = String(format: "%.2f", k.preisProEinheit).replacingOccurrences(of: ".", with: ",")
            if k.verbrauchProM2 > 0 {
                mengeProEinheit = String(format: "%.1f", k.verbrauchProM2).replacingOccurrences(of: ".", with: ",")
            }
            verschnittProzent = String(Int(k.verschnittProzent * 100))
        } else {
            einzelpreis = ""                          // kein Preis hinterlegt → du trägst ihn ein (wird „dein Wert")
        }
    }

    private func hinzufuegen() {
        let pm = PositionMaterial(context: viewContext)
        pm.id = UUID()
        pm.materialName = materialName
        pm.einheit = einheit
        pm.mengeProEinheit = AufwandEingabeFeld.jeEinheit(text: mengeProEinheit, gesamt: eingabeGesamt, menge: position.menge)
        pm.einzelpreis = Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) ?? 0
        pm.verschnittProzent = (Double(verschnittProzent) ?? 5) / 100.0
        // Hinterlegter Firmenpreis → Firmenwert; selbst eingetippt → dein Wert.
        pm.quelle = ((preisSatz(materialName)?.preisProEinheit ?? 0) > 0) ? "raffi" : "eigen"
        pm.position = position
        lerneInKatalog()          // neues Material in den Katalog aufnehmen (suchbar + Preis merken)
        try? viewContext.save()
        dismiss()
    }

    /// Nimmt ein neu eingetragenes Material in den Katalog auf, damit es beim nächsten Mal
    /// gefunden wird — in den Such-Katalog (CDLexikonEntry) und, mit Preis, in den bepreisten
    /// Katalog (KalkMaterial). Idempotent: legt nur an, was noch fehlt.
    private func lerneInKatalog() {
        let name = materialName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let z = name.lowercased()
        let preis = Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) ?? 0

        // Preis merken (KalkMaterial), wenn ein Preis da ist und noch keiner hinterlegt.
        if preis > 0 && preisSatz(name) == nil {
            let km = KalkMaterial(context: viewContext)
            km.id = UUID()
            km.name = name
            km.einheit = einheit
            km.preisProEinheit = preis
            km.lieferant = "selbst angelegt"
            km.letzteAktualisierung = Date()
        }
        // Suchbar machen (CDLexikonEntry), wenn noch nicht im Katalog.
        if !katalog.contains(where: { ($0.name ?? "").lowercased() == z }) {
            let e = CDLexikonEntry(context: viewContext)
            e.name = name
            e.kategorie = "Selbst angelegt"
            e.code = "EIGEN-\(UUID().uuidString.prefix(6))"
        }
    }

    private func berechneVorschau() -> Double {
        let menge = AufwandEingabeFeld.jeEinheit(text: mengeProEinheit, gesamt: eingabeGesamt, menge: position.menge)
        let preis = Double(einzelpreis.replacingOccurrences(of: ",", with: ".")) ?? 0
        let verschnitt = (Double(verschnittProzent) ?? 0) / 100.0
        return menge * preis * (1 + verschnitt)
    }
}
