import SwiftUI
import Combine
import Speech
import AVFoundation

// MARK: - Spracherkennung (lokal, de_DE, kein Cloud)

@MainActor
final class SpeechRecognizer: ObservableObject {
    @Published var isRecording  = false
    @Published var liveText     = ""
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de_DE"))
    private var engine     = AVAudioEngine()
    private var request:   SFSpeechAudioBufferRecognitionRequest?
    private var task:      SFSpeechRecognitionTask?

    func toggle(onDone: @escaping (String) -> Void) {
        isRecording ? stop(onDone: onDone) : requestAndStart(onDone: onDone)
    }

    private func requestAndStart(onDone: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Spracherkennung nicht erlaubt. Einstellungen → iMOPS → Spracherkennung."
                }
                return
            }
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                guard granted else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Mikrofon-Zugriff verweigert. Einstellungen → iMOPS → Mikrofon."
                    }
                    return
                }
                DispatchQueue.main.async { self?.startEngine(onDone: onDone) }
            }
        }
    }

    private func startEngine(onDone: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Spracherkennung momentan nicht verfügbar."
            return
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)

        request = SFSpeechAudioBufferRecognitionRequest()
        guard let req = request else { return }
        req.shouldReportPartialResults = true
        // Lokal wenn verfügbar — keine Daten verlassen das Gerät
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }

        liveText = ""
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let result { self.liveText = result.bestTranscription.formattedString }
                if error != nil || result?.isFinal == true {
                    let spoken = self.liveText
                    self.stopEngine()
                    if !spoken.isEmpty { onDone(spoken) }
                }
            }
        }

        let format = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buf, _ in
            self?.request?.append(buf)
        }
        do {
            try engine.start()
            isRecording = true
        } catch {
            errorMessage = "Mikrofon konnte nicht gestartet werden."
            stopEngine()
        }
    }

    func stop(onDone: @escaping (String) -> Void) {
        let spoken = liveText
        stopEngine()
        if !spoken.isEmpty { onDone(spoken) }
    }

    private func stopEngine() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        liveText = ""
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Wiederverwendbarer Mic-Button

struct VoiceInputButton: View {
    @Binding var text: String
    @StateObject private var sr = SpeechRecognizer()

    var body: some View {
        Button {
            sr.toggle { spoken in
                if !text.isEmpty && !text.hasSuffix(" ") && !text.hasSuffix("\n") {
                    text += " "
                }
                text += spoken
            }
        } label: {
            Image(systemName: sr.isRecording ? "stop.circle.fill" : "mic.circle")
                .font(.title2)
                .foregroundStyle(sr.isRecording ? .red : .orange)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .alert("Spracheingabe", isPresented: Binding(
            get: { sr.errorMessage != nil },
            set: { if !$0 { sr.errorMessage = nil } }
        )) {
            Button("OK") { sr.errorMessage = nil }
        } message: {
            Text(sr.errorMessage ?? "")
        }
    }
}
