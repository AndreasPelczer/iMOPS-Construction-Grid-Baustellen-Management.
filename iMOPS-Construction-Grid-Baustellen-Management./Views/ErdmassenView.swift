//
//  ErdmassenView.swift
//  Bogen 1: aus einem Höhenraster (DGM1-XYZ) die Erdmassen rechnen — Abtrag/Auftrag gegen
//  ein Planum — und den Aushub als LV-Position übernehmen. Von dort läuft die Kette weiter:
//  MaschinenPlanung → Bagger-Stunden → Miete → Brigade.
//
//  EHRLICH: Schätzung aus offenen Höhendaten, kein Vermesser-Aufmaß; Bodenauflockerung
//  ist nicht eingerechnet (geometrisches Volumen im gewachsenen Zustand).
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ErdmassenView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var event: Event

    @State private var showingPicker = false
    @State private var fileName = ""
    @State private var dgm: Gelaendemodell?
    @State private var zielHoehe = 0.0
    @State private var error = ""
    @State private var meldung = ""

    private var massen: Erdmassen? {
        dgm.map { ErdmassenRechner.gegenEbene($0, zielHoehe: zielHoehe) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    if !error.isEmpty { errorBox }
                    if let dgm { gelaendeKarte(dgm) }
                    if let m = massen { massenKarte(m) }
                    if massen != nil { uebernahmeLeiste() }
                }
                .padding()
            }
            .navigationTitle("Erdmassen aus Gelände")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .fileImporter(isPresented: $showingPicker,
                          allowedContentTypes: [UTType(filenameExtension: "xyz") ?? .plainText, .plainText, .data],
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
            Text("Rechnet Abtrag/Auftrag gegen ein Planum aus einem DGM1-Höhenraster („x y z“ je Zeile); der Abtrag wird als Aushub ins LV übernommen.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button { showingPicker = true } label: {
                Label("Gelände (XYZ)", systemImage: "mountain.2")
            }
            .buttonStyle(.borderedProminent)
            if !fileName.isEmpty { Text(fileName).font(.caption).foregroundStyle(.secondary) }
            NavigationLink {
                AushubAusDXFView(event: event)
            } label: {
                Label("Aushub aus zwei DXF (Gelände + Haus)", systemImage: "square.3.layers.3d")
            }
            .buttonStyle(.bordered)
            Text("Zwei Zeichnungen statt eines Rasters: Geländeplan ohne Haus + Grundstückszeichnung mit Haus → Umriss, Aushubsohle, Abtrag. Rechnet offline im Mops. Die Geländebrücke (Welle 7) auf der Baustelle macht dasselbe server-seitig, inkl. Hauslage platzieren.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var errorBox: some View {
        Text(error).font(.caption).foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8).background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func gelaendeKarte(_ dgm: Gelaendemodell) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gelände").font(.subheadline.weight(.semibold))
            Text("\(fmt(dgm.flaeche)) m² · \(dgm.zellen) Rasterpunkte (\(fmt(dgm.dx))×\(fmt(dgm.dy)) m)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            Text("Höhen \(fmt(dgm.minHoehe))–\(fmt(dgm.maxHoehe)) m · Mittel \(fmt(dgm.mittlereHoehe)) m")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack {
                Text("Planum (Zielhöhe)")
                Spacer()
                TextField("m", value: $zielHoehe, format: .number)
                    .frame(width: 90).multilineTextAlignment(.trailing)
                    #if !os(macOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text("m").foregroundStyle(.secondary)
            }
            Button {
                zielHoehe = (dgm.mittlereHoehe * 100).rounded() / 100
            } label: {
                Label("Massenausgleich (Abtrag = Auftrag)", systemImage: "arrow.up.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func massenKarte(_ m: Erdmassen) -> some View {
        let tage = Erdbauleistung.stunden(menge: m.abtragM3, leistung: Erdbauleistung.minibagger) / 8.0
        return VStack(alignment: .leading, spacing: 6) {
            Text("Erdmassen gegen Planum \(fmt(zielHoehe)) m").font(.subheadline.weight(.semibold))
            zeile("⛏ Abtrag (Aushub)", "\(fmt(m.abtragM3)) m³")
            zeile("🪣 Auftrag (Auffüllen)", "\(fmt(m.auftragM3)) m³")
            zeile(m.nettoM3 >= 0 ? "🚚 Überschuss (abfahren)" : "🚚 Defizit (Boden liefern)",
                  "\(fmt(abs(m.nettoM3))) m³")
            Text("≈ \(fmt(tage)) Minibagger-Tage (Richtwert \(fmt(Erdbauleistung.minibagger)) m³/h) — genauer über die Geräte-Stammdaten.")
                .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack { Text(titel).font(.subheadline); Spacer()
            Text(wert).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
    }

    private func uebernahmeLeiste() -> some View {
        Button { uebernehmen() } label: {
            Label("Aushub ins LV übernehmen", systemImage: "tray.and.arrow.down.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Übernehmen

    private func uebernehmen() {
        guard let m = massen, m.abtragM3 > 0 || m.auftragM3 > 0 else { return }
        var nextPos = (event.lvPositionen?.count ?? 0) + 1
        var angelegt = 0

        func lege(_ bez: String, menge: Double, kg: String) {
            guard menge > 0 else { return }
            let pos = LVPosition(context: viewContext)
            pos.posNr = String(format: "01.%02d", nextPos)
            pos.mengenQuelle = .schaetzung
            pos.kostenGruppeNummer = kg
            pos.event = event
            pos.quellDatei = "Gelände \(fileName) · Planum \(fmt(zielHoehe)) m"
            pos.bezeichnung = bez
            pos.langtext = "Aus DGM1-Höhenraster \(fileName), Planum \(fmt(zielHoehe)) m (Schätzung, ohne Auflockerung)."
            pos.einheit = "m³"
            pos.menge = (menge * 100).rounded() / 100
            _ = LeistungskatalogService.autoMatch(position: pos, in: viewContext)
            nextPos += 1; angelegt += 1
        }

        lege("Bodenaushub Baugrube", menge: m.abtragM3, kg: "311")
        lege("Auffüllen und verdichten", menge: m.auftragM3, kg: "312")

        do {
            try viewContext.save()
            meldung = "\(angelegt) Erdbau-Position(en) ins LV übernommen (Schätzung, aus \(fileName))."
        } catch {
            meldung = "Fehler beim Speichern: \(error.localizedDescription)"
        }
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
                error = ""
                guard let modell = Gelaendemodell.ausXYZ(text) else {
                    dgm = nil
                    error = "Kein sauberes Höhenraster erkannt. Erwartet: „x y z“ je Zeile (DGM1-XYZ), lückenloses Gitter."
                    return
                }
                dgm = modell
                zielHoehe = (modell.mittlereHoehe * 100).rounded() / 100   // Start = Massenausgleich
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
