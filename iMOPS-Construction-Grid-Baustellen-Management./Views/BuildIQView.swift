#if !targetEnvironment(macCatalyst)
import SwiftUI
import Vision
import Combine
import AVFoundation
import CoreData

// MARK: - BuildIQView

struct BuildIQView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var ctx

    @StateObject private var scannerVM = ScannerViewModel()
    @State private var session = AVCaptureSession()
    @State private var photoOutput = AVCapturePhotoOutput()

    @State private var isProcessing = false
    @State private var scanResult: BuildIQResult? = nil
    @State private var errorMessage: String? = nil
    @State private var showAssignSheet = false
    @State private var showHelp = false
    @State private var shutterEffect = false

    private let buildIQService = BuildIQService()
    private let ocrService = OCRService()

    var body: some View {
        ZStack {
            ScannerDevicePreview(session: session)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.orange, lineWidth: 3)
                .frame(width: 300, height: 200)
                .overlay(
                    Text("Lieferschein oder Material scannen")
                        .font(.caption).bold()
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4),
                    alignment: .bottom
                )

            if shutterEffect {
                Color.white.opacity(0.8).ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Abbrechen") { dismiss() }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.black.opacity(0.55))
                        .foregroundColor(.white)
                        .cornerRadius(8)

                    Spacer()

                    Label("BuildIQ", systemImage: "brain.head.profile")
                        .font(.headline).bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.orange.opacity(0.85))
                        .cornerRadius(8)

                    Spacer()

                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.black.opacity(0.55))
                            .cornerRadius(8)
                    }
                    .frame(width: 90)
                }
                .padding()

                Spacer()

                if isProcessing {
                    ProgressView("KI analysiert...")
                        .padding()
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 12)
                }

                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                if let result = scanResult {
                    resultCard(result)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if !isProcessing {
                    captureButton
                }
            }
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.3), value: scanResult != nil)
        .onAppear { setupCamera() }
        .onDisappear { session.stopRunning() }
        .sheet(isPresented: $showAssignSheet) {
            if let result = scanResult {
                BuildIQBuchungView(result: result) {
                    dismiss()
                }
                .environment(\.managedObjectContext, ctx)
            }
        }
        .sheet(isPresented: $showHelp) {
            BuildIQHelpView()
        }
    }

    // MARK: - Ergebniskarte

    private func resultCard(_ result: BuildIQResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DIN 276 · \(result.kg_nummer)")
                        .font(.caption).foregroundColor(.orange)
                    Text(result.kg_bezeichnung)
                        .font(.title3).bold().foregroundColor(.white)
                }
                Spacer()
                konfidenzBadge(result.konfidenz)
            }

            Text(result.begruendung)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            // Welle 5.3: Mengen-Anzeige
            if let menge = result.menge, let einheit = result.einheit {
                HStack {
                    Image(systemName: "scale.3d")
                        .foregroundColor(.orange)
                    // Welle 5.3: Menge ohne überflüssige Nullen, max. 2 Nachkommastellen,
                    // lokalisiert (de: Komma) — sonst zeigt der Double "15,000000".
                    Text("\(menge.formatted(.number.precision(.fractionLength(0...2)))) \(einheit)")
                        .font(.headline)
                        .foregroundColor(.white)
                    if let conf = result.menge_konfidenz {
                        Text("(\(conf))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 5)
            }

            HStack(spacing: 12) {
                Button {
                    showAssignSheet = true
                } label: {
                    Label("Auf Position buchen", systemImage: "ruler")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button {
                    withAnimation { scanResult = nil; errorMessage = nil }
                } label: {
                    Label("Erneut", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.88))
        .cornerRadius(16)
    }

    private func konfidenzBadge(_ konfidenz: String) -> some View {
        let color: Color = konfidenz == "hoch" ? .green : konfidenz == "mittel" ? .yellow : .red
        return Text(konfidenz.uppercased())
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.25))
            .foregroundColor(color)
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1))
    }

    // MARK: - Kamera

    private var captureButton: some View {
        Button(action: takePhoto) {
            ZStack {
                Circle().fill(Color.white).frame(width: 70, height: 70)
                Circle().stroke(Color.orange, lineWidth: 4).frame(width: 80, height: 80)
                Image(systemName: "camera.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 30))
            }
            .shadow(radius: 10)
        }
    }

    private func setupCamera() {
        #if targetEnvironment(simulator)
        return
        #else
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            session.commitConfiguration()
            DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        } catch {}
        #endif
    }

    private func takePhoto() {
        withAnimation(.easeInOut(duration: 0.1)) { shutterEffect = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shutterEffect = false }

        #if targetEnvironment(simulator)
        processText("15 m² Betonsteinwand Porenbeton PP2-0.4 Planblock Mauerwerk")
        #else
        scannerVM.onImageCaptured = { (image: UIImage) in
            ocrService.performOCR(on: image) { observations in
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                processText(text.isEmpty ? "Unbekanntes Baumaterial" : text)
            }
        }
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: scannerVM)
        #endif
    }

    private func processText(_ text: String) {
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let result = try await buildIQService.analyzeText(text)
                await MainActor.run {
                    withAnimation { scanResult = result }
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Analyse fehlgeschlagen: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - BuildIQ-Buchung (Welle 5.3.2)
// Scan-Ergebnis (KG + Menge) auf eine konkrete LV-Position buchen — als Aufmaß mit
// quelle = .buildiq (Option B2). Polier bestätigt immer (Option C1, Buch Kap 1:
// BuildIQ ist Werkzeug, der Mensch entscheidet). A1: ein Material pro Scan.
struct BuildIQBuchungView: View {
    @Environment(\.managedObjectContext) var ctx
    @Environment(\.dismiss) var dismiss

    let result: BuildIQResult
    let onGebucht: () -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LVPosition.posNr, ascending: true)]
    ) private var positionen: FetchedResults<LVPosition>

    @State private var gewaehlt: LVPosition?

    // Weicher KG-Filter (Vorauswahl, nicht hart): passende Positionen zuerst.
    private var passende: [LVPosition] {
        positionen.filter { $0.kostenGruppeNummer == result.kg_nummer }
    }
    private var uebrige: [LVPosition] {
        positionen.filter { $0.kostenGruppeNummer != result.kg_nummer }
    }

    var body: some View {
        NavigationStack {
            List {
                if !passende.isEmpty {
                    Section("Passend zu KG \(result.kg_nummer)") {
                        ForEach(passende, id: \.objectID, content: positionRow)
                    }
                }
                if !uebrige.isEmpty {
                    Section(passende.isEmpty ? "Alle LV-Positionen" : "Andere Positionen") {
                        ForEach(uebrige, id: \.objectID, content: positionRow)
                    }
                }
            }
            .navigationTitle("Position wählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) { scanKopf }
            .overlay {
                if positionen.isEmpty {
                    ContentUnavailableView(
                        "Keine LV-Positionen",
                        systemImage: "tray",
                        description: Text("Importiere zuerst ein Leistungsverzeichnis.")
                    )
                }
            }
            .sheet(item: $gewaehlt) { pos in
                BuildIQBuchungBestaetigenView(result: result, position: pos) {
                    gewaehlt = nil
                    onGebucht()
                }
                .environment(\.managedObjectContext, ctx)
            }
        }
    }

    private func positionRow(_ p: LVPosition) -> some View {
        Button { gewaehlt = p } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(p.bezeichnung ?? "Position")
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack(spacing: 8) {
                    if let nr = p.posNr, !nr.isEmpty {
                        Text("Pos \(nr)").font(.caption2).foregroundColor(.secondary)
                    }
                    if let kg = p.kostenGruppeNummer, !kg.isEmpty {
                        Text("KG \(kg)").font(.caption2).foregroundColor(.orange)
                    }
                    if let bau = p.event?.title ?? p.event?.name, !bau.isEmpty {
                        Text("· \(bau)").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text("Soll \(p.sollMenge.formatted(.number.precision(.fractionLength(0...2)))) \(p.einheit ?? "")")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
        }
    }

    private var scanKopf: some View {
        HStack {
            Image(systemName: "brain.head.profile").foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(result.kg_nummer) · \(result.kg_bezeichnung)")
                    .font(.subheadline).bold()
                if let menge = result.menge {
                    Text("Scan: \(menge.formatted(.number.precision(.fractionLength(0...2)))) \(result.einheit ?? "")")
                        .font(.caption).foregroundColor(.secondary)
                } else {
                    Text("Scan ohne Menge — beim Buchen von Hand eintragen")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - BuildIQ-Buchung bestätigen
// Zeigt die Soll/Ist-Vorschau MIT dem gescannten Wert, bevor gebucht wird (der Polier
// sieht die Konsequenz). Buchung = neue Aufmaß-Zeile mit quelle = .buildiq.
private struct BuildIQBuchungBestaetigenView: View {
    @Environment(\.managedObjectContext) var ctx
    @Environment(\.dismiss) var dismiss

    let result: BuildIQResult
    @ObservedObject var position: LVPosition
    let onGebucht: () -> Void

    @State private var mengeText: String
    @State private var einheit: String

    init(result: BuildIQResult, position: LVPosition, onGebucht: @escaping () -> Void) {
        self.result = result
        self.position = position
        self.onGebucht = onGebucht
        _mengeText = State(initialValue: result.menge.map {
            $0.formatted(.number.precision(.fractionLength(0...2)))
        } ?? "")
        _einheit = State(initialValue: result.einheit ?? position.einheit ?? "")
    }

    private var neueMenge: Double? {
        Double(mengeText.replacingOccurrences(of: ",", with: "."))
    }
    private var valid: Bool { (neueMenge ?? 0) > 0 }
    private var neuesIst: Double { position.istMengeSumme + (neueMenge ?? 0) }
    private var neueAbweichung: Double { position.sollMenge - neuesIst }
    private var neueAbwProzent: Double {
        position.sollMenge > 0 ? neueAbweichung / position.sollMenge : 0
    }
    // Gleiche Schwellen wie LVPosition.aufmassAmpel (5 %/15 %), auf den Vorschauwert.
    private var vorschauAmpel: AufmassAmpel {
        guard position.sollMenge > 0 else { return .keinAufmass }
        let a = abs(neueAbwProzent)
        if a <= 0.05 { return .gruen }
        if a <= 0.15 { return .orange }
        return .rot
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0,00", text: $mengeText)
                            .keyboardType(.decimalPad)
                            .font(.title3.monospacedDigit())
                        TextField("Einheit", text: $einheit)
                            .frame(maxWidth: 90)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Gescannte Menge *")
                } footer: {
                    Text("Soll laut LV: \(position.sollMenge.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                }

                Section("Vorschau nach Buchung") {
                    vorschauZeile("SOLL", position.sollMenge)
                    vorschauZeile("bisher IST", position.istMengeSumme)
                    vorschauZeile("+ Scan", neueMenge ?? 0)
                    vorschauZeile("= neues IST", neuesIst, betont: true)
                    HStack {
                        Text("ABWEICHUNG").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(neueAbweichung.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "") (\((neueAbwProzent * 100).formatted(.number.precision(.fractionLength(0...1)))) %)")
                            .font(.callout.monospacedDigit())
                        Circle().fill(vorschauAmpel.farbe).frame(width: 12, height: 12)
                    }
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "brain.head.profile").foregroundColor(.orange)
                        Text("Wird als Aufmaß mit Quelle BuildIQ festgehalten. Du bestätigst — die KI bucht nicht allein.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(position.bezeichnung ?? "Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zurück") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buchen") { buchen() }.disabled(!valid).tint(.orange)
                }
            }
        }
    }

    private func vorschauZeile(_ label: String, _ value: Double, betont: Bool = false) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(value.formatted(.number.precision(.fractionLength(0...2)))) \(einheit.isEmpty ? (position.einheit ?? "") : einheit)")
                .font(betont ? .body.monospacedDigit().weight(.semibold) : .callout.monospacedDigit())
        }
    }

    private func buchen() {
        let a = Aufmass(context: ctx)
        a.id = UUID()
        a.istMenge = neueMenge ?? 0
        a.istEinheit = einheit.isEmpty ? nil : einheit
        a.notiz = "BuildIQ: \(result.kg_nummer) \(result.kg_bezeichnung)"
        a.quelle = .buildiq
        a.erstelltAm = Date()
        a.lvPosition = position
        try? ctx.save()
        dismiss()
        onGebucht()
    }
}

// MARK: - BuildIQ Landing (Tab-Root)

struct BuildIQLandingView: View {
    @State private var showScanner = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 130, height: 130)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 54))
                        .foregroundColor(.orange)
                }
                .padding(.top, 40)

                VStack(spacing: 6) {
                    Text("BuildIQ")
                        .font(.largeTitle).bold()
                    Text("KI-gestützte Baumaterial-Erkennung")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 18) {
                    featureRow(icon: "camera.fill",      title: "Kamera-Scan",       desc: "Fotografiere Lieferscheine oder Materialschilder")
                    featureRow(icon: "text.viewfinder",  title: "Texterkennung",      desc: "Vision OCR liest den Text automatisch")
                    featureRow(icon: "sparkles",         title: "Mops (lokal)",       desc: "Ordnet auf der Box eine DIN 276 Kostengruppe zu – ohne Cloud")
                    featureRow(icon: "link.badge.plus",  title: "Auftrag zuweisen",   desc: "Ergebnis direkt einem offenen Auftrag zuordnen")
                }
                .padding(.horizontal, 28)

                Button {
                    showScanner = true
                } label: {
                    Label("Scanner starten", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("BuildIQ")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
        }
        .fullScreenCover(isPresented: $showScanner) {
            BuildIQView()
        }
        .sheet(isPresented: $showHelp) {
            BuildIQHelpView()
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - BuildIQ Hilfe

struct BuildIQHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Was ist BuildIQ?") {
                    Text("BuildIQ verbindet Kamera, OCR und den lokalen Mops (auf der Box, ohne Cloud), um Baumaterialien automatisch zu erkennen und DIN 276 Kostengruppen zuzuordnen – direkt auf der Baustelle.")
                }

                Section("So funktioniert's") {
                    helpStep(nr: "1", icon: "camera.fill",     text: "Halte die Kamera auf einen Lieferschein oder ein Materialschild.")
                    helpStep(nr: "2", icon: "text.viewfinder", text: "Tippe den Auslöser – Vision OCR liest den Text automatisch.")
                    helpStep(nr: "3", icon: "sparkles",        text: "Der lokale Mops (auf der Box) analysiert und ordnet eine DIN 276 Kostengruppe zu.")
                    helpStep(nr: "4", icon: "link.badge.plus", text: "Weise das Ergebnis einem offenen Auftrag zu.")
                }

                Section("DIN 276 Kostengruppen") {
                    Text("DIN 276 gliedert Baukosten in Gruppen von 100–700. Beispiele:")
                    Label("KG 300 – Bauwerk (Baukonstruktion)", systemImage: "building.2")
                    Label("KG 330 – Außenwände / Außenstützen", systemImage: "square.split.diagonal")
                    Label("KG 352 – Außentüren und -fenster", systemImage: "door.sliding.left.hand.closed")
                    Label("KG 400 – Technische Anlagen", systemImage: "wrench.and.screwdriver")
                }

                Section("Konfidenz-Ampel") {
                    HStack(spacing: 10) {
                        Circle().fill(Color.green).frame(width: 10, height: 10)
                        Text("Hoch – Ergebnis sehr zuverlässig")
                    }
                    HStack(spacing: 10) {
                        Circle().fill(Color.yellow).frame(width: 10, height: 10)
                        Text("Mittel – manuelle Prüfung empfohlen")
                    }
                    HStack(spacing: 10) {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("Niedrig – bitte manuell korrigieren")
                    }
                }

                Section("Hinweise") {
                    Label("Gute Beleuchtung verbessert die OCR-Genauigkeit erheblich.", systemImage: "lightbulb")
                    Label("GEMINI_API_KEY muss in Secrets.plist hinterlegt sein.", systemImage: "key.fill")
                    Label("BuildIQ ist nur auf iPhone/iPad verfügbar (kein macCatalyst).", systemImage: "iphone")
                }
            }
            .navigationTitle("BuildIQ Hilfe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .tint(.orange)
                }
            }
        }
    }

    private func helpStep(nr: String, icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(Color.orange).frame(width: 24, height: 24)
                Text(nr).font(.caption).bold().foregroundColor(.white)
            }
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
#endif
