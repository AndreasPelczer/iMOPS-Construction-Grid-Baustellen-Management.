//
//   HouseConfiguratorView.swift
//   iMOPS-Construction-Grid-Baustellen-Management.
//
//   Haus-Konfigurator: Dynamische Weiche mit stabilem State-Speicher.
//

import SwiftUI
import CoreData

struct HouseConfiguratorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 🛰️ Der Eingang von der EventDetailView
    var spezielesEvent: Event? = nil
    
    @State private var project = HouseProject()
    @State private var result: HouseProjectResult? = nil // Hier frieren wir das Ergebnis ein!
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            if let currentResult = result {
                // =========================================================
                // ZUSTAND B: FESTE ÜBERSICHT (DEIN ORIGINALES SHEET-DESIGN)
                // =========================================================
                VStack(spacing: 0) {
                    
                    // Kosten-Header aus deinem Original-Layout
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentResult.project.projektName.isEmpty
                                     ? currentResult.project.haustyp.rawValue
                                     : currentResult.project.projektName)
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Label("\(Int(currentResult.project.wohnflaeche)) m\u{00B2}", systemImage: "ruler")
                                    Label("\(currentResult.project.geschosse) Geschoss(e)", systemImage: "building.2")
                                    Label(currentResult.project.ausstattung.rawValue, systemImage: "star")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatCurrency(currentResult.gesamtkosten))
                                    .font(.title2.bold().monospacedDigit())
                                    .foregroundStyle(.tint)
                                Text("Gesamtkosten").font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        // iMOPS KPIs mit den Glossar-Fragezeichen
                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                HStack(spacing: 3) {
                                    Text(formatCurrencyShort(currentResult.baukosten.gesamtBaukosten))
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(.gray).italic()
                                    GlossarButton(schluessel: "kostenschaetzung")
                                }
                                Text("Schätzung").font(.caption2).foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 2) {
                                HStack(spacing: 3) {
                                    Text(formatCurrencyShort(currentResult.gesamtkosten))
                                        .font(.subheadline.bold().monospacedDigit())
                                        .foregroundStyle(.yellow)
                                    GlossarButton(schluessel: "kostenanschlag")
                                }
                                Text("Anschlag").font(.caption2).foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 2) {
                                HStack(spacing: 3) {
                                    Text("--").font(.subheadline.bold().monospacedDigit()).foregroundStyle(.green)
                                    GlossarButton(schluessel: "kostenfeststellung")
                                }
                                Text("Feststellung").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    
                    // Umschalter (Dein vertrautes 4er-Gespann)
                    Picker("Ansicht", selection: $selectedTab) {
                        Text("Kosten").tag(0)
                        Text("Material").tag(1)
                        Text("Massen").tag(2)
                        Text("Zeitplan").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Die originalen Reiter-Inhalte
                    ScrollView {
                        switch selectedTab {
                        case 0:
                                                    // =========================================================
                                                    // ORIGINAL KOSTEN-TAB (Inklusive aller Baunebenkosten!)
                                                    // =========================================================
                                                    VStack(alignment: .leading, spacing: 16) {
                                                        
                                                        // 1. Hauptgruppe: Baukosten
                                                        cardView(title: "Baukosten", icon: "building.2") {
                                                            VStack(spacing: 6) {
                                                                ForEach(currentResult.baukosten.positionen, id: \.0) { name, betrag in
                                                                    kostenRow(name, betrag: betrag, anteil: betrag / currentResult.baukosten.gesamtBaukosten)
                                                                }
                                                                Divider()
                                                                HStack {
                                                                    Text("Summe Baukosten").font(.subheadline.bold())
                                                                    Spacer()
                                                                    Text(formatCurrency(currentResult.baukosten.gesamtBaukosten))
                                                                        .font(.subheadline.bold().monospacedDigit())
                                                                }
                                                            }
                                                        }
                                                        
                                                        // 2. Hauptgruppe: Baunebenkosten (Das vermisste Ding!)
                                                        cardView(title: "Baunebenkosten (Architekt, Vermesser, Gebühren)", icon: "doc.text") {
                                                            VStack(spacing: 6) {
                                                                ForEach(currentResult.baunebenkosten) { nk in
                                                                    VStack(alignment: .leading, spacing: 2) {
                                                                        HStack {
                                                                            Text(nk.bezeichnung).font(.subheadline)
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
                                                                    Text("Summe Nebenkosten").font(.subheadline.bold())
                                                                    Spacer()
                                                                    Text(formatCurrency(currentResult.baunebenkosten.reduce(0) { $0 + $1.betrag }))
                                                                        .font(.subheadline.bold().monospacedDigit())
                                                                        .foregroundStyle(.orange)
                                                                }
                                                                .padding(.top, 4)
                                                            }
                                                        }
                                                    }
                                                    .padding()
                            
                        case 1:
                            VStack(alignment: .leading, spacing: 16) {
                                let grouped = Dictionary(grouping: currentResult.materialien, by: { $0.gewerk }).sorted { $0.key < $1.key }
                                ForEach(grouped, id: \.0) { gewerk, items in
                                    cardView(title: gewerk, icon: "shippingbox") {
                                        ForEach(items) { mat in
                                            HStack {
                                                Text(mat.titel)
                                                Spacer()
                                                Text("\(Int(mat.menge)) \(mat.einheit)")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            
                        case 2:
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(currentResult.massen) { pos in
                                    HStack {
                                        Text(pos.bezeichnung)
                                        Spacer()
                                        Text("\(Int(pos.menge)) \(pos.einheit)")
                                    }
                                }
                            }
                            .padding()
                            
                        case 3:
                            // 🚀 DEIN GRAFISCHER ZEITSTRAHLKALENDER
                            BauzeitenplanView(phasen: currentResult.phasen)
                                .padding()
                            
                        default:
                            EmptyView()
                        }
                    }
                    
                    // Knöpfe unten blenden wir NUR ein, wenn wir im Hauptmenü neu planen
                    if spezielesEvent == nil {
                        HStack(spacing: 16) {
                            Button("Anpassen") { result = nil }
                                .buttonStyle(.bordered)
                            Button("Als Baustelle anlegen") {
                                _ = HouseProjectGenerator.createEvent(from: currentResult, into: viewContext)
                                try? viewContext.save()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                }
                .navigationTitle(currentResult.project.projektName.isEmpty ? "Übersicht" : currentResult.project.projektName)
                
            } else {
                // =========================================================
                // ZUSTAND A: HAUS-KONFIGURATOR (LEERE MASKE FÜR NEUPLANUNG)
                // =========================================================
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
        }
        // 🛰️ DER SICHERHEITS-ANKER: Beim Öffnen laden wir die Daten EINMALIG in den State!
        .onAppear {
            if let event = spezielesEvent {
                let rekonstruiertesProjekt = HouseProject(
                    projektName: event.title ?? "Baustelle",
                    wohnflaeche: 140, // Nimmt deine Baseline
                    geschosse: 2
                )
                self.result = HouseProjectGenerator.generate(from: rekonstruiertesProjekt)
            }
        }
    }
    
    // =========================================================
    // HIER DEINE ORIGINALEN HILFSFUNKTIONEN (Unverändert!)
    // =========================================================
    private func cardView<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            content()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    RoundedRectangle(cornerRadius: 3).fill(Color(uiColor: .tintColor).opacity(0.7))
                        .frame(width: geo.size.width * anteil, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var grunddatenSection: some View {
        Section(header: Label("Grunddaten", systemImage: "house")) {
            TextField("Projektname", text: $project.projektName)
            Picker("Haustyp", selection: $project.haustyp) {
                ForEach(Haustyp.allCases) { typ in Text(typ.rawValue).tag(typ) }
            }
            HStack {
                Text("Wohnflaeche")
                Spacer()
                TextField("m\u{00B2}", value: $project.wohnflaeche, format: .number)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                Text("m\u{00B2}").foregroundStyle(.secondary)
            }
            Stepper("Geschosse: \(project.geschosse)", value: $project.geschosse, in: 1...4)
            Picker("Dachform", selection: $project.dachform) {
                ForEach(Dachform.allCases) { d in Text(d.rawValue).tag(d) }
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
                            .font(.caption).foregroundStyle(.secondary)
                    }.tag(a)
                }
            }.pickerStyle(.segmented)
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
        if value >= 1_000_000 { return String(format: "%.1f Mio", value / 1_000_000) }
        else if value >= 1000 { return String(format: "%.0f T\u{20AC}", value / 1000) }
        return formatCurrency(value)
    }
}
