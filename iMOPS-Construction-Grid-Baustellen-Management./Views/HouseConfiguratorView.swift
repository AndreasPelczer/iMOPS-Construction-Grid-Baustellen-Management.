//
//  HouseConfiguratorView.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Haus-Konfigurator: Eingabeformular + Ergebnis-Ansicht.
//

import SwiftUI
internal import CoreData

// MARK: - Haupt-View: Konfigurator

struct HouseConfiguratorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var project = HouseProject()
    @State private var result: HouseProjectResult?
    @State private var showingResult = false

    var body: some View {
        Form {
            grunddatenSection
            raeumeSection
            technikSection
            ausstattungSection

            Section {
                Button {
                    result = HouseProjectGenerator.generate(from: project)
                    showingResult = true
                } label: {
                    HStack {
                        Spacer()
                        Label("Projekt generieren", systemImage: "wand.and.stars")
                            .font(.headline)
                        Spacer()
                    }
                }
                .listRowBackground(Color.accentColor)
                .foregroundStyle(.white)
            }
        }
        .navigationTitle("Haus-Konfigurator")
        .sheet(isPresented: $showingResult) {
            if let result {
                NavigationStack {
                    HouseProjectResultView(result: result)
                }
            }
        }
    }

    // MARK: - Grunddaten

    private var grunddatenSection: some View {
        Section(header: Label("Grunddaten", systemImage: "house")) {
            TextField("Projektname", text: $project.projektName)

            Picker("Haustyp", selection: $project.haustyp) {
                ForEach(Haustyp.allCases) { typ in
                    Text(typ.rawValue).tag(typ)
                }
            }

            HStack {
                Text("Wohnflaeche")
                Spacer()
                TextField("m\u{00B2}", value: $project.wohnflaeche, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("m\u{00B2}").foregroundStyle(.secondary)
            }

            Stepper("Geschosse: \(project.geschosse)", value: $project.geschosse, in: 1...4)

            Picker("Dachform", selection: $project.dachform) {
                ForEach(Dachform.allCases) { d in
                    Text(d.rawValue).tag(d)
                }
            }

            Toggle("Keller geplant", isOn: $project.kellerGeplant)
        }
    }

    // MARK: - Raeume

    private var raeumeSection: some View {
        Section(header: Label("Raeume", systemImage: "door.left.hand.open")) {
            Stepper("Zimmer: \(project.anzahlZimmer)", value: $project.anzahlZimmer, in: 1...12)
            Stepper("Baeder: \(project.anzahlBaeder)", value: $project.anzahlBaeder, in: 1...5)
            Stepper("Gaeste-WC: \(project.anzahlGaesteWC)", value: $project.anzahlGaesteWC, in: 0...3)
            Toggle("Kueche", isOn: $project.kueche)
            Toggle("Garage", isOn: $project.garage)
        }
    }

    // MARK: - Technik

    private var technikSection: some View {
        Section(header: Label("Technik", systemImage: "bolt.fill")) {
            Toggle("Fussbodenheizung", isOn: $project.fussbodenheizung)
            Toggle("Waermepumpe", isOn: $project.waermepumpe)
            Toggle("Solaranlage (PV)", isOn: $project.solaranlage)
            Toggle("SmartHome", isOn: $project.smartHome)
        }
    }

    // MARK: - Ausstattung

    private var ausstattungSection: some View {
        Section(header: Label("Ausstattung", systemImage: "star")) {
            Picker("Niveau", selection: $project.ausstattung) {
                ForEach(Ausstattungsniveau.allCases) { a in
                    HStack {
                        Text(a.rawValue)
                        Text("(\(Int(a.kostenProQm)) EUR/m\u{00B2})")
                            .foregroundStyle(.secondary)
                    }
                    .tag(a)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Geschaetzte Baukosten")
                Spacer()
                Text(formatCurrency(project.wohnflaeche * project.ausstattung.kostenProQm))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "EUR"
        fmt.locale = Locale(identifier: "de_DE")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "\(Int(value)) EUR"
    }
}

// MARK: - Ergebnis-Ansicht

struct HouseProjectResultView: View {
    let result: HouseProjectResult
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showingSaveConfirmation = false
    @State private var savedSuccessfully = false

    var body: some View {
        VStack(spacing: 0) {
            // Kosten-Header
            kostenHeader

            // Tab-Auswahl
            Picker("Ansicht", selection: $selectedTab) {
                Text("Kosten").tag(0)
                Text("Material").tag(1)
                Text("Massen").tag(2)
                Text("Zeitplan").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Tab-Content
            ScrollView {
                switch selectedTab {
                case 0: kostenTab
                case 1: materialTab
                case 2: massenTab
                case 3: zeitplanTab
                default: EmptyView()
                }
            }
        }
        .navigationTitle("Projektergebnis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schliessen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    showingSaveConfirmation = true
                } label: {
                    Label("Als Baustelle anlegen", systemImage: "square.and.arrow.down")
                }
            }
        }
        .alert("Baustelle anlegen?", isPresented: $showingSaveConfirmation) {
            Button("Anlegen") {
                _ = HouseProjectGenerator.createEvent(from: result, into: viewContext)
                do {
                    try viewContext.save()
                    savedSuccessfully = true
                } catch {
                    print("Fehler: \(error)")
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Erstellt eine Baustelle mit allen Auftraegen, Materialien und Checklisten aus der Konfiguration.")
        }
        .alert("Baustelle angelegt", isPresented: $savedSuccessfully) {
            Button("OK") { dismiss() }
        } message: {
            Text("Die Baustelle wurde erfolgreich angelegt. Du findest sie unter 'Baustellen'.")
        }
    }

    // MARK: - Kosten-Header

    private var kostenHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.project.projektName.isEmpty
                         ? result.project.haustyp.rawValue
                         : result.project.projektName)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Label("\(Int(result.project.wohnflaeche)) m\u{00B2}", systemImage: "ruler")
                        Label("\(result.project.geschosse) Geschoss(e)", systemImage: "building.2")
                        Label(result.project.ausstattung.rawValue, systemImage: "star")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatCurrency(result.gesamtkosten))
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                    Text("Gesamtkosten").font(.caption).foregroundStyle(.secondary)
                }
            }

            // Kurzuebersicht
            HStack(spacing: 16) {
                miniKPI(label: "Baukosten", value: result.baukosten.gesamtBaukosten)
                miniKPI(label: "Nebenkosten", value: result.baunebenkosten.reduce(0) { $0 + $1.betrag })
                miniKPI(label: "EUR/m\u{00B2}", value: result.gesamtkosten / result.project.wohnflaeche, unit: "")
                let totalWeeks = result.phasen.map { $0.endeWoche }.max() ?? 0
                VStack(spacing: 2) {
                    Text("\(totalWeeks) Wo.").font(.subheadline.bold().monospacedDigit())
                    Text("Bauzeit").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func miniKPI(label: String, value: Double, unit: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(formatCurrencyShort(value))
                .font(.subheadline.bold().monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: - Kosten Tab

    private var kostenTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Baukosten
            cardView(title: "Baukosten", icon: "building.2") {
                VStack(spacing: 6) {
                    ForEach(result.baukosten.positionen, id: \.0) { name, betrag in
                        kostenRow(name, betrag: betrag, anteil: betrag / result.baukosten.gesamtBaukosten)
                    }
                    Divider()
                    HStack {
                        Text("Summe Baukosten").font(.subheadline.bold())
                        Spacer()
                        Text(formatCurrency(result.baukosten.gesamtBaukosten))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            }

            // Baunebenkosten
            cardView(title: "Baunebenkosten", icon: "doc.text") {
                VStack(spacing: 6) {
                    ForEach(result.baunebenkosten) { nk in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(nk.bezeichnung).font(.subheadline)
                                Spacer()
                                Text(formatCurrency(nk.betrag))
                                    .font(.subheadline.monospacedDigit())
                            }
                            if !nk.details.isEmpty {
                                Text(nk.details).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    Divider()
                    HStack {
                        Text("Summe Nebenkosten").font(.subheadline.bold())
                        Spacer()
                        Text(formatCurrency(result.baunebenkosten.reduce(0) { $0 + $1.betrag }))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            }

            // Gesamtkosten
            HStack {
                Text("GESAMTKOSTEN").font(.headline)
                Spacer()
                Text(formatCurrency(result.gesamtkosten))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Color.accentColor)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding()
    }

    private func kostenRow(_ name: String, betrag: Double, anteil: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name).font(.subheadline)
                Spacer()
                Text(formatCurrency(betrag)).font(.subheadline.monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(0.7))
                        .frame(width: geo.size.width * anteil, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Material Tab

    private var materialTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            let grouped = Dictionary(grouping: result.materialien, by: { $0.gewerk })
                .sorted { $0.key < $1.key }

            ForEach(grouped, id: \.0) { gewerk, items in
                cardView(title: gewerk, icon: iconForGewerk(gewerk)) {
                    VStack(spacing: 8) {
                        ForEach(items) { mat in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mat.titel).font(.subheadline)
                                    if !mat.notiz.isEmpty {
                                        Text(mat.notiz).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(formatMenge(mat.menge)) \(mat.einheit)")
                                        .font(.subheadline.monospacedDigit())
                                    Text(formatCurrency(mat.einzelpreis * mat.menge))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }

                        // Gewerk-Summe
                        let gewerkSumme = items.reduce(0) { $0 + $1.einzelpreis * $1.menge }
                        HStack {
                            Text("Materialsumme").font(.caption.bold()).foregroundStyle(.secondary)
                            Spacer()
                            Text(formatCurrency(gewerkSumme)).font(.caption.bold().monospacedDigit())
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Massen Tab

    private var massenTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            let grouped = Dictionary(grouping: result.massen, by: { $0.gewerk })
                .sorted { $0.key < $1.key }

            ForEach(grouped, id: \.0) { gewerk, items in
                cardView(title: gewerk, icon: iconForGewerk(gewerk)) {
                    VStack(spacing: 6) {
                        ForEach(items) { pos in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pos.bezeichnung).font(.subheadline)
                                    if !pos.details.isEmpty {
                                        Text(pos.details).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(formatMenge(pos.menge)) \(pos.einheit)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Zeitplan Tab

    private var zeitplanTab: some View {
        BauzeitenplanView(phasen: result.phasen)
            .padding()
    }

    // MARK: - Card Helper

    private func cardView<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Formatter

    private func formatCurrency(_ value: Double) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = "EUR"
        fmt.locale = Locale(identifier: "de_DE")
        fmt.maximumFractionDigits = 0
        return fmt.string(from: NSNumber(value: value)) ?? "\(Int(value)) EUR"
    }

    private func formatCurrencyShort(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1f Mio", value / 1_000_000)
        } else if value >= 1000 {
            return String(format: "%.0f T\u{20AC}", value / 1000)
        }
        return formatCurrency(value)
    }

    private func formatMenge(_ value: Double) -> String {
        if value == floor(value) { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    private func iconForGewerk(_ gewerk: String) -> String {
        switch gewerk {
        case "Rohbau":            return "building.2"
        case "Erdarbeiten":       return "mountain.2"
        case "Dach":              return "house.lodge"
        case "Fenster & Tueren":  return "door.left.hand.open"
        case "Elektro":           return "bolt.fill"
        case "Sanitaer":          return "drop.fill"
        case "Heizung":           return "flame"
        case "Trockenbau":        return "square.split.2x2"
        case "Estrich & Boden":   return "square.grid.3x3"
        case "Malerarbeiten":     return "paintbrush.fill"
        case "Aussenanlagen":     return "tree"
        case "Ausbau":            return "wrench.and.screwdriver"
        case "Allgemein":         return "checkmark.seal"
        default:                  return "shippingbox"
        }
    }
}
