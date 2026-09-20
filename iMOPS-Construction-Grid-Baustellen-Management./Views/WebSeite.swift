import SwiftUI
import WebKit

// MARK: - WebSeite
//
// Die Brücke UIKit → SwiftUI: `WKWebView` ist Apples Web-Motor (wie Safari innen
// drin), aber ein UIKit-View. SwiftUI kennt ihn nicht direkt — darum verpacken wir
// ihn in ein `UIViewRepresentable`. Zwei Pflicht-Methoden:
//   makeUIView  — baut den View einmal.
//   updateUIView — füttert ihn mit Inhalt (hier: das HTML als Text).
//
// `loadHTMLString` lädt HTML direkt aus dem Speicher — kein Netz, kein Server. Unsere
// Wegweiser-Seiten tragen ihr CSS inline, also reicht das (offline auf der Baustelle).
struct WebSeite: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        // baseURL nil = keine externen Dateien; Web-Fonts fallen sauber auf System-Fonts zurück.
        web.loadHTMLString(html, baseURL: nil)
    }
}
