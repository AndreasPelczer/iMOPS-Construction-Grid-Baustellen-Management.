#if !targetEnvironment(macCatalyst)
import SwiftUI
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
                AuftragZuweisungView(result: result) {
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

            HStack(spacing: 12) {
                Button {
                    showAssignSheet = true
                } label: {
                    Label("Auftrag zuweisen", systemImage: "link.badge.plus")
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
        processText("Ytong Porenbeton PP2-0.4 240mm Wandbaustein Planblock Mauerwerk")
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

// MARK: - Auftrag-Zuweisung

struct AuftragZuweisungView: View {
    @Environment(\.managedObjectContext) var ctx
    @Environment(\.dismiss) var dismiss

    let result: BuildIQResult
    let onAssigned: () -> Void

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Auftrag.processingDetails, ascending: true)],
        predicate: NSPredicate(format: "isCompleted == NO")
    ) private var auftraege: FetchedResults<Auftrag>

    var body: some View {
        NavigationStack {
            List(auftraege) { auftrag in
                Button {
                    auftrag.kostenGruppeNummer = result.kg_nummer
                    auftrag.kostenGruppeBezeichnung = result.kg_bezeichnung
                    try? ctx.save()
                    onAssigned()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(auftrag.processingDetails ?? "Auftrag")
                            .font(.headline)
                            .foregroundColor(.primary)
                        HStack {
                            if let emp = auftrag.employeeName, !emp.isEmpty {
                                Label(emp, systemImage: "person")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let kg = auftrag.kostenGruppeNummer {
                                Text("KG \(kg)")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Auftrag auswählen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(result.kg_nummer) · \(result.kg_bezeichnung)")
                            .font(.subheadline).bold()
                        Text(result.begruendung)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.orange.opacity(0.1))
            }
            .overlay {
                if auftraege.isEmpty {
                    ContentUnavailableView(
                        "Keine offenen Aufträge",
                        systemImage: "tray",
                        description: Text("Lege zuerst einen Auftrag an.")
                    )
                }
            }
        }
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
                    featureRow(icon: "sparkles",         title: "Gemini 2.0 Flash",   desc: "KI ordnet DIN 276 Kostengruppen zu")
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
                    Text("BuildIQ verbindet Kamera, OCR und Google Gemini 2.0 Flash, um Baumaterialien automatisch zu erkennen und DIN 276 Kostengruppen zuzuordnen – direkt auf der Baustelle.")
                }

                Section("So funktioniert's") {
                    helpStep(nr: "1", icon: "camera.fill",     text: "Halte die Kamera auf einen Lieferschein oder ein Materialschild.")
                    helpStep(nr: "2", icon: "text.viewfinder", text: "Tippe den Auslöser – Vision OCR liest den Text automatisch.")
                    helpStep(nr: "3", icon: "sparkles",        text: "Gemini 2.0 Flash analysiert und ordnet eine DIN 276 Kostengruppe zu.")
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
