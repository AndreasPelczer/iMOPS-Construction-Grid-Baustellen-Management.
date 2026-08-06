//  WandLeserView.swift
//  Welle 5c — Wände/Öffnungen aus einem DXF/DWG-Plan lesen und ins LV übernehmen.
//
//  Mehrfachauswahl: mehrere Layer ankreuzen (Wände, Türen, Fenster …), eine
//  Geschosshöhe für die Wände, dann alle auf einmal ins LV. Jede LV-Position
//  bekommt die Herkunft (Datei + Layer) in `quellDatei` — Gegenstück zum PDF-Beleg.

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Server-Modell (snake_case = passt 1:1 auf die JSON-Antwort)

private struct WandLayer: Codable, Identifiable {
    let name: String
    let objekte: Int
    let laenge_roh: Double
    let laenge_m: Double?
    let stueck: Int?
    let stueck_methode: String?
    let doppellinien_verdacht: Bool?
    var id: String { name }
    var istOeffnung: Bool { stueck != nil }
    var istWand: Bool { stueck == nil && laenge_m != nil }
}

private struct WandLeserResult: Codable {
    let einheit: String
    let einheit_bekannt: Bool
    let layer_liste: [WandLayer]
    let hinweise: [String]
}

struct WandLeserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var showingPicker = false
    @State private var fileData: Data?
    @State private var fileName = ""
    @State private var result: WandLeserResult?
    @State private var loading = false
    @State private var error = ""
    @State private var selected: Set<String> = []
    @State private var geschosshoehe = "2,75"
    @State private var stueckText: [String: String] = [:]
    @State private var unitOverride: Double?
    @State private var uebernahmeMeldung = ""

    private let einheiten: [(String, Double)] = [("mm", 0.001), ("cm", 0.01), ("m", 1.0), ("Zoll", 0.0254)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    if loading {
                        ProgressView("Lese Plan …").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    if !error.isEmpty { errorBox }
                    if let r = result {
                        if !r.einheit_bekannt && unitOverride == nil { einheitWahl }
                        layerAuswahl(r)
                        if brauchtHoehe(r) { hoeheFeld }
                        if !selected.isEmpty { uebernahmeLeiste(r) }
                        ForEach(r.hinweise, id: \.self) { h in
                            Text("• " + h).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Wände aus Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [UTType(filenameExtension: "dxf") ?? .data,
                                                UTType(filenameExtension: "dwg") ?? .data],
                          allowsMultipleSelection: false) { res in handlePick(res) }
            .alert("Leistungsverzeichnis", isPresented: Binding(
                get: { !uebernahmeMeldung.isEmpty },
                set: { if !$0 { uebernahmeMeldung = "" } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(uebernahmeMeldung) }
        }
    }

    // MARK: - Bausteine

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Liest Wände, Türen und Fenster aus einem Architekten-Plan (DXF/DWG). Kreuze an, was du ins LV übernehmen willst.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showingPicker = true } label: {
                Label(fileName.isEmpty ? "Plan wählen (DXF/DWG)" : "Anderen Plan wählen",
                      systemImage: "doc.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            if !fileName.isEmpty {
                Label(fileName, systemImage: "doc").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var errorBox: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(error).font(.footnote)
        }
        .padding(10)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var einheitWahl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Einheit der Datei ist unbekannt — bitte wählen:").font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(einheiten, id: \.0) { (label, faktor) in
                    Button(label) { unitOverride = faktor; ladeListe() }.buttonStyle(.bordered)
                }
            }
        }
    }

    private func layerAuswahl(_ r: WandLeserResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Was übernehmen?").font(.headline)
            ForEach(r.layer_liste) { lay in
                layerRow(lay)
            }
        }
    }

    private func layerRow(_ lay: WandLayer) -> some View {
        let an = selected.contains(lay.name)
        return VStack(alignment: .leading, spacing: 6) {
            Button { toggle(lay.name) } label: {
                HStack {
                    Image(systemName: an ? "checkmark.square.fill" : "square")
                        .foregroundStyle(an ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lay.name).font(.subheadline.weight(.medium))
                        Text(untertitel(lay)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(wertText(lay)).font(.subheadline.monospacedDigit())
                        .foregroundStyle(lay.laenge_m != nil || lay.stueck != nil ? .primary : .secondary)
                }
            }
            .buttonStyle(.plain)
            if an && lay.istOeffnung {
                HStack(spacing: 6) {
                    Text("Anzahl").font(.caption)
                    TextField("\(lay.stueck ?? 0)", text: Binding(
                        get: { stueckText[lay.name] ?? String(lay.stueck ?? 0) },
                        set: { stueckText[lay.name] = $0 }))
                        .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                        .frame(width: 50).textFieldStyle(.roundedBorder)
                    Text("Stk").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.leading, 28)
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private var hoeheFeld: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Geschosshöhe (für Wände)").font(.subheadline)
                TextField("2,75", text: $geschosshoehe)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .frame(width: 60).textFieldStyle(.roundedBorder)
                Text("m").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Höhe steht nicht im Grundriss — bitte bestätigen (Standard 2,75 m).")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func uebernahmeLeiste(_ r: WandLeserResult) -> some View {
        let hoehe = hoeheWert()
        let teile = selected.sorted().compactMap { name -> String? in
            guard let lay = r.layer_liste.first(where: { $0.name == name }) else { return nil }
            if let stk = lay.stueck {
                let n = Int(stueckText[name] ?? "") ?? stk
                return "\(n)× \(beschriftung(name))"
            } else if let m = lay.laenge_m {
                return "\(fmt(m * hoehe)) m² \(beschriftung(name))"
            }
            return nil
        }
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            if !teile.isEmpty {
                Text("Wird angelegt: " + teile.joined(separator: " · "))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Button {
                uebernehmenAlle(r)
            } label: {
                Label("Ins LV übernehmen (\(selected.count))", systemImage: "plus.square.on.square")
            }
            .buttonStyle(.borderedProminent)
            .disabled(teile.isEmpty)
        }
    }

    // MARK: - Texte / Klassifizierung

    private func toggle(_ name: String) {
        if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
    }

    private func brauchtHoehe(_ r: WandLeserResult) -> Bool {
        selected.contains { name in r.layer_liste.first(where: { $0.name == name })?.istWand == true }
    }

    private func hoeheWert() -> Double {
        Double(geschosshoehe.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func untertitel(_ lay: WandLayer) -> String {
        if lay.stueck != nil { return "\(lay.objekte) Objekte · \(lay.stueck_methode ?? "")" }
        if lay.doppellinien_verdacht == true { return "\(lay.objekte) Objekte · Doppellinien halbiert" }
        return "\(lay.objekte) Objekte"
    }

    private func wertText(_ lay: WandLayer) -> String {
        if let stk = lay.stueck { return "~\(stk) Stk" }
        if let m = lay.laenge_m { return fmt(m) + " m" }
        return fmt(lay.laenge_roh)
    }

    private func bezeichnungFuer(_ layer: String) -> String {
        let u = layer.uppercased()
        if u.contains("TUER") || u.contains("TÜR") || u.contains("DOOR") { return "Türen" }
        if u.contains("FENSTER") || u.contains("WINDOW") { return "Fenster" }
        if u.contains("WAND") || u.contains("WALL") { return "Wandfläche" }
        if u.contains("DACH") || u.contains("ROOF") { return "Dachfläche" }
        if u.contains("TREPPE") || u.contains("STAIR") { return "Treppe" }
        return layer
    }

    /// Geschoss aus Layer-Präfix (KG_/EG_/DG_/OG_/UG_) oder dem Dateinamen ableiten.
    private func geschossKuerzel(_ layer: String) -> String? {
        let s = (layer + " " + fileName).uppercased()
        if s.contains("KG_") || s.contains("KELLER") { return "Keller" }
        if s.contains("EG_") || s.contains("ERDGESCH") { return "Erdgeschoss" }
        if s.contains("DG_") || s.contains("DACH") { return "Dachgeschoss" }
        if s.contains("OG_") || s.contains("OBERGESCH") { return "Obergeschoss" }
        if s.contains("UG_") || s.contains("UNTERGESCH") { return "Untergeschoss" }
        return nil
    }

    /// Bezeichnung inkl. Geschoss, z. B. „Türen – Keller".
    private func beschriftung(_ layer: String) -> String {
        let base = bezeichnungFuer(layer)
        if let g = geschossKuerzel(layer) { return "\(base) – \(g)" }
        return base
    }

    /// Geschoss-Objekt zum Namen finden oder anlegen (damit das LV nach Ebene gruppiert/summiert).
    private func geschossObjekt(_ name: String) -> Geschoss {
        if let vorhanden = HierarchieHelfer.alleGeschosse(for: event).first(where: { $0.name == name }) {
            return vorhanden
        }
        let gebaeude = HierarchieHelfer.alleGebaeude(for: event).first
            ?? HierarchieHelfer.neuesGebaeude(name: "Hauptgebäude", for: event, in: viewContext)
        let g = HierarchieHelfer.neuesGeschoss(name: name, in: gebaeude, context: viewContext)
        // Bau-Reihenfolge von unten nach oben, damit die Ebenen-Übersicht richtig sortiert.
        let ordnung: [String: Int16] = ["Untergeschoss": 0, "Keller": 1, "Erdgeschoss": 2,
                                        "Obergeschoss": 3, "Dachgeschoss": 4]
        if let r = ordnung[name] { g.reihenfolge = r }
        return g
    }

    private func kgFuer(_ layer: String) -> String {
        let u = layer.uppercased()
        if u.contains("FENSTER") || u.contains("WINDOW") { return "334" }
        if u.contains("TUER") || u.contains("TÜR") || u.contains("DOOR") { return "344" }
        if u.contains("WAND") || u.contains("WALL") { return "331" }
        return "300"
    }

    // MARK: - Übernehmen ins LV

    private func uebernehmenAlle(_ r: WandLeserResult) {
        let hoehe = hoeheWert()
        var nextPos = (event.lvPositionen?.count ?? 0) + 1
        var angelegt = 0

        for name in selected.sorted() {
            guard let lay = r.layer_liste.first(where: { $0.name == name }) else { continue }
            let pos = LVPosition(context: viewContext)
            pos.posNr = String(format: "05.%02d", nextPos)
            pos.mengenQuelle = .schaetzung
            pos.kostenGruppeNummer = kgFuer(name)
            pos.event = event
            pos.quellDatei = "\(fileName) · Layer \(name)"   // Herkunft = Datei + Layer
            if let g = geschossKuerzel(name) {               // an Geschoss hängen → Rollup „nach Ebene"
                pos.geschoss = geschossObjekt(g)
            }

            if let stk = lay.stueck {
                let n = Int(stueckText[name] ?? "") ?? stk
                pos.bezeichnung = "\(beschriftung(name)) (aus Plan)"
                pos.einheit = "Stk"
                pos.menge = Double(n)
            } else if let m = lay.laenge_m {
                pos.bezeichnung = "\(beschriftung(name)) (aus Plan: \(fmt(m)) m × \(geschosshoehe) m)"
                pos.einheit = "m²"
                pos.menge = m * hoehe
            } else {
                viewContext.delete(pos)
                continue
            }
            nextPos += 1
            angelegt += 1
        }

        do {
            try viewContext.save()
            uebernahmeMeldung = "\(angelegt) Position(en) ins LV übernommen (Schätzung, aus \(fileName))."
            selected.removeAll()
        } catch {
            uebernahmeMeldung = "Fehler beim Speichern: \(error.localizedDescription)"
        }
    }

    // MARK: - Datei + Netzwerk

    private func handlePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let err):
            error = "Fehler: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                error = "Keine Berechtigung für die Datei."; return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                fileData = try Data(contentsOf: url)
                fileName = url.lastPathComponent
                selected.removeAll(); stueckText.removeAll(); unitOverride = nil
                self.result = nil; error = ""
                ladeListe()
            } catch {
                self.error = "Fehler beim Lesen: \(error.localizedDescription)"
            }
        }
    }

    private func ladeListe() {
        guard let data = fileData else { return }
        loading = true; error = ""
        guard let url = URL(string: MopsConfig.host + "/wandleser/analyse") else {
            error = "Ungültige Server-URL"; loading = false; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dxf_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        if let e = unitOverride {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"einheit_m\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(e)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { data, response, err in
            DispatchQueue.main.async {
                loading = false
                if let err = err { error = "Netzwerkfehler: \(err.localizedDescription)"; return }
                guard let data = data else { error = "Keine Antwort vom Server."; return }

                if let r = try? JSONDecoder().decode(WandLeserResult.self, from: data) {
                    result = r
                    error = ""
                    return
                }

                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                error = ServerFehlertext.fuer(status: status, data: data)
            }
        }.resume()
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
