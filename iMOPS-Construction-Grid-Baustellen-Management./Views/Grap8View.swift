//
//  Grap8View.swift
//  iMOPS-Construction-Grid-Baustellen-Management.
//
//  Grap8 — die Kausalketten-Leinwand als Fenster in der App.
//
//  Die Leinwand ist eine Web-Anwendung (React Flow, Projekt `~/Projekte/grap8-canvas`),
//  gebaut nach `Grap8Web/` im Repo-Wurzelverzeichnis und dort als **Folder Reference**
//  ins Bundle kopiert. Kein SwiftUI-Nachbau: Zoom, Ziehen, Kabel, Anschlusspunkte und
//  Zyklusprüfung kommen fertig aus React Flow.
//
//  Schritt 1 zeigt die **Beispieldaten** der Leinwand. Es gibt bewusst *keine*
//  Brücke zwischen JavaScript und Swift und keinen Zugriff auf Core Data —
//  die Datenanbindung ist ein eigenes Kapitel.
//
//  ── Zwei Fallen, beide im Simulator nachgemessen ──────────────────────────────
//
//  1. **Ordner statt synchronisierter Gruppe.** Xcodes synchronisierte Gruppe klopft
//     Unterordner flach (nachgewiesen an `Resources/Knowledge`, siehe
//     `ExactMatchKnowledge.locateYAML`). Die Leinwand braucht `assets/` als echten
//     Unterordner, sonst findet `index.html` ihr Skript nicht. Darum liegt `Grap8Web`
//     außerhalb des Quellordners und ist als Folder Reference eingebunden.
//
//  2. **Eigenes Schema statt `file://`.** Der naheliegende Weg `loadFileURL(_:allowingReadAccessTo:)`
//     ergibt einen **weißen Schirm**: Vite baut `<script type="module">`, und ein Modul
//     hat über `file://` die Herkunft `null`. Die CORS-Prüfung verwirft es stillschweigend —
//     das Hauptdokument lädt sauber, `didFail` feuert nie, die Seite bleibt leer.
//     Darum wird das Bundle unter `grap8://leinwand/` ausgeliefert. Ein eigenes Schema
//     hat eine echte Herkunft, Module laden normal, und es geht kein Byte ins Netz —
//     alles kommt aus dem App-Bundle.
//

import SwiftUI
import WebKit
import os

private let logger = Logger(subsystem: "com.deadrabbit.imops", category: "Grap8")

// MARK: - Bildschirm

struct Grap8View: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ladefehler: String?

    var body: some View {
        NavigationStack {
            Group {
                if let ladefehler {
                    fehlerbox(ladefehler)
                } else {
                    Grap8WebView(ladefehler: $ladefehler)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("Grap8")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .tint(.orange)
                }
            }
        }
    }

    // Ein weißer Schirm sagt nichts. Wenn die Leinwand nicht lädt, soll dastehen warum.
    private func fehlerbox(_ text: String) -> some View {
        ContentUnavailableView {
            Label("Leinwand lädt nicht", systemImage: "square.on.square.dashed")
        } description: {
            Text(text)
        }
    }
}

// MARK: - Die Leinwand selbst

private struct Grap8WebView: UIViewRepresentable {

    /// Unterordner im App-Bundle — muss zum Namen der Folder Reference passen.
    static let ordner = "Grap8Web"
    /// Eigenes Schema. Darf kein von WebKit bekanntes sein (http, file, about …).
    static let schema = "grap8"
    static let startseite = URL(string: "\(schema)://leinwand/index.html")!

    @Binding var ladefehler: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let konfiguration = WKWebViewConfiguration()
        konfiguration.userContentController.addUserScript(Self.viewportSkript)

        // Das Bundle unter eigenem Schema ausliefern — siehe Falle 2 im Dateikopf.
        if let wurzel = Self.bundleWurzel() {
            konfiguration.setURLSchemeHandler(Grap8BundleHandler(wurzel: wurzel),
                                              forURLScheme: Self.schema)
        }

        let web = WKWebView(frame: .zero, configuration: konfiguration)
        web.navigationDelegate = context.coordinator
        // Safari → Entwickeln → Gerät: damit ein leerer Schirm untersuchbar ist.
        web.isInspectable = true
        // Zoom und Verschieben macht React Flow selbst. Die WKWebView darf nicht
        // zusätzlich scrollen, sonst kämpfen zwei Gestenerkenner um denselben Finger.
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.allowsBackForwardNavigationGestures = false
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        // Nur einmal laden — `updateUIView` läuft bei jedem Neuzeichnen.
        guard !context.coordinator.hatGeladen else { return }

        guard let wurzel = Self.bundleWurzel() else {
            melde("\(Self.ordner)/index.html liegt nicht im App-Bundle. "
                  + "Der Ordner muss als Folder Reference in „Copy Bundle Resources“ stehen.")
            return
        }

        context.coordinator.hatGeladen = true
        logger.info("Grap8 lädt aus dem Bundle: \(wurzel.path, privacy: .public)")
        web.load(URLRequest(url: Self.startseite))
    }

    /// Der `Grap8Web`-Ordner im Bundle — oder `nil`, wenn er nicht mitkopiert wurde.
    private static func bundleWurzel() -> URL? {
        Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: ordner)?
            .deletingLastPathComponent()
    }

    private func melde(_ text: String) {
        logger.error("\(text, privacy: .public)")
        // Nicht während des Zeichnens in den Zustand schreiben.
        DispatchQueue.main.async { ladefehler = text }
    }

    /// Verhindert, dass WebKit die ganze Seite mitzoomt — der Kneifgriff gehört der Leinwand.
    private static let viewportSkript = WKUserScript(
        source: """
        (function () {
          var m = document.querySelector('meta[name=viewport]');
          if (!m) { m = document.createElement('meta'); m.name = 'viewport'; document.head.appendChild(m); }
          m.setAttribute('content',
            'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover');
        })();
        """,
        injectionTime: .atDocumentEnd,
        forMainFrameOnly: true
    )

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let eltern: Grap8WebView
        var hatGeladen = false

        init(_ eltern: Grap8WebView) { self.eltern = eltern }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            logger.info("Grap8-Leinwand geladen.")
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            eltern.melde("Die Leinwand brach beim Laden ab: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            eltern.melde("Die Leinwand ließ sich nicht öffnen: \(error.localizedDescription)")
        }
    }
}

// MARK: - Auslieferung aus dem Bundle

/// Beantwortet `grap8://…`-Anfragen aus dem mitgelieferten `Grap8Web`-Ordner.
/// Rein lokal: was nicht im Ordner liegt, gibt es nicht — es wird nichts nachgeladen.
private final class Grap8BundleHandler: NSObject, WKURLSchemeHandler {

    private let wurzel: URL

    init(wurzel: URL) {
        self.wurzel = wurzel.standardizedFileURL
        super.init()
    }

    func webView(_ webView: WKWebView, start aufgabe: WKURLSchemeTask) {
        guard let url = aufgabe.request.url else {
            aufgabe.didFailWithError(URLError(.badURL))
            return
        }

        var pfad = url.path
        if pfad.isEmpty || pfad == "/" { pfad = "/index.html" }

        let datei = wurzel.appendingPathComponent(pfad).standardizedFileURL

        // Kein Ausbruch aus dem Ordner über „..“.
        guard datei.path.hasPrefix(wurzel.path + "/"), let daten = try? Data(contentsOf: datei) else {
            logger.error("Grap8: nicht im Bundle — \(pfad, privacy: .public)")
            aufgabe.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let antwort = URLResponse(url: url,
                                  mimeType: Self.typ(fuer: datei.pathExtension),
                                  expectedContentLength: daten.count,
                                  textEncodingName: "utf-8")
        aufgabe.didReceive(antwort)
        aufgabe.didReceive(daten)
        aufgabe.didFinish()
    }

    func webView(_ webView: WKWebView, stop aufgabe: WKURLSchemeTask) {
        // Alles wird synchron beantwortet — hier bleibt nichts abzubrechen.
    }

    /// WebKit prüft den Typ bei Modulen streng: ein `.js` mit falschem Typ wird verworfen.
    private static func typ(fuer endung: String) -> String {
        switch endung.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs":   return "text/javascript"
        case "css":         return "text/css"
        case "json":        return "application/json"
        case "svg":         return "image/svg+xml"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "woff2":       return "font/woff2"
        case "woff":        return "font/woff"
        case "map":         return "application/json"
        default:            return "application/octet-stream"
        }
    }
}

#Preview {
    Grap8View()
}
