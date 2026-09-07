import SwiftUI
import UniformTypeIdentifiers

// MARK: - Antwort des Servers (POST /ifc/analyse)
//
// Bewusst alles optional: der Server ist ehrlich, wenn er etwas nicht weiß —
// fehlt die Einheit im Modell, kommen Rohwerte und `einheit_bekannt: false`.
// Ein Decoder, der auf Vollständigkeit besteht, würde genau diese Ehrlichkeit
// in einen Parse-Fehler verwandeln.

struct IFCQuelle: Codable {
    let datei: String?
    let schema: String?
    let einheit: String?
    let einheit_bekannt: Bool?
    let einheit_quelle: String?
    let modellart: String?
}

struct IFCMenge: Codable {
    let wert: Double?
    let einheit: String?
    /// "qto" = stand im Modell · "berechnet" = aus den Maßen gerechnet ·
    /// "gezählt" = Stück · "unbekannt" = keine Menge ermittelbar
    let art: String?
    let kennwert: String?
    let oeffnungen_abgezogen: Bool?
    let umgerechnet: Bool?
}

struct IFCNamensteile: Codable {
    let bauteil: String?
    let art: String?
    let art_klartext: String?
    let dicke_m: Double?
    let hoehe_m: Double?
    let lfd_nr: Int?
}

struct IFCBauteil: Codable, Identifiable {
    let ifc_type: String?
    let name: String?
    let material: String?
    let menge: IFCMenge?
    let kg: String?
    let aus_name: IFCNamensteile?
    let volumen_m3: Double?
    let global_id: String?

    var id: String { global_id ?? ((name ?? "?") + (aus_name?.lfd_nr.map(String.init) ?? "")) }
}

struct IFCGeschoss: Codable, Identifiable {
    let name: String?
    let elevation_m: Double?
    let bauteile: [IFCBauteil]?
    var id: String { name ?? "?" }
}

struct IFCSumme: Codable, Identifiable {
    let geschoss: String?
    let kg: String?
    let material: String?
    let einheit: String?
    let wert: Double?
    var id: String { "\(geschoss ?? "")-\(kg ?? "")-\(material ?? "")-\(einheit ?? "")" }
}

struct IFCErgebnis: Codable {
    let quelle: IFCQuelle?
    let geschosse: [IFCGeschoss]?
    let summen: [IFCSumme]?
    let hinweise: [String]?
    let ignoriert: [IFCIgnoriert]?
}

struct IFCIgnoriert: Codable, Identifiable {
    let name: String?
    let grund: String?
    let geschoss: String?
    var id: String { (name ?? "?") + (geschoss ?? "") }
}

// MARK: - IFCLeserView
//
// IFC-Datei aus SketchUp hochladen, geschossweise Mengen zurückbekommen.
// Zweiter Einleseweg neben dem Wand-Leser (DXF), nicht statt dessen.

struct IFCLeserView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var showingPicker = false
    @State private var fileData: Data?
    @State private var fileName = ""
    @State private var result: IFCErgebnis?
    @State private var loading = false
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Form {
                dateiAbschnitt
                if loading { ladeAnzeige }
                if !error.isEmpty { fehlerAbschnitt }
                if let r = result {
                    quelleAbschnitt(r)
                    summenAbschnitt(r)
                    geschossAbschnitt(r)
                    hinweisAbschnitt(r)
                }
            }
            .navigationTitle("IFC-Leser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [UTType(filenameExtension: "ifc") ?? .data],
                          allowsMultipleSelection: false) { ergebnis in
                dateiUebernehmen(ergebnis)
            }
        }
    }

    // MARK: Abschnitte

    private var dateiAbschnitt: some View {
        Section {
            Button {
                showingPicker = true
            } label: {
                Label(fileName.isEmpty ? "IFC-Datei wählen" : fileName,
                      systemImage: "cube.transparent")
            }
            if fileData != nil {
                Button {
                    auswerten()
                } label: {
                    Label("Auswerten", systemImage: "arrow.up.doc")
                }
                .disabled(loading)
            }
        } footer: {
            Text("SketchUp exportiert IFC mit Geschossen und Materialien. Die Mengen kommen aus der Geometrie — Entwurfsmaße, keine Ausführungsplanung.")
        }
    }

    private var ladeAnzeige: some View {
        Section {
            HStack {
                ProgressView()
                Text("Der Server liest das Modell…").foregroundStyle(.secondary)
            }
        }
    }

    private var fehlerAbschnitt: some View {
        Section {
            Text(error).foregroundStyle(.red)
        }
    }

    private func quelleAbschnitt(_ r: IFCErgebnis) -> some View {
        Section("Datei") {
            if let q = r.quelle {
                zeile("Schema", q.schema ?? "?")
                zeile("Einheit", q.einheit ?? "?")
                // Ist die Einheit unbekannt, sind alle Zahlen Rohwerte. Das
                // darf nicht untergehen — sonst wandern sie als Meter weiter.
                if q.einheit_bekannt == false {
                    Label("Einheit im Modell nicht deklariert — die Werte sind Rohwerte, keine Meter.",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                if q.modellart == "entwurf" {
                    Text("Entwurfsgeometrie: Rohbaumaße ohne Schichtaufbau. Die Mengen sind Schätzungen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func summenAbschnitt(_ r: IFCErgebnis) -> some View {
        Group {
            if let summen = r.summen, !summen.isEmpty {
                // Volumen zuerst: Mauerwerk wird nach m³ bestellt, nicht nach m².
                let volumen = summen.filter { $0.einheit == "m3" }
                let rest    = summen.filter { $0.einheit != "m3" }

                if !volumen.isEmpty {
                    Section("Mengen nach Volumen") {
                        ForEach(volumen) { s in summenZeile(s) }
                    }
                }
                if !rest.isEmpty {
                    Section("Weitere Mengen") {
                        ForEach(rest) { s in summenZeile(s) }
                    }
                }
            }
        }
    }

    private func summenZeile(_ s: IFCSumme) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.material ?? "ohne Material").font(.callout)
                Text("\(s.geschoss ?? "?") · KG \(s.kg ?? "offen")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(fmt(s.wert)) \(s.einheit ?? "")")
                .font(.callout.monospacedDigit())
        }
    }

    private func geschossAbschnitt(_ r: IFCErgebnis) -> some View {
        ForEach(r.geschosse ?? []) { g in
            Section("\(g.name ?? "?") — \(g.bauteile?.count ?? 0) Bauteile") {
                ForEach(g.bauteile ?? []) { b in
                    bauteilZeile(b)
                }
            }
        }
    }

    private func bauteilZeile(_ b: IFCBauteil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(b.aus_name?.bauteil ?? b.name ?? "?").font(.callout)
            HStack(spacing: 8) {
                if let m = b.menge, let w = m.wert {
                    Text("\(fmt(w)) \(m.einheit ?? "")").font(.caption.monospacedDigit())
                    // Die Herkunft der Menge ist wichtiger als die Zahl:
                    // "qto" stand im Modell, "berechnet" haben wir geschätzt.
                    Text(herkunft(m.art))
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(m.art == "qto" ? Color.green.opacity(0.15)
                                                   : Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
                if let v = b.volumen_m3 {
                    Text("· \(fmt(v)) m³").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Text("KG \(b.kg ?? "offen")")
                    .font(.caption2)
                    .foregroundStyle(b.kg == "offen" ? .orange : .secondary)
                if let mat = b.material { Text(mat).font(.caption2).foregroundStyle(.secondary) }
                if let d = b.aus_name?.dicke_m {
                    Text("d = \(Int(d * 1000)) mm").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 1)
    }

    private func hinweisAbschnitt(_ r: IFCErgebnis) -> some View {
        Group {
            if let h = r.hinweise, !h.isEmpty {
                Section("Hinweise vom Server") {
                    ForEach(h, id: \.self) { text in
                        Text(text).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let ign = r.ignoriert, !ign.isEmpty {
                Section("Nicht als Bauteil gewertet (\(ign.count))") {
                    // Ausweisen statt verschlucken: sonst hält jemand die
                    // Liste für unvollständig und sucht.
                    ForEach(ign.prefix(12)) { i in
                        Text(i.name ?? "?").font(.caption2).foregroundStyle(.secondary)
                    }
                    if ign.count > 12 {
                        Text("… und \(ign.count - 12) weitere")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Hilfen

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack { Text(titel); Spacer(); Text(wert).foregroundStyle(.secondary) }
    }

    private func herkunft(_ art: String?) -> String {
        switch art {
        case "qto":       return "aus dem Modell"
        case "berechnet": return "gerechnet"
        case "gezählt":   return "Stück"
        default:          return "unbekannt"
        }
    }

    private func fmt(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        return String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }

    private func dateiUebernehmen(_ ergebnis: Result<[URL], Error>) {
        switch ergebnis {
        case .failure(let e):
            error = "Datei konnte nicht geöffnet werden: \(e.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            // Sicherheitsbereich: ohne das liefert das Lesen bei Dateien
            // außerhalb der App-Sandbox nichts.
            let zugriff = url.startAccessingSecurityScopedResource()
            defer { if zugriff { url.stopAccessingSecurityScopedResource() } }
            do {
                fileData = try Data(contentsOf: url)
                fileName = url.lastPathComponent
                result = nil
                error = ""
            } catch {
                self.error = "Fehler beim Lesen: \(error.localizedDescription)"
            }
        }
    }

    private func auswerten() {
        guard let data = fileData else { return }
        loading = true; error = ""; result = nil

        guard let url = URL(string: MopsConfig.host + "/ifc/analyse") else {
            error = "Ungültige Server-URL"; loading = false; return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Große Modelle brauchen Zeit — die Box rechnet die Geometrie durch.
        request.timeoutInterval = 180
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"ifc_file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        URLSession.shared.uploadTask(with: request, from: body) { data, response, err in
            DispatchQueue.main.async {
                loading = false
                if let err = err { error = "Netzwerkfehler: \(err.localizedDescription)"; return }
                guard let data = data else { error = "Keine Antwort vom Server."; return }

                if let r = try? JSONDecoder().decode(IFCErgebnis.self, from: data) {
                    result = r
                    error = ""
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                error = ServerFehlertext.fuer(status: status, data: data)
            }
        }.resume()
    }
}
