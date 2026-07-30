import SwiftUI
import Combine

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @State private var serverURL: String = SKPConversionService.shared.serverURL
    @State private var serverStatus: String = ""
    @State private var isCheckingServer = false
    @State private var wetterApiKey: String = UserDefaults.standard.string(forKey: WetterService.apiKeyUserDefaultsKey) ?? ""

    // Mops-Server-URL (LAN-IP oder Cloudflare-Tunnel)
    @AppStorage(MopsConfig.Keys.baseURL) private var mopsBaseURL: String = MopsConfig.defaultHost
    @State private var mopsServerStatus: String = ""
    @State private var isCheckingMops = false

    // Firmendaten (XRechnung Seller / Bautagesbericht)
    @AppStorage(FirmenSettings.Keys.name)     private var firmaName    = ""
    @AppStorage(FirmenSettings.Keys.strasse)  private var strasse      = ""
    @AppStorage(FirmenSettings.Keys.plz)      private var plz          = ""
    @AppStorage(FirmenSettings.Keys.ort)      private var ort          = ""
    @AppStorage(FirmenSettings.Keys.ustIdNr)  private var ustIdNr      = ""
    @AppStorage(FirmenSettings.Keys.mwstSatz) private var mwstSatz     = 19.0

    // Kalkulations-Zuschläge. Vorgaben identisch zu FirmenSettings — beide lesen
    // denselben Schlüssel, deshalb müssen die Vorgaben übereinstimmen.
    @AppStorage(FirmenSettings.Keys.zuschlagJeKostenart) private var zuschlagJeKostenart = false
    @AppStorage(FirmenSettings.Keys.zuschlagLohn)        private var zuschlagLohn        = 0.20
    @AppStorage(FirmenSettings.Keys.zuschlagMaterial)    private var zuschlagMaterial    = 0.20
    @AppStorage(FirmenSettings.Keys.zuschlagGeraet)      private var zuschlagGeraet      = 0.20
    @AppStorage(FirmenSettings.Keys.bgk)                 private var bgk                 = 0.12
    @AppStorage(FirmenSettings.Keys.wagnisGewinn)        private var wagnisGewinn        = 0.08

    // Benachrichtigungen
    @AppStorage(NotificationService.Keys.fristenEnabled) private var notifsEnabled = true
    @AppStorage(NotificationService.Keys.vorwarnTage)    private var vorwarnTage   = 1

    private let mwstOptionen: [Double] = [19.0, 7.0, 0.0]
    private let vorwarnOptionen: [(label: String, tage: Int)] = [
        ("1 Tag vorher", 1),
        ("2 Tage vorher", 2),
        ("3 Tage vorher", 3),
        ("7 Tage vorher", 7)
    ]

    var body: some View {
        @Bindable var session = session
        Form {

            // --- Firmendaten ---
            Section {
                TextField("Firmenname", text: $firmaName)
                TextField("Straße & Hausnummer", text: $strasse)
                HStack(spacing: 8) {
                    TextField("PLZ", text: $plz)
                        .frame(maxWidth: 80)
                        .keyboardType(.numberPad)
                    TextField("Ort", text: $ort)
                }
                HStack {
                    Text("USt-IdNr.").foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    TextField("DE123456789", text: $ustIdNr)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                HStack {
                    Text("MwSt-Satz").foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    Spacer()
                    Picker("MwSt", selection: $mwstSatz) {
                        ForEach(mwstOptionen, id: \.self) { satz in
                            Text(satz == 0 ? "0 % (steuerfrei)" : "\(Int(satz)) %")
                                .tag(satz)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("Firmendaten")
            } footer: {
                Text("Werden für XRechnung-Export (Rechnungsaussteller) und Bautagesbericht verwendet.")
                    .font(.caption)
            }

            // --- Kalkulations-Zuschläge (Firmenwerte) ---
            Section {
                Toggle(isOn: $zuschlagJeKostenart) {
                    Label("Je Kostenart aufschlagen", systemImage: "square.split.1x2")
                }
                .tint(.orange)

                if zuschlagJeKostenart {
                    satzZeile("Lohn", wert: $zuschlagLohn, farbe: .green, bis: 3.0)
                    satzZeile("Material", wert: $zuschlagMaterial, farbe: .blue, bis: 1.0)
                    satzZeile("Geräte", wert: $zuschlagGeraet, farbe: .purple, bis: 1.0)
                } else {
                    satzZeile("Wagnis & Gewinn", wert: $wagnisGewinn, farbe: .orange, bis: 0.25)
                    satzZeile("BGK", wert: $bgk, farbe: .orange, bis: 0.25)
                }
            } header: {
                Text("Kalkulation — Zuschläge")
            } footer: {
                Text("""
                Gelten für jede LV-Position, die nicht ausdrücklich abweicht. Hier einmal \
                gepflegt statt in jeder Position einzeln. Wer eine einzelne Position anders \
                rechnen will, schaltet dort „Von den Firmenwerten abweichen" ein.

                „Je Kostenart" trennt die Sätze nach Lohn, Material und Gerät — auf dem Bau \
                trägt der Lohn den Löwenanteil (Größenordnung ×2,75), Material und Gerät \
                kaum etwas. Aus ist es ein Satz W&G plus einer BGK auf die Summe.
                """)
                .font(.caption)
            }

            // --- Benachrichtigungen ---
            Section {
                Toggle(isOn: $notifsEnabled) {
                    Label("Fristen-Erinnerungen", systemImage: "bell.badge")
                }
                if notifsEnabled {
                    Picker(selection: $vorwarnTage) {
                        ForEach(vorwarnOptionen, id: \.tage) { opt in
                            Text(opt.label).tag(opt.tage)
                        }
                    } label: {
                        Label("Vorwarnung", systemImage: "clock")
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("Benachrichtigungen")
            } footer: {
                Text(notifsEnabled
                    ? "Benachrichtigungen werden am Frist-Tag und \(vorwarnTage == 1 ? "1 Tag" : "\(vorwarnTage) Tage") vorher um 08:00 Uhr gesendet."
                    : "Keine Frist-Erinnerungen. Bestehende Benachrichtigungen werden beim nächsten Speichern entfernt.")
                    .font(.caption)
            }

            // --- Rolle ---
            Section("Rolle") {
                Picker("Aktive Rolle", selection: $session.role) {
                    ForEach(AppSession.Role.allCases) { role in
                        Label(role.title, systemImage: role.sfSymbol).tag(role)
                    }
                }
                .pickerStyle(.inline)
            }

            // --- Sprache ---
            Section("Sprache") {
                Picker("Language", selection: $session.languageCode) {
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                    Text("Español").tag("es")
                    Text("العربية").tag("ar")
                }
            }

            // --- Wetter ---
            Section("Wetter") {
                SecureField("OpenWeatherMap API-Key", text: $wetterApiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: wetterApiKey) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: WetterService.apiKeyUserDefaultsKey)
                        Task { await WetterService.shared.cacheLeeren() }
                    }
                Link(destination: URL(string: "https://openweathermap.org/api")!) {
                    Label("Kostenlos registrieren (openweathermap.org)", systemImage: "safari")
                        .font(.caption)
                }
                Text("Kostenloser Plan reicht: 60 Abfragen/Minute, aktuelles Wetter pro Standort.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // --- SKP-Server ---
            Section("SKP-Konvertierungsserver") {
                TextField("Server-URL", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onChange(of: serverURL) { _, newValue in
                        SKPConversionService.shared.serverURL = newValue
                    }
                HStack {
                    Button { checkServer() } label: {
                        Label("Verbindung testen", systemImage: "network")
                    }
                    .disabled(isCheckingServer)
                    Spacer()
                    if isCheckingServer {
                        ProgressView()
                    } else if !serverStatus.isEmpty {
                        Text(serverStatus)
                            .font(.caption)
                            .foregroundStyle(serverStatus.contains("OK") ? .green : .red)
                    }
                }
                Text("Der Server konvertiert SKP-Dateien (SketchUp) automatisch in USDZ fuer den CAD-Viewer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // --- Mops-Server (BauWissen / Pre-Filter) ---
            Section("Mops-Server (BauWissen)") {
                TextField("Server-URL", text: $mopsBaseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                HStack {
                    Button("Standard wiederherstellen") {
                        mopsBaseURL = MopsConfig.defaultHost
                        mopsServerStatus = ""
                    }
                    .font(.caption)
                    .disabled(mopsBaseURL == MopsConfig.defaultHost)

                    Spacer()

                    Button { checkMopsServer() } label: {
                        Label("Testen", systemImage: "network")
                    }
                    .disabled(isCheckingMops || mopsBaseURL.isEmpty)
                }

                if isCheckingMops {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Verbinde …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if !mopsServerStatus.isEmpty {
                    Text(mopsServerStatus)
                        .font(.caption)
                        .foregroundStyle(mopsServerStatus.contains("OK") ? .green : .red)
                }

                Text("LAN-IP der Mops-Box im Heimnetz (Standard) oder Cloudflare-Tunnel-URL fuer mobile Nutzung. Aenderungen wirken sofort beim naechsten Mops-Call.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Text("Baustelle = Event (CoreData). Auftraege werden pro Baustelle verwaltet. CAD-Viewer und Gewerke-Vorlagen sind integriert.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    private func checkServer() {
        isCheckingServer = true
        serverStatus = ""
        Task {
            let health = await SKPConversionService.shared.checkHealth()
            await MainActor.run {
                isCheckingServer = false
                if let h = health {
                    serverStatus = h.blenderAvailable ? "OK - Blender verfügbar" : "OK - Blender fehlt!"
                } else {
                    serverStatus = "Nicht erreichbar"
                }
            }
        }
    }

    /// Health-Probe gegen die aktuell konfigurierte Mops-Server-URL.
    /// Liest MopsConfig.host (= aktueller AppStorage-Wert) automatisch.
    private func checkMopsServer() {
        isCheckingMops = true
        mopsServerStatus = ""
        let client = MopsClient()
        Task {
            let reachable = await client.checkHealth()
            await MainActor.run {
                isCheckingMops = false
                mopsServerStatus = reachable ? "OK - Mops erreichbar" : "Nicht erreichbar"
            }
        }
    }

    /// Ein Zuschlagssatz mit Prozent UND Faktor — der Faktor ist die Zahl, in der
    /// auf dem Bau gedacht wird („mal 2,75 auf den Lohn").
    @ViewBuilder
    private func satzZeile(_ titel: String,
                           wert: Binding<Double>,
                           farbe: Color,
                           bis: Double) -> some View {
        HStack {
            Text(titel)
            Spacer()
            Text("\(Int(wert.wrappedValue * 100)) %")
                .font(.body.monospacedDigit())
                .foregroundStyle(farbe)
            Text("(×\((1 + wert.wrappedValue).formatted(.number.precision(.fractionLength(2)))))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        Slider(value: wert, in: 0...bis, step: 0.05)
            .tint(farbe)
    }
}
