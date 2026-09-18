import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
import PDFKit
#endif

/// Antwort von `POST /gelaendebruecke/grundstueck` — Geometrie zum Platzieren der Hauslage
/// (ohne Aushubrechnung): Gelände-Ausdehnung + Grundstücksgrenzen.
struct GrundstueckInfo: Codable {
    struct Bbox: Codable { let min_x, min_y, max_x, max_y: Double }
    let bbox: Bbox
    let gelaende_min: Double
    let gelaende_max: Double
    let n_hoehen: Int
    let grenzlinien: [[[Double]]]   // Liste von Zügen; jeder Zug = Liste von [x, y]
    let meldung: String?
}

/// (Welle 7, Schritt 2b) Der geparkte Rest der Geländebrücke, jetzt fertig: liegt das Haus
/// NICHT in der Vermessungs-DXF (der Normalfall — die Architektin liefert es nur auf dem PDF),
/// zeigt die App Grundstück + Gelände, der Nutzer legt (nach Augenmaß) den **PDF-Lageplan**
/// drunter, richtet ihn aus, schiebt ein maßstäbliches **Haus-Rechteck** drauf — und dessen
/// Ecken gehen als `footprint` (UTM) an `/calculate`. So wird ein haus-loser Plan rechenbar.
struct HauslagePlatzierenView: View {
    let dxfData: Data
    /// Originaler Dateiname. Die Box entscheidet an der Endung, ob sie DWG->DXF wandelt.
    var dateiname: String = "upload.dxf"
    /// OK-Bodenplatte laut Plan (m ü. NN), aus dem Karten-Feld durchgereicht. nil → Auto.
    var fixOkbp: Double? = nil
    /// Rückgabe des fertig gerechneten Ergebnisses an die Geländebrücke-Karte.
    var onErgebnis: (GelaendeResult) -> Void = { _ in }

    enum Modus: String, CaseIterable { case ansicht = "Ansicht", plan = "Plan", haus = "Haus" }

    @Environment(\.dismiss) private var dismiss
    @State private var info: GrundstueckInfo?
    @State private var fehler: String?
    @State private var laedt = true

    @State private var modus: Modus = .haus
    @State private var canvasSize: CGSize = .zero

    // Ansicht (Zoom/Pan der ganzen Zeichnung)
    @State private var viewScale: CGFloat = 1
    @State private var viewOffset: CGSize = .zero
    @GestureState private var dragLive: CGSize = .zero
    @GestureState private var magLive: CGFloat = 1

    // PDF-Lageplan (nach Augenmaß ausgerichtet)
    #if canImport(UIKit)
    @State private var pdfBild: UIImage?
    #endif
    @State private var pdfOffset: CGSize = .zero
    @State private var pdfScale: CGFloat = 1
    @State private var pdfWinkel: Double = 0        // Grad
    @State private var pdfDeckkraft: Double = 0.6
    @State private var zeigePDFPicker = false

    // Haus-Rechteck (in UTM)
    @State private var hausX = 0.0
    @State private var hausY = 0.0
    @State private var hausLText = "9.50"
    @State private var hausBText = "8.00"
    @State private var hausWinkel = 0.0             // Grad

    @State private var rechnet = false
    @State private var rechenFehler: String?

    var body: some View {
        NavigationStack {
            Group {
                if laedt {
                    ProgressView("Grundstück wird geladen …").frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let fehler {
                    ContentUnavailableView("Konnte nicht laden", systemImage: "exclamationmark.triangle",
                                           description: Text(fehler))
                } else if let info {
                    inhalt(info)
                }
            }
            .navigationTitle("Hauslage platzieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() }.tint(.orange) } }
            #if canImport(UIKit)
            .fileImporter(isPresented: $zeigePDFPicker,
                          allowedContentTypes: [.pdf, .image, .data]) { r in ladePDF(r) }
            #endif
        }
        .presentationSizing(.page)
        .task { await ladeGrundstueck() }
    }

    // MARK: - Inhalt

    @ViewBuilder
    private func inhalt(_ info: GrundstueckInfo) -> some View {
        VStack(spacing: 10) {
            Text("Gelände \(f2(info.gelaende_min))–\(f2(info.gelaende_max)) m · \(info.n_hoehen) Höhenpunkte · \(info.grenzlinien.count) Grenzzüge")
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            plotFlaeche(info)
                .frame(maxWidth: .infinity, minHeight: 300)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Picker("Modus", selection: $modus) {
                ForEach(Modus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            modusSteuerung(info)

            HStack(spacing: 12) {
                Image(systemName: "house.fill").foregroundStyle(.orange)
                Text("Haus \(f1(hausL)) × \(f1(hausB)) m").font(.subheadline.bold())
                Spacer()
                Text("≈ \(f1(hausL * hausB)) m²").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(10).background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            if let rechenFehler {
                Text(rechenFehler).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            rechnenKnopf(info)
        }
        .padding()
    }

    // MARK: - Zeichenfläche (Zoom/Pan + PDF + DXF + Haus)

    private func plotFlaeche(_ info: GrundstueckInfo) -> some View {
        GeometryReader { geo in
            let effScale = viewScale * (modus == .ansicht ? magLive : 1)
            let effOffset = CGSize(width: viewOffset.width + (modus == .ansicht ? dragLive.width : 0),
                                   height: viewOffset.height + (modus == .ansicht ? dragLive.height : 0))
            let pOff = CGSize(width: pdfOffset.width + (modus == .plan ? dragLive.width : 0),
                              height: pdfOffset.height + (modus == .plan ? dragLive.height : 0))
            let pScale = pdfScale * (modus == .plan ? magLive : 1)

            ZStack {
                #if canImport(UIKit)
                if let pdfBild {
                    Image(uiImage: pdfBild).resizable().scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(pScale).rotationEffect(.degrees(pdfWinkel)).offset(pOff)
                        .opacity(pdfDeckkraft)
                        .allowsHitTesting(false)
                }
                #endif
                Canvas { ctx, _ in zeichne(ctx, info: info, size: geo.size) }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(effScale)
            .offset(effOffset)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(dragG(size: geo.size).simultaneously(with: magG))
            .onAppear {
                canvasSize = geo.size
                if hausX == 0, hausY == 0 {
                    hausX = (info.bbox.min_x + info.bbox.max_x) / 2
                    hausY = (info.bbox.min_y + info.bbox.max_y) / 2
                }
            }
            .onChange(of: geo.size) { _, s in canvasSize = s }
        }
    }

    private func dragG(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragLive) { v, s, _ in if modus != .haus { s = v.translation } }
            .onEnded { v in
                switch modus {
                case .ansicht:
                    viewOffset = CGSize(width: viewOffset.width + v.translation.width,
                                        height: viewOffset.height + v.translation.height)
                case .plan:
                    pdfOffset = CGSize(width: pdfOffset.width + v.translation.width,
                                       height: pdfOffset.height + v.translation.height)
                case .haus:
                    if let (x, y) = screenToUTM(v.location, size: size) { hausX = x; hausY = y }
                }
            }
    }

    private var magG: some Gesture {
        MagnificationGesture()
            .updating($magLive) { v, s, _ in if modus != .haus { s = v } }
            .onEnded { v in
                switch modus {
                case .ansicht: viewScale = max(0.3, min(8, viewScale * v))
                case .plan:    pdfScale = max(0.1, min(12, pdfScale * v))
                case .haus:    break
                }
            }
    }

    private func zeichne(_ ctx: GraphicsContext, info: GrundstueckInfo, size: CGSize) {
        let t = GeoTransform.make(size: size, info: info)

        // Gelände-Ausdehnung (wo Höhen liegen → nur da wird gerechnet)
        let a = t.toScreen(info.bbox.min_x, info.bbox.min_y)
        let b = t.toScreen(info.bbox.max_x, info.bbox.max_y)
        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
        ctx.stroke(Path(rect), with: .color(.orange.opacity(0.35)), lineWidth: 1)

        // Grundstücksgrenzen
        for zug in info.grenzlinien {
            var path = Path(); var erster = true
            for p in zug where p.count >= 2 {
                let pt = t.toScreen(p[0], p[1])
                if erster { path.move(to: pt); erster = false } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(.primary), lineWidth: 1.5)
        }

        // Haus-Rechteck
        let ecken = hausEckenUTM().map { t.toScreen($0.0, $0.1) }
        if ecken.count == 4 {
            var p = Path(); p.move(to: ecken[0])
            for q in ecken.dropFirst() { p.addLine(to: q) }
            p.closeSubpath()
            ctx.fill(p, with: .color(.orange.opacity(0.30)))
            ctx.stroke(p, with: .color(.orange), lineWidth: 2)
            for e in ecken { ctx.fill(Path(ellipseIn: CGRect(x: e.x - 4, y: e.y - 4, width: 8, height: 8)), with: .color(.orange)) }
        }
    }

    // MARK: - Modus-Steuerung

    @ViewBuilder
    private func modusSteuerung(_ info: GrundstueckInfo) -> some View {
        switch modus {
        case .ansicht:
            HStack {
                Text("Ziehen = schieben · zwei Finger = zoomen").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Einpassen") { viewScale = 1; viewOffset = .zero }.font(.caption)
            }
        case .plan:
            VStack(spacing: 8) {
                #if canImport(UIKit)
                if pdfBild == nil {
                    Button { zeigePDFPicker = true } label: {
                        Label("Lageplan (PDF/Foto) wählen", systemImage: "doc.badge.plus")
                    }.buttonStyle(.borderedProminent).tint(.orange)
                    Text("Lageplan mit Hausstellung wählen, dann nach Augenmaß ziehen/pinchen/drehen, bis er auf den Grenzen liegt.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack {
                        Text("Ziehen/pinchen = ausrichten").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Plan wechseln") { zeigePDFPicker = true }.font(.caption)
                    }
                    HStack {
                        Image(systemName: "rotate.right").font(.caption)
                        Slider(value: $pdfWinkel, in: -180...180)
                        Text("\(Int(pdfWinkel))°").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                    }
                    HStack {
                        Image(systemName: "circle.lefthalf.filled").font(.caption)
                        Slider(value: $pdfDeckkraft, in: 0.1...1.0)
                        Text("\(Int(pdfDeckkraft * 100))%").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                    }
                }
                #else
                Text("PDF-Hintergrund nur auf iPad/iPhone.").font(.caption).foregroundStyle(.secondary)
                #endif
            }
        case .haus:
            VStack(spacing: 8) {
                HStack {
                    Text("Antippen = Haus-Mitte setzen").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(spacing: 10) {
                    masseFeld("Länge", $hausLText)
                    masseFeld("Breite", $hausBText)
                }
                HStack {
                    Image(systemName: "rotate.right").font(.caption)
                    Slider(value: $hausWinkel, in: 0...180)
                    Text("\(Int(hausWinkel))°").font(.caption.monospacedDigit()).frame(width: 40, alignment: .trailing)
                }
            }
        }
    }

    private func masseFeld(_ label: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("m", text: text)
                .frame(width: 60).multilineTextAlignment(.trailing)
                #if !os(macOS)
                .keyboardType(.decimalPad)
                #endif
            Text("m").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func rechnenKnopf(_ info: GrundstueckInfo) -> some View {
        Button { Task { await rechne(info) } } label: {
            HStack {
                if rechnet { ProgressView().tint(.white) }
                Text(rechnet ? "Rechne Cut/Fill …" : "Aushub rechnen").font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(hausGueltig ? Color.orange : Color.gray.opacity(0.4))
            .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!hausGueltig || rechnet)
    }

    // MARK: - Geometrie

    private var hausL: Double { Double(hausLText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var hausB: Double { Double(hausBText.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    private var hausGueltig: Bool { hausL > 0 && hausB > 0 }

    /// Die 4 Haus-Ecken in UTM: Rechteck L×B um (hausX,hausY), um `hausWinkel` gedreht.
    private func hausEckenUTM() -> [(Double, Double)] {
        let hl = hausL / 2, hb = hausB / 2
        let r = hausWinkel * .pi / 180
        let cs = cos(r), sn = sin(r)
        let lokal: [(Double, Double)] = [(-hb, -hl), (hb, -hl), (hb, hl), (-hb, hl)]
        return lokal.map { (dx, dy) in
            (hausX + dx * cs - dy * sn, hausY + dx * sn + dy * cs)
        }
    }

    /// Bildschirm-Tap → UTM (View-Transform rückgängig, dann Basis-Transform rückgängig).
    private func screenToUTM(_ loc: CGPoint, size: CGSize) -> (Double, Double)? {
        guard size.width > 0, viewScale > 0 else { return nil }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let base = CGPoint(x: (loc.x - viewOffset.width - center.x) / viewScale + center.x,
                           y: (loc.y - viewOffset.height - center.y) / viewScale + center.y)
        guard let info else { return nil }
        return GeoTransform.make(size: size, info: info).toUTM(base)
    }

    // MARK: - PDF laden

    #if canImport(UIKit)
    private func ladePDF(_ r: Result<URL, Error>) {
        guard case .success(let url) = r else { return }
        let braucht = url.startAccessingSecurityScopedResource()
        defer { if braucht { url.stopAccessingSecurityScopedResource() } }
        pdfOffset = .zero; pdfScale = 1; pdfWinkel = 0
        if url.pathExtension.lowercased() == "pdf" {
            pdfBild = Self.rendere(pdf: url)
        } else if let d = try? Data(contentsOf: url) {
            pdfBild = UIImage(data: d)
        }
    }

    /// Erste PDF-Seite scharf als Bild (2× für Lesbarkeit beim Zoomen).
    static func rendere(pdf url: URL) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        let rect = page.bounds(for: .mediaBox)
        let skala: CGFloat = 2
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: rect.width * skala, height: rect.height * skala), format: format)
        return renderer.image { c in
            UIColor.white.set(); c.fill(CGRect(origin: .zero, size: CGSize(width: rect.width * skala, height: rect.height * skala)))
            let cg = c.cgContext
            cg.translateBy(x: 0, y: rect.height * skala)
            cg.scaleBy(x: skala, y: -skala)
            page.draw(with: .mediaBox, to: cg)
        }
    }
    #endif

    // MARK: - Server

    private func ladeGrundstueck() async {
        do {
            let data = try await post(pfad: "/gelaendebruecke/grundstueck", footprint: nil)
            info = try JSONDecoder().decode(GrundstueckInfo.self, from: data)
            laedt = false
        } catch let e as ServerFehler {
            fehler = e.text; laedt = false
        } catch {
            fehler = error.localizedDescription; laedt = false
        }
    }

    private func rechne(_ info: GrundstueckInfo) async {
        rechnet = true; rechenFehler = nil
        let poly = hausEckenUTM()
        let json = "[" + poly.map { "[\(String(format: "%.3f", $0.0)),\(String(format: "%.3f", $0.1))]" }.joined(separator: ",") + "]"
        do {
            let data = try await post(pfad: "/gelaendebruecke/calculate", footprint: json)
            let result = try JSONDecoder().decode(GelaendeResult.self, from: data)
            rechnet = false
            onErgebnis(result)
            dismiss()
        } catch let e as ServerFehler {
            rechenFehler = e.text; rechnet = false
        } catch {
            rechenFehler = "Antwort nicht lesbar: \(error.localizedDescription)"; rechnet = false
        }
    }

    private struct ServerFehler: Error { let text: String }

    /// Multipart-POST der DXF an die Box, optional mit `footprint`-Formfeld und `fix_okbp`-Query.
    private func post(pfad: String, footprint: String?) async throws -> Data {
        var urlString = MopsConfig.host + pfad
        if pfad.hasSuffix("/calculate"), let okbp = fixOkbp, okbp > 0 {
            urlString += "?fix_okbp=\(okbp)"
        }
        guard let url = URL(string: urlString) else { throw ServerFehler(text: "Ungültige Server-URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dxf_file\"; filename=\"\(dateiname)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(dxfData)
        body.append("\r\n".data(using: .utf8)!)
        if let footprint {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"footprint\"\r\n\r\n".data(using: .utf8)!)
            body.append(footprint.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        let (data, resp) = try await URLSession.shared.upload(for: request, from: body)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = obj["detail"] as? String {
                throw ServerFehler(text: detail)
            }
            throw ServerFehler(text: "Server-Fehler (\(http.statusCode))")
        }
        return data
    }

    private func f1(_ d: Double) -> String { String(format: "%.1f", d) }
    private func f2(_ d: Double) -> String { String(format: "%.2f", d) }
}

/// Isotrope Abbildung UTM ↔ Bildschirm (gleicher Maßstab in X und Y). Für Zeichnen UND fürs
/// Zurückrechnen der Tap-Position — derselbe Maßstab in beide Richtungen.
private struct GeoTransform {
    let s: CGFloat
    let offX: CGFloat
    let offY: CGFloat
    let minX: Double
    let minY: Double
    let height: CGFloat

    func toScreen(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: offX + CGFloat(x - minX) * s,
                y: height - offY - CGFloat(y - minY) * s)   // Y nach oben
    }

    func toUTM(_ p: CGPoint) -> (Double, Double) {
        guard s > 0 else { return (minX, minY) }
        let x = Double((p.x - offX) / s) + minX
        let y = Double((height - offY - p.y) / s) + minY
        return (x, y)
    }

    static func make(size: CGSize, info: GrundstueckInfo) -> GeoTransform {
        var xs: [Double] = [info.bbox.min_x, info.bbox.max_x]
        var ys: [Double] = [info.bbox.min_y, info.bbox.max_y]
        for zug in info.grenzlinien {
            for p in zug where p.count >= 2 { xs.append(p[0]); ys.append(p[1]) }
        }
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        let w = max(maxX - minX, 0.001), h = max(maxY - minY, 0.001)
        let pad: CGFloat = 20
        let s = min((size.width - 2 * pad) / CGFloat(w), (size.height - 2 * pad) / CGFloat(h))
        let offX = (size.width - CGFloat(w) * s) / 2
        let offY = (size.height - CGFloat(h) * s) / 2
        return GeoTransform(s: s, offX: offX, offY: offY, minX: minX, minY: minY, height: size.height)
    }
}
