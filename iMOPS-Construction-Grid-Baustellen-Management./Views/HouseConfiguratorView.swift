//
//   HouseConfiguratorView.swift
//   iMOPS-Construction-Grid-Baustellen-Management.
//
//   Haus-Konfigurator mit stabiler Ergebnisansicht.
//

import SwiftUI
import CoreData

struct HouseConfiguratorView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var spezielesEvent: Event? = nil
    var onCreated: ((Event) -> Void)? = nil

    @State private var project = HouseProject()
    @State private var result: HouseProjectResult?
    @State private var selectedTab = 0
    @State private var showingSaveConfirmation = false
    @State private var savedSuccessfully = false

    init(spezielesEvent: Event? = nil, onCreated: ((Event) -> Void)? = nil) {
        self.spezielesEvent = spezielesEvent
        self.onCreated = onCreated
    }

    var body: some View {
        Group {
            if let result {
                resultContent(result)
            } else {
                configuratorForm
            }
        }
        .onAppear {
            guard result == nil, let event = spezielesEvent else { return }
            let sourceProject = loadHouseProject(from: event)
            project = sourceProject
            result = HouseProjectGenerator.generate(from: sourceProject)
        }
    }

    private var configuratorForm: some View {
        Form {
            grunddatenSection
            raeumeSection
            technikSection
            ausstattungSection

            Section {
                Button {
                    result = HouseProjectGenerator.generate(from: project)
                } label: {
                    HStack {
                        Spacer()
                        Label("Projekt berechnen & auswerten", systemImage: "chart.bar.doc.horizontal")
                            .font(.headline)
                        Spacer()
                    }
                }
                .listRowBackground(Color(uiColor: .tintColor))
                .foregroundStyle(.white)
            }
        }
        .navigationTitle("Haus-Konfigurator")
    }

    private func resultContent(_ result: HouseProjectResult) -> some View {
        VStack(spacing: 0) {
            resultHeader(result)

            Picker("Ansicht", selection: $selectedTab) {
                Text("Kosten").tag(0)
                Text("Material").tag(1)
                Text("Massen").tag(2)
                Text("Zeitplan").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                switch selectedTab {
                case 0:
                    kostenTab(result)
                case 1:
                    materialTab(result)
                case 2:
                    massenTab(result)
                case 3:
                    BauzeitenplanView(phasen: result.phasen)
                        .padding()
                default:
                    EmptyView()
                }
            }

            if spezielesEvent == nil {
                HStack(spacing: 16) {
                    Button("Anpassen") {
                        self.result = nil
                    }
                    .buttonStyle(.bordered)

                    Button("Als Baustelle anlegen") {
                        showingSaveConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .navigationTitle(result.project.projektName.isEmpty ? "Uebersicht" : result.project.projektName)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Baustelle anlegen?", isPresented: $showingSaveConfirmation) {
            Button("Anlegen") {
                let event = HouseProjectGenerator.createEvent(from: result, into: viewContext)
                do {
                    try viewContext.save()
                    onCreated?(event)
                    savedSuccessfully = true
                } catch {
                    print("HouseConfiguratorView: Konnte Baustelle nicht speichern: \(error)")
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Erstellt eine Baustelle mit Auftraegen, Materialien und Checklisten aus der Konfiguration.")
        }
        .alert("Baustelle angelegt", isPresented: $savedSuccessfully) {
            Button("OK") {}
        } message: {
            Text("Die Baustelle wurde erfolgreich angelegt.")
        }
    }

    private func resultHeader(_ result: HouseProjectResult) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.project.projektName.isEmpty ? result.project.haustyp.rawValue : result.project.projektName)
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
                        .foregroundStyle(.tint)
                    Text("Gesamtkosten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                kpiWithGlossar(label: "Schaetzung", value: result.baukosten.gesamtBaukosten, color: .gray, schluessel: "kostenschaetzung")
                kpiWithGlossar(label: "Anschlag", value: result.gesamtkosten, color: .yellow, schluessel: "kostenanschlag")
                kpiWithGlossar(label: "Feststellung", valueText: "--", color: .green, schluessel: "kostenfeststellung")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func kpiWithGlossar(
        label: String,
        value: Double? = nil,
        valueText: String? = nil,
        color: Color,
        schluessel: String
    ) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text(valueText ?? value.map(formatCurrencyShort) ?? "--")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(color)
                GlossarButton(schluessel: schluessel)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func kostenTab(_ result: HouseProjectResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            cardView(title: "Baukosten", icon: "building.2") {
                VStack(spacing: 6) {
                    ForEach(result.baukosten.positionen, id: \.0) { name, betrag in
                        kostenRow(name, betrag: betrag, anteil: betrag / result.baukosten.gesamtBaukosten)
                    }
                    Divider()
                    HStack {
                        Text("Summe Baukosten")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(formatCurrency(result.baukosten.gesamtBaukosten))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            }

            cardView(title: "Baunebenkosten", icon: "doc.text") {
                VStack(spacing: 6) {
                    ForEach(result.baunebenkosten) { nk in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(nk.bezeichnung)
                                    .font(.subheadline)
                                Spacer()
                                Text(formatCurrency(nk.betrag))
                                    .font(.subheadline.monospacedDigit())
                            }
                            if !nk.details.isEmpty {
                                Text(nk.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider().opacity(0.2)
                    }

                    HStack {
                        Text("Summe Nebenkosten")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(formatCurrency(result.baunebenkosten.reduce(0) { $0 + $1.betrag }))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 4)
                }
            }

            HStack {
                Text("Gesamtkosten")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(result.gesamtkosten))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.tint)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding()
    }

    private func materialTab(_ result: HouseProjectResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            let grouped = Dictionary(grouping: result.materialien, by: { $0.gewerk }).sorted { $0.key < $1.key }
            ForEach(grouped, id: \.0) { gewerk, items in
                cardView(title: gewerk, icon: "shippingbox") {
                    VStack(spacing: 8) {
                        ForEach(items) { mat in
                            HStack {
                                Text(mat.titel)
                                Spacer()
                                Text("\(Int(mat.menge)) \(mat.einheit)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func massenTab(_ result: HouseProjectResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            cardView(title: "Massen", icon: "ruler") {
                VStack(spacing: 8) {
                    ForEach(result.massen) { pos in
                        HStack {
                            Text(pos.bezeichnung)
                            Spacer()
                            Text("\(Int(pos.menge)) \(pos.einheit)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding()
    }

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

    private func kostenRow(_ name: String, betrag: Double, anteil: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text(formatCurrency(betrag))
                    .font(.subheadline.monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .tintColor).opacity(0.7))
                        .frame(width: geo.size.width * min(max(anteil, 0), 1), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

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
                Text("m\u{00B2}")
                    .foregroundStyle(.secondary)
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

    private var raeumeSection: some View {
        Section(header: Label("Raeume", systemImage: "door.left.hand.open")) {
            Stepper("Zimmer: \(project.anzahlZimmer)", value: $project.anzahlZimmer, in: 1...12)
            Stepper("Baeder: \(project.anzahlBaeder)", value: $project.anzahlBaeder, in: 1...5)
            Stepper("Gaeste-WC: \(project.anzahlGaesteWC)", value: $project.anzahlGaesteWC, in: 0...3)
            Toggle("Kueche", isOn: $project.kueche)
            Toggle("Garage", isOn: $project.garage)
        }
    }

    private var technikSection: some View {
        Section(header: Label("Technik", systemImage: "bolt.fill")) {
            Toggle("Fussbodenheizung", isOn: $project.fussbodenheizung)
            Toggle("Waermepumpe", isOn: $project.waermepumpe)
            Toggle("Solaranlage (PV)", isOn: $project.solaranlage)
            Toggle("SmartHome", isOn: $project.smartHome)
        }
    }

    private var ausstattungSection: some View {
        Section(header: Label("Ausstattung", systemImage: "star")) {
            Picker("Niveau", selection: $project.ausstattung) {
                ForEach(Ausstattungsniveau.allCases) { a in
                    HStack {
                        Text(a.rawValue)
                        Text("(\(Int(a.kostenProQm)) EUR/m\u{00B2})")
                            .font(.caption)
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
                    .foregroundStyle(.tint)
            }
        }
    }

    private func loadHouseProject(from event: Event) -> HouseProject {
        guard
            let extras = event.extras,
            let data = extras.data(using: .utf8),
            let payload = try? JSONDecoder().decode(EventExtrasPayload.self, from: data),
            let houseProject = payload.houseProject
        else {
            return HouseProject(
                projektName: event.title ?? "Baustelle",
                wohnflaeche: 140,
                geschosse: 2
            )
        }

        return houseProject
    }

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
        } else if value >= 1_000 {
            return String(format: "%.0f T\u{20AC}", value / 1_000)
        }
        return formatCurrency(value)
    }
}

struct HouseProjectResultView: View {
    let result: HouseProjectResult
    var allowsCreateEvent: Bool = true
    var onCreated: ((Event) -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var showingSaveConfirmation = false
    @State private var savedSuccessfully = false

    var body: some View {
        VStack(spacing: 0) {
            resultHeader

            Picker("Ansicht", selection: $selectedTab) {
                Text("Kosten").tag(0)
                Text("Material").tag(1)
                Text("Massen").tag(2)
                Text("Zeitplan").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                switch selectedTab {
                case 0:
                    kostenTab
                case 1:
                    materialTab
                case 2:
                    massenTab
                case 3:
                    BauzeitenplanView(phasen: result.phasen)
                        .padding()
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle("Projektergebnis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schliessen") {
                    dismiss()
                }
            }
            if allowsCreateEvent {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingSaveConfirmation = true
                    } label: {
                        Label("Als Baustelle anlegen", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .alert("Baustelle anlegen?", isPresented: $showingSaveConfirmation) {
            Button("Anlegen") {
                let event = HouseProjectGenerator.createEvent(from: result, into: viewContext)
                do {
                    try viewContext.save()
                    onCreated?(event)
                    savedSuccessfully = true
                } catch {
                    print("HouseProjectResultView: Konnte Baustelle nicht speichern: \(error)")
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Erstellt eine Baustelle mit allen Auftraegen, Materialien und Checklisten aus der Konfiguration.")
        }
        .alert("Baustelle angelegt", isPresented: $savedSuccessfully) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Die Baustelle wurde erfolgreich angelegt. Du findest sie unter 'Baustellen'.")
        }
    }

    private var resultHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.project.projektName.isEmpty ? result.project.haustyp.rawValue : result.project.projektName)
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
                        .foregroundStyle(.tint)
                    Text("Gesamtkosten")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                miniKPI(label: "Baukosten", value: result.baukosten.gesamtBaukosten)
                miniKPI(label: "Nebenkosten", value: result.baunebenkosten.reduce(0) { $0 + $1.betrag })
                miniKPI(label: "EUR/m\u{00B2}", value: result.gesamtkosten / result.project.wohnflaeche)
                let totalWeeks = result.phasen.map { $0.endeWoche }.max() ?? 0
                VStack(spacing: 2) {
                    Text("\(totalWeeks) Wo.")
                        .font(.subheadline.bold().monospacedDigit())
                    Text("Bauzeit")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func miniKPI(label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(formatCurrencyShort(value))
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var kostenTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardView(title: "Baukosten", icon: "building.2") {
                VStack(spacing: 6) {
                    ForEach(result.baukosten.positionen, id: \.0) { name, betrag in
                        kostenRow(name, betrag: betrag, anteil: betrag / result.baukosten.gesamtBaukosten)
                    }
                    Divider()
                    HStack {
                        Text("Summe Baukosten")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(formatCurrency(result.baukosten.gesamtBaukosten))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            }

            cardView(title: "Baunebenkosten", icon: "doc.text") {
                VStack(spacing: 6) {
                    ForEach(result.baunebenkosten) { nk in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(nk.bezeichnung)
                                    .font(.subheadline)
                                Spacer()
                                Text(formatCurrency(nk.betrag))
                                    .font(.subheadline.monospacedDigit())
                            }
                            if !nk.details.isEmpty {
                                Text(nk.details)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider().opacity(0.2)
                    }
                    HStack {
                        Text("Summe Nebenkosten")
                            .font(.subheadline.bold())
                        Spacer()
                        Text(formatCurrency(result.baunebenkosten.reduce(0) { $0 + $1.betrag }))
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            }
        }
        .padding()
    }

    private var materialTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            let grouped = Dictionary(grouping: result.materialien, by: { $0.gewerk }).sorted { $0.key < $1.key }
            ForEach(grouped, id: \.0) { gewerk, items in
                cardView(title: gewerk, icon: "shippingbox") {
                    VStack(spacing: 8) {
                        ForEach(items) { mat in
                            HStack {
                                Text(mat.titel)
                                Spacer()
                                Text("\(Int(mat.menge)) \(mat.einheit)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var massenTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardView(title: "Massen", icon: "ruler") {
                VStack(spacing: 8) {
                    ForEach(result.massen) { pos in
                        HStack {
                            Text(pos.bezeichnung)
                            Spacer()
                            Text("\(Int(pos.menge)) \(pos.einheit)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding()
    }

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

    private func kostenRow(_ name: String, betrag: Double, anteil: Double) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                Spacer()
                Text(formatCurrency(betrag))
                    .font(.subheadline.monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(uiColor: .tintColor).opacity(0.7))
                        .frame(width: geo.size.width * min(max(anteil, 0), 1), height: 6)
                }
            }
            .frame(height: 6)
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

    private func formatCurrencyShort(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1f Mio", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.0f T\u{20AC}", value / 1_000)
        }
        return formatCurrency(value)
    }
}
