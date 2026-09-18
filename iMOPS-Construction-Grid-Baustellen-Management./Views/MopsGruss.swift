import SwiftUI
import UIKit

//  Der kleine Gruß: der Bau-Mops trottet für ~1 Sekunde ins Bild und winkt sich
//  wieder raus — wenn der Canvas aufgeht, oder wenn iMOPS eine Datei umwandelt/einliest.
//
//  Die Frames sind ein im Browser gerendeter Laufzyklus des rigged GLB
//  (Resources/MopsGruss/mops_00…27.png, transparent). Kein 3D-Runtime nötig —
//  eine schlichte Bildfolge, die überall läuft.

// MARK: - Auslöser (von überall: MopsGruss.shared.winke())

/// Ein Klopfzeichen, das der Root-Lauscher aufnimmt und den Gruß spielt.
/// So braucht jede Import-/Umwandel-Stelle nur EINE Zeile: `MopsGruss.shared.winke()`.
enum MopsGruss {
    static let name = Notification.Name("iMOPS.mopsGruss")

    /// Spielt den Gruß (irgendein sichtbarer `.mopsGrussLauscht()`-Bildschirm zeigt ihn).
    static func winke() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil)
        }
    }
}

// MARK: - Die Bildfolge (einmal geladen, dann geteilt)

enum MopsGrussBilder {
    static let frames: [UIImage] = {
        (0..<28).compactMap { i in
            let name = String(format: "mops_%02d", i)
            let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "MopsGruss")
                   ?? Bundle.main.url(forResource: name, withExtension: "png")
            return url.flatMap { UIImage(contentsOfFile: $0.path) }
        }
    }()
}

// MARK: - Die Animation

/// Spielt den Laufzyklus EINMAL: einblenden, ein paar Schritte nach rechts trotten,
/// ausblenden — dann `abgeschlossen()`. Blockiert nie die Bedienung (kein Hit-Testing).
struct MopsGrussView: View {
    var abgeschlossen: () -> Void

    @State private var index = 0
    @State private var sichtbar = false     // Ein-/Ausblenden (Deckkraft + kurzer Pop)
    @State private var xFrac = 0.60         // trottet von rechts (0.60) nach links (0.40)
    private let frames = MopsGrussBilder.frames
    private let fps: Double = 27

    var body: some View {
        GeometryReader { geo in
            Group {
                if frames.indices.contains(index) {
                    Image(uiImage: frames[index])
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 180)
                        .scaleEffect(sichtbar ? 1 : 0.86)
                        .opacity(sichtbar ? 1 : 0)
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
                        .position(x: geo.size.width * xFrac, y: geo.size.height * 0.62)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: starte)
    }

    private func starte() {
        guard !frames.isEmpty else { abgeschlossen(); return }
        let laufDauer = Double(frames.count) / fps          // ~1 s
        withAnimation(.easeOut(duration: 0.2)) { sichtbar = true }        // schnell rein, kein Mitwachsen
        withAnimation(.linear(duration: laufDauer)) { xFrac = 0.40 }      // gleichmäßig nach links trotten
        Task { @MainActor in
            for i in frames.indices {
                index = i
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000 / fps))
            }
            withAnimation(.easeIn(duration: 0.22)) { sichtbar = false }   // nur ausblenden, nicht zurückspringen
            try? await Task.sleep(nanoseconds: 240_000_000)
            abgeschlossen()
        }
    }
}

// MARK: - Wirt: legt den Gruß über den Inhalt, wenn ein Spiel-Token gesetzt ist

private struct MopsGrussWirt: ViewModifier {
    @Binding var spielId: UUID?
    func body(content: Content) -> some View {
        content.overlay {
            if let id = spielId {
                MopsGrussView { spielId = nil }
                    .id(id)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Öffentliche Anwendungen

extension View {
    /// Spielt den Gruß EINMAL, wenn diese Ansicht erscheint (z. B. der Canvas).
    func mopsGrussBeiErscheinen() -> some View {
        modifier(MopsGrussBeiErscheinen())
    }

    /// Lauscht auf `MopsGruss.winke()` und spielt den Gruß dann hier.
    /// Einmal weit oben einhängen (Root) — fängt Umwandeln/Einlesen von überall.
    func mopsGrussLauscht() -> some View {
        modifier(MopsGrussLauscht())
    }
}

private struct MopsGrussBeiErscheinen: ViewModifier {
    @State private var spielId: UUID?
    func body(content: Content) -> some View {
        content
            .modifier(MopsGrussWirt(spielId: $spielId))
            .onAppear { if spielId == nil { spielId = UUID() } }
    }
}

private struct MopsGrussLauscht: ViewModifier {
    @State private var spielId: UUID?
    func body(content: Content) -> some View {
        content
            .modifier(MopsGrussWirt(spielId: $spielId))
            .onReceive(NotificationCenter.default.publisher(for: MopsGruss.name)) { _ in
                spielId = UUID()
            }
    }
}
