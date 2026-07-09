//
//  PDFPreviewView.swift.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Created by Andreas Pelczer on 20.06.26.
//
import SwiftUI
import PDFKit

// Eine einfache SwiftUI Hülle für das Apple PDFKit
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// Unsere Vorschau-View mit "Teilen" Button
struct PDFPreviewView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            PDFKitView(url: url)
                .ignoresSafeArea()
                .navigationTitle("PDF Vorschau")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .teilenOderSpeichern(isPresented: $showingShareSheet, url: url)
        }
    }
    // In eurem PDFKit-Wrapper für SwiftUI
    struct MopsPDFReaderView: UIViewRepresentable {
        let pdfURL: URL

        func makeUIView(context: Context) -> PDFView {
            let pdfView = PDFView()
            pdfView.document = PDFDocument(url: pdfURL)
            pdfView.autoScales = true
            return pdfView
        }

        func updateUIView(_ uiView: PDFView, context: Context) {
            // Eventuell Dokument aktualisieren, falls sich die URL ändert
        }
    }
}

// MARK: - PDF mit Sprung zur Fundstelle (Weg A: Wert im Text suchen + gelb markieren)

/// PDFKit-Hülle, die beim Laden nach den Begriffen sucht, zur ersten Fundstelle
/// springt und sie gelb markiert. Erster Begriff, der trifft, gewinnt.
struct PDFSuchView: UIViewRepresentable {
    let url: URL
    let suchbegriffe: [String]
    let onErgebnis: (Bool) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        let doc = PDFDocument(url: url)
        pdfView.document = doc
        context.coordinator.markiereTreffer(in: pdfView, doc: doc)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onErgebnis: onErgebnis, suchbegriffe: suchbegriffe)
    }

    final class Coordinator {
        let onErgebnis: (Bool) -> Void
        let suchbegriffe: [String]
        init(onErgebnis: @escaping (Bool) -> Void, suchbegriffe: [String]) {
            self.onErgebnis = onErgebnis
            self.suchbegriffe = suchbegriffe
        }

        func markiereTreffer(in view: PDFView, doc: PDFDocument?) {
            guard let doc else { DispatchQueue.main.async { self.onErgebnis(false) }; return }
            for begriff in suchbegriffe where !begriff.isEmpty {
                let treffer = doc.findString(begriff, withOptions: [.caseInsensitive])
                guard let sel = treffer.first else { continue }
                sel.color = .systemYellow
                for page in sel.pages {
                    let markierung = PDFAnnotation(bounds: sel.bounds(for: page),
                                                   forType: .highlight, withProperties: nil)
                    markierung.color = .systemYellow
                    page.addAnnotation(markierung)
                }
                DispatchQueue.main.async {
                    view.setCurrentSelection(sel, animate: true)
                    view.go(to: sel)
                    self.onErgebnis(true)
                }
                return
            }
            DispatchQueue.main.async { self.onErgebnis(false) }
        }
    }
}

/// Vorschau, die direkt zur Fundstelle springt und sie gelb markiert.
struct PDFTrefferView: View {
    let url: URL
    let suchbegriffe: [String]
    let titel: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var trefferGefunden: Bool?

    var body: some View {
        NavigationStack {
            PDFSuchView(url: url, suchbegriffe: suchbegriffe) { gefunden in
                trefferGefunden = gefunden
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                if trefferGefunden == false {
                    Text("Stelle nicht automatisch gefunden – bitte im PDF suchen.")
                        .font(.footnote)
                        .padding(8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.top, 8)
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showingShareSheet = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .teilenOderSpeichern(isPresented: $showingShareSheet, url: url)
        }
    }
}
