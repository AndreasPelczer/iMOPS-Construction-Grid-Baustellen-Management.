//
//  ImporteView.swift
//
//  Alles, was man einlesen kann — an einem Ort.
//
//  Andreas, 22.09.2026: „Wir müssen gleich nochmal über alle Skripte und
//  Importmöglichkeiten sprechen, da gibt es viele und die sind über die ganze App
//  verteilt, an den Stellen wo man sie braucht, denke ich. Einige braucht man oft
//  und viel, andere selten … und dann muss man sie finden. Können wir alles was mit
//  Importieren zu tun hat zusammenführen unter Importe, die jetzigen Importe an den
//  richtigen Stellen bleiben bestehen, aber es gibt sie auch kompakt."
//
//  🔴 DIE BEDINGUNG: keine zweite Wahrheit. Diese Ansicht RUFT die vorhandenen
//  Import-Ansichten auf und baut nichts nach. Sonst hätten wir zwei GAEB-Importe,
//  die sich auseinanderentwickeln — genau der Fehler, den wir hier dreimal gejagt
//  haben. Was hier steht, ist eine TÜR, kein zweiter Raum.
//
//  Gemessen am 22.09.: 8 Import-Dateien, 20 Ansichten mit Import-Knöpfen.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ImporteView: View {
    @Environment(\.managedObjectContext) private var ctx
    /// Optional: gibt es eine Baustelle, gehen auch die baustellenbezogenen Wege.
    var event: Event?

    @State private var zeigeDateiWahl = false
    @State private var erkannt: ErkannteDatei?

    private struct ErkannteDatei: Identifiable {
        let url: URL
        let typ: DroppedFileType
        var id: String { url.absoluteString }
    }

    var body: some View {
        List {
            Section {
                Button { zeigeDateiWahl = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.folder")
                            .font(.title2).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Datei aussuchen oder herziehen — der Mops sagt, was es ist")
                                .font(.body.weight(.semibold))
                            Text("GAEB · DXF · IFC · PDF · Excel · JSON · SketchUp")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            } header: {
                Text("Wenn du nicht weisst, wohin")
            } footer: {
                Text("Der Mops erkennt das Format an der Dateiendung und sagt, was er "
                     + "damit machen kann. Entscheiden tust du.")
            }

            if event == nil {
                Section {
                    Label("Für die meisten Wege braucht es eine Baustelle. "
                          + "Öffne eine — dann steht hier mehr.",
                          systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            gruppe("Leistungsverzeichnis", "Was gebaut werden soll — daraus entstehen Mengen, Preise und Arbeitspakete", [
                weg("GAEB einlesen", ".x83 · .x84 · .x86 · .d83 — Ausschreibung vom Architekten",
                    "doc.badge.arrow.up", .orange, .gaeb),
                weg("LV aus PDF", "Planungsbüro-PDF — Positionen werden gelesen und vor dem Übernehmen gezeigt",
                    "doc.text.magnifyingglass", .orange, .lvPdf),
                weg("LV als JSON", "aus einer Datei, die der Mops selbst geschrieben hat",
                    "curlybraces", .orange, .lvJson),
            ])

            gruppe("Zeichnungen und Modelle", "Was daraus kommt, sind Mengen — keine Bilder", [
                weg("DXF-Zeichnung", "Wände, Türen, Fenster als Stück und Fläche",
                    "scribble.variable", .blue, .dxf),
                weg("Aushub aus zwei DXF", "Gelände vorher und nachher — daraus die Erdmassen",
                    "mountain.2", .blue, .aushub),
                weg("IFC-Modell", "Bauteile und Mengen aus den Objektnamen",
                    "building.2", .purple, .ifc),
                weg("3D-Modell ansehen", ".usdz · .obj · .stl · .glb · SketchUp",
                    "cube", .green, .cad),
            ])

            gruppe("Unterlagen", "PDFs, aus denen der Mops Fakten liest", [
                weg("Unterlagen auswerten", "Statik, Bodengutachten, B-Plan, Genehmigung",
                    "doc.text.viewfinder", .indigo, .unterlagen),
            ])

            gruppe("Stammdaten und Preise", "Gilt für alle Baustellen, nicht nur für diese", [
                weg("Material und Preise", "Excel oder CSV vom Lieferanten",
                    "tablecells", .teal, .material),
                weg("Firma übernehmen", "Stammdaten von einem anderen Mops",
                    "building.columns", .teal, .firma),
            ])
        }
        .navigationTitle("Importe")
        .navigationBarTitleDisplayMode(.inline)
        // 🔴 `universalFileDropTarget` war gebaut, getestet und NIRGENDS eingehängt —
        // gemessen am 22.09.2026. Hier ist die Stelle, an der es hingehört: wer eine
        // Datei hat und nicht weiss wohin, zieht sie hierher.
        .universalFileDropTarget { url in
            erkannt = ErkannteDatei(url: url, typ: DroppedFileType.detect(from: url))
        }
        .fileImporter(isPresented: $zeigeDateiWahl,
                      allowedContentTypes: [.item], allowsMultipleSelection: false) { ergebnis in
            guard case .success(let urls) = ergebnis, let url = urls.first else { return }
            erkannt = ErkannteDatei(url: url, typ: DroppedFileType.detect(from: url))
        }
        .sheet(item: $erkannt) { d in
            ErkannteDateiBlatt(url: d.url, typ: d.typ, hatBaustelle: event != nil)
        }
    }

    // MARK: - Die Wege

    private enum Ziel {
        case gaeb, lvPdf, lvJson, dxf, aushub, ifc, cad, unterlagen, material, firma
    }

    private struct Weg: Identifiable {
        let id = UUID()
        let titel: String, unter: String, symbol: String
        let farbe: Color, ziel: Ziel
    }

    private func weg(_ t: String, _ u: String, _ s: String, _ f: Color, _ z: Ziel) -> Weg {
        Weg(titel: t, unter: u, symbol: s, farbe: f, ziel: z)
    }

    @ViewBuilder
    private func gruppe(_ name: String, _ unter: String, _ wege: [Weg]) -> some View {
        Section {
            ForEach(wege) { w in
                NavigationLink {
                    SpaeterLaden { ziel(w.ziel) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: w.symbol)
                            .font(.title3).foregroundStyle(w.farbe)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.titel).font(.subheadline.weight(.semibold))
                            Text(w.unter).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(brauchtBaustelle(w.ziel) && event == nil)
            }
        } header: {
            Text(name)
        } footer: {
            Text(unter)
        }
    }

    private func brauchtBaustelle(_ z: Ziel) -> Bool {
        switch z {
        case .material, .firma: return false
        default:                return true
        }
    }

    /// 🔴 Hier wird NUR weitergeleitet. Keine eigene Logik, kein zweiter Importer.
    private func ziel(_ z: Ziel) -> AnyView {
        switch z {
        case .gaeb, .lvPdf, .lvJson:
            if let event { AnyView(LVView(event: event)) } else { AnyView(leer) }
        case .dxf:
            if let event { AnyView(IFCLeserView(event: event)) } else { AnyView(leer) }
        case .aushub:
            if let event { AnyView(AushubAusDXFView(event: event)) } else { AnyView(leer) }
        case .ifc:
            if let event { AnyView(IFCLeserView(event: event)) } else { AnyView(leer) }
        case .cad, .unterlagen:
            if let event { AnyView(EventDetailView(event: event)) } else { AnyView(leer) }
        case .material:
            AnyView(StammdatenPflegeView())
        case .firma:
            AnyView(StammdatenPflegeView())
        }
    }

    private var leer: some View {
        ContentUnavailableView("Dafür braucht es eine Baustelle",
                               systemImage: "building.2",
                               description: Text("Leg eine an oder öffne eine vorhandene."))
    }
}

// MARK: - Was ist das für eine Datei?

/// Zeigt, was der Mops in der Datei erkennt — und was er damit machen kann.
/// 🔴 Er übernimmt nichts von selbst: erkennen ist nicht einlesen.
struct ErkannteDateiBlatt: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let typ: DroppedFileType
    let hatBaustelle: Bool

    private var groesse: String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: typ.iconName)
                            .font(.largeTitle).foregroundStyle(typ.iconColor)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(url.lastPathComponent).font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text("\(typ.displayName) · \(groesse)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text(typ.wasDerMopsDamitMacht).font(.subheadline)
                } header: {
                    Text("Was der Mops damit machen kann")
                } footer: {
                    if typ == .unknown {
                        Text("Erkannt wird an der Dateiendung. Wenn du weisst, was das ist, "
                             + "nimm den passenden Weg aus der Liste.")
                    } else if typ.brauchtBaustelle && !hatBaustelle {
                        Text("Dafür braucht es eine Baustelle. Öffne eine und komm wieder.")
                    } else {
                        Text("Der Mops liest nichts von selbst ein — du entscheidest, wohin.")
                    }
                }
            }
            .navigationTitle("Was ist das?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verstanden") { dismiss() }
                }
            }
        }
    }
}
