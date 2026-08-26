//  MateriallisteView.swift
//  Excel-Mengen — SketchUp-Materialliste (.xlsx) lesen und ins LV übernehmen.
//
//  Gegenstück zum WandLeser (DXF): SketchUp rechnet Volumen/Maße selbst und exportiert
//  sie als Excel. Wir lesen den Export über POST /materialliste (Box).
//
//  Struktur im LV (Deckel/Unterpunkte, REB-23.003): Pro Kategorie/Sektion EIN Deckel
//  (Außenwand 24cm, Innenputz …) mit der Gesamtmenge, darunter die Einzel-Bauteile als
//  aufklappbare Unterpunkte. Nur der Deckel zählt in Summen, die Einzelteile sind Belege.
//  Kalkulation/Bestellwesen hinter dem LV bleiben unberührt.
//
//  Ehrlichkeits-Prinzip (Tao): Volumen/Maße sind Fakt aus der Datei, die Einordnung in
//  Kategorien ist abgeleitet — darum alles als `mengenQuelle = .schaetzung`.

import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Server-Modell (snake_case = 1:1 auf die JSON-Antwort von /materialliste)

private struct MBauteil: Codable, Identifiable {
    let name: String
    let kategorie: String
    let mengen_typ: String?
    let anzahl: Int
    let volumen_m3: Double?
    let flaeche_m2: Double?
    let dicke_m: Double?

    /// Material-Nummer vom T&C-Bestellschein, wenn der Server sie eindeutig
    /// zuordnen konnte. Landet beim Import in `LVPosition.artikelNummer` — dem
    /// Feld, das Bestellliste, Anfrage-PDF und Mail-Export bereits auswerten.
    let material_nr: String?
    /// Erkannte Güte („PPW 2-0,35"), nur zur Anzeige.
    let material_guete: String?
    /// Warum keine Nummer da ist: keine_guete / mehrdeutig / nicht_im_schein.
    let material_befund: String?

    var id: String { name }
}

private struct MateriallisteResult: Codable {
    let quelle: String
    let quelle_typ: String
    let einheit: String
    let bauteile_gesamt: Int
    let bauteile: [MBauteil]
    let unbekannt: [String]
    let geschaetzt: Bool
    let hinweise: [String]
}

// MARK: - Sektion (= ein Deckel im LV)

private struct MSektion: Identifiable {
    let key: String
    let label: String
    let kategorie: String
    let mengenTyp: String
    let einheit: String
    let summe: Double
    let bauteile: [MBauteil]
    var id: String { key }
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
    @State private var selected: Set<String> = []      // gewählte Sektionen (Deckel)
    @State private var uebernahmeMeldung = ""

    private let kategorieReihenfolge = ["aussenwand", "innenwand", "bodenplatte", "beton",
                                        "ringbalken", "sturz", "putz_aussen", "putz_innen",
                                        "putz", "bodenflaeche", "unbekannt"]

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
                        gesamtsumme(r)
                        sektionsAuswahl(r)
                        if !selected.isEmpty { uebernahmeLeiste(r) }
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
                          allowedContentTypes: [UTType.spreadsheet, UTType.commaSeparatedText,
                                                UTType(filenameExtension: "xlsx") ?? .data,
                                                UTType(filenameExtension: "csv") ?? .data],
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
            Text("Liest einen SketchUp-Mengenauszug (.xlsx). Jede Kategorie wird ein LV-Eintrag (Deckel), die Einzel-Bauteile hängen aufklappbar darunter. Häkchen raus, was nicht ins LV soll.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showingPicker = true } label: {
                Label(fileName.isEmpty ? "Datei wählen (.xlsx / .csv)" : "Andere Datei wählen",
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

    /// Gesamtsumme oben — getrennt nach Einheit (m³ / m² / Stk lassen sich nicht mischen).
    private func gesamtsumme(_ r: MateriallisteResult) -> some View {
        let sek = sektionen(r).filter { selected.contains($0.key) }
        let vol = sek.filter { $0.einheit == "m³" }.reduce(0.0) { $0 + $1.summe }
        let fl  = sek.filter { $0.einheit == "m²" }.reduce(0.0) { $0 + $1.summe }
        let stk = sek.filter { $0.einheit == "Stk" }.reduce(0.0) { $0 + $1.summe }
        var teile: [String] = []
        if vol > 0 { teile.append("\(fmt(vol)) m³") }
        if fl  > 0 { teile.append("\(fmt(fl)) m²") }
        if stk > 0 { teile.append("\(Int(stk)) Stk") }
        return VStack(alignment: .leading, spacing: 4) {
            Text("Gesamtsumme (gewählt)").font(.caption).foregroundStyle(.secondary)
            Text(teile.isEmpty ? "—" : teile.joined(separator: "  ·  "))
                .font(.title3.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }

    private func sektionsAuswahl(_ r: MateriallisteResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(sektionen(r).count) LV-Einträge").font(.headline)
                Spacer()
                Button(selected.count == sektionen(r).count ? "Keine" : "Alle") {
                    let all = Set(sektionen(r).map(\.key))
                    selected = (selected.count == all.count) ? [] : all
                }.font(.caption)
            }
            ForEach(sektionen(r)) { sek in sektionRow(sek) }
        }
    }

    private func sektionRow(_ sek: MSektion) -> some View {
        let an = selected.contains(sek.key)
        return VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(sek.bauteile) { b in
                        HStack {
                            Text(b.name).font(.caption2).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(mengeAnzeige(b)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            } label: {
                Button { toggle(sek.key) } label: {
                    HStack {
                        Image(systemName: an ? "checkmark.square.fill" : "square")
                            .foregroundStyle(an ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sek.label).font(.subheadline.weight(.medium))
                            Text("\(sek.bauteile.count) Bauteile · KG \(kgFuer(sek.kategorie))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(fmt(sek.summe)) \(sek.einheit)").font(.subheadline.monospacedDigit())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func uebernahmeLeiste(_ r: MateriallisteResult) -> some View {
        let sek = sektionen(r).filter { selected.contains($0.key) }
        let bauteile = sek.reduce(0) { $0 + $1.bauteile.count }
        return VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("\(sek.count) LV-Einträge mit \(bauteile) Einzelpositionen darunter (aufklappbar). Schätzung.")
                .font(.footnote).foregroundStyle(.secondary)
            Button {
                uebernehmenAlle(r)
            } label: {
                Label("Ins LV übernehmen (\(sek.count))", systemImage: "plus.square.on.square")
            }
            .buttonStyle(.borderedProminent)
            .disabled(sek.isEmpty)
        }
    }

    // MARK: - Sektionen bilden (Gruppierung nach Kategorie, Wände nach Dicke)

    private func sektionen(_ r: MateriallisteResult) -> [MSektion] {
        var groups: [String: [MBauteil]] = [:]
        for b in r.bauteile where mengeUndEinheit(b) != nil {
            let key = (b.kategorie == "aussenwand" || b.kategorie == "innenwand")
                ? "\(b.kategorie)|\(b.dicke_m ?? 0)" : b.kategorie
            groups[key, default: []].append(b)
        }
        let sektionen: [MSektion] = groups.map { (key, items) in
            let first = items[0]
            let einheit = mengeUndEinheit(first)?.1 ?? ""
            let summe = items.reduce(0.0) { $0 + (mengeUndEinheit($1)?.0 ?? 0) }
            return MSektion(key: key, label: sektionLabel(first), kategorie: first.kategorie,
                            mengenTyp: first.mengen_typ ?? "", einheit: einheit, summe: summe, bauteile: items)
        }
        return sektionen.sorted {
            let ia = kategorieReihenfolge.firstIndex(of: $0.kategorie) ?? 99
            let ib = kategorieReihenfolge.firstIndex(of: $1.kategorie) ?? 99
            if ia != ib { return ia < ib }
            return ($0.bauteile.first?.dicke_m ?? 0) > ($1.bauteile.first?.dicke_m ?? 0)
        }
    }

    private func sektionLabel(_ b: MBauteil) -> String {
        let base = kategorieLabel(b.kategorie)
        if (b.kategorie == "aussenwand" || b.kategorie == "innenwand"), let d = b.dicke_m {
            return "\(base) \(cm(d)) cm"
        }
        return base
    }

    // MARK: - Menge / Klassifizierung

    private func toggle(_ key: String) {
        if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
    }

    private func mengeUndEinheit(_ b: MBauteil) -> (Double, String)? {
        switch b.mengen_typ {
        case "volumen": if let v = b.volumen_m3 { return (v, "m³") }
        case "flaeche": if let f = b.flaeche_m2 { return (f, "m²") }
        case "stueck":  return (Double(b.anzahl), "Stk")
        default: break
        }
        return nil
    }

    private func mengeAnzeige(_ b: MBauteil) -> String {
        guard let (menge, einheit) = mengeUndEinheit(b) else { return "—" }
        return "\(fmt(menge)) \(einheit)"
    }

    private func kategorieLabel(_ k: String) -> String {
        switch k {
        case "aussenwand": return "Außenwand (Mauerwerk)"
        case "innenwand": return "Innenwand (Mauerwerk)"
        case "bodenplatte": return "Bodenplatte (Beton)"
        case "beton": return "Beton"
        case "ringbalken": return "Ringbalken"
        case "sturz": return "Stürze"
        case "putz_aussen": return "Außenputz"
        case "putz_innen", "putz": return "Innenputz"
        case "bodenflaeche": return "Bodenflächen"
        // Bestellliste-Sektionen tragen den Gruppentitel als Kategorie (z.B.
        // „1 Abdichtung …") — den direkt zeigen statt „Nicht zugeordnet".
        default:
            // Der Server bildet Bauteile ohne bekannte Bauart, die aber eine
            // Kostengruppe im Namen tragen, auf „kg_360" ab. Roh sieht das im LV
            // häßlich aus — die Bezeichnung steht im DIN-276-Katalog, den die App
            // ohnehin mitbringt.
            if k.hasPrefix("kg_") {
                let nummer = String(k.dropFirst(3))
                if let knoten = DIN276BaumKatalog.knoten(mitNummer: nummer) {
                    return "KG \(nummer) \(knoten.bezeichnung)"
                }
                return "KG \(nummer)"
            }
            return k.isEmpty ? "Nicht zugeordnet" : k
        }
    }

    /// DIN-276-Kostengruppe je Kategorie — grobe Vorbelegung (abgeleitet, änderbar).
    private func kgFuer(_ kategorie: String) -> String {
        switch kategorie {
        // Grobe Vorbelegung (mengenQuelle = .schaetzung) — der Nutzer kann jede KG
        // im LV ändern. Nummern nach DIN276BaumKatalog (siehe DIN276KostenGruppe).
        case "aussenwand", "beton": return "331"   // Tragende Außenwände
        case "innenwand":    return "341"          // Tragende Innenwände (lag fälschlich auf 331)
        case "bodenplatte":  return "322"          // Flachgründungen und Bodenplatten (war 324 = Gründungsbeläge)
        case "ringbalken":   return "351"          // Deckenkonstruktion
        case "sturz":        return "334"          // Außenwandöffnungen
        case "putz_aussen":  return "335"          // Außenwandbekleidung außen
        case "putz_innen", "putz": return "345"    // Innenwandbekleidung
        case "bodenflaeche": return "353"          // Deckenbeläge (war 325 = Abdichtungen und Bekleidungen)
        default:
            // „kg_520" heißt: der Server hat die Kostengruppe im Bauteilnamen
            // gefunden. Die ist genauer als alles, was wir hier raten könnten —
            // ein Mensch hat sie in die Zeichnung geschrieben.
            if kategorie.hasPrefix("kg_") { return String(kategorie.dropFirst(3)) }
            return "300"
        }
    }

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

    // MARK: - Übernehmen ins LV (Deckel + Unterpunkte)

    private func uebernehmenAlle(_ r: MateriallisteResult) {
        var nextPos = (event.lvPositionen?.count ?? 0) + 1
        var deckelAngelegt = 0
        var kinderAngelegt = 0

        for sek in sektionen(r) where selected.contains(sek.key) {
            // Deckel = die zählende LV-Position (Gesamtmenge der Sektion)
            let deckel = LVPosition(context: viewContext)
            deckel.posNr = String(format: "06.%02d", nextPos); nextPos += 1
            deckel.mengenQuelle = .schaetzung
            deckel.kostenGruppeNummer = kgFuer(sek.kategorie)
            deckel.event = event
            deckel.quellDatei = "\(fileName) · \(sek.label)"
            if let g = geschossKuerzel(sek.bauteile.first?.name ?? "") { deckel.geschoss = geschossObjekt(g) }
            deckel.bezeichnung = "\(sek.label) (aus Materialliste)"
            deckel.einheit = sek.einheit
            deckel.menge = sek.summe
            deckel.deckelNotiz = "\(sek.bauteile.count) Einzel-Bauteile aus \(fileName)"
            deckelAngelegt += 1

            // Unterpunkte = die einzelnen Bauteile (Belege, zählen nicht doppelt)
            for b in sek.bauteile {
                guard let (menge, einheit) = mengeUndEinheit(b) else { continue }
                let kind = LVPosition(context: viewContext)
                kind.bezeichnung = b.name
                kind.menge = menge
                kind.einheit = einheit
                kind.kostenGruppeNummer = deckel.kostenGruppeNummer
                kind.mengenQuelleRaw = deckel.mengenQuelleRaw
                kind.event = deckel.event
                kind.quellDatei = "\(fileName) · \(b.name)"
                // Material-Nummer an den BELEG, nicht an den Deckel: unter einem
                // Deckel „Außenwand 24 cm" stecken zwei Steinsorten mit zwei
                // Nummern — eine Nummer je Deckel wäre gelogen. Damit taucht das
                // Bauteil im bestehenden Bestelllisten-Weg mit Artikelnummer auf.
                kind.artikelNummer = b.material_nr
                kind.deckel = deckel   // → Unterpunkt
                kinderAngelegt += 1
            }
        }

        do {
            try viewContext.save()
            uebernahmeMeldung = "\(deckelAngelegt) LV-Einträge mit \(kinderAngelegt) Einzelpositionen übernommen (Schätzung, aus \(fileName))."
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

        URLSession.shared.uploadTask(with: request, from: body) { data, response, err in
            DispatchQueue.main.async {
                loading = false
                if let err = err { error = "Netzwerkfehler: \(err.localizedDescription)"; return }
                guard let data = data else { error = "Keine Antwort vom Server."; return }

                if let r = try? JSONDecoder().decode(MateriallisteResult.self, from: data) {
                    result = r
                    selected = Set(sektionen(r).map(\.key))   // Standard: alle Sektionen gewählt
                    error = ""
                    return
                }

                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                error = ServerFehlertext.fuer(status: status, data: data)
            }
        }.resume()
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",")
    }

    private func cm(_ dicke_m: Double) -> String {
        let v = dicke_m * 100
        if abs(v - v.rounded()) < 0.05 { return String(Int(v.rounded())) }
        return String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
}
