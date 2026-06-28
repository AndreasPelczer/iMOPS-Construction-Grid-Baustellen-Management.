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
                .sheet(isPresented: $showingShareSheet) {
                    LVShareSheet(url: url).ignoresSafeArea()
                }
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
