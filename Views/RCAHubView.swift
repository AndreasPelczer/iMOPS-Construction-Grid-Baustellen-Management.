//
//  RCAHubView.swift
//  test25B
//
//  Created by Andreas Pelczer on 12.01.26.
//
//  RCA = Remote Chef Annotation
//  Foto aufnehmen → Annotation schreiben → optional einem Event zuordnen → speichern.
//

import SwiftUI
import CoreData

// MARK: - RCA Hub (Hauptansicht)

struct RCAHubView: View {
    @Environment(\.managedObjectContext) private var ctx
    private var store = RCAStore.shared

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var showAnnotationSheet = false

    var body: some View {
        Group {
            if store.entries.isEmpty {
                emptyState
            } else {
                entryList
            }
        }
        .navigationTitle("RCA")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showCamera = true } label: {
                        Label("Foto aufnehmen", systemImage: "camera")
                    }
                    Button { showPhotoPicker = true } label: {
                        Label("Aus Galerie wählen", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            RCACameraView(image: $capturedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            RCAPhotoPicker(image: $capturedImage)
        }
        .sheet(isPresented: $showAnnotationSheet) {
            if let img = capturedImage {
                RCAAnnotationSheet(image: img) {
                    capturedImage = nil
                }
                .environment(\.managedObjectContext, ctx)
            }
        }
        .onChange(of: capturedImage) {
            if capturedImage != nil {
                showAnnotationSheet = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("Keine Annotationen")
                .font(.title3.bold())

            Text("Fotografiere eine Situation und füge eine Notiz hinzu.\nPerfekt für HACCP-Dokumentation, Abweichungen und Schulung.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            Button {
                showCamera = true
            } label: {
                Label("Foto aufnehmen", systemImage: "camera.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        List {
            ForEach(store.entries) { entry in
                NavigationLink {
                    RCADetailView(entry: entry)
                } label: {
                    RCARowView(entry: entry)
                }
            }
            .onDelete { offsets in
                for idx in offsets {
                    store.deleteEntry(store.entries[idx].id)
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Row View

struct RCARowView: View {
    let entry: RCAEntry
    private var store: RCAStore { RCAStore.shared }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let img = store.imageFor(entry) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.note.isEmpty ? "Ohne Notiz" : entry.note)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if !entry.eventTitle.isEmpty {
                        Label(entry.eventTitle, systemImage: "target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(entry.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View

struct RCADetailView: View {
    let entry: RCAEntry
    private var store: RCAStore { RCAStore.shared }
    @State private var editedNote: String = ""
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Bild
                if let img = store.imageFor(entry) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Metadaten
                HStack(spacing: 12) {
                    Label(entry.timestamp.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !entry.eventTitle.isEmpty {
                        Label(entry.eventTitle, systemImage: "target")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Tags
                if !entry.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                Divider()

                // Notiz
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Annotation")
                            .font(.headline)
                        Spacer()
                        Button(isEditing ? "Fertig" : "Bearbeiten") {
                            if isEditing {
                                store.updateNote(entry.id, newNote: editedNote)
                            }
                            isEditing.toggle()
                        }
                    }

                    if isEditing {
                        TextEditor(text: $editedNote)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text(entry.note.isEmpty ? "Keine Notiz hinterlegt." : entry.note)
                            .foregroundStyle(entry.note.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Annotation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { editedNote = entry.note }
    }
}

// MARK: - Annotation Sheet (nach Foto)

struct RCAAnnotationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var ctx
    let image: UIImage
    var onDone: () -> Void

    @State private var note: String = ""
    @State private var selectedEvent: Event?
    @State private var selectedTags: Set<String> = []

    private let availableTags = ["HACCP", "Temperatur", "Hygiene", "Abweichung", "Schulung", "Qualität"]

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.eventStartTime, ascending: false)],
        animation: .default
    )
    private var events: FetchedResults<Event>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Vorschau
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Notiz
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Annotation").font(.headline)
                        TextField("Was ist hier zu sehen? Was fällt auf?", text: $note, axis: .vertical)
                            .lineLimit(3...8)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Tags
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags").font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(availableTags, id: \.self) { tag in
                                Button {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                } label: {
                                    Text(tag)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(selectedTags.contains(tag) ? Color.orange : Color(.systemGray5))
                                        .foregroundStyle(selectedTags.contains(tag) ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Event-Zuordnung
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Event zuordnen").font(.headline)

                        Picker("Event", selection: $selectedEvent) {
                            Text("Kein Event").tag(nil as Event?)
                            ForEach(events, id: \.objectID) { event in
                                Text(event.title ?? "Event").tag(event as Event?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding()
            }
            .navigationTitle("Neue Annotation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Abbrechen") { onDone(); dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Speichern") {
                        _ = RCAStore.shared.addEntry(
                            image: image,
                            note: note,
                            tags: Array(selectedTags),
                            event: selectedEvent
                        )
                        onDone()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Flow Layout (für Tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.origins[index].x,
                                      y: bounds.minY + result.origins[index].y),
                          proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            origins.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), origins)
    }
}

// MARK: - Kamera (UIImagePickerController Wrapper)

struct RCACameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: RCACameraView
        init(_ parent: RCACameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Picker (aus Galerie)

import PhotosUI

struct RCAPhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: RCAPhotoPicker
        init(_ parent: RCAPhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}
