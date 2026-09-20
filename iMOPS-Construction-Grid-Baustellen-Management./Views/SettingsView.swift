import SwiftUI
import PhotosUI
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
    // Briefpapier — was auf jedem Dokument steht, das das Haus verlaesst.
    @AppStorage(FirmenSettings.Keys.steuernummer)      private var steuernummer = ""
    @AppStorage(FirmenSettings.Keys.telefon)           private var telefon      = ""
    @AppStorage(FirmenSettings.Keys.fax)               private var fax          = ""
    @AppStorage(FirmenSettings.Keys.email)             private var email        = ""
    @AppStorage(FirmenSettings.Keys.web)               private var web          = ""
    @AppStorage(FirmenSettings.Keys.bank)              private var bank         = ""
    @AppStorage(FirmenSettings.Keys.iban)              private var iban         = ""
    @AppStorage(FirmenSettings.Keys.bic)               private var bic          = ""
    @AppStorage(FirmenSettings.Keys.bank2)             private var bank2        = ""
    @AppStorage(FirmenSettings.Keys.iban2)             private var iban2        = ""
    @AppStorage(FirmenSettings.Keys.bic2)              private var bic2         = ""
    @AppStorage(FirmenSettings.Keys.handelsregister)   private var handelsregister = ""
    @AppStorage(FirmenSettings.Keys.geschaeftsfuehrer) private var geschaeftsfuehrer = ""
    @AppStorage(FirmenSettings.Keys.rechtstextFuss)    private var rechtstextFuss = ""
    @AppStorage(FirmenSettings.Keys.zahlungszielTage)  private var zahlungszielTage = 14
    @AppStorage(FirmenSettings.Keys.logoDatei)         private var logoDatei    = ""

    @State private var logoAuswahl: PhotosPickerItem?
    @AppStorage(FirmenSettings.Keys.mwstSatz) private var mwstSatz     = 19.0

    // Kalkulations-Zuschläge. Vorgaben identisch zu FirmenSettings — beide lesen
    // denselben Schlüssel, deshalb müssen die Vorgaben übereinstimmen.
    @AppStorage(FirmenSettings.Keys.zuschlagJeKostenart) private var zuschlagJeKostenart = false
    @AppStorage(FirmenSettings.Keys.zuschlagLohn)        private var zuschlagLohn        = 0.20
    @AppStorage(FirmenSettings.Keys.zuschlagMaterial)    private var zuschlagMaterial    = 0.20
    @AppStorage(FirmenSettings.Keys.zuschlagGeraet)      private var zuschlagGeraet      = 0.20
    @AppStorage(FirmenSettings.Keys.bgk)                 private var bgk                 = 0.12
    @AppStorage(FirmenSettings.Keys.wagnisGewinn)        private var wagnisGewinn        = 0.08

    // Firmenprofil: mit welchen Sätzen rechnet der Mops? Goldschmitt (echt) ↔ Mops (neutral/Demo).
    @AppStorage(Firmenprofil.defaultsKey) private var firmenprofilRaw = Firmenprofil.goldschmitt.rawValue

    // Kennwerte je m² Wohnfläche für die Grobkostenschätzung im Planer.
    // Vorgaben identisch zu FirmenSettings (siehe dort: es sind EURE Erfahrungswerte,
    // keine lizenzierten BKI-Daten).
    @AppStorage(FirmenSettings.Keys.kennwertEinfach) private var kennwertEinfach = 2000.0
    @AppStorage(FirmenSettings.Keys.kennwertMittel)  private var kennwertMittel  = 2500.0
    @AppStorage(FirmenSettings.Keys.kennwertGehoben) private var kennwertGehoben = 3200.0

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

    /// Logo wählen, ansehen, entfernen.
    ///
    /// Das Bild landet als **Datei im App-Support**, in den UserDefaults steht nur
    /// der Dateiname (`FirmenSettings.setzeLogo`). UserDefaults wird bei jedem
    /// Start vollständig gelesen — ein PNG gehört da nicht hinein.
    @ViewBuilder
    private var logoZeile: some View {
        HStack(spacing: 12) {
            if let daten = FirmenSettings.logoDaten, let bild = UIImage(data: daten) {
                Image(uiImage: bild)
                    .resizable().scaledToFit()
                    .frame(width: 90, height: 44)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .foregroundStyle(.tertiary)
                    .frame(width: 90, height: 44)
                    .overlay(Text("kein Logo").font(.caption2).foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 6) {
                PhotosPicker(selection: $logoAuswahl, matching: .images) {
                    Label(logoDatei.isEmpty ? "Logo wählen" : "Logo ersetzen",
                          systemImage: "photo")
                        .font(.subheadline)
                }
                if !logoDatei.isEmpty {
                    Button(role: .destructive) {
                        FirmenSettings.setzeLogo(nil)
                        logoDatei = ""
                    } label: {
                        Label("Entfernen", systemImage: "trash").font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .onChange(of: logoAuswahl) { _, neu in
            guard let neu else { return }
            Task {
                // PNG-Daten anfordern; scheitert das, bleibt das alte Logo stehen.
                if let daten = try? await neu.loadTransferable(type: Data.self) {
                    FirmenSettings.setzeLogo(daten)
                    // Erzwingt das Neuzeichnen der Vorschau — der Dateiname ist
                    // derselbe, also merkt SwiftUI die Änderung sonst nicht.
                    logoDatei = ""
                    logoDatei = "firmenlogo.png"
                }
            }
        }
    }

    var body: some View {
        @Bindable var session = session
        Form {

            // --- Hilfe & Wegweiser ---
            Section {
                NavigationLink {
                    MopsBrowserView()
                } label: {
                    Label("Mops-Wegweiser", systemImage: "book.pages")
                }
            } header: {
                Text("Hilfe")
            } footer: {
                Text("Klickpläne und Erklär-Seiten direkt in der App — zum Vorführen und Verstehen.")
            }

            // --- Preise & Stammdaten ---
            Section {
                NavigationLink {
                    StammdatenPflegeView()
                } label: {
                    Label("Meine Preise & Stammdaten", systemImage: "eurosign.circle")
                }
            } header: {
                Text("Preise")
            } footer: {
                Text("Deine eigenen Material-, Lohn- und Gerätepreise eintragen und ändern — antippen und tippen. Ohne eigene Preise rechnet der Mops mit Standardwerten. (Preise bleiben lokal auf dem Gerät.)")
            }

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
                Text("Stehen im Briefkopf jedes Dokuments und als Rechnungsaussteller in der XRechnung.")
                    .font(.caption)
            }

            // --- Briefpapier ---
            //
            // Alles optional. Was leer bleibt, wird im Dokument WEGGELASSEN —
            // nie als Platzhalter gedruckt. Ein Briefkopf ohne Faxnummer sieht
            // normal aus, einer mit „Fax: –" sieht nach Software aus.
            Section {
                logoZeile

                TextField("Steuernummer", text: $steuernummer)
                TextField("Telefon", text: $telefon)
                    .keyboardType(.phonePad)
                TextField("Fax", text: $fax)
                    .keyboardType(.phonePad)
                TextField("E-Mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Web", text: $web)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Briefpapier — Logo & Kontakt")
            } footer: {
                Text("Leere Felder werden auf dem Dokument weggelassen.")
                    .font(.caption)
            }

            Section {
                TextField("Bank", text: $bank)
                TextField("IBAN", text: $iban)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("BIC", text: $bic)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            } header: {
                Text("Bankverbindung")
            } footer: {
                Text("Die IBAN steht im Rechnungsfuß und als Zahlungsangabe in der XRechnung.")
                    .font(.caption)
            }

            Section("Zweite Bankverbindung (optional)") {
                TextField("Bank", text: $bank2)
                TextField("IBAN", text: $iban2)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                TextField("BIC", text: $bic2)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
            }

            Section {
                TextField("Handelsregister (z. B. HRB 1234, AG Würzburg)",
                          text: $handelsregister)
                TextField("Geschäftsführer", text: $geschaeftsfuehrer)
                HStack {
                    Text("Zahlungsziel").foregroundStyle(.secondary)
                    Spacer()
                    TextField("14", value: $zahlungszielTage, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 60)
                        .keyboardType(.numberPad)
                    Text("Tage").foregroundStyle(.secondary)
                }
                TextField("Rechtstext im Fuß (z. B. VOB/B, Gerichtsstand)",
                          text: $rechtstextFuss, axis: .vertical)
                    .lineLimit(1...3)
            } header: {
                Text("Register & Zahlung")
            } footer: {
                Text("Zahlungsziel 0 = keine Angabe auf der Rechnung.")
                    .font(.caption)
            }

            // Die Prüfung, die vor dem ersten echten Versand steht.
            if !FirmenSettings.briefkopfIstVollstaendig {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Briefkopf noch unvollständig")
                                .font(.subheadline.weight(.semibold))
                            Text("Für eine ordnungsgemäße Rechnung fehlen noch "
                                 + "Firmenname, Anschrift und USt-IdNr. oder Steuernummer. "
                                 + "Dokumente lassen sich erzeugen, sind aber Demo — "
                                 + "nicht für echte Kunden.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            // --- Firmenprofil: mit welchen Sätzen rechnet der Mops? ---
            Section {
                Picker(selection: $firmenprofilRaw) {
                    Text("🏢 Goldschmitt (echt)").tag(Firmenprofil.goldschmitt.rawValue)
                    Text("🐶 Mops (neutral)").tag(Firmenprofil.mops.rawValue)
                } label: {
                    Label("Aktives Profil", systemImage: "arrow.left.arrow.right.circle")
                }
                .pickerStyle(.segmented)

                NavigationLink {
                    FirmenprofilUebersichtView()
                } label: {
                    Label("Goldschmitt vs. Mops — Selbstkosten & Rechnung", systemImage: "rectangle.split.2x1")
                }
            } header: {
                Text("Firmenprofil")
            } footer: {
                Text("""
                Bestimmt, mit welchen Lohn-KOSTEN der Mops rechnet: „Goldschmitt" = eure echten \
                Löhne, „Mops" = neutrale Bau-Tarif-Werte. Das sind KOSTEN (Lohn + Nebenkosten) — \
                der Verkaufspreis kommt über die Zuschläge/„Wo verdient der Boss?". In der \
                Kalkulation stehen beide Profile nebeneinander zum Vergleich. „Mops" ist zugleich \
                der DSGVO-sichere Demo-Modus — keine Goldschmitt-Zahl im Spiel.
                """)
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

                NavigationLink {
                    GewinnSchieberView()
                } label: {
                    Label("Wo verdient der Boss? — gegen das Orakel prüfen", systemImage: "scope")
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

            // --- Kennwerte je m² (Grobkostenschätzung im Planer) ---
            Section {
                kennwertZeile("Einfach", wert: $kennwertEinfach)
                kennwertZeile("Mittel",  wert: $kennwertMittel)
                kennwertZeile("Gehoben", wert: $kennwertGehoben)
            } header: {
                Text("Kalkulation — Kennwerte je m²")
            } footer: {
                Text("""
                Womit der Planer eine Baustelle grob schätzt, bevor ein LV da ist: \
                Wohnfläche × Kennwert, verteilt auf die Gewerke.

                Das sind EURE Erfahrungswerte, keine lizenzierten BKI-Daten — darum heißt \
                es hier „Kennwert" und nicht „BKI". Eine Schätzung ist ein anderer Zustand \
                als eine Messung: sie taugt für die Größenordnung, nicht als Nachweis.

                Ein leeres Feld fällt auf die Vorgabe zurück (2000 / 2500 / 3200 €/m²), \
                damit eine versehentliche 0 nicht die ganze Schätzung auf null zieht.
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

    /// Ein Kennwert in €/m². Anders als die Zuschläge kein Slider — Firmenwerte tippt
    /// man einmal ein, und zwischen 2000 und 3200 wäre ein Schieber ohnehin zu grob.
    private func kennwertZeile(_ titel: String, wert: Binding<Double>) -> some View {
        LabeledContent(titel) {
            HStack(spacing: 4) {
                TextField(titel, value: wert, format: .number.precision(.fractionLength(0)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: 90)
                Text("€/m²").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
