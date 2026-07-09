import SwiftUI
import CoreData

/// „Die eine Tür": alle Unterlagen auf einmal reingeworfen. Mops sortiert (Vorschlag,
/// pro Datei korrigierbar), dann läuft alles automatisch in den richtigen Auswerter —
/// Statik → LV-Mengen (extract-plan + Deckel/Dedup), Unterlagen → Fakten (extract-doc),
/// Rest wird nur abgelegt. Der Mensch nickt die Sortierung ab, nicht jede Zeile.
struct TuerSortierView: View {
    let event: Event
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    struct Eintrag: Identifiable {
        let id = UUID()
        let url: URL
        var ziel: SortierZiel
        var dateiname: String { url.lastPathComponent }
    }

    enum Phase { case sortieren, laeuft, fertig }

    @State private var eintraege: [Eintrag]
    @State private var phase: Phase = .sortieren
    @State private var fortschritt = ""
    @State private var lvAnzahl = 0
    @State private var faktenAnzahl = 0
    @State private var abgelegtAnzahl = 0
    @State private var fehler: [String] = []

    init(event: Event, urls: [URL]) {
        self.event = event
        _eintraege = State(initialValue: urls.map {
            Eintrag(url: $0, ziel: DateiSortierer.sortiere($0.lastPathComponent))
        })
    }

    private var zuVerarbeiten: Int { eintraege.filter { $0.ziel != .ablegen }.count }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .sortieren: sortierListe
                case .laeuft:    laeuftAnsicht
                case .fertig:    fertigAnsicht
                }
            }
            .navigationTitle("Unterlagen reinwerfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarInhalt }
        }
        .interactiveDismissDisabled(phase == .laeuft)
    }

    // MARK: Sortier-Ansicht

    private var sortierListe: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "wand.and.stars").foregroundStyle(.orange)
                    Text("Mops hat vorsortiert. Stimmt der Korb nicht, tipp rechts auf das Pfeil-Symbol und schieb die Datei um. Der Korb Nur-ablegen wird nicht ausgelesen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(SortierZiel.allCases, id: \.self) { ziel in
                let dazu = eintraege.indices.filter { eintraege[$0].ziel == ziel }
                if !dazu.isEmpty {
                    Section {
                        ForEach(dazu, id: \.self) { i in
                            eintragRow($eintraege[i])
                        }
                    } header: {
                        Label("\(ziel.titel) · \(dazu.count)", systemImage: ziel.symbol)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func eintragRow(_ e: Binding<Eintrag>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
            Text(e.wrappedValue.dateiname)
                .font(.subheadline).lineLimit(1).truncationMode(.middle)
            Spacer()
            Menu {
                ForEach(SortierZiel.allCases, id: \.self) { ziel in
                    Button {
                        e.wrappedValue.ziel = ziel
                    } label: {
                        if ziel == e.wrappedValue.ziel {
                            Label(ziel.titel, systemImage: "checkmark")
                        } else {
                            Text(ziel.titel)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.borderless)
        }
    }

    // MARK: Läuft

    private var laeuftAnsicht: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Mops arbeitet …").font(.headline)
            Text(fortschritt).font(.caption).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Die Box rechnet der Reihe nach — das kann bei vielen Plänen dauern.")
                .font(.caption2).foregroundStyle(.tertiary).multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Fertig

    private var fertigAnsicht: some View {
        List {
            Section {
                bilanzZeile("LV-Positionen aus Statik", lvAnzahl, "ruler", .green)
                bilanzZeile("Unterlagen als Fakten gespeichert", faktenAnzahl, "doc.text.magnifyingglass", .green)
                bilanzZeile("Nur abgelegt", abgelegtAnzahl, "tray", .secondary)
            } header: {
                Label("Fertig", systemImage: "checkmark.seal.fill")
            }
            if !fehler.isEmpty {
                Section("Übersprungen (\(fehler.count))") {
                    ForEach(fehler, id: \.self) { f in
                        Text(f).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text("Prüf im LV und in der Abdeckungs-Sicht, ob alles stimmt — Mops hat vorgearbeitet, das letzte Wort hast du.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func bilanzZeile(_ titel: String, _ n: Int, _ symbol: String, _ farbe: Color) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(farbe)
            Text(titel)
            Spacer()
            Text("\(n)").font(.headline.monospacedDigit()).foregroundStyle(farbe)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarInhalt: some ToolbarContent {
        switch phase {
        case .sortieren:
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Loslegen (\(zuVerarbeiten))") { losLegen() }
                    .tint(.orange)
                    .disabled(zuVerarbeiten == 0)
            }
        case .laeuft:
            ToolbarItem(placement: .principal) { EmptyView() }
        case .fertig:
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }.tint(.orange)
            }
        }
    }

    // MARK: - Ablauf

    private func fehlerText(_ error: Error) -> String {
        (error as? MopsClientError)?.errorDescription ?? error.localizedDescription
    }

    private func losLegen() {
        let statik = eintraege.filter { $0.ziel == .statik }
        let fakten = eintraege.filter { $0.ziel == .fakten }
        let abgelegt = eintraege.filter { $0.ziel == .ablegen }.count
        let gesamt = statik.count + fakten.count
        phase = .laeuft
        let client = MopsClient()

        Task {
            var lv = 0
            var faktenResults: [ExtractDocResult] = []
            var fehlerListe: [String] = []
            var i = 0

            // 1) Statik → LV-Mengen
            for e in statik {
                i += 1
                await MainActor.run { fortschritt = "Statik \(i)/\(gesamt) · \(e.dateiname)" }
                do {
                    let data = try Data(contentsOf: e.url)
                    let res = try await client.extractPlan(pdf: data, filename: e.dateiname)
                    await MainActor.run {
                        let neu = ExtractPlanMapper.mapPositions(res, into: viewContext, event: event)
                        for p in neu {
                            p.setValue(e.dateiname, forKey: "dokuName")
                            p.setValue(e.url.absoluteString, forKey: "dokuPath")
                            for kind in p.unterPositionenArray {   // Belege erben die Quelle
                                kind.setValue(e.dateiname, forKey: "dokuName")
                                kind.setValue(e.url.absoluteString, forKey: "dokuPath")
                            }
                        }
                        lv += neu.count
                    }
                } catch {
                    fehlerListe.append("\(e.dateiname): \(fehlerText(error))")
                }
            }

            // 2) Unterlagen → Fakten
            for e in fakten {
                i += 1
                await MainActor.run { fortschritt = "Unterlage \(i)/\(gesamt) · \(e.dateiname)" }
                do {
                    let data = try Data(contentsOf: e.url)
                    let res = try await client.extractDoc(pdf: data, filename: e.dateiname)
                    faktenResults.append(res)
                } catch {
                    fehlerListe.append("\(e.dateiname): \(fehlerText(error))")
                }
            }

            await MainActor.run {
                if !faktenResults.isEmpty {
                    var extras = EventExtrasPayload.laden(aus: event)
                    extras.mergeAuswertungen(faktenResults, am: Date())
                    extras.speichern(in: event)
                }
                try? viewContext.save()
                lvAnzahl = lv
                faktenAnzahl = faktenResults.count
                abgelegtAnzahl = abgelegt
                fehler = fehlerListe
                phase = .fertig
            }
        }
    }
}
