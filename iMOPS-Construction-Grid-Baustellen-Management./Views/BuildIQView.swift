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
    @State private var shutterEffect = false

    private let buildIQService = BuildIQService()
    private let ocrService = OCRService()

    var body: some View {
        ZStack {
            // Kamera-Hintergrund
            ScannerDevicePreview(session: session)
                .ignoresSafeArea()

            // Scan-Rahmen
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

            // Shutter-Blitz
            if shutterEffect {
                Color.white.opacity(0.8).ignoresSafeArea()
            }

            // UI-Ebene
            VStack {
                // Header
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
                    Color.clear.frame(width: 90, height: 36) // Balance
                }
                .padding()

                Spacer()

                // Analyse läuft
                if isProcessing {
                    ProgressView("KI analysiert...")
                        .padding()
                        .background(Color.black.opacity(0.75))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 12)
                }

                // Fehlermeldung
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

                // Ergebniskarte oder Auslöser
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
        // Simulator: Testtext direkt verarbeiten
        processText("Ytong Porenbeton PP2-0.4 240mm Wandbaustein Planblock Mauerwerk")
        #else
        scannerVM.onImageCaptured = { image in
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
                // Ergebnis-Preview oben
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
#endif
