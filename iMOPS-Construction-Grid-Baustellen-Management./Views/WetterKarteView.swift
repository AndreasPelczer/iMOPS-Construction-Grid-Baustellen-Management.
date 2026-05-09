import SwiftUI

// MARK: - WetterKarteView
// Kompakte Wetterkarte für EventDetailView.
// Zeigt aktuelles Wetter + Bau-relevante Warnungen für den Standort der Baustelle.

struct WetterKarteView: View {
    let ort: String

    @State private var wetter: BaustellenWetter?
    @State private var warnungen: [BauWarnung] = []
    @State private var ladeZustand: LadeZustand = .idle
    @State private var zeigeDetails = false

    enum LadeZustand {
        case idle, laden, fertig, fehler(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Wetter", systemImage: "cloud.sun.fill")
                    .font(.headline)
                Spacer()
                if case .laden = ladeZustand {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button {
                        Task { await ladeWetter() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }

            // Inhalt
            switch ladeZustand {
            case .idle:
                EmptyView()

            case .laden:
                HStack {
                    ProgressView()
                    Text("Wetter wird geladen…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

            case .fehler(let msg):
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.caption).foregroundStyle(.secondary)
                }

            case .fertig:
                if let w = wetter {
                    wetterInhalt(w)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task { await ladeWetter() }
        .sheet(isPresented: $zeigeDetails) {
            if let w = wetter {
                WetterDetailSheet(wetter: w, warnungen: warnungen)
            }
        }
    }

    // MARK: - Wetter-Inhalt

    @ViewBuilder
    private func wetterInhalt(_ w: BaustellenWetter) -> some View {
        // Ampel + Kurzinfo
        HStack(spacing: 14) {
            // Ampelkreis
            Circle()
                .fill(BauWetterRegeln.ampelFarbe(fuer: w))
                .frame(width: 12, height: 12)

            // Symbol + Temperatur
            Image(systemName: w.icon)
                .font(.title2)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(w.beschreibung)
                    .font(.subheadline.weight(.medium))
                Text("\(w.temperaturText)  💨 \(w.windText)  💧 \(w.luftfeuchtigkeit)%")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                zeigeDetails = true
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        // Warnungen (max. 2 kompakt)
        if !warnungen.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(warnungen.prefix(2)) { warnung in
                    HStack(spacing: 6) {
                        Image(systemName: warnung.stufe.symbol)
                            .foregroundStyle(warnung.stufe.farbe)
                            .font(.caption)
                        Text(warnung.titel)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(warnung.stufe.farbe)
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(warnung.stufe.farbe.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if warnungen.count > 2 {
                    Text("+\(warnungen.count - 2) weitere Hinweise")
                        .font(.caption2).foregroundStyle(.secondary)
                        .onTapGesture { zeigeDetails = true }
                }
            }
        }

        // Indoor-Empfehlung
        if let empfehlung = BauWetterRegeln.indoorEmpfehlung(fuer: w) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.blue)
                Text(empfehlung.grund)
                    .font(.caption).foregroundStyle(.blue)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Laden

    private func ladeWetter() async {
        guard !ort.isEmpty else {
            ladeZustand = .fehler("Kein Standort für diese Baustelle hinterlegt")
            return
        }
        ladeZustand = .laden
        do {
            let w = try await WetterService.shared.wetterFuer(ort: ort)
            wetter = w
            warnungen = BauWetterRegeln.warnungen(fuer: w)
            ladeZustand = .fertig
        } catch {
            ladeZustand = .fehler(error.localizedDescription)
        }
    }
}

// MARK: - Detail-Sheet mit allen Warnungen

struct WetterDetailSheet: View {
    let wetter: BaustellenWetter
    let warnungen: [BauWarnung]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Übersicht
                Section("Aktuell in \(wetter.ort)") {
                    HStack {
                        Image(systemName: wetter.icon).font(.title).frame(width: 44)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wetter.beschreibung).font(.headline)
                            Text("Temperatur: \(wetter.temperaturText) (gefühlt \(String(format: "%.0f°C", wetter.gefuehlteTemp)))")
                            Text("Wind: \(wetter.windText)")
                            Text("Niederschlag: \(String(format: "%.1f mm/h", wetter.niederschlag1h))")
                            Text("Luftfeuchtigkeit: \(wetter.luftfeuchtigkeit)%")
                        }
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Warnungen
                if !warnungen.isEmpty {
                    Section("Baustellen-Warnungen") {
                        ForEach(warnungen) { warnung in
                            VStack(alignment: .leading, spacing: 6) {
                                Label(warnung.titel, systemImage: warnung.stufe.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(warnung.stufe.farbe)
                                Text(warnung.detail)
                                    .font(.caption).foregroundStyle(.secondary)
                                if !warnung.betroffeneKGs.isEmpty {
                                    HStack(spacing: 4) {
                                        Text("Betrifft:")
                                            .font(.caption2).foregroundStyle(.secondary)
                                        ForEach(warnung.betroffeneKGs, id: \.self) { kg in
                                            Text("KG \(kg)")
                                                .font(.caption2)
                                                .padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(warnung.stufe.farbe.opacity(0.12))
                                                .foregroundStyle(warnung.stufe.farbe)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    Section {
                        Label("Keine Einschränkungen — alle Arbeiten möglich", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                // Indoor-Empfehlung
                if let empfehlung = BauWetterRegeln.indoorEmpfehlung(fuer: wetter) {
                    Section("Empfehlung") {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(empfehlung.gewerk, systemImage: "house.fill")
                                .font(.subheadline.weight(.semibold))
                            Text(empfehlung.grund)
                                .font(.caption).foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Text("Indoor-KGs:")
                                    .font(.caption2).foregroundStyle(.secondary)
                                ForEach(empfehlung.bevorzugteKGs.prefix(6), id: \.self) { kg in
                                    Text("KG \(kg)")
                                        .font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.10))
                                        .foregroundStyle(.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Text("Letzte Aktualisierung: \(wetter.zeitpunkt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Wetterbericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
