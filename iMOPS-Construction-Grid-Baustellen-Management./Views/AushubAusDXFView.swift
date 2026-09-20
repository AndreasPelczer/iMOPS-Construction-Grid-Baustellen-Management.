//
//  AushubAusDXFView.swift
//  Geländebrücke, offline: zwei DXF rein — Geländeplan ohne Haus, Grundstückszeichnung
//  mit Haus — und der Aushub kommt gerechnet raus, nicht geschätzt.
//
//  Der Weg in fünf Schritten, genau wie auf dem Papier:
//    1. Geländeplan laden  → Punktwolke
//    2. Maßstab bestätigen → SketchUp-Zollfalle abfangen
//    3. Zeichnung mit Haus → Umriss des Baukörpers
//    4. Höhenanker setzen  → Rohfußboden müNN, damit das Modell weiß, wo oben ist
//    5. Rechnen            → Abtrag/Auftrag, dann ins LV
//
//  EHRLICH: geometrisches Volumen im gewachsenen Zustand, ohne Auflockerung, kein
//  Vermesser-Aufmaß. Rasterzellen ohne Geländepunkt werden gezählt und angezeigt.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct AushubAusDXFView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    // Schritt 1+2: Gelände
    @State private var gelaende: DXFRohmodell?
    @State private var gelaendeDatei = ""
    @State private var massstab: DXFMassstab = .meter
    @State private var massstabBegruendung = ""

    // Schritt 3: Haus
    @State private var haus: DXFRohmodell?
    @State private var hausDatei = ""
    @State private var umrissQuelle = Self.autoQuelle
    @State private var bezeichnung = "Baugrube Wohnhaus ausheben"

    // Schritt 4: Anker und Maße
    @State private var schonInMuNN = false
    @State private var rohfussboden = 196.10
    @State private var ankerModellZ = 2.30
    @State private var bodenaufbau = 0.22
    @State private var plattendicke = 0.16
    @State private var polster = 0.65
    @State private var arbeitsraum = 0.50
    @State private var zellgroesse = 0.25

    // Schritt 5
    @State private var ergebnis: Aushubergebnis?
    @State private var rechnet = false
    @State private var fehler = ""
    @State private var meldung = ""
    @State private var picker: Picke?

    static let autoQuelle = "automatisch (Wand-Layer)"

    private enum Picke: Identifiable { case gelaende, haus; var id: Int { self == .gelaende ? 0 : 1 } }

    private var vorgabe: Aushubvorgabe {
        Aushubvorgabe(rohfussbodenMuNN: rohfussboden, bodenaufbau: bodenaufbau,
                      plattendicke: plattendicke, polster: polster, arbeitsraum: arbeitsraum)
    }

    private var hoehenversatz: Double {
        schonInMuNN ? 0 : Aushubrechner.hoehenversatz(modellZ: ankerModellZ,
                                                      entsprichtMuNN: vorgabe.okBodenplatteMuNN)
    }

    /// Alle Layer der Hauszeichnung, die als Umriss taugen (mindestens 4 Punkte).
    private var umrissQuellen: [String] {
        guard let haus else { return [Self.autoQuelle] }
        return [Self.autoQuelle] + haus.proLayer.filter { $0.value >= 4 }.keys.sorted()
    }

    private var umriss: Umriss? {
        guard let haus else { return nil }
        let roh: Umriss?
        if umrissQuelle == Self.autoQuelle {
            roh = DXFGelaendeLeser.gebaeudeUmriss(haus)
        } else {
            roh = Umriss.umschliessend(haus.punkte.filter { $0.layer == umrissQuelle })
        }
        return roh?.skaliert(massstab.faktor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    if !fehler.isEmpty { fehlerBox }
                    schrittGelaende
                    if gelaende != nil { schrittHaus }
                    if gelaende != nil && haus != nil { schrittAnker; rechnenKnopf }
                    if let e = ergebnis { ergebnisKarte(e); uebernahme }
                }
                .padding()
            }
            .navigationTitle("Aushub aus DXF")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .fileImporter(isPresented: Binding(get: { picker != nil }, set: { if !$0 { picker = nil } }),
                          allowedContentTypes: [UTType(filenameExtension: "dxf") ?? .data, .data],
                          allowsMultipleSelection: false) { res in
                let ziel = picker; picker = nil
                handle(res, ziel: ziel)
            }
            .alert("Leistungsverzeichnis", isPresented: Binding(
                get: { !meldung.isEmpty }, set: { if !$0 { meldung = "" } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(meldung) }
        }
    }

    // MARK: - Schritte

    private var intro: some View {
        Text("Zwei Zeichnungen, ein Aushub: der Geländeplan **ohne** Haus liefert die Höhen, "
             + "die Grundstückszeichnung **mit** Haus den Umriss. Beide müssen aus demselben "
             + "Koordinatensystem kommen.")
            .font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var fehlerBox: some View {
        Text(fehler).font(.caption).foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8).background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var schrittGelaende: some View {
        karte("1 · Geländeplan (ohne Haus)") {
            Button { picker = .gelaende } label: {
                Label(gelaende == nil ? "Gelände-DXF wählen" : "andere Datei", systemImage: "mountain.2")
            }
            .buttonStyle(.borderedProminent)

            if let g = gelaende, let u = g.umriss {
                Text(gelaendeDatei).font(.caption).foregroundStyle(.secondary)
                zeile("Punkte", "\(g.punkte.count)")
                zeile("Spannweite", String(format: "%.2f × %.2f Einheiten", u.breite, u.tiefe))
                if g.abgebrochen {
                    hinweis("Der Blockbaum war tiefer als \(DXFGelaendeLeser.maxTiefe) Ebenen — "
                            + "es kann Geometrie fehlen.")
                }
                Divider()
                Text("Maßstab").font(.subheadline.bold())
                Picker("Maßstab", selection: $massstab) {
                    Text(DXFMassstab.meter.name).tag(DXFMassstab.meter)
                    Text(DXFMassstab.zollAlsMeter.name).tag(DXFMassstab.zollAlsMeter)
                }
                .pickerStyle(.segmented)
                .onChange(of: massstab) { _, _ in ergebnis = nil }
                Text(massstabBegruendung).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                zeile("ergibt", String(format: "%.1f × %.1f m, Höhenspanne %.2f m",
                                       u.breite * massstab.faktor, u.tiefe * massstab.faktor,
                                       g.zSpanne * massstab.faktor))
            }
        }
    }

    private var schrittHaus: some View {
        karte("2 · Zeichnung mit Haus") {
            Button { picker = .haus } label: {
                Label(haus == nil ? "Haus-DXF wählen" : "andere Datei", systemImage: "house")
            }
            .buttonStyle(.bordered)

            if let h = haus {
                Text(hausDatei).font(.caption).foregroundStyle(.secondary)
                Picker("Umriss aus", selection: $umrissQuelle) {
                    ForEach(umrissQuellen, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: umrissQuelle) { _, _ in ergebnis = nil }

                if let u = umriss {
                    zeile("Umriss", String(format: "%.2f × %.2f m = %.1f m²", u.breite, u.tiefe, u.flaeche))
                    zeile("mit Arbeitsraum", String(format: "%.1f m²", u.erweitert(um: arbeitsraum).flaeche))
                } else {
                    hinweis("In dieser Zeichnung wurde kein Wand-Layer erkannt "
                            + "(gesucht wird nach \(DXFGelaendeLeser.gebaeudeBegriffe.joined(separator: ", "))). "
                            + "Oben den richtigen Layer auswählen.")
                }
                Text("\(h.punkte.count) Punkte, \(h.proLayer.count) Layer")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var schrittAnker: some View {
        karte("3 · Höhenanker und Aufbau") {
            Toggle("Geländemodell liegt schon in müNN", isOn: $schonInMuNN)
                .onChange(of: schonInMuNN) { _, _ in ergebnis = nil }
                .font(.subheadline)

            feld("Rohfußboden EG (müNN)", $rohfussboden, schritt: 0.01)
            if !schonInMuNN {
                feld("OK Bodenplatte liegt im Modell auf Z (m)", $ankerModellZ, schritt: 0.01)
                if let z = hausWandfussZ {
                    Button("Wandfuß aus der Hauszeichnung übernehmen (\(fmt(z)) m)") {
                        ankerModellZ = (z * 100).rounded() / 100; ergebnis = nil
                    }
                    .font(.caption)
                }
                zeile("Höhenversatz", String(format: "Modell + %.2f = müNN", hoehenversatz))
            }
            Divider()
            feld("Bodenaufbau über der Platte (m)", $bodenaufbau, schritt: 0.01)
            feld("Plattendicke (m)", $plattendicke, schritt: 0.01)
            feld("Polster / Frostschutz (m)", $polster, schritt: 0.05)
            feld("Arbeitsraum allseitig (m)", $arbeitsraum, schritt: 0.05)
            feld("Rasterzelle (m)", $zellgroesse, schritt: 0.05)
            Divider()
            zeile("OK Bodenplatte", String(format: "%.2f müNN", vorgabe.okBodenplatteMuNN))
            zeile("Aushubsohle", String(format: "%.2f müNN", vorgabe.sohleMuNN))
                .fontWeight(.semibold)
        }
    }

    private var rechnenKnopf: some View {
        Button { rechne() } label: {
            Label(rechnet ? "rechnet …" : "Aushub rechnen", systemImage: "function")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(rechnet || umriss == nil)
    }

    private func ergebnisKarte(_ e: Aushubergebnis) -> some View {
        karte("4 · Ergebnis") {
            zeile("Fläche", String(format: "%.1f m² (%.2f × %.2f m)", e.flaecheM2,
                                   e.ausschnitt.breite, e.ausschnitt.tiefe))
            zeile("Gelände", String(format: "%.2f – %.2f müNN (Mittel %.2f)",
                                    e.gelaendeMin, e.gelaendeMax, e.gelaendeMittel))
            zeile("Aushubsohle", String(format: "%.2f müNN", e.sohleMuNN))
            zeile("mittlere Tiefe", String(format: "%.2f m", e.mittlereTiefe))
            Divider()
            HStack {
                Text("Abtrag").font(.headline)
                Spacer()
                Text(String(format: "%.1f m³", e.abtragM3)).font(.headline.monospacedDigit())
            }
            if e.auftragM3 > 0.05 {
                zeile("Auftrag", String(format: "%.1f m³", e.auftragM3))
            }
            if let h = e.rasterHinweis { hinweis(h) }
            Text("Geometrisches Volumen im gewachsenen Zustand — ohne Auflockerung, "
                 + "ohne Böschungsausrundung, kein Vermesser-Aufmaß.")
                .font(.caption2).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var uebernahme: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Bezeichnung der LV-Position", text: $bezeichnung)
                .textFieldStyle(.roundedBorder)
            Button { uebernehmen() } label: {
                Label("Aushub ins LV übernehmen", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Kleinteile

    private func karte<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(.headline)
            inhalt()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack { Text(titel).font(.subheadline); Spacer()
            Text(wert).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
    }

    private func hinweis(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func feld(_ titel: String, _ wert: Binding<Double>, schritt: Double) -> some View {
        HStack {
            Text(titel).font(.subheadline)
            Spacer()
            TextField("", value: wert, format: .number.precision(.fractionLength(0...3)))
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                #if !os(macOS)
                .keyboardType(.decimalPad)
                #endif
                .textFieldStyle(.roundedBorder)
                .onChange(of: wert.wrappedValue) { _, _ in ergebnis = nil }
        }
    }

    /// Unterkante der Hauswände im Modell (nach Maßstab) — der übliche Anker „OK Bodenplatte".
    private var hausWandfussZ: Double? {
        guard let haus else { return nil }
        let ps = umrissQuelle == Self.autoQuelle
            ? haus.punkte(mitBegriffen: DXFGelaendeLeser.gebaeudeBegriffe)
            : haus.punkte.filter { $0.layer == umrissQuelle }
        guard let z = ps.map(\.z).min() else { return nil }
        return z * massstab.faktor
    }

    private func fmt(_ d: Double) -> String {
        let r = (d * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r)
    }

    // MARK: - Rechnen

    private func rechne() {
        guard let g = gelaende, let u = umriss else { return }
        rechnet = true
        fehler = ""
        let f = massstab.faktor
        let versatz = hoehenversatz
        let punkte = g.punkte.map { (x: $0.x * f, y: $0.y * f, z: $0.z * f + versatz) }
        let v = vorgabe
        let zelle = max(0.05, zellgroesse)
        DispatchQueue.global(qos: .userInitiated).async {
            let erg = Aushubrechner.rechne(gelaende: punkte, umriss: u, vorgabe: v, zellgroesse: zelle)
            DispatchQueue.main.async {
                rechnet = false
                if let erg {
                    ergebnis = erg
                } else {
                    fehler = "Kein Ergebnis: Das Geländemodell deckt den Hausumriss nicht ab. "
                           + "Stammen beide Zeichnungen aus demselben Koordinatensystem?"
                }
            }
        }
    }

    // MARK: - Übernehmen

    private func uebernehmen() {
        guard let e = ergebnis, e.abtragM3 > 0 || e.auftragM3 > 0 else { return }
        var nextPos = (event.lvPositionen?.count ?? 0) + 1
        var angelegt = 0

        func lege(_ bez: String, menge: Double, kg: String) {
            guard menge > 0.01 else { return }
            let pos = LVPosition(context: viewContext)
            pos.posNr = String(format: "01.%02d", nextPos)
            pos.mengenQuelle = .schaetzung
            pos.kostenGruppeNummer = kg
            pos.event = event
            pos.quellDatei = "\(gelaendeDatei) + \(hausDatei)"
            pos.bezeichnung = bez
            pos.langtext = e.rechenweg + " Quelle: \(gelaendeDatei) (Gelände) und \(hausDatei) (Umriss)."
            pos.einheit = "m³"
            pos.menge = (menge * 100).rounded() / 100
            _ = LeistungskatalogService.autoMatch(position: pos, in: viewContext)
            nextPos += 1; angelegt += 1
        }

        lege(bezeichnung.isEmpty ? "Baugrube ausheben" : bezeichnung, menge: e.abtragM3, kg: "311")
        lege("Auffüllen und verdichten", menge: e.auftragM3, kg: "312")

        do {
            try viewContext.save()
            meldung = "\(angelegt) Position(en) ins LV übernommen — mit Rechenweg im Langtext."
        } catch {
            meldung = "Fehler beim Speichern: \(error.localizedDescription)"
        }
    }

    // MARK: - Datei

    private func handle(_ res: Result<[URL], Error>, ziel: Picke?) {
        guard let ziel else { return }
        switch res {
        case .failure(let err): fehler = "Fehler: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                fehler = "Keine Berechtigung für die Datei."; return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let modell = DXFGelaendeLeser.lies(dxf: text)
                guard !modell.istLeer else {
                    fehler = "In \(url.lastPathComponent) wurden keine Punkte gefunden. "
                           + "Ist das eine DXF mit Geometrie (VERTEX/3DFACE/LINE)?"
                    return
                }
                fehler = ""
                ergebnis = nil
                switch ziel {
                case .gelaende:
                    gelaende = modell
                    gelaendeDatei = url.lastPathComponent
                    let v = DXFMassstab.vorschlag(fuer: modell)
                    massstab = v.massstab
                    massstabBegruendung = v.begruendung
                case .haus:
                    haus = modell
                    hausDatei = url.lastPathComponent
                    umrissQuelle = Self.autoQuelle
                    if let z = hausWandfussZ { ankerModellZ = (z * 100).rounded() / 100 }
                }
            } catch {
                fehler = "Fehler beim Lesen: \(error.localizedDescription) "
                       + "(DXF muss Text sein, keine DWG/Binär-DXF)."
            }
        }
    }
}
