import SwiftUI

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

/// (Schritt 2b, kleinste Scheibe) Zeigt das Grundstück + die Gelände-Ausdehnung eines DXF.
/// Das Haus-Rechteck zum Platzieren kommt im nächsten Schritt dazu.
struct HauslagePlatzierenView: View {
    let dxfData: Data

    @Environment(\.dismiss) private var dismiss
    @State private var info: GrundstueckInfo?
    @State private var fehler: String?
    @State private var laedt = true

    var body: some View {
        NavigationStack {
            Group {
                if laedt {
                    ProgressView("Grundstück wird geladen …")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let fehler {
                    ContentUnavailableView("Konnte nicht laden", systemImage: "exclamationmark.triangle",
                                           description: Text(fehler))
                } else if let info {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Gelände \(String(format: "%.2f", info.gelaende_min))–\(String(format: "%.2f", info.gelaende_max)) m · \(info.n_hoehen) Höhenpunkte · \(info.grenzlinien.count) Grenzzüge")
                            .font(.caption).foregroundStyle(.secondary)
                        GrundstueckCanvas(info: info)
                            .frame(maxWidth: .infinity, minHeight: 320)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("Nächster Schritt: das Haus-Rechteck hier drauflegen (Maße + Abstände) → Aushub rechnen.")
                            .font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Hauslage platzieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() }.tint(.orange) }
            }
        }
        .presentationSizing(.page)
        .task { await ladeGrundstueck() }
    }

    private func ladeGrundstueck() async {
        guard let url = URL(string: MopsConfig.host + "/gelaendebruecke/grundstueck") else {
            fehler = "Ungültige Server-URL"; laedt = false; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dxf_file\"; filename=\"upload.dxf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(dxfData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        do {
            let (data, resp) = try await URLSession.shared.upload(for: request, from: body)
            if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                var detail: String?
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    detail = obj["detail"] as? String
                }
                fehler = detail ?? "Server-Fehler (\(http.statusCode))"
                laedt = false
                return
            }
            info = try JSONDecoder().decode(GrundstueckInfo.self, from: data)
            laedt = false
        } catch {
            fehler = error.localizedDescription
            laedt = false
        }
    }
}

/// Zeichnet Grundstücksgrenzen + Gelände-Ausdehnung, auf die Fläche eingepasst (UTM → Bildschirm).
private struct GrundstueckCanvas: View {
    let info: GrundstueckInfo

    var body: some View {
        Canvas { ctx, size in
            // Alle Punkte einsammeln (Grenzen + Bbox-Ecken), um die Ausdehnung zu bestimmen.
            var xs: [Double] = [info.bbox.min_x, info.bbox.max_x]
            var ys: [Double] = [info.bbox.min_y, info.bbox.max_y]
            for zug in info.grenzlinien {
                for p in zug where p.count >= 2 { xs.append(p[0]); ys.append(p[1]) }
            }
            guard let minX = xs.min(), let maxX = xs.max(),
                  let minY = ys.min(), let maxY = ys.max() else { return }
            let w = max(maxX - minX, 0.001), h = max(maxY - minY, 0.001)
            let pad: CGFloat = 20
            let s = min((size.width - 2*pad) / CGFloat(w), (size.height - 2*pad) / CGFloat(h))
            // zentriert einpassen
            let offX = (size.width  - CGFloat(w) * s) / 2
            let offY = (size.height - CGFloat(h) * s) / 2
            func P(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: offX + CGFloat(x - minX) * s,
                        y: size.height - offY - CGFloat(y - minY) * s)   // Y nach oben
            }

            // Gelände-Ausdehnung (leichtes Rechteck)
            let a = P(info.bbox.min_x, info.bbox.min_y)
            let b = P(info.bbox.max_x, info.bbox.max_y)
            let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                              width: abs(a.x - b.x), height: abs(a.y - b.y))
            ctx.stroke(Path(rect), with: .color(.orange.opacity(0.35)), lineWidth: 1)

            // Grundstücksgrenzen
            for zug in info.grenzlinien {
                var path = Path()
                var erster = true
                for p in zug where p.count >= 2 {
                    let pt = P(p[0], p[1])
                    if erster { path.move(to: pt); erster = false } else { path.addLine(to: pt) }
                }
                ctx.stroke(path, with: .color(.primary), lineWidth: 1.5)
            }
        }
    }
}
