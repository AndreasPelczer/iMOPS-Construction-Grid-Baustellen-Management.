import SwiftUI
import Combine
import CoreData
import PhotosUI

struct MangelErfassenView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let event: Event

    @State private var titel = ""
    @State private var beschreibung = ""
    @State private var ort = ""
    @State private var gewerk = ""
    @State private var schwere: MangelSchwere = .mittel
    @State private var frist: Date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var hatFrist = true
    @State private var selectedKG: DIN276KostenGruppe? = nil
    @State private var erfasstVon = ""

    @State private var fotoItem: PhotosPickerItem? = nil
    @State private var fotoImage: UIImage? = nil
    @State private var zeigeKamera = false

    @State private var lastViolation: RuleViolation? = nil
    @State private var showHelp = false

    private let gewerkOptionen = [
        "Rohbau", "Mauerwerk", "Beton", "Elektro", "Sanitär",
        "Heizung", "Lüftung", "Trockenbau", "Fliesen", "Maler",
        "Estrich", "Dachdecker", "Zimmerer", "Schlosser", "Sonstiges"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Mangelbeschreibung") {
                    TextField("Kurztitel (Pflicht)", text: $titel)
                    HStack(alignment: .top, spacing: 8) {
                        TextField("Details", text: $beschreibung, axis: .vertical)
                            .lineLimit(3...6)
                        VoiceInputButton(text: $beschreibung)
                            .padding(.top, 2)
                    }
                }

                Section("Ort & Gewerk") {
                    TextField("Ort z.B. EG Bad, OG Wohnung 3", text: $ort)
                    Picker("Gewerk", selection: $gewerk) {
                        Text("– wählen –").tag("")
                        ForEach(gewerkOptionen, id: \.self) { Text($0).tag($0) }
                    }
                    NavigationLink {
                        KostenGruppePickerView(selection: $selectedKG)
                    } label: {
                        HStack {
                            Text("Kostengruppe")
                            Spacer()
                            Text(selectedKG?.anzeige ?? "Keine")
                                .foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }

                Section("Schwere & Frist") {
                    Picker("Schwere", selection: $schwere) {
                        ForEach(MangelSchwere.allCases) { s in
                            Label(s.displayName, systemImage: s.symbol)
                                .foregroundStyle(s.farbe).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Frist setzen", isOn: $hatFrist)
                    if hatFrist {
                        DatePicker("Frist", selection: $frist, displayedComponents: .date)
                    }

                    TextField("Erfasst von", text: $erfasstVon)
                }

                Section("Foto") {
                    if let img = fotoImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture { fotoImage = nil }
                        Text("Tippen zum Entfernen")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 16) {
                            Button {
                                zeigeKamera = true
                            } label: {
                                Label("Kamera", systemImage: "camera.fill")
                            }
                            .buttonStyle(.bordered)

                            PhotosPicker(selection: $fotoItem, matching: .images) {
                                Label("Bibliothek", systemImage: "photo.fill")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Mangel erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHelp = true } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .tint(.orange)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showHelp) {
                MangelHelpView()
                    .presentationSizing(.page)
            }
            .onChange(of: fotoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        fotoImage = img
                    }
                }
            }
            .fullScreenCover(isPresented: $zeigeKamera) {
                KameraView(onFoto: { img in fotoImage = img })
            }
            .alert(
                lastViolation.map { $0.ruleId } ?? "Fehler",
                isPresented: Binding(
                    get: { lastViolation != nil },
                    set: { if !$0 { lastViolation = nil } }
                )
            ) {
                Button("OK") { lastViolation = nil }
            } message: {
                if let v = lastViolation { Text(v.reason) }
            }
        }
    }

    // MARK: - Speichern

    private func speichern() {
        lastViolation = nil
        let mangel = Mangel(context: ctx)
        mangel.id           = UUID()
        mangel.titel        = titel.trimmingCharacters(in: .whitespaces)
        mangel.beschreibung = beschreibung.trimmingCharacters(in: .whitespaces)
        mangel.ort          = ort.trimmingCharacters(in: .whitespaces)
        mangel.gewerk       = gewerk
        mangel.kostenGruppeNummer = selectedKG?.nummer
        mangel.status       = .offen
        mangel.mangelSchwere = schwere
        mangel.frist        = hatFrist ? frist : nil
        mangel.erfasstAm    = Date()
        mangel.erfasstVon   = erfasstVon.trimmingCharacters(in: .whitespaces)
        mangel.event        = event
        if let img = fotoImage { mangel.fotoPfad = speicherFoto(img, id: mangel.id!) }
        do {
            try ctx.save()
            NotificationService.shared.schedule(for: mangel)
            dismiss()
        } catch {
            lastViolation = RuleViolation(
                ruleId: "BAU-R99",
                reason: "Speichern fehlgeschlagen: \(error.localizedDescription)",
                fields: nil
            )
        }
    }

    private func speicherFoto(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir  = docs.appendingPathComponent("Maengel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url  = dir.appendingPathComponent("\(id.uuidString).jpg")
        try? data.write(to: url)
        return url.path
    }
}

// MARK: - Kamera-View

struct KameraView: UIViewControllerRepresentable {
    let onFoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFoto: onFoto, dismiss: dismiss) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFoto: (UIImage) -> Void
        let dismiss: DismissAction
        init(onFoto: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onFoto = onFoto; self.dismiss = dismiss
        }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onFoto(img) }
            dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { dismiss() }
    }
}

// MARK: - Hilfe

struct MangelHelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Was ist ein Mangel?") {
                    Text("Ein Mangel ist eine Abweichung von der vereinbarten Leistung – z.B. ein Riss im Putz, falsch verlegte Leitungen, oder fehlende Dämmung.")
                }
                Section("Schwere-Stufen") {
                    Label("Kritisch – sofortige Behebung, Sicherheitsrisiko", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Label("Hoch – Behebung innerhalb weniger Tage", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    Label("Mittel – Standardfrist (14 Tage)", systemImage: "minus.circle.fill").foregroundStyle(.yellow)
                    Label("Niedrig – bei nächster Gelegenheit", systemImage: "arrow.down.circle.fill").foregroundStyle(.blue)
                }
                Section("Spracheingabe") {
                    Label("Tippe auf den Mic-Button neben \"Details\" um zu diktieren", systemImage: "mic.circle")
                    Label("Tippe erneut auf Stop um die Aufnahme zu beenden", systemImage: "stop.circle.fill")
                    Label("Spracherkennung läuft lokal auf deinem Gerät — keine Daten werden übertragen", systemImage: "lock.shield")
                }
                Section("Foto") {
                    Label("Foto als Beweis – wichtig bei Gewährleistungsansprüchen", systemImage: "camera.fill")
                    Label("Tippe auf das Foto um es zu entfernen", systemImage: "hand.tap")
                }
                Section("Status-Ablauf") {
                    Label("Offen → In Arbeit → Behoben", systemImage: "arrow.right.circle")
                }
            }
            .navigationTitle("Hilfe: Mangel erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }
}
