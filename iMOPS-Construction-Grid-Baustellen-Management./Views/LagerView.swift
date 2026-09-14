//
//  LagerView.swift
//  Das Lager: Bestand (Summe der Buchungen), Nachbestellen (unter Meldebestand),
//  Lagerorte verwalten. Buchen über das LagerBuchungSheet.
//

import SwiftUI

struct LagerView: View {
    @ObservedObject private var lager = LagerStore.shared

    private enum Segment: String, CaseIterable { case bestand = "Bestand", nachbestellen = "Nachbestellen", orte = "Lagerorte" }
    @State private var segment: Segment = .bestand

    @State private var showingBuchung = false
    @State private var neuerOrtName = ""
    @State private var zeigeNeuerOrt = false
    // Meldebestand setzen (per Artikel).
    @State private var meldeCode: String?
    @State private var meldeName = ""
    @State private var meldeText = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $segment) {
                ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                switch segment {
                case .bestand:       bestandSektion
                case .nachbestellen: nachbestellenSektion
                case .orte:          orteSektion
                }
            }
        }
        .navigationTitle("Lager")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingBuchung = true } label: { Label("Buchen", systemImage: "plus.circle.fill") }
                    .disabled(lager.lagerorte.isEmpty)
            }
        }
        .sheet(isPresented: $showingBuchung) { LagerBuchungSheet() }
        .alert("Neuer Lagerort", isPresented: $zeigeNeuerOrt) {
            TextField("Name (z. B. Hof, Halle, Container)", text: $neuerOrtName)
            Button("Anlegen") {
                let n = neuerOrtName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { lager.addLagerort(name: n) }
                neuerOrtName = ""
            }
            Button("Abbrechen", role: .cancel) { neuerOrtName = "" }
        }
        .alert("Meldebestand — \(meldeName)", isPresented: Binding(get: { meldeCode != nil }, set: { if !$0 { meldeCode = nil } })) {
            TextField("Menge (0 = kein Meldebestand)", text: $meldeText).keyboardType(.decimalPad)
            Button("Speichern") {
                if let code = meldeCode {
                    let wert = Double(meldeText.replacingOccurrences(of: ",", with: ".")) ?? 0
                    lager.setMindestbestand(artikelCode: code, schwelle: wert)
                }
                meldeCode = nil
            }
            Button("Abbrechen", role: .cancel) { meldeCode = nil }
        } message: {
            Text("Unter diesem Bestand meldet das Lager „nachbestellen“.")
        }
    }

    // MARK: - Bestand

    @ViewBuilder private var bestandSektion: some View {
        let artikel = lager.artikelImLager()
        if artikel.isEmpty {
            ContentUnavailableView("Noch nichts im Lager", systemImage: "shippingbox",
                                   description: Text("Über „Buchen“ einen Wareneingang erfassen."))
        } else {
            ForEach(artikel, id: \.code) { a in
                let gesamt = lager.gesamtbestand(artikelCode: a.code)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(a.name).font(.body)
                        Spacer()
                        Text(gesamt.formatted(.number.precision(.fractionLength(0...2))) + " " + a.einheit)
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(gesamt > 0 ? .primary : .secondary)
                    }
                    let jeOrt = lager.bestandJeOrt(artikelCode: a.code)
                    if jeOrt.count > 1 || (jeOrt.first?.ort.name.isEmpty == false) {
                        Text(jeOrt.map { "\($0.ort.name): \($0.menge.formatted(.number.precision(.fractionLength(0...2))))" }
                            .joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let schwelle = lager.mindestbestaende[a.code], schwelle > 0 {
                        Text("Meldebestand \(schwelle.formatted(.number.precision(.fractionLength(0...2)))) \(a.einheit)")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing) {
                    Button("Meldebestand") {
                        meldeCode = a.code; meldeName = a.name
                        meldeText = (lager.mindestbestaende[a.code].map { String($0) }) ?? ""
                    }.tint(.blue)
                }
            }
        }
    }

    // MARK: - Nachbestellen

    @ViewBuilder private var nachbestellenSektion: some View {
        let unter = lager.unterMindestbestand()
        if unter.isEmpty {
            ContentUnavailableView("Alles im grünen Bereich", systemImage: "checkmark.circle",
                                   description: Text("Kein Artikel unter seinem Meldebestand. Meldebestand setzt du im Reiter „Bestand“ (nach links wischen)."))
        } else {
            ForEach(unter, id: \.code) { u in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(u.name).font(.body)
                        Text("Bestand \(u.bestand.formatted(.number.precision(.fractionLength(0...2)))) / Meldebestand \(u.schwelle.formatted(.number.precision(.fractionLength(0...2)))) \(u.einheit)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("nachbestellen", systemImage: "cart.badge.plus")
                        .labelStyle(.iconOnly).foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Lagerorte

    @ViewBuilder private var orteSektion: some View {
        Section {
            if lager.lagerorte.isEmpty {
                Text("Noch kein Lagerort. Lege einen an (Hof, Halle, Container …).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(lager.lagerorte) { o in
                HStack {
                    Image(systemName: "building.2.crop.circle").foregroundStyle(.secondary)
                    Text(o.name)
                    Spacer()
                    let anzahl = lager.artikelImLager().filter { lager.bestand(artikelCode: $0.code, lagerortID: o.id) != 0 }.count
                    if anzahl > 0 { Text("\(anzahl) Artikel").font(.caption).foregroundStyle(.secondary) }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        _ = lager.removeLagerort(o.id)   // greift nur, wenn nie bebucht
                    } label: { Label("Löschen", systemImage: "trash") }
                }
            }
        } footer: {
            Text("Ein Lagerort mit Buchungen bleibt erhalten (die Historie braucht ihn).")
        }
        Section {
            Button { zeigeNeuerOrt = true } label: { Label("Neuen Lagerort anlegen", systemImage: "plus") }
        }
    }
}

#Preview { NavigationStack { LagerView() } }
