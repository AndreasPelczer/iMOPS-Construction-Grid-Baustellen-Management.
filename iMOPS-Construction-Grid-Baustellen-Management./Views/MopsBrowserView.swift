import SwiftUI

// MARK: - MopsBrowserView (der Wegweiser IN der App)
//
// Zeigt die gebündelten Wegweiser-Seiten (Klickplan, Erklär-Mockups) — „iPad auf dem
// Schoß", offline. Die HTML-Dateien liegen im App-Paket unter Resources/Wegweiser/
// (genau wie die YAML-Wissensbasis unter Knowledge/). Wir lesen sie beim Öffnen,
// ziehen den Titel aus dem <title>-Tag und listen sie. Antippen → im WebView anzeigen.
//
// Neue Seite hinzufügen = einfach eine .html in den Wegweiser-Ordner legen; die Liste
// findet sie automatisch (kein Code-Anfassen).

struct WegweiserSeite: Identifiable {
    let id = UUID()
    let titel: String
    let html: String
}

struct MopsBrowserView: View {
    @State private var seiten: [WegweiserSeite] = []

    var body: some View {
        List {
            Section {
                ForEach(seiten) { seite in
                    NavigationLink {
                        WebSeite(html: seite.html)
                            .navigationTitle(seite.titel)
                            .navigationBarTitleDisplayMode(.inline)
                            .ignoresSafeArea(edges: .bottom)
                    } label: {
                        Label(seite.titel, systemImage: "doc.richtext")
                    }
                }
            } header: {
                Text("Klickpläne & Erklär-Seiten")
            } footer: {
                Text("So versteht man den Mops, ohne Erklärung — durchklicken. Offline, direkt in der App.")
            }

            if seiten.isEmpty {
                Text("Keine Wegweiser-Seiten gefunden.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mops-Wegweiser")
        .task { if seiten.isEmpty { seiten = Self.ladeSeiten() } }
    }

    /// Die gebündelten Wegweiser-.html lesen. Hinweis: synchronisierte Xcode-Ordner
    /// flachen den `Wegweiser`-Unterordner ins Bundle-Wurzelverzeichnis ab — darum
    /// `subdirectory: nil`. Das Grap8-Web liegt im eigenen Unterordner `Grap8Web/`
    /// und wird hier nicht erfasst; ein evtl. `index.html` filtern wir sicherheitshalber.
    /// Klickplan zuerst, Rest alphabetisch.
    static func ladeSeiten() -> [WegweiserSeite] {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "html", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.lowercased() != "index.html" }
        let seiten = urls.compactMap { url -> WegweiserSeite? in
            guard let html = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            let titel = titelAus(html) ?? url.deletingPathExtension().lastPathComponent
            return WegweiserSeite(titel: titel, html: html)
        }
        return seiten.sorted { a, b in
            let ak = a.titel.localizedCaseInsensitiveContains("klickplan")
            let bk = b.titel.localizedCaseInsensitiveContains("klickplan")
            if ak != bk { return ak }                 // Klickplan nach oben
            return a.titel.localizedCompare(b.titel) == .orderedAscending
        }
    }

    private static func titelAus(_ html: String) -> String? {
        guard let start = html.range(of: "<title>"),
              let ende = html.range(of: "</title>"),
              start.upperBound <= ende.lowerBound else { return nil }
        let t = html[start.upperBound..<ende.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
