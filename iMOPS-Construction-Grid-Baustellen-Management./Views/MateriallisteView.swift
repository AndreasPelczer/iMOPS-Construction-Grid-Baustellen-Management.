//  MateriallisteView.swift
//  Excel-Mengen — SketchUp-Materialliste (.xlsx) lesen und ins LV übernehmen.
//
//  Gegenstück zum WandLeser (DXF): SketchUp rechnet Volumen/Maße selbst und exportiert
//  sie als Excel. Wir lesen den Export über POST /materialliste (Box) und übernehmen
//  Positionen ins LV. Herkunft (Datei + Position) landet in `quellDatei`.
//
//  Ehrlichkeits-Prinzip (Tao): Volumen/Maße sind Fakt aus der Datei, die Einordnung in
//  Kategorien ist abgeleitet — darum alles als `mengenQuelle = .schaetzung` (geschätzt).

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Server-Modell (snake_case = 1:1 auf die JSON-Antwort von /materialliste)

private struct MPosition: Codable, Identifiable {
    let name: String
    let kategorie: String
    let dicke_m: Double?
    let anzahl_bauteile: Int
    let mengen_typ: String?
    let volumen_m3: Double?
    let flaeche_m2: Double?
    let stueck: Int?
    let abgeleitet: Bool?
    let bauteile_beispiel: [String]?
    var id: String { name }
}

private struct MateriallisteResult: Codable {
    let quelle: String
    let quelle_typ: String
    let einheit: String
    let bauteile_gesamt: Int
    let positionen: [MPosition]
    let unbekannt: [String]
    let geschaetzt: Bool
    let hinweise: [String]
}

struct MateriallisteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var showingPicker = false
    @State private var fileData: Data?
    @State private var fileName = ""
    @State private var result: MateriallisteResult?
    @State private var loading = false
    @State private var error = ""
    @State private var selected: Set<String> = []
    @State private var uebernahmeMeldung = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    if loading {
                        ProgressView("Lese Materialliste …").frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    if !error.isEmpty { errorBox }
                    if let r = result {
                        positionsAuswahl(r)
                        if !selected.isEmpty { uebernahmeLeiste(r) }
                        if !r.unbekannt.isEmpty {
                            Text("Nicht zugeordnet: " + r.unbekannt.joined(separator: ", "))
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        ForEach(r.hinweise, id: \.self) { h in
                            Text("• " + h).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Mengen aus Excel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [UTType.spreadsheet,
                                                UTType(filenameExtension: "xlsx") ?? .data],
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
            Text("Liest einen SketchUp-Mengenauszug (.xlsx) und bündelt die Bauteile zu Positionen (Wände, Putz, Boden, Beton …). Kreuze an, was ins LV soll.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showingPicker = true } label: {
                Label(fileName.isEmpty ? "Excel wählen (.xlsx)" : "Andere Excel wählen",
                      systemImage: "tablecells")
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

    private func positionsAuswahl(_ r: MateriallisteResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Was übernehmen?").font(.headline)
                Spacer()
                Button(selected.count == r.positionen.count ? "Keine" : "Alle") {
                    if selected.count == r.positionen.count { selected.removeAll() }
                    else { selected = Set(r.positionen.map(\.name)) }
                }.font(.caption)
            }
            ForEach(r.positionen) { p in positionRow(p) }
        }
    }

    private func positionRow(_ p: MPosition) -> some View {
        let an = selected.contains(p.name)
        return Button { toggle(p.name) } label: {
            HStack {
                Image(systemName: an ? "checkmark.square.fill" : "square")
                    .foregroundStyle(an ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.name).font(.subheadline.weight(.medium))
                    Text("\(p.anzahl_bauteile) Bauteile · abgeleitet").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(mengeAnzeige(p)).font(.subheadline.monospacedDigit())
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func uebernahmeLeiste(_ r: MateriallisteResult) -> some View {
        let teile = selected.sorted().compactMap { name -> String? in
            guard let p = r.positionen.first(where: { $0.name == name }) else { return nil }
            return "\(mengeAnzeige(p)) \(p.name)"
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

    // MARK: - Menge / Klassifizierung

    private func toggle(_ name: String) {
        if selected.contains(name) { selected.remove(name) } else { selected.insert(name) }
    }

    /// Menge + Einheit je nach mengen_typ (volumen → m³, flaeche → m², stueck → Stk).
    private func mengeUndEinheit(_ p: MPosition) -> (Double, String)? {
        switch p.mengen_typ {
        case "volumen": if let v = p.volumen_m3 { return (v, "m³") }
        case "flaeche": if let f = p.flaeche_m2 { return (f, "m²") }
        case "stueck":  if let s = p.stueck { return (Double(s), "Stk") }
        default: break
        }
        return nil
    }

    private func mengeAnzeige(_ p: MPosition) -> String {
        guard let (menge, einheit) = mengeUndEinheit(p) else { return "—" }
        return "\(fmt(menge)) \(einheit)"
    }

    /// DIN-276-Kostengruppe je Kategorie — grobe Vorbelegung (abgeleitet, änderbar).
    private func kgFuer(_ kategorie: String) -> String {
        switch kategorie {
        case "aussenwand", "innenwand", "beton", "ringbalken", "sturz": return "331"  // tragende Konstruktion / Mauerwerk
        case "bodenplatte":  return "324"  // Gründung / Bodenplatte
        case "putz_aussen":  return "335"  // Außenwandbekleidungen außen
        case "putz_innen", "putz": return "345"  // Innenwandbekleidungen
        case "bodenflaeche": return "325"  // Bodenbeläge
        default: return "300"
        }
    }

    /// Geschoss aus Bauteil-Präfix (EG_/OG_/UG_/KG_/DG_) oder Dateinamen ableiten.
    private func geschossKuerzel(_ hinweis: String) -> String? {
        let s = (hinweis + " " + fileName).uppercased()
        if s.contains("KG_") || s.contains("KELLER") { return "Keller" }
        if s.contains("EG_") || s.contains("ERDGESCH") { return "Erdgeschoss" }
        if s.contains("DG_") || s.contains("DACH") { return "Dachgeschoss" }
        if s.contains("OG_") || s.contains("OBERGESCH") { return "Obergeschoss" }
        if s.contains("UG_") || s.contains("UNTERGESCH") { return "Untergeschoss" }
        return nil
    }

    private func geschossObjekt(_ name: String) -> Geschoss {
        if let vorhanden = HierarchieHelfer.alleGeschosse(for: event).first(where: { $0.name == name }) {
            return vorhanden
        }
        let gebaeude = HierarchieHelfer.alleGebaeude(for: event).first
            ?? HierarchieHelfer.neuesGebaeude(name: "Hauptgebäude", for: event, in: viewContext)
        let g = HierarchieHelfer.neuesGeschoss(name: name, in: gebaeude, context: viewContext)
        let ordnung: [String: Int16] = ["Untergeschoss": 0, "Keller": 1, "Erdgeschoss": 2,
                                        "Obergeschoss": 3, "Dachgeschoss": 4]
        if let r = ordnung[name] { g.reihenfolge = r }
        return g
    }

    // MARK: - Übernehmen ins LV

    private func uebernehmenAlle(_ r: MateriallisteResult) {
        var nextPos = (event.lvPositionen?.count ?? 0) + 1
        var angelegt = 0

        for name in selected.sorted() {
            guard let p = r.positionen.first(where: { $0.name == name }),
                  let (menge, einheit) = mengeUndEinheit(p) else { continue }
            let pos = LVPosition(context: viewContext)
            pos.posNr = String(format: "06.%02d", nextPos)   // 06 = aus Materialliste
            pos.mengenQuelle = .schaetzung
            pos.kostenGruppeNummer = kgFuer(p.kategorie)
            pos.event = event
            pos.quellDatei = "\(fileName) · \(p.name)"
            if let g = geschossKuerzel(p.bauteile_beispiel?.first ?? "") {
                pos.geschoss = geschossObjekt(g)
            }
            pos.bezeichnung = "\(p.name) (aus Materialliste)"
            pos.einheit = einheit
            pos.menge = menge
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
                selected.removeAll(); self.result = nil; error = ""
                ladeMengen()
            } catch {
                self.error = "Fehler beim Lesen: \(error.localizedDescription)"
            }
        }
    }

    private func ladeMengen() {
        guard let data = fileData else { return }
        loading = true; error = ""
        guard let url = URL(string: MopsConfig.host + "/materialliste") else {
            error = "Ungültige Server-URL"; loading = false; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { data, _, err in
            DispatchQueue.main.async {
                loading = false
                if let err = err { error = "Netzwerkfehler: \(err.localizedDescription)"; return }
                guard let data = data else { error = "Keine Antwort vom Server."; return }
                do {
                    result = try JSONDecoder().decode(MateriallisteResult.self, from: data)
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
        String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }
}
