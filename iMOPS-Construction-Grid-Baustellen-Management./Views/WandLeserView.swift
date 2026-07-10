//  WandLeserView.swift
//  Welle 5c — Wände aus einem DXF/DWG-Plan lesen.
//
//  Ablauf: Plan wählen → Server gibt Layer-Liste → Nutzer tippt den Wand-Layer an
//  → Server rechnet die Wandlänge in Meter. Ehrlich: unbekannte Einheit lässt sich
//  überschreiben, Doppellinien-Verdacht wird offen angezeigt.

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Server-Modelle (snake_case = passt 1:1 auf die JSON-Antwort)

private struct WandLayer: Codable, Identifiable {
    let name: String
    let objekte: Int
    let laenge_roh: Double
    let laenge_m: Double?
    var id: String { name }
}

private struct WandLeserResult: Codable {
    let einheit: String
    let einheit_bekannt: Bool
    let einheit_quelle: String
    let layer_liste: [WandLayer]
    let hinweise: [String]
    // nur gesetzt, wenn ein Layer gewählt wurde:
    let layer_gewaehlt: String?
    let laenge_roh: Double?
    let doppellinien_verdacht: Bool?
    let wandlaenge_m: Double?
    let geschaetzt: Bool?
}

struct WandLeserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var geschosshoehe = "2,75"
    @State private var uebernahmeMeldung = ""
    @State private var showingPicker = false
    @State private var fileData: Data? = nil
    @State private var fileName: String = ""
    @State private var result: WandLeserResult? = nil
    @State private var chosenLayer: String? = nil
    @State private var unitOverride: Double? = nil
    @State private var loading = false
    @State private var error: String = ""

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
                        layerListe(r)
                        if chosenLayer != nil { ergebnis(r) }
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
            Text("Liest die Wandlängen aus einem Architekten-Plan (DXF/DWG). Du wählst den Layer, auf dem die Wände liegen — der Mops rechnet die Länge in Meter.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                showingPicker = true
            } label: {
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

    private func layerListe(_ r: WandLeserResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcher Layer sind die Wände?").font(.headline)
            ForEach(r.layer_liste) { lay in
                Button {
                    chosenLayer = lay.name
                    analyse(layer: lay.name, einheitM: unitOverride)
                } label: {
                    layerRow(lay)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func layerRow(_ lay: WandLayer) -> some View {
        let gewaehlt = chosenLayer == lay.name
        return HStack {
            Image(systemName: gewaehlt ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(gewaehlt ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(lay.name).font(.subheadline.weight(.medium))
                Text("\(lay.objekte) Objekte").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(lay.laenge_m != nil ? fmt(lay.laenge_m!) + " m" : fmt(lay.laenge_roh))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(lay.laenge_m != nil ? Color.primary : Color.secondary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func ergebnis(_ r: WandLeserResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            if let m = r.wandlaenge_m {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(fmt(m)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("m Wand").font(.title3).foregroundStyle(.secondary)
                }
                if r.geschaetzt == true {
                    Label("Schätzung", systemImage: "questionmark.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
                uebernahmeBlock(m)
            } else {
                // Einheit unbekannt → Rohwert + Umrechnung anbieten
                if let roh = r.laenge_roh {
                    Text("\(fmt(roh)) Zeichnungseinheiten").font(.title3.weight(.semibold))
                }
                Text("Einheit der Datei ist unbekannt — bitte wählen:").font(.footnote).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(einheiten, id: \.0) { (label, faktor) in
                        Button(label) {
                            unitOverride = faktor
                            if let l = chosenLayer { analyse(layer: l, einheitM: faktor) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if r.doppellinien_verdacht == true {
                Label("Wände scheinen als Doppellinien gezeichnet — Länge wurde halbiert.",
                      systemImage: "square.split.2x1")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(r.hinweise, id: \.self) { h in
                Text("• " + h).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // Übernehmen ins LV: Wandlänge × Geschosshöhe → Wandfläche als LV-Position (Schätzung).
    private func uebernahmeBlock(_ laengeM: Double) -> some View {
        let hoehe = Double(geschosshoehe.replacingOccurrences(of: ",", with: ".")) ?? 0
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 6) {
                Text("Geschosshöhe").font(.subheadline)
                TextField("2,75", text: $geschosshoehe)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                Text("m").font(.subheadline).foregroundStyle(.secondary)
            }
            if hoehe > 0 {
                Text("→ Wandfläche ≈ \(fmt(laengeM * hoehe)) m²")
                    .font(.subheadline.weight(.semibold))
                Text("Höhe steht nicht im Grundriss — bitte bestätigen (Standard 2,75 m).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button {
                uebernehmen(laengeM: laengeM)
            } label: {
                Label("Ins LV übernehmen", systemImage: "plus.square.on.square")
            }
            .buttonStyle(.borderedProminent)
            .disabled(hoehe <= 0)
        }
    }

    private func uebernehmen(laengeM: Double) {
        let hoehe = Double(geschosshoehe.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard hoehe > 0 else { uebernahmeMeldung = "Bitte eine gültige Geschosshöhe eingeben."; return }
        let flaeche = laengeM * hoehe
        let nextPos = (event.lvPositionen?.count ?? 0) + 1

        let pos = LVPosition(context: viewContext)
        pos.posNr = String(format: "05.%02d", nextPos)
        pos.bezeichnung = "Wandfläche (aus Plan: \(fmt(laengeM)) m × \(geschosshoehe) m)"
        pos.einheit = "m²"
        pos.menge = flaeche
        pos.mengenQuelle = .schaetzung          // aus Plan geschätzt → Welle-9-Ampel (andersfarbig)
        pos.kostenGruppeNummer = "331"          // Tragende Außenwände (Startwert, im LV anpassbar)
        pos.event = event

        do {
            try viewContext.save()
            uebernahmeMeldung = "Ins LV übernommen: Wandfläche \(fmt(flaeche)) m² (Schätzung, aus Plan)."
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
                chosenLayer = nil
                unitOverride = nil
                self.result = nil
                error = ""
                analyse(layer: nil, einheitM: nil)   // erst Layer-Liste holen
            } catch {
                self.error = "Fehler beim Lesen: \(error.localizedDescription)"
            }
        }
    }

    private func analyse(layer: String?, einheitM: Double?) {
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
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dxf_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        if let layer = layer, !layer.isEmpty { field("layer", layer) }
        if let e = einheitM { field("einheit_m", String(e)) }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { data, _, err in
            DispatchQueue.main.async {
                loading = false
                if let err = err { error = "Netzwerkfehler: \(err.localizedDescription)"; return }
                guard let data = data else { error = "Keine Antwort vom Server."; return }
                do {
                    result = try JSONDecoder().decode(WandLeserResult.self, from: data)
                    error = ""
                } catch {
                    if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let detail = obj["detail"] as? String {
                        self.error = detail
                    } else {
                        self.error = String(data: data, encoding: .utf8) ?? "Unlesbare Antwort"
                    }
                }
            }
        }.resume()
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
