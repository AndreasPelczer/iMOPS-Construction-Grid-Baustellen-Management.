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

// MARK: - PDF-Sprung zur Quelle (Weg B: gespeicherte Seite; Weg A: Wert im Text markieren)

enum PDFSuchErgebnis { case markiert, nurSeite, nichts }

/// PDFKit-Hülle, die beim Laden zur Quelle springt:
/// 1. Ist die Seite bekannt (Weg B), dorthin springen und dort den Wert gelb markieren.
/// 2. Sonst das ganze PDF nach dem Wert durchsuchen (Weg A) und markieren.
/// 3. Findet sich nichts (z.B. errechnete Summe ohne bekannte Seite): melden.
struct PDFSuchView: UIViewRepresentable {
    let url: URL
    let suchbegriffe: [String]
    let seite: Int?
    let onErgebnis: (PDFSuchErgebnis) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        let doc = PDFDocument(url: url)
        pdfView.document = doc
        context.coordinator.springe(in: pdfView, doc: doc)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onErgebnis: onErgebnis, suchbegriffe: suchbegriffe, seite: seite)
    }

    final class Coordinator {
        let onErgebnis: (PDFSuchErgebnis) -> Void
        let suchbegriffe: [String]
        let seite: Int?
        init(onErgebnis: @escaping (PDFSuchErgebnis) -> Void, suchbegriffe: [String], seite: Int?) {
            self.onErgebnis = onErgebnis
            self.suchbegriffe = suchbegriffe
            self.seite = seite
        }

        private func markiere(_ sel: PDFSelection, in view: PDFView) {
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
                self.onErgebnis(.markiert)
            }
        }

        func springe(in view: PDFView, doc: PDFDocument?) {
            guard let doc else { DispatchQueue.main.async { self.onErgebnis(.nichts) }; return }

            // Weg B: bekannte Seite ist die Wahrheit — dorthin, und dort den Wert markieren.
            if let seite, seite >= 1, seite <= doc.pageCount, let page = doc.page(at: seite - 1) {
                for begriff in suchbegriffe where !begriff.isEmpty {
                    let treffer = doc.findString(begriff, withOptions: [.caseInsensitive])
                    if let sel = treffer.first(where: { $0.pages.contains(page) }) {
                        markiere(sel, in: view); return
                    }
                }
                // Kein Text-Treffer auf der Seite (z.B. errechnete Summe): einfach die Seite zeigen.
                DispatchQueue.main.async { view.go(to: page); self.onErgebnis(.nurSeite) }
                return
            }

            // Weg A: keine Seite bekannt — ganzes PDF nach dem Wert durchsuchen.
            for begriff in suchbegriffe where !begriff.isEmpty {
                let treffer = doc.findString(begriff, withOptions: [.caseInsensitive])
                if let sel = treffer.first { markiere(sel, in: view); return }
            }
            DispatchQueue.main.async { self.onErgebnis(.nichts) }
        }
    }
}

/// Vorschau, die direkt zur Quelle springt (Seite oder Fundstelle) und markiert.
struct PDFTrefferView: View {
    let url: URL
    let suchbegriffe: [String]
    let seite: Int?
    let titel: String
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var ergebnis: PDFSuchErgebnis?

    private var hinweis: String? {
        switch ergebnis {
        case .nichts: return "Stelle nicht gefunden – bitte im PDF suchen."
        case .nurSeite: return "Seite \(seite ?? 0) – Wert ist eine errechnete Summe, nicht einzeln markierbar."
        default: return nil
        }
    }

    var body: some View {
        NavigationStack {
            PDFSuchView(url: url, suchbegriffe: suchbegriffe, seite: seite) { erg in
                ergebnis = erg
            }
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                if let hinweis {
                    Text(hinweis)
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
