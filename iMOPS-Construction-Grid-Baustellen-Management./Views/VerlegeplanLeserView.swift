//
//  VerlegeplanLeserView.swift
//  Bogen 2: einen Pflaster-/Flächen-Verlegeplan (DXF) lesen und die Mengen ins LV übernehmen.
//
//  OFFLINE — der VerlegeplanLeser parst die DXF direkt (Steinzählung × Maß im Blocknamen).
//  Jede übernommene Position bekommt die Herkunft (Datei + Layer) in `quellDatei` und wird
//  gleich per autoMatch an die Pflaster-Aufwandswerte gehängt (ROT→GELB).
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct VerlegeplanLeserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var showingPicker = false
    @State private var fileName = ""
    @State private var result: VerlegeplanResult?
    @State private var error = ""
    @State private var selectedLayer: Set<String> = []
    @State private var selectedAufbau: Set<String> = []
    @State private var meldung = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    if !error.isEmpty { errorBox }
                    if let r = result {
                        if r.istLeer {
                            Text("Keine Pflaster-/Flächen-Blöcke erkannt. Ist das ein Verlegeplan (Steine als Blöcke)? Wandpläne gehen über „Wände aus Plan“.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            layerAuswahl(r)
                        }
                        if !r.aufbau.isEmpty { aufbauAuswahl(r) }
                        if !r.hinweise.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(r.hinweise, id: \.self) { h in
                                    Text("• " + h).font(.caption2).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        if !selectedLayer.isEmpty || !selectedAufbau.isEmpty { uebernahmeLeiste(r) }
                    }
                }
                .padding()
            }
            .navigationTitle("Mengen aus Plan")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [UTType(filenameExtension: "dxf") ?? .data],
                          allowsMultipleSelection: false) { res in handlePick(res) }
            .alert("Leistungsverzeichnis", isPresented: Binding(
                get: { !meldung.isEmpty }, set: { if !$0 { meldung = "" } })) {
                Button("OK", role: .cancel) { }
            } message: { Text(meldung) }
        }
    }

    // MARK: - Bausteine

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Liest Mengen aus einem Verlegeplan (DXF): Pflasterfläche aus der Steinzählung × Maß im Blocknamen, Randsteine als Stück, der Aufbau (Schotter/Splitt) aus den Layer-Namen.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showingPicker = true } label: {
                Label(fileName.isEmpty ? "Plan wählen (DXF)" : "Anderen Plan wählen", systemImage: "doc.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            if !fileName.isEmpty {
                Text(fileName).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var errorBox: some View {
        Text(error).font(.caption).foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8).background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func layerAuswahl(_ r: VerlegeplanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Erkannt — ankreuzen, was ins LV soll").font(.subheadline.weight(.semibold))
            ForEach(r.layer) { lay in
                zeile(name: lay.name,
                      menge: "\(fmt(lay.menge)) \(lay.einheit)",
                      detail: lay.detail,
                      an: selectedLayer.contains(lay.name)) {
                    if selectedLayer.contains(lay.name) { selectedLayer.remove(lay.name) }
                    else { selectedLayer.insert(lay.name) }
                }
            }
        }
    }

    private func aufbauAuswahl(_ r: VerlegeplanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aufbau (Tragschicht/Bettung)").font(.subheadline.weight(.semibold))
            Text("Menge ≈ Pflasterfläche (\(fmt(r.flaecheGesamt)) m²). Dicke danach in der Position setzen.")
                .font(.caption2).foregroundStyle(.secondary)
            ForEach(r.aufbau, id: \.self) { name in
                zeile(name: name,
                      menge: "\(fmt(r.flaecheGesamt)) m²",
                      detail: bezeichnungFuer(name),
                      an: selectedAufbau.contains(name)) {
                    if selectedAufbau.contains(name) { selectedAufbau.remove(name) }
                    else { selectedAufbau.insert(name) }
                }
            }
        }
    }

    private func zeile(name: String, menge: String, detail: String, an: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: an ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(an ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(name).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(menge).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    if !detail.isEmpty {
                        Text(detail).font(.caption2).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    private func uebernahmeLeiste(_ r: VerlegeplanResult) -> some View {
        let anzahl = selectedLayer.count + selectedAufbau.count
        return Button {
            uebernehmen(r)
        } label: {
            Label("\(anzahl) Position(en) ins LV übernehmen", systemImage: "tray.and.arrow.down.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 4)
    }

    // MARK: - Übernehmen

    private func uebernehmen(_ r: VerlegeplanResult) {
        var nextPos = (event.lvPositionen?.count ?? 0) + 1
        var angelegt = 0

        func lege(name: String, menge: Double, einheit: String, detail: String) {
            let pos = LVPosition(context: viewContext)
            pos.posNr = String(format: "07.%02d", nextPos)
            pos.mengenQuelle = .schaetzung
            pos.kostenGruppeNummer = kgFuer(name)
            pos.event = event
            pos.quellDatei = "\(fileName) · Layer \(name)"
            pos.bezeichnung = bezeichnungFuer(name)
            pos.langtext = "Aus Verlegeplan \(fileName), Layer \(name): \(detail)"
            pos.einheit = einheit
            pos.menge = menge
            _ = LeistungskatalogService.autoMatch(position: pos, in: viewContext)
            nextPos += 1; angelegt += 1
        }

        for lay in r.layer where selectedLayer.contains(lay.name) {
            lege(name: lay.name, menge: lay.menge, einheit: lay.einheit, detail: lay.detail)
        }
        for name in r.aufbau where selectedAufbau.contains(name) {
            lege(name: name, menge: r.flaecheGesamt, einheit: "m²", detail: "Tragschicht/Bettung, Fläche aus Pflaster")
        }

        do {
            try viewContext.save()
            meldung = "\(angelegt) Position(en) ins LV übernommen (Schätzung, aus \(fileName))."
            selectedLayer.removeAll(); selectedAufbau.removeAll()
        } catch {
            meldung = "Fehler beim Speichern: \(error.localizedDescription)"
        }
    }

    // MARK: - Zuordnung Layer → Katalog

    /// Katalog-nahe Bezeichnung, damit autoMatch die Pflaster-Aufwandswerte trifft.
    private func bezeichnungFuer(_ layer: String) -> String {
        let u = layer.lowercased()
        if u.contains("pflaster") { return "Betonverbundpflaster verlegen" }
        if u.contains("leisten") { return "Leistensteine setzen" }
        if u.contains("bord") || u.contains("rand") { return "Bordsteine setzen" }
        if u.contains("schotter") { return "Schottertragschicht 0/32 einbauen" }
        if u.contains("splitt") { return "Splittbett herstellen" }
        return "\(layer) (aus Plan)"
    }

    /// DIN-276-Kostengruppe: Pflaster/Aufbau = Außenanlagen/Verkehrsflächen (520), sonst 500.
    private func kgFuer(_ layer: String) -> String {
        let u = layer.lowercased()
        if ["pflaster", "schotter", "splitt", "bord", "rand", "leisten"].contains(where: u.contains) { return "520" }
        return "500"
    }

    // MARK: - Datei

    private func handlePick(_ res: Result<[URL], Error>) {
        switch res {
        case .failure(let err): error = "Fehler: \(err.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                error = "Keine Berechtigung für die Datei."; return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                fileName = url.lastPathComponent
                selectedLayer.removeAll(); selectedAufbau.removeAll(); error = ""
                let r = VerlegeplanLeser.lies(dxf: text)
                result = r
                // Flächen-Layer als Vorschlag vorauswählen (die will man fast immer).
                selectedLayer = Set(r.layer.filter { $0.art == .flaeche }.map(\.name))
            } catch {
                self.error = "Fehler beim Lesen: \(error.localizedDescription)"
            }
        }
    }

    private func fmt(_ d: Double) -> String {
        let r = (d * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(format: "%.2f", r)
    }
}
