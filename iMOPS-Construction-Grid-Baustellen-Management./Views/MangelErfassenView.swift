import SwiftUI
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

    // Foto
    @State private var fotoItem: PhotosPickerItem? = nil
    @State private var fotoImage: UIImage? = nil
    @State private var zeigeKamera = false

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
                    TextField("Details", text: $beschreibung, axis: .vertical)
                        .lineLimit(3...6)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
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
        }
    }

    // MARK: - Speichern

    private func speichern() {
        let mangel = Mangel(context: ctx)
        mangel.id = UUID()
        mangel.titel = titel.trimmingCharacters(in: .whitespaces)
        mangel.beschreibung = beschreibung.trimmingCharacters(in: .whitespaces)
        mangel.ort = ort.trimmingCharacters(in: .whitespaces)
        mangel.gewerk = gewerk
        mangel.kostenGruppeNummer = selectedKG?.nummer
        mangel.status = .offen
        mangel.mangelSchwere = schwere
        mangel.frist = hatFrist ? frist : nil
        mangel.erfasstAm = Date()
        mangel.erfasstVon = erfasstVon.trimmingCharacters(in: .whitespaces)
        mangel.event = event

        if let img = fotoImage {
            mangel.fotoPfad = speicherFoto(img, id: mangel.id!)
        }

        do {
            try ctx.save()
            dismiss()
        } catch {
            print("Mangel speichern Fehler: \(error)")
        }
    }

    private func speicherFoto(_ image: UIImage, id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Maengel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(id.uuidString).jpg")
        try? data.write(to: url)
        return url.path
    }
}

// MARK: - Einfache Kamera-View

struct KameraView: UIViewControllerRepresentable {
    let onFoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

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
