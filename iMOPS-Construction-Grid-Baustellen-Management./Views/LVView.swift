import SwiftUI
import Combine
import CoreData
import MessageUI
import UIKit

// MARK: - LV Hauptansicht

private enum LVGruppierung: String, CaseIterable, Identifiable {
    case kostenGruppe
    case dokumentStruktur
    case gebaeudeGeschoss

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kostenGruppe: return "KG"
        case .dokumentStruktur: return "Dokument"
        case .gebaeudeGeschoss: return "Ebene"
        }
    }

    var systemImage: String {
        switch self {
        case .kostenGruppe: return "folder"
        case .dokumentStruktur: return "doc.text"
        case .gebaeudeGeschoss: return "building.2"
        }
    }
}

private struct LVSectionGroup: Identifiable {
    let id: String
    let title: String
    let items: [LVPosition]
}

/// Sprung ins Quell-PDF mit Suchbegriffen (Weg A): URL + was gesucht/markiert wird.
private struct PDFSprung: Identifiable {
    let id = UUID()
    let url: URL
    let suchbegriffe: [String]
    let seite: Int?
    let titel: String
}

struct LVView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(ImportedFileHandler.self) private var importedFileHandler
    @ObservedObject var event: Event

    @FetchRequest private var positionen: FetchedResults<LVPosition>
    @State private var pdfSprung: PDFSprung?
    @State private var showingAdd = false
    @State private var editPosition: LVPosition?
    @State private var actionPosition: LVPosition?
    @State private var positionToDelete: LVPosition?
    @State private var kalkPosition: LVPosition?
    @State private var fortschrittPosition: LVPosition?
    @State private var aufmassPosition: LVPosition?
    @State private var showBestellliste = false
    @State private var showAngebotsVergleich = false
    @State private var showKostenübersicht = false
    @State private var showAbdeckung = false
    @State private var showUebernahme = false
    @State private var showGeschossKosten = false
    @State private var showHierarchieVerwalten = false
    @State private var showFreigabeStatus = false
    @State private var showStammdaten = false
    @State private var showImport = false
    @State private var showGAEBImport = false
    @State private var showBausteine = false
    @State private var droppedGAEBURL: URL?
    @State private var showHelp = false
    @State private var exportURL: URL?
    @State private var gruppierung: LVGruppierung = .kostenGruppe

    // Typ B — manuelles Zusammenführen zu einem Deckel
    @State private var auswahlModus = false
    @State private var ausgewaehlt: Set<NSManagedObjectID> = []
    @State private var deckelDialog = false
    @State private var speicherFehler: String?

    @State private var showMissingPricesAlert = false
    @State private var missingPricesCount = 0
    @State private var pendingExportFormat: GAEBExportFormat?

    @State private var showXRMissingAlert = false
    @State private var xrMissingCount = 0

    @StateObject private var store = AngebotsStore.shared
    @StateObject private var fortStore = LVFortschrittStore.shared

    init(event: Event) {
        self.event = event
        _positionen = FetchRequest(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \LVPosition.kostenGruppeNummer, ascending: true),
                NSSortDescriptor(keyPath: \LVPosition.posNr, ascending: true)
            ],
            predicate: NSPredicate(format: "event == %@", event),
            animation: .default
        )
    }

    private var grouped: [LVSectionGroup] {
        switch gruppierung {
        case .kostenGruppe:
            return groupedByKostenGruppe
        case .dokumentStruktur:
            return groupedByDokumentStruktur
        case .gebaeudeGeschoss:
            return groupedByGebaeudeGeschoss
        }
    }

    private var groupedByKostenGruppe: [LVSectionGroup] {
        let dict = Dictionary(grouping: Array(positionen), by: { $0.kostenGruppeNummer ?? "—" })
        return dict.sorted { $0.key < $1.key }.map { key, items in
            LVSectionGroup(
                id: "kg-\(key)",
                title: "KG \(key) – \(dinBezeichnung(key))",
                items: items
            )
        }
    }

    // Welle 9 — dritte Achse: nach Bau-Hierarchie (Gebäude · Geschoss). Sortiert nach
    // reihenfolge; Positionen ohne Geschoss (falls doch mal eine durchrutscht) landen unten.
    private var groupedByGebaeudeGeschoss: [LVSectionGroup] {
        let dict = Dictionary(grouping: Array(positionen), by: { $0.geschoss })
        return dict.map { geschoss, items -> (sort: (Int16, Int16, String), group: LVSectionGroup) in
            let gebName = geschoss?.gebaeude?.name ?? "—"
            let gesName = geschoss?.name ?? "Ohne Geschoss"
            let gebReihe = geschoss?.gebaeude?.reihenfolge ?? Int16.max
            let gesReihe = geschoss?.reihenfolge ?? Int16.max
            return (
                sort: (gebReihe, gesReihe, gesName),
                group: LVSectionGroup(
                    id: "geschoss-\(geschoss?.id?.uuidString ?? "ohne")",
                    title: "\(gebName) · \(gesName)",
                    items: items
                )
            )
        }
        .sorted { l, r in
            if l.sort.0 != r.sort.0 { return l.sort.0 < r.sort.0 }
            if l.sort.1 != r.sort.1 { return l.sort.1 < r.sort.1 }
            return l.sort.2 < r.sort.2
        }
        .map { $0.group }
    }

    private var groupedByDokumentStruktur: [LVSectionGroup] {
        let dict = Dictionary(grouping: Array(positionen), by: dokumentAbschnitt)
        return dict.sorted { lhs, rhs in
            documentSortBefore(lhs.key, rhs.key)
        }.map { key, items in
            LVSectionGroup(
                id: "doc-\(key)",
                title: key == "—" ? "Ohne Abschnitt" : "Abschnitt \(key)",
                items: items
            )
        }
    }

    private var gesamtFortschritt: Double {
        let base = Array(positionen).filter { !LVPositionHelper.isAlternative($0) }
        guard !base.isEmpty else { return 0 }
        let sum = base.map {
            fortStore.fortschritt(for: $0.objectID.uriRepresentation().absoluteString)?.prozent ?? 0
        }.reduce(0, +)
        return Double(sum) / Double(base.count) / 100.0
    }

    private var gesamtSumme: Double {
        ohneDuplikate(Array(positionen).filter { !LVPositionHelper.isAlternative($0) }).reduce(0.0) { sum, pos in
            let preis: Double
            if pos.hatKalkulation {
                preis = LVKalkulator.kalkuliere(position: pos).einheitspreisVK
            } else if let best = store.guenstigster(for: pos.objectID.uriRepresentation().absoluteString) {
                preis = best.einzelpreis
            } else {
                preis = pos.value(forKey: "einkaufspreis") as? Double ?? 0
            }
            return sum + (pos.menge * preis)
        }
    }

    // MARK: - Bewehrungs-Duplikate gruppieren (Plan + Liste liefern dieselbe Menge)

    private enum LVCluster: Identifiable {
        case einzel(LVPosition)
        case duplikat(key: String, positionen: [LVPosition])
        var id: String {
            switch self {
            case .einzel(let p): return p.objectID.uriRepresentation().absoluteString
            case .duplikat(let key, _): return "dup:" + key
            }
        }
    }

    private func istBewehrung(_ p: LVPosition) -> Bool { LVDedup.istBewehrung(p) }

    /// „Gleiche Position": Bezeichnung + Menge (nur Bewehrung/kg wird gruppiert).
    /// Delegiert an die gemeinsame Regel (`LVDedup`), damit Bildschirm und Export identisch zählen.
    private func dedupKey(_ p: LVPosition) -> String { LVDedup.dedupKey(p) }

    /// Gruppiert gleiche Bewehrungs-Positionen zu einem Cluster; alles andere bleibt einzeln.
    private func clustere(_ items: [LVPosition]) -> [LVCluster] {
        var result: [LVCluster] = []
        var verwendet = Set<NSManagedObjectID>()
        for pos in items {
            if verwendet.contains(pos.objectID) { continue }
            if istBewehrung(pos) {
                let k = dedupKey(pos)
                let gleiche = items.filter { istBewehrung($0) && dedupKey($0) == k }
                if gleiche.count > 1 {
                    gleiche.forEach { verwendet.insert($0.objectID) }
                    result.append(.duplikat(key: k, positionen: gleiche))
                    continue
                }
            }
            verwendet.insert(pos.objectID)
            result.append(.einzel(pos))
        }
        return result
    }

    /// Fürs Summieren: nur zählbare Positionen — Unterpunkte (Belege unter einem Deckel)
    /// zählen nicht mit, doppelt importierte Bewehrung zählt einmal. Gemeinsame Regel
    /// (`zaehlbarePositionen`), die auch GAEB/PDF/Kostenübersicht verwenden.
    private func ohneDuplikate(_ liste: [LVPosition]) -> [LVPosition] {
        liste.zaehlbarePositionen()
    }

    private func mengeText(_ p: LVPosition?) -> String {
        (p?.menge ?? 0).formatted(.number.precision(.fractionLength(0...2)))
    }

    /// Suchbegriffe, mit denen die Position im Quell-PDF gefunden wird (Weg A):
    /// die Menge in deutscher UND englischer Schreibweise (z.B. „21,45" und „21.45").
    /// Der Wert stammt aus dem PDF, steht dort also i.d.R. wörtlich — außer bei
    /// errechneten Deckel-Summen, die im PDF nicht als einzelne Zahl auftauchen.
    private static func suchbegriffe(fuer pos: LVPosition) -> [String] {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        nf.usesGroupingSeparator = false
        var begriffe: [String] = []
        nf.decimalSeparator = ","
        if let komma = nf.string(from: NSNumber(value: pos.menge)) { begriffe.append(komma) }
        nf.decimalSeparator = "."
        if let punkt = nf.string(from: NSNumber(value: pos.menge)) { begriffe.append(punkt) }
        var gesehen = Set<String>()
        return begriffe.filter { gesehen.insert($0).inserted }
    }

    // MARK: - Typ B: Deckel-Zeile, Auswahl, Zusammenführen

    private var ausgewaehltePositionen: [LVPosition] {
        positionen.filter { ausgewaehlt.contains($0.objectID) }
    }

    /// Quell-PDF-URL einer Position (dokuPath, sonst Fallback CADFiles/<dokuName>).
    private func quellURL(fuer pos: LVPosition) -> URL? {
        if let path = pos.value(forKey: "dokuPath") as? String, let u = URL(string: path) { return u }
        if let name = pos.value(forKey: "dokuName") as? String, !name.isEmpty {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return docs.appendingPathComponent("CADFiles").appendingPathComponent(name)
        }
        return nil
    }

    /// Öffnet das Quell-PDF an der Stelle der Position (auch für Deckel & Unterpunkte).
    private func oeffnePDF(fuer pos: LVPosition) {
        guard let url = quellURL(fuer: pos) else { return }
        pdfSprung = PDFSprung(url: url,
                              suchbegriffe: Self.suchbegriffe(fuer: pos),
                              seite: pos.seiteImPDF,
                              titel: pos.bezeichnung ?? "Quell-PDF")
    }

    /// Lupen-Knopf „im PDF ansehen", nur wenn die Position eine Quelle hat.
    @ViewBuilder
    private func pdfKnopf(fuer pos: LVPosition) -> some View {
        if quellURL(fuer: pos) != nil {
            Button { oeffnePDF(fuer: pos) } label: {
                Image(systemName: "doc.text.magnifyingglass").foregroundStyle(.orange)
            }
            .buttonStyle(.borderless)
        }
    }

    /// Ein Deckel mit seinen Belegen: aufklappbar, Belege grau + „zählt nicht".
    @ViewBuilder
    private func deckelRow(_ pos: LVPosition) -> some View {
        DisclosureGroup {
            ForEach(pos.unterPositionenArray, id: \.objectID) { kind in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(kind.bezeichnung ?? "—").font(.caption)
                    Spacer()
                    if pos.istElement {
                        // Baustein eines Elements: das Rezept-Maß und was es beisteuert.
                        // „0,35 m³/m² · 17,50 €/m²" — beides bezogen auf die Element-Einheit.
                        Text(rezeptText(kind, element: pos))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text(bausteinBeitrag(kind), format: .currency(code: "EUR"))
                            .font(.caption.monospacedDigit()).foregroundStyle(.indigo)
                    } else {
                        Text("\(mengeText(kind)) \(kind.einheit ?? "")")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Text("zählt nicht").font(.caption2).foregroundStyle(.tertiary)
                    }
                    pdfKnopf(fuer: kind)
                }
                // Auch die einzelnen Belege sind bearbeit-/kalkulierbar (Tippen öffnet den Dialog).
                .contentShape(Rectangle())
                .onTapGesture { actionPosition = kind }
                .contextMenu {
                    Button { editPosition = kind } label: { Label("Bearbeiten", systemImage: "pencil") }
                    Button { kalkPosition = kind } label: { Label("Kalkulation", systemImage: "function") }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: pos.istElement ? "square.stack.3d.down.right.fill" : "square.stack.3d.up.fill")
                    .font(.footnote)
                    .foregroundStyle(pos.istElement ? .indigo : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pos.bezeichnung ?? "—").font(.subheadline.weight(.semibold))
                    if pos.istElement {
                        // Element: der Preis ENTSTEHT aus den Bausteinen — deshalb steht
                        // hier der Einheitspreis, nicht „zählt einmal".
                        Text("Element · \(pos.unterPositionenArray.count) Bausteine · \(elementEPText(pos))")
                            .font(.caption2).foregroundStyle(.indigo)
                    } else {
                        Text("Deckel · \(pos.unterPositionenArray.count) Belege · zählt einmal")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Text("\(mengeText(pos)) \(pos.einheit ?? "")")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                pdfKnopf(fuer: pos)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { aufloesen(pos) } label: {
                Label("Auflösen", systemImage: "square.stack.3d.up.slash")
            }.tint(.gray)
        }
        // Der Deckel ist die zählende Position — hier wird bearbeitet & kalkuliert.
        // (Tippen bleibt fürs Auf-/Zuklappen der Gruppe.)
        .swipeActions(edge: .leading) {
            Button { editPosition = pos } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.orange)
            Button { kalkPosition = pos } label: { Label("Kalkulation", systemImage: "function") }.tint(.indigo)
        }
        // Auch als Kontextmenü — am Mac (Designed for iPad) gibt es keinen Swipe,
        // Rechtsklick/Zwei-Finger erreicht alles trotzdem.
        .contextMenu {
            Button { editPosition = pos } label: { Label("Bearbeiten", systemImage: "pencil") }
            Button { kalkPosition = pos } label: { Label("Kalkulation", systemImage: "function") }
            Button { fortschrittPosition = pos } label: { Label("Fortschritt", systemImage: "chart.bar") }
            Button { aufmassPosition = pos } label: { Label("Aufmaß", systemImage: "ruler") }
            Divider()
            if pos.istElement {
                Button { setzeDeckelArt(pos, .mengentraeger) } label: {
                    Label("Wieder als Mengenträger rechnen", systemImage: "square.stack.3d.up.fill")
                }
            } else {
                Button { setzeDeckelArt(pos, .element) } label: {
                    Label("Als Element rechnen (Bausteine summieren)",
                          systemImage: "square.stack.3d.down.right.fill")
                }
            }
            Divider()
            Button(role: .destructive) {
                aufloesen(pos)
            } label: {
                Label("Gruppierung auflösen", systemImage: "square.stack.3d.up.slash")
            }
        }
    }

    // MARK: - Element (B-Element)

    /// Einheitspreis des Elements, wie ihn die Bausteine ergeben — z.B. „87,00 €/m²".
    private func elementEPText(_ element: LVPosition) -> String {
        let ep = LVKalkulator.kalkuliereElement(element).einheitspreisVK
        let geld = ep.formatted(.currency(code: "EUR"))
        return "\(geld)/\(element.einheit ?? "Einheit")"
    }

    /// Das Rezept-Maß eines Bausteins: „0,35 m³/m²".
    private func rezeptText(_ baustein: LVPosition, element: LVPosition) -> String {
        let wert = baustein.mengeJeDeckelEinheit.formatted(.number.precision(.fractionLength(0...3)))
        return "\(wert) \(baustein.einheit ?? "")/\(element.einheit ?? "")"
    }

    /// Was der Baustein je Einheit des Elements beisteuert (zuschlagsfrei —
    /// den Zuschlag trägt das Element).
    private func bausteinBeitrag(_ baustein: LVPosition) -> Double {
        LVKalkulator.kalkuliere(position: baustein).einheitspreisEK * baustein.mengeJeDeckelEinheit
    }

    /// Umschalten zwischen Mengenträger (Belege) und Element (Bausteine summieren).
    /// Ändert nur die Rechenrichtung — die Gruppierung selbst bleibt, wie sie ist.
    private func setzeDeckelArt(_ deckel: LVPosition, _ art: DeckelArt) {
        deckel.deckelTyp = art
        speichere("Deckel-Art \(art.anzeige)")
    }

    /// Zeile im Auswahl-Modus: Häkchen + Bezeichnung + Menge.
    @ViewBuilder
    private func selectableRow(_ pos: LVPosition) -> some View {
        let selektiert = ausgewaehlt.contains(pos.objectID)
        HStack(spacing: 12) {
            Image(systemName: selektiert ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selektiert ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(pos.bezeichnung ?? "—").font(.subheadline)
                if pos.istDeckel {
                    Text("Deckel · \(pos.unterPositionenArray.count) Belege")
                        .font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer()
            Text("\(mengeText(pos)) \(pos.einheit ?? "")")
                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selektiert { ausgewaehlt.remove(pos.objectID) } else { ausgewaehlt.insert(pos.objectID) }
        }
    }

    /// Macht `deckel` zum Deckel, hängt die übrigen Ausgewählten als Belege darunter.
    /// Hält es EINE Ebene flach: eigene Belege eines künftigen Belegs wandern mit hoch.
    private func zusammenfuehren(deckel: LVPosition, kinder: [LVPosition]) {
        deckel.deckel = nil
        for k in kinder where k.objectID != deckel.objectID {
            for enkel in k.unterPositionenArray { enkel.deckel = deckel }
            k.deckel = deckel
        }
        speichere("Zusammenführen")
        auswahlModus = false
        ausgewaehlt.removeAll()
    }

    /// Löst einen Deckel auf: alle Belege werden wieder eigenständig.
    private func aufloesen(_ deckel: LVPosition) {
        for k in deckel.unterPositionenArray { k.deckel = nil }
        deckel.deckelNotiz = nil
        // Ohne Bausteine ist die Element-Markierung sinnlos — und beim erneuten
        // Gruppieren soll nicht heimlich die alte Rechenrichtung wieder gelten.
        deckel.deckelTyp = .mengentraeger
        speichere("Auflösen")
    }

    /// Speichert und macht Fehler SICHTBAR (statt `try?`, das sie verschluckt hat).
    /// Bei Erfolg landet die Deckel-Gruppierung dauerhaft in Core Data.
    private func speichere(_ kontext: String) {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            speicherFehler = "\(kontext): \(error.localizedDescription)"
            print("‼️ LV-Speichern fehlgeschlagen [\(kontext)]: \(error)")
        }
    }

    @ViewBuilder
    private func clusterView(_ cluster: LVCluster) -> some View {
        switch cluster {
        case .einzel(let pos):
            if pos.istDeckel {
                deckelRow(pos)
            } else {
                positionRow(pos)
            }
        case .duplikat(_, let posns):
            DisclosureGroup {
                ForEach(posns, id: \.objectID) { positionRow($0) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.on.doc.fill").font(.footnote).foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(posns.first?.bezeichnung ?? "—").font(.subheadline.weight(.semibold))
                        Text("\(posns.count) Quellen (Plan + Liste) · zählt einmal")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    Spacer()
                    Text("\(mengeText(posns.first)) \(posns.first?.einheit ?? "")")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
        }
    }

    @ViewBuilder
    private func positionRow(_ pos: LVPosition) -> some View {
        LVPositionRow(position: pos) { targetURL in
            pdfSprung = PDFSprung(url: targetURL,
                                  suchbegriffe: Self.suchbegriffe(fuer: pos),
                                  seite: pos.seiteImPDF,
                                  titel: pos.bezeichnung ?? "Quell-PDF")
        }
        .contentShape(Rectangle())
        .onTapGesture { actionPosition = pos }
        .contextMenu {
            Button { editPosition = pos } label: { Label("Bearbeiten", systemImage: "pencil") }
            Button { kalkPosition = pos } label: { Label("Kalkulation", systemImage: "function") }
            Button { duplicateAsAlternative(pos) } label: { Label("Alternative", systemImage: "doc.on.doc") }
            Button { fortschrittPosition = pos } label: { Label("Fortschritt", systemImage: "chart.bar") }
            Button { aufmassPosition = pos } label: { Label("Aufmaß", systemImage: "ruler") }
            Divider()
            Button(role: .destructive) { positionToDelete = pos } label: { Label("Löschen", systemImage: "trash") }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { positionToDelete = pos } label: { Label("Löschen", systemImage: "trash") }.tint(.red)
        }
        .swipeActions(edge: .leading) {
            Button { editPosition = pos } label: { Label("Bearbeiten", systemImage: "pencil") }.tint(.orange)
            Button { kalkPosition = pos } label: { Label("Kalkulation", systemImage: "function") }.tint(.indigo)
            Button { duplicateAsAlternative(pos) } label: { Label("Alternative", systemImage: "doc.on.doc") }.tint(.blue)
            Button { fortschrittPosition = pos } label: { Label("Fortschritt", systemImage: "chart.bar") }.tint(.green)
            Button { aufmassPosition = pos } label: { Label("Aufmaß", systemImage: "ruler") }.tint(.teal)
        }
    }

    var body: some View {
        List {
            if positionen.isEmpty {
                ContentUnavailableView(
                    "Kein LV vorhanden",
                    systemImage: "doc.text",
                    description: Text("Tippe auf + oder importiere ein LV.")
                )
            } else {
                Section {
                    Picker("LV-Ansicht", selection: $gruppierung) {
                        ForEach(LVGruppierung.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if gesamtFortschritt > 0 {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Gesamtfortschritt", systemImage: "chart.bar.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(gesamtFortschritt >= 1 ? .green : .orange)
                                Spacer()
                                Text("\(Int(gesamtFortschritt * 100)) %")
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(gesamtFortschritt >= 1 ? .green : .orange)
                            }
                            ProgressView(value: gesamtFortschritt)
                                .progressViewStyle(.linear)
                                .tint(gesamtFortschritt >= 1 ? .green : .orange)
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(grouped) { gruppe in
                    // Unterpunkte (Belege) erscheinen NICHT flach — sie hängen unter ihrem Deckel.
                    let topLevel = gruppe.items.filter { !$0.istUnterpunkt }
                    if !topLevel.isEmpty {
                        Section {
                            if auswahlModus {
                                ForEach(topLevel, id: \.objectID) { selectableRow($0) }
                            } else {
                                ForEach(clustere(topLevel)) { cluster in
                                    clusterView(cluster)
                                }
                            }
                        } header: {
                            sectionHeader(gruppe)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if gesamtSumme > 0 {
                HStack {
                    Text("Angebotssumme (netto):")
                        .font(.headline)
                    Spacer()
                    Text(gesamtSumme, format: .currency(code: "EUR"))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundColor(.green)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if auswahlModus {
                HStack {
                    Text("\(ausgewaehlt.count) ausgewählt")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        deckelDialog = true
                    } label: {
                        Label("Zusammenführen", systemImage: "square.stack.3d.up")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(ausgewaehlt.count < 2)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
        .confirmationDialog("Welche Position ist der Deckel?",
                            isPresented: $deckelDialog, titleVisibility: .visible) {
            // Größte Menge zuerst = Vorschlag; Deckel ist der, den du tippst.
            ForEach(ausgewaehltePositionen.sorted { $0.menge > $1.menge }, id: \.objectID) { pos in
                Button("\(pos.bezeichnung ?? "—") · \(mengeText(pos)) \(pos.einheit ?? "")") {
                    zusammenfuehren(deckel: pos, kinder: ausgewaehltePositionen)
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Deckel zählt in der Summe. Die anderen hängen als Beleg darunter und zählen nicht mehr doppelt.")
        }
        .alert("Speichern fehlgeschlagen", isPresented: Binding(
            get: { speicherFehler != nil },
            set: { if !$0 { speicherFehler = nil } }
        )) {
            Button("OK", role: .cancel) { speicherFehler = nil }
        } message: {
            Text(speicherFehler ?? "")
        }
        .gaebDropTarget { url in
            droppedGAEBURL = url
            showGAEBImport = true
        }
        .navigationTitle("LV – \(event.title ?? "Baustelle")")
        .navigationBarTitleDisplayMode(.inline)
        // Welle 9: Baustelle erhält ein Default-Geschoss und alle noch nicht zugeordneten
        // Positionen werden eingehängt (deckt neue Events + frisch importierte/angelegte
        // Positionen ab, unabhängig von der Einmal-Migration). Idempotent.
        .onAppear {
            let ergebnis = HierarchieHelfer.sichereDefaultGeschoss(for: event, in: viewContext)
            if ergebnis.geaendert { try? viewContext.save() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(auswahlModus ? "Fertig" : "Auswählen") {
                    auswahlModus.toggle()
                    if !auswahlModus { ausgewaehlt.removeAll() }
                }
                .disabled(positionen.isEmpty)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Ansicht", selection: $gruppierung) {
                        ForEach(LVGruppierung.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(option)
                        }
                    }

                    Divider()

                    Button { showBestellliste = true } label: {
                        Label("Bestellliste", systemImage: "envelope.badge")
                    }
                    .disabled(positionen.isEmpty)

                    Button { showAngebotsVergleich = true } label: {
                        Label("Angebotsvergleich", systemImage: "chart.bar.doc.horizontal")
                    }

                    Button { showKostenübersicht = true } label: {
                        Label("Kostenzusammenfassung", systemImage: "chart.pie")
                    }

                    Button { showAbdeckung = true } label: {
                        Label("Was ist abgedeckt?", systemImage: "checklist")
                    }
                    .disabled(positionen.isEmpty)

                    Button { showUebernahme = true } label: {
                        Label("Aus Unterlagen übernehmen", systemImage: "tray.and.arrow.down")
                    }

                    Button { showGeschossKosten = true } label: {
                        Label("Kosten nach Ebene (Geschoss)", systemImage: "building.2")
                    }
                    .disabled(positionen.isEmpty)

                    Button { showHierarchieVerwalten = true } label: {
                        Label("Ebenen verwalten", systemImage: "building.2.crop.circle")
                    }

                    Button { showFreigabeStatus = true } label: {
                        Label("Ebenen-Freigabe / Status", systemImage: "checkmark.seal")
                    }
                    .disabled(positionen.isEmpty)

                    Button { showStammdaten = true } label: {
                        Label("Stammdaten pflegen", systemImage: "slider.horizontal.3")
                    }

                    Divider()

                    Button { generatePDF() } label: {
                        Label("LV als PDF", systemImage: "arrow.up.doc")
                    }
                    .disabled(positionen.isEmpty)

                    Button { generateCSV() } label: {
                        Label("LV als CSV (Excel)", systemImage: "tablecells")
                    }
                    .disabled(positionen.isEmpty)

                    Button { triggerGAEBExport(.x83_v33) } label: {
                        Label("GAEB X83 exportieren", systemImage: "arrow.up.doc.fill")
                    }
                    .disabled(positionen.isEmpty)

                    Button { triggerGAEBExport(.x84_v33) } label: {
                        Label("GAEB X84 exportieren (Angebot)", systemImage: "signature")
                    }
                    .disabled(positionen.isEmpty)

                    Button { triggerXRechnungExport() } label: {
                        Label("XRechnung exportieren", systemImage: "eurosign.circle")
                    }
                    .disabled(positionen.isEmpty)

                    Divider()

                    Button { showImport = true } label: {
                        Label("Aus PDF importieren", systemImage: "doc.text.magnifyingglass")
                    }

                    Button { showGAEBImport = true } label: {
                        Label("GAEB X83 importieren", systemImage: "doc.badge.arrow.up")
                    }

                    Button { showBausteine = true } label: {
                        Label("LV-Bausteine auswählen", systemImage: "checklist")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .fullScreenCover(isPresented: $showingAdd) {
            AddLVPositionView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(item: $editPosition) { pos in
            AddLVPositionView(event: event, editPosition: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .navigationDestination(item: $kalkPosition) { pos in
            LVTiefenkalkulationView(position: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(item: $fortschrittPosition) { pos in
            LVFortschrittSheet(position: pos)
        }
        .fullScreenCover(item: $aufmassPosition) { pos in
            AufmassSheet(position: pos)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showBestellliste) {
            LieferantenBestelllisteView(event: event, positionen: Array(positionen))
        }
        .fullScreenCover(isPresented: $showAngebotsVergleich) {
            AngebotsVergleichView(event: event, positionen: Array(positionen))
        }
        .sheet(isPresented: $showAbdeckung) {
            LVAbdeckungView(positionen: Array(positionen))
        }
        .sheet(isPresented: $showUebernahme) {
            AuswertungUebernahmeView(event: event)
        }
        .fullScreenCover(isPresented: $showKostenübersicht) {
            KostenübersichtView(event: event, positionen: Array(positionen))
        }
        .fullScreenCover(isPresented: $showGeschossKosten) {
            GeschossKostenView(event: event, positionen: Array(positionen))
        }
        .fullScreenCover(isPresented: $showHierarchieVerwalten) {
            HierarchieVerwaltenView(event: event)
        }
        .fullScreenCover(isPresented: $showFreigabeStatus) {
            FreigabeStatusView(event: event)
        }
        .fullScreenCover(isPresented: $showStammdaten) {
            StammdatenPflegeView()
        }
        .fullScreenCover(isPresented: $showImport) {
            LVImportView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showGAEBImport, onDismiss: { droppedGAEBURL = nil }) {
            GAEBImportView(event: event, initialURL: droppedGAEBURL)
                .environment(\.managedObjectContext, viewContext)
        }
        .fullScreenCover(isPresented: $showBausteine) {
            LVBausteinAuswahlView(event: event)
                .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: importedFileHandler.pendingGAEBURL) { _, newURL in
            if let url = newURL {
                droppedGAEBURL = url
                importedFileHandler.pendingGAEBURL = nil
                showGAEBImport = true
            }
        }
        .teilenOderSpeichern(datei: $exportURL)
        .fullScreenCover(isPresented: $showHelp) {
            LVHelpView()
        }
        .fullScreenCover(item: $pdfSprung) { sprung in
            PDFTrefferView(url: sprung.url,
                           suchbegriffe: sprung.suchbegriffe,
                           seite: sprung.seite,
                           titel: sprung.titel)
        }
        .confirmationDialog(
            actionPosition?.bezeichnung ?? "LV-Position",
            isPresented: Binding(
                get: { actionPosition != nil },
                set: { if !$0 { actionPosition = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let pos = actionPosition {
                Button {
                    showAngebotsVergleich = true
                    actionPosition = nil
                } label: {
                    Label("Rückmeldung / Angebot erfassen", systemImage: "chart.bar.doc.horizontal")
                }
                Button {
                    editPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Position bearbeiten", systemImage: "pencil")
                }
                Button {
                    kalkPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Kalkulation", systemImage: "function")
                }
                Button {
                    fortschrittPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Fortschritt", systemImage: "chart.bar")
                }
                Button {
                    aufmassPosition = pos
                    actionPosition = nil
                } label: {
                    Label("Aufmaß", systemImage: "ruler")
                }
                Button(role: .destructive) {
                    positionToDelete = pos
                    actionPosition = nil
                } label: {
                    Label("Löschen", systemImage: "trash")
                }
            }
        }
        .modifier(DeletePositionConfirm(position: $positionToDelete) { delete($0) })
        .alert("Fehlende Preise", isPresented: $showMissingPricesAlert) {
            Button("Trotzdem exportieren") {
                if let fmt = pendingExportFormat { doGAEBExport(fmt) }
            }
            Button("Abbrechen", role: .cancel) { pendingExportFormat = nil }
        } message: {
            Text("\(missingPricesCount) Position\(missingPricesCount == 1 ? " hat" : "en haben") keinen Preis (weder Angebot noch Kalkulation). Der X84 wird für diese mit leeren EP-Feldern exportiert.")
        }
        .alert("Export nicht möglich – fehlende Preise", isPresented: $showXRMissingAlert) {
            Button("Verstanden", role: .cancel) { }
        } message: {
            Text("\(xrMissingCount) Position\(xrMissingCount == 1 ? " hat" : "en haben") keinen Preis (weder Angebot noch Kalkulation). Eine Rechnung mit 0,00-€-Positionen wird nicht exportiert – bitte erst Preis im Angebotsvergleich erfassen oder die Position kalkulieren.")
        }
    }

    // MARK: - Section Header

    @ViewBuilder
    private func sectionHeader(_ gruppe: LVSectionGroup) -> some View {
        HStack {
            Text(gruppe.title)
                .font(.caption.weight(.semibold))
            Spacer()
            let basis = gruppe.items.filter { !LVPositionHelper.isAlternative($0) }
            let altCount = gruppe.items.count - basis.count
            if altCount > 0 {
                Text("\(altCount) Alt.")
                    .font(.caption2).foregroundStyle(.blue)
                Text("·").foregroundStyle(.secondary).font(.caption2)
            }
            let summe = basis.reduce(0.0) { $0 + $1.menge }
            Text("\(summe.formatted(.number.precision(.fractionLength(0...2)))) ges.")
                .font(.caption2).foregroundStyle(.secondary)
            if !basis.isEmpty {
                let avg = basis.map {
                    fortStore.fortschritt(
                        for: $0.objectID.uriRepresentation().absoluteString)?.prozent ?? 0
                }.reduce(0, +) / basis.count
                if avg > 0 {
                    Text("·").foregroundStyle(.secondary).font(.caption2)
                    Text("ø \(avg)%")
                        .font(.caption2)
                        .foregroundStyle(avg == 100 ? .green : .orange)
                }
            }
        }
    }

    private func dokumentAbschnitt(_ position: LVPosition) -> String {
        let nr = (position.posNr ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nr.isEmpty else { return "—" }

        let parts = nr.split(separator: ".").map(String.init)
        if parts.count >= 3 {
            return parts.prefix(2).joined(separator: ".")
        }
        if parts.count >= 2, parts[0].count <= 2 {
            return parts[0]
        }
        if parts.count >= 2 {
            return parts.prefix(2).joined(separator: ".")
        }
        return nr
    }

    private func documentSortBefore(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == "—" { return false }
        if rhs == "—" { return true }

        let left = lhs.split(separator: ".").map { Int($0) ?? Int.max }
        let right = rhs.split(separator: ".").map { Int($0) ?? Int.max }
        let count = max(left.count, right.count)

        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r }
        }

        return lhs < rhs
    }

    // MARK: - Actions

    private func delete(_ pos: LVPosition) {
        viewContext.delete(pos)
        try? viewContext.save()
    }

    private func duplicateAsAlternative(_ base: LVPosition) {
        let alt = LVPosition(context: viewContext)
        let baseNr = base.posNr ?? "1"
        alt.posNr = LVPositionHelper.nextAlternativeNr(for: baseNr, existing: Array(positionen))
        alt.bezeichnung = (base.bezeichnung ?? "") + " (Alternative)"
        alt.menge = base.menge
        alt.einheit = base.einheit
        alt.kostenGruppeNummer = base.kostenGruppeNummer
        alt.artikelNummer = base.artikelNummer
        alt.lieferant = base.lieferant
        alt.event = event
        try? viewContext.save()
    }

    private func generatePDF() {
        let data = LVPDFExporter.generate(event: event, positionen: Array(positionen))
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-").appending(".pdf")
        writeAndShare(data: data, filename: name)
    }

    private func generateCSV() {
        let data = LVCSVExporter.generate(event: event, positionen: Array(positionen))
        let name = "LV-\(event.title ?? "Baustelle")"
            .replacingOccurrences(of: " ", with: "-").appending(".csv")
        writeAndShare(data: data, filename: name)
    }

    private func triggerGAEBExport(_ format: GAEBExportFormat) {
        if format.includePrices {
            let missing = Array(positionen).filter { pos in
                LVKalkulator.effektiverEP(for: pos, store: store) == 0
            }.count
            if missing > 0 {
                missingPricesCount = missing
                pendingExportFormat = format
                showMissingPricesAlert = true
                return
            }
        }
        doGAEBExport(format)
    }

    private func doGAEBExport(_ format: GAEBExportFormat) {
        let data = GAEBExporter.export(
            event: event,
            positionen: Array(positionen),
            format: format,
            store: store
        )
        let title = (event.title ?? "Baustelle").replacingOccurrences(of: " ", with: "-")
        let name = "\(title)-\(format.filenameSuffix).xml"
        writeAndShare(data: data, filename: name)
        pendingExportFormat = nil
    }

    private func triggerXRechnungExport() {
        let nonAlt = Array(positionen).filter { !LVPositionHelper.isAlternative($0) }
        let missing = nonAlt.filter { pos in
            LVKalkulator.effektiverEP(for: pos, store: store) == 0
        }.count
        if missing > 0 {
            xrMissingCount = missing
            showXRMissingAlert = true
            return
        }
        doXRechnungExport()
    }

    private func doXRechnungExport() {
        let data = XRechnungExporter.export(
            event: event,
            positionen: Array(positionen),
            store: store
        )
        let title = (event.title ?? "Baustelle").replacingOccurrences(of: " ", with: "-")
        writeAndShare(data: data, filename: "\(title)-XRechnung.xml")
    }

    private func writeAndShare(data: Data, filename: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        if (try? data.write(to: url)) != nil {
            exportURL = url
        }
    }

    private func dinBezeichnung(_ kg: String) -> String {
        switch kg {
        case "100": return "Grundstück"
        case "200": return "Herrichten & Erschließen"
        case "300": return "Baukonstruktionen"
        case "310": return "Baugrube"
        case "320": return "Gründung"
        case "330": return "Außenwände"
        case "340": return "Innenwände"
        case "350": return "Decken"
        case "360": return "Dächer"
        case "370": return "Infrastruktur"
        case "380": return "Fenster & Türen"
        case "390": return "Sonstige Baukonstruktion"
        case "400": return "Technische Anlagen"
        case "410": return "Abwasser, Wasser, Gas"
        case "420": return "Wärmeversorgung"
        case "430": return "Lufttechnische Anlagen"
        case "440": return "Starkstrom"
        case "450": return "Fernmelde- & IT-Anlagen"
        case "500": return "Außenanlagen"
        case "600": return "Ausstattung"
        case "700": return "Baunebenkosten"
        default: return "Sonstige"
        }
    }
}

// MARK: - „Was ist abgedeckt?" — ehrliche Erfassungs-Übersicht

/// Zeigt, was aus welchen Dokumenten gelesen wurde, mit ehrlichen Prüf-Hinweisen
/// (ohne Quelle / ohne Seitenverweis) und der klaren Grenze: nur Importiertes ist bekannt.
struct LVAbdeckungView: View {
    let positionen: [LVPosition]
    @Environment(\.dismiss) private var dismiss

    private var aktive: [LVPosition] {
        positionen.filter { !LVPositionHelper.isAlternative($0) }
    }

    private func doku(_ p: LVPosition) -> String? {
        guard let n = p.value(forKey: "dokuName") as? String, !n.isEmpty else { return nil }
        return n
    }

    private struct DocGruppe: Identifiable {
        let id: String
        var name: String { id }
        let positionen: [LVPosition]
    }

    private var docGruppen: [DocGruppe] {
        let mit = aktive.compactMap { p in doku(p).map { ($0, p) } }
        let dict = Dictionary(grouping: mit, by: { $0.0 })
        return dict.keys.sorted().map { name in
            DocGruppe(id: name, positionen: dict[name]!.map { $0.1 })
        }
    }

    private var ohneQuelle: [LVPosition] { aktive.filter { doku($0) == nil } }
    private var ohneSeiteMitDoku: [LVPosition] { aktive.filter { doku($0) != nil && $0.seiteImPDF == nil } }

    private func anzahl(_ q: MengenQuelle) -> Int { aktive.filter { $0.mengenQuelle == q }.count }

    private func quelleLabel(_ q: MengenQuelle) -> String {
        switch q {
        case .statik:     return "aus Statik-Tabelle (belastbar)"
        case .bplan:      return "Planwert (B-Plan)"
        case .schaetzung: return "geschätzt"
        case .manuell:    return "von Hand eingetragen"
        }
    }
    private func quelleFarbe(_ q: MengenQuelle) -> Color {
        switch q {
        case .statik:             return .green
        case .bplan, .schaetzung: return .orange
        case .manuell:            return .secondary
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Überblick") {
                    HStack {
                        Text("Positionen gesamt")
                        Spacer()
                        Text("\(aktive.count)").monospacedDigit().foregroundStyle(.secondary)
                    }
                    ForEach([MengenQuelle.statik, .bplan, .schaetzung, .manuell], id: \.self) { q in
                        let n = anzahl(q)
                        if n > 0 {
                            HStack(spacing: 8) {
                                Circle().fill(quelleFarbe(q)).frame(width: 9, height: 9)
                                Text(quelleLabel(q)).font(.subheadline)
                                Spacer()
                                Text("\(n)").monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !ohneQuelle.isEmpty || !ohneSeiteMitDoku.isEmpty {
                    Section("Prüf-Hinweise") {
                        if !ohneQuelle.isEmpty {
                            hinweis("exclamationmark.triangle.fill", .orange,
                                    "\(ohneQuelle.count) ohne Quell-Dokument",
                                    "Herkunft unklar – nicht im Plan nachprüfbar.")
                        }
                        if !ohneSeiteMitDoku.isEmpty {
                            hinweis("doc.text.magnifyingglass", .secondary,
                                    "\(ohneSeiteMitDoku.count) ohne Seitenverweis",
                                    "Springt nicht direkt ins PDF (alte Importe oder Summen). Neu importieren hilft.")
                        }
                    }
                }

                Section("Nach Quell-Dokument") {
                    ForEach(docGruppen) { g in
                        DisclosureGroup {
                            ForEach(g.positionen, id: \.objectID) { p in
                                HStack(spacing: 8) {
                                    Circle().fill(quelleFarbe(p.mengenQuelle)).frame(width: 7, height: 7)
                                    Text(p.bezeichnung ?? "—").font(.caption)
                                    Spacer()
                                    if let s = p.seiteImPDF {
                                        Text("S. \(s)").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "doc.text").foregroundStyle(.orange)
                                Text(g.name).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Text("\(g.positionen.count)").monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !ohneQuelle.isEmpty {
                        HStack {
                            Image(systemName: "questionmark.folder").foregroundStyle(.orange)
                            Text("Ohne Quelle").foregroundStyle(.orange)
                            Spacer()
                            Text("\(ohneQuelle.count)").monospacedDigit().foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Text("Diese Übersicht zeigt nur, was aus importierten Dokumenten gelesen wurde. Pläne, die nicht reingegeben wurden, kann die App nicht kennen – die Vollständigkeit gegen die echten Unterlagen bleibt dein Blick.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Was ist abgedeckt?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func hinweis(_ icon: String, _ color: Color, _ titel: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.subheadline.weight(.medium))
                Text(sub).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
