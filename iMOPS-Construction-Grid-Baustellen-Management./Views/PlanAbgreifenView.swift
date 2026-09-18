import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import PDFKit
#endif

/// „Plan abgreifen": einen Plan (PDF/Bild) anzeigen, den Maßstab an EINER bekannten Strecke
/// setzen, dann das Haus (oder eine Fläche) nachtippen → Fläche/Länge in Metern. So arbeitet
/// die Firma von Hand mit dem Maßstab-Lineal — hier digital. Kein Architekten-DXF nötig.
struct PlanAbgreifenView: View {
    enum Modus { case kalibrieren, flaeche }

    @State private var bild: UIImage?
    @State private var modus: Modus = .kalibrieren
    @State private var kalibPunkte: [CGPoint] = []
    @State private var flaechePunkte: [CGPoint] = []
    @State private var kalibMeterText = ""
    @State private var zeigePicker = false
    @State private var meldung: String?

    private var meterProEinheit: Double? {
        guard kalibPunkte.count == 2,
              let m = Double(kalibMeterText.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return PlanMass.meterProEinheit(kalibA: kalibPunkte[0], kalibB: kalibPunkte[1], echteMeter: m)
    }

    private var masse: PlanMass.Masse? {
        guard let mpe = meterProEinheit, flaechePunkte.count >= 3 else { return nil }
        return PlanMass.masse(polygon: flaechePunkte, meterProEinheit: mpe)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let bild {
                planFlaeche(bild)
                steuerung
            } else {
                startLeer
            }
        }
        .navigationTitle("Plan abgreifen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if bild != nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { zeigePicker = true } label: { Image(systemName: "photo.badge.plus") }
                }
            }
        }
        .fileImporter(isPresented: $zeigePicker,
                      allowedContentTypes: [.pdf, .image, .data]) { r in ladePlan(r) }
    }

    // MARK: - Leerzustand

    private var startLeer: some View {
        VStack(spacing: 16) {
            Image(systemName: "ruler").font(.system(size: 44)).foregroundStyle(.orange)
            Text("Plan wählen (PDF oder Foto)").font(.headline)
            Text("Dann: Maßstab an einer bekannten Strecke setzen, danach das Haus nachtippen.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { zeigePicker = true } label: {
                Label("Plan wählen", systemImage: "doc.badge.plus")
            }.buttonStyle(.borderedProminent).tint(.orange)
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Plan mit Tipp-Punkten

    private func planFlaeche(_ bild: UIImage) -> some View {
        let aspect = bild.size.width / max(bild.size.height, 1)
        return GeometryReader { geo in
            let w = geo.size.width
            let h = min(geo.size.height, w / max(aspect, 0.01))
            ZStack(alignment: .topLeading) {
                Image(uiImage: bild).resizable().frame(width: w, height: h)
                Canvas { ctx, _ in zeichne(ctx) }.frame(width: w, height: h).allowsHitTesting(false)
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { g in tippe(g.location, in: CGSize(width: w, height: h)) })
        }
    }

    private func zeichne(_ ctx: GraphicsContext) {
        // Kalibrier-Strecke (blau).
        if kalibPunkte.count == 2 {
            var p = Path(); p.move(to: kalibPunkte[0]); p.addLine(to: kalibPunkte[1])
            ctx.stroke(p, with: .color(.blue), lineWidth: 2)
        }
        for pt in kalibPunkte { ctx.fill(kreis(pt), with: .color(.blue)) }
        // Flächen-Polygon (orange).
        if flaechePunkte.count >= 2 {
            var p = Path(); p.move(to: flaechePunkte[0])
            for q in flaechePunkte.dropFirst() { p.addLine(to: q) }
            if flaechePunkte.count >= 3 { p.closeSubpath() }
            ctx.stroke(p, with: .color(.orange), lineWidth: 2)
            if flaechePunkte.count >= 3 { ctx.fill(p, with: .color(.orange.opacity(0.18))) }
        }
        for pt in flaechePunkte { ctx.fill(kreis(pt), with: .color(.orange)) }
    }

    private func kreis(_ p: CGPoint) -> Path {
        Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10))
    }

    private func tippe(_ p: CGPoint, in size: CGSize) {
        guard p.x >= 0, p.y >= 0, p.x <= size.width, p.y <= size.height else { return }
        switch modus {
        case .kalibrieren:
            if kalibPunkte.count >= 2 { kalibPunkte = [] }
            kalibPunkte.append(p)
        case .flaeche:
            flaechePunkte.append(p)
        }
    }

    // MARK: - Steuerung + Ergebnis

    private var steuerung: some View {
        VStack(spacing: 10) {
            Picker("Modus", selection: $modus) {
                Text("1 · Maßstab").tag(Modus.kalibrieren)
                Text("2 · Fläche (Haus)").tag(Modus.flaeche)
            }.pickerStyle(.segmented)

            if modus == .kalibrieren {
                HStack {
                    Text("Zwei Punkte antippen, echte Länge:")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    TextField("z. B. 10", text: $kalibMeterText)
                        .frame(width: 70).multilineTextAlignment(.trailing)
                        #if !os(macOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("m").foregroundStyle(.secondary)
                }
                if kalibPunkte.count == 2, meterProEinheit != nil {
                    Label("Maßstab gesetzt — jetzt auf Modus 2 (Fläche) wechseln und das Haus nachtippen.",
                          systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                } else {
                    Text("\(kalibPunkte.count)/2 Punkten gesetzt.").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text(meterProEinheit == nil ? "Erst den Maßstab setzen!" : "Ecken des Hauses der Reihe nach antippen.")
                        .font(.caption).foregroundStyle(meterProEinheit == nil ? .orange : .secondary)
                    Spacer()
                    Button("Letzten Punkt zurück") { if !flaechePunkte.isEmpty { flaechePunkte.removeLast() } }
                        .font(.caption).disabled(flaechePunkte.isEmpty)
                }
            }

            if let m = masse { ergebnis(m) }
        }
        .padding()
        .background(.thinMaterial)
    }

    private func ergebnis(_ m: PlanMass.Masse) -> some View {
        VStack(spacing: 6) {
            HStack {
                Label("Fläche", systemImage: "square.dashed").foregroundStyle(.orange)
                Spacer()
                Text("\(z(m.flaecheM2, 1)) m²").font(.title3.bold().monospacedDigit()).foregroundStyle(.orange)
            }
            HStack {
                Text("≈ \(z(m.laengeM, 1)) × \(z(m.breiteM, 1)) m · Umfang \(z(m.umfangM, 1)) m")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                NavigationLink {
                    BaugrubeRechnerView(vorgabeLaenge: m.laengeM, vorgabeBreite: m.breiteM)
                } label: {
                    Label("→ Baugrube", systemImage: "arrow.up.bin")
                }.font(.caption.bold())
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Laden

    private func ladePlan(_ r: Result<URL, Error>) {
        guard case .success(let url) = r else { return }
        let braucht = url.startAccessingSecurityScopedResource()
        defer { if braucht { url.stopAccessingSecurityScopedResource() } }
        kalibPunkte = []; flaechePunkte = []; modus = .kalibrieren
        #if canImport(UIKit)
        if url.pathExtension.lowercased() == "pdf" {
            bild = Self.rendere(pdf: url)
        } else if let d = try? Data(contentsOf: url) {
            bild = UIImage(data: d)
        }
        if bild == nil { meldung = "Konnte den Plan nicht laden." }
        #endif
    }

    #if canImport(UIKit)
    /// Erste PDF-Seite scharf als Bild rendern (2× für gute Tipp-Genauigkeit).
    static func rendere(pdf url: URL) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        let rect = page.bounds(for: .mediaBox)
        let skala: CGFloat = 2
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: rect.width * skala, height: rect.height * skala),
                                               format: format)
        return renderer.image { c in
            UIColor.white.set(); c.fill(CGRect(origin: .zero, size: CGSize(width: rect.width * skala, height: rect.height * skala)))
            let cg = c.cgContext
            cg.translateBy(x: 0, y: rect.height * skala)
            cg.scaleBy(x: skala, y: -skala)
            page.draw(with: .mediaBox, to: cg)
        }
    }
    #endif

    private func z(_ d: Double, _ s: Int) -> String {
        d.formatted(.number.precision(.fractionLength(0...s)).grouping(.automatic))
    }
}
