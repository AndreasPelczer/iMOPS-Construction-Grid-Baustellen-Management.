//
//  LagerBuchungSheet.swift
//  Eine Lagerbewegung buchen: Wareneingang · Warenausgang · Umlagerung · Inventur.
//  Artikel kommt aus dem Katalog (CDLexikonEntry), gebucht wird in den LagerStore.
//

import SwiftUI
import CoreData

struct LagerBuchungSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var lager = LagerStore.shared

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \CDLexikonEntry.name, ascending: true)])
    private var katalog: FetchedResults<CDLexikonEntry>

    @State private var art: Buchungsart = .eingang
    @State private var artikel: CDLexikonEntry?
    @State private var mengeText = ""
    @State private var einheit = ""
    @State private var ort: UUID?
    @State private var zielOrt: UUID?          // nur Umlagerung
    @State private var notiz = ""

    /// Bei Inventur ist die eingegebene Menge das gezählte IST, sonst die Bewegungsmenge.
    private var menge: Double { Double(mengeText.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var kannBuchen: Bool {
        guard artikel != nil, ort != nil, !einheit.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if art == .umlagerung { return zielOrt != nil && zielOrt != ort && menge > 0 }
        if art == .inventur   { return menge >= 0 }
        return menge > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Art", selection: $art) {
                        ForEach(Buchungsart.allCases, id: \.self) { a in Text(a.anzeige).tag(a) }
                    }
                    .pickerStyle(.menu)
                } footer: {
                    Text(hinweisFuerArt)
                }

                Section("Artikel") {
                    Picker("Material", selection: $artikel) {
                        Text("– wählen –").tag(CDLexikonEntry?.none)
                        ForEach(katalog, id: \.objectID) { e in
                            Text(e.name ?? e.code ?? "?").tag(CDLexikonEntry?.some(e))
                        }
                    }
                    .onChange(of: artikel) { _, neu in
                        if let code = neu?.code,
                           let letzte = lager.artikelImLager().first(where: { $0.code == code }) {
                            if einheit.isEmpty { einheit = letzte.einheit }
                        }
                    }
                    HStack {
                        TextField(art == .inventur ? "Gezählte Menge" : "Menge", text: $mengeText)
                            .keyboardType(.decimalPad)
                        TextField("Einheit", text: $einheit)
                            .frame(maxWidth: 90)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(art == .umlagerung ? "Von Lagerort" : "Lagerort") {
                    lagerortPicker(auswahl: $ort)
                }
                if art == .umlagerung {
                    Section("Nach Lagerort") { lagerortPicker(auswahl: $zielOrt) }
                }

                // Aktueller Bestand als Orientierung (besonders für Inventur/Ausgang).
                if let code = artikel?.code, let o = ort {
                    let b = lager.bestand(artikelCode: code, lagerortID: o)
                    LabeledContent("Aktueller Bestand hier",
                                   value: b.formatted(.number.precision(.fractionLength(0...2))) + " " + einheit)
                        .foregroundStyle(.secondary)
                }

                Section("Notiz (optional)") {
                    TextField("z. B. Lieferschein-Nr., Baustelle", text: $notiz, axis: .vertical)
                }

                if lager.lagerorte.isEmpty {
                    Section {
                        Text("Noch kein Lagerort angelegt — erst einen Lagerort erstellen.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Buchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buchen") { buchen(); dismiss() }.disabled(!kannBuchen)
                }
            }
        }
    }

    private func lagerortPicker(auswahl: Binding<UUID?>) -> some View {
        Picker("Lagerort", selection: auswahl) {
            Text("– wählen –").tag(UUID?.none)
            ForEach(lager.lagerorte) { o in Text(o.name).tag(UUID?.some(o.id)) }
        }
    }

    private var hinweisFuerArt: String {
        switch art {
        case .eingang:    return "Ware kommt ins Lager (Bestand steigt)."
        case .ausgang:    return "Ware verlässt das Lager, z. B. auf eine Baustelle (Bestand sinkt)."
        case .umlagerung: return "Von einem Lagerort zum anderen — der Gesamtbestand bleibt gleich."
        case .inventur:   return "Gezählt: der Bestand wird auf den eingegebenen Wert gesetzt."
        case .korrektur:  return "Manuelle Berichtigung."
        }
    }

    private func buchen() {
        guard let e = artikel, let code = e.code, let o = ort else { return }
        let name = e.name ?? code
        switch art {
        case .eingang:
            lager.eingang(artikelCode: code, name: name, einheit: einheit, menge: menge, lagerortID: o, notiz: notiz)
        case .ausgang:
            lager.ausgang(artikelCode: code, name: name, einheit: einheit, menge: menge, lagerortID: o, notiz: notiz)
        case .umlagerung:
            if let ziel = zielOrt {
                lager.umlagern(artikelCode: code, name: name, einheit: einheit, menge: menge,
                               vonOrt: o, nachOrt: ziel, notiz: notiz)
            }
        case .inventur:
            lager.inventur(artikelCode: code, name: name, einheit: einheit, gezaehlt: menge, lagerortID: o, notiz: notiz)
        case .korrektur:
            lager.eingang(artikelCode: code, name: name, einheit: einheit, menge: menge, lagerortID: o, notiz: notiz)
        }
    }
}
