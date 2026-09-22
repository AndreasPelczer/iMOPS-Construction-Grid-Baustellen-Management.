import SwiftUI
import CoreData

// MARK: - Haupt-View

struct ContentView: View {

    @EnvironmentObject var eventListVM: EventListViewModel
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedFilter: EventFilter = .alle
    @State private var loeschKandidaten: IndexSet?
    @State private var loeschFolgen = BaustelleLoeschen.Folgen()
    @State private var loeschName = ""
    @State private var zeigeWaisen = false
    @State private var waisen = 0
    @State private var sortOrder: EventSortOrder = .datumNeuAlt
    @State private var searchText = ""
    @State private var showingAddEventSheet = false
    @State private var showingHousePlanner = false
    @State private var showingGrap8 = false
    @State private var showHelp = false

    var body: some View {
        List {
            // Die Klammer über ALLE Baustellen — steht vor der Auswahl einer einzelnen.
            Section {
                // SpaeterLaden: sonst baut NavigationLink das Ziel bei JEDEM
                // Neuzeichnen mit auf — daran ist die App am 21.09. abgestürzt.
                NavigationLink { SpaeterLaden { TagesblickView() } } label: { TagesblickKarte() }
            }
            // 🔴 Aufträge ohne Baustelle. Kein Bildschirm zeigt sie sonst — sie sind
            // beim Löschen liegengeblieben, weil `Event.jobs` auf Nullify steht.
            // Die Zeile erscheint nur, wenn es wirklich welche gibt.
            if waisen > 0 {
                Section {
                    Button { zeigeWaisen = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "questionmark.folder")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(waisen) Arbeitspakete ohne Baustelle")
                                    .font(.subheadline.weight(.semibold))
                                Text("beim Löschen liegengeblieben — sie stören nicht, "
                                     + "aber sie werden mehr")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                NavigationLink {
                    SpaeterLaden { ImporteView() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.title3).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Importe").font(.body.weight(.semibold))
                            Text("alles Einlesbare an einem Ort — GAEB, Zeichnungen, "
                                 + "Unterlagen, Preise")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                EventFilterPicker(selectedFilter: $selectedFilter)
            }
            Section {
                EventListView(
                    events: $eventListVM.events,
                    onDelete: deleteEvents
                )
            }
        }
        .onAppear { waisen = BaustelleLoeschen.waisen(in: viewContext).count }
        .sheet(isPresented: $zeigeWaisen) {
            WaisenAufraeumenView { waisen = BaustelleLoeschen.waisen(in: viewContext).count }
                .environment(\.managedObjectContext, viewContext)
        }
        .searchable(text: $searchText, prompt: "Baustelle, Ort, Bauherr...")
        .alert("\(loeschName) löschen?", isPresented: Binding(
            get: { loeschKandidaten != nil },
            set: { if !$0 { loeschKandidaten = nil } }
        )) {
            Button("Löschen", role: .destructive) { loeschenAusfuehren() }
            Button("Behalten", role: .cancel) { loeschKandidaten = nil }
        } message: {
            Text("Das geht mit: \(loeschFolgen.satz)."
                 + (loeschFolgen.schritteSatz.map { "\n\n\($0)" } ?? "")
                 + "\n\nDas lässt sich nicht rückgängig machen.")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                EditButton()
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.circle")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sortierung", selection: $sortOrder) {
                        ForEach(EventSortOrder.allCases) { order in
                            Label(order.rawValue, systemImage: order.icon).tag(order)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .tint(.orange)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingHousePlanner = true } label: {
                    Label("Hausplaner", systemImage: "house.and.flag")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingGrap8 = true } label: {
                    Label("Grap8", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEventSheet = true }) {
                    Label("Neue Baustelle", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingHousePlanner) {
            NavigationStack {
                HouseConfiguratorView { _ in
                    showingHousePlanner = false
                }
                .environment(\.managedObjectContext, viewContext)
            }
            .presentationSizing(.page)
        }
        // Vollbild statt Blatt: eine Leinwand zum Ziehen und Zoomen braucht den ganzen
        // Schirm; ein Blatt-Rand nimmt Platz und fängt Randgesten ab.
        // Achtung: ein Vollbild lässt sich NICHT wegwischen — die einzige Tür zurück ist
        // der „Fertig"-Knopf in der Werkzeugleiste von `Grap8View`.
        .fullScreenCover(isPresented: $showingGrap8) {
            // Schritt 1: die Leinwand zeigt ihre Beispieldaten, noch ohne Verbindung
            // zu Core Data. Darum hängt sie an der Liste und nicht an einer Baustelle.
            Grap8View()
        }
        .sheet(isPresented: $showingAddEventSheet) {
            AddEventView()
                .environment(\.managedObjectContext, viewContext)
                .presentationSizing(.page)
        }
        .sheet(isPresented: $showHelp) {
            BaustellenListeHelpView()
                .presentationSizing(.page)
        }
        .onChange(of: selectedFilter) { _, newFilter in
            withAnimation { eventListVM.applyFilterAndSearch(filter: newFilter, query: searchText, sort: sortOrder) }
        }
        .onChange(of: searchText) { _, q in
            eventListVM.applyFilterAndSearch(filter: selectedFilter, query: q, sort: sortOrder)
        }
        .onChange(of: sortOrder) { _, newSort in
            withAnimation { eventListVM.applyFilterAndSearch(filter: selectedFilter, query: searchText, sort: newSort) }
        }
        .onAppear {
            eventListVM.applyFilterAndSearch(filter: selectedFilter, query: searchText, sort: sortOrder)
        }
        .alert(
            "Datenfehler",
            isPresented: Binding(
                get: { eventListVM.lastError != nil },
                set: { if !$0 { eventListVM.lastError = nil } }
            )
        ) {
            Button("OK") { eventListVM.lastError = nil }
        } message: {
            if let err = eventListVM.lastError {
                Text(err)
            }
        }
    }

    /// 🔴 Vor dem Löschen stehen die Folgen da. Nicht als Warnung („bist du sicher?"),
    /// sondern als Aufzählung dessen, was verschwindet — nach dem Muster vom
    /// Auftrag-Löschen (destructive-delete-safety).
    private func deleteEvents(offsets: IndexSet) {
        loeschKandidaten = offsets
        let betroffen = offsets.map { eventListVM.events[$0] }
        var f = BaustelleLoeschen.Folgen()
        for e in betroffen {
            let g = BaustelleLoeschen.folgen(e)
            f.auftraege += g.auftraege; f.positionen += g.positionen
            f.maengel += g.maengel; f.berichte += g.berichte
        }
        loeschFolgen = f
        loeschName = betroffen.count == 1
            ? (betroffen.first?.title ?? "Baustelle")
            : "\(betroffen.count) Baustellen"
    }

    private func loeschenAusfuehren() {
        if let offsets = loeschKandidaten {
            eventListVM.deleteEvents(offsets: offsets)
        }
        loeschKandidaten = nil
    }

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            let persistenceController = PersistenceController.preview
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(EventListViewModel(context: persistenceController.container.viewContext))
        }
    }
}

// MARK: - Hilfe

struct BaustellenListeHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                // In grossen freundlichen Buchstaben. Douglas Adams hatte recht:
                // das Nützlichste auf dem Umschlag eines Handbuchs ist die Beruhigung.
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("DON'T PANIC")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(Color.green)
                        Text("Eine Baustelle, auf der alles schiefgehen kann — kein Problem, du hast den Mops.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Baustellen-Übersicht") {
                    Text("Hier siehst du alle deine Baustellen (Projekte). Jede Baustelle enthält Aufträge, Mängel, Pläne, Checklisten und Wetterdaten.")
                }
                Section("Suche") {
                    Label("Suchfeld oben: filtert nach Name, Ort, Bauherr und Projektnummer", systemImage: "magnifyingglass")
                    Label("Suche und Filterreiter arbeiten zusammen", systemImage: "slider.horizontal.3")
                }
                Section("Filter") {
                    Label("In Planung – es gibt Aufträge, aber keiner hat angefangen", systemImage: "pencil.and.ruler")
                    Label("Läuft – jemand arbeitet, oder etwas ist schon fertig", systemImage: "play.circle.fill")
                    Label("Fertig – alle Aufträge sind erledigt", systemImage: "checkmark.circle.fill")
                    Label("Alle – gesamte Übersicht (Standard)", systemImage: "list.bullet")
                    Text("Die Reiter fragen die Arbeit, nicht den Kalender: ein verstrichener Endtermin macht keine Baustelle fertig — er macht sie überfällig.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Sortierung") {
                    Label("Tippe auf ↕ in der Toolbar um die Sortierung zu ändern", systemImage: "arrow.up.arrow.down")
                    Label("Datum (neu → alt): neueste Baustellen zuerst", systemImage: "arrow.down.calendar")
                    Label("Datum (alt → neu): älteste Baustellen zuerst", systemImage: "arrow.up.calendar")
                    Label("Name (A → Z): alphabetisch", systemImage: "textformat.abc")
                    Label("Offene Mängel: Baustellen mit den meisten offenen Mängeln zuerst", systemImage: "exclamationmark.triangle")
                }
                Section("Neue Baustelle") {
                    Label("Tippe auf das + rechts oben um eine neue Baustelle anzulegen", systemImage: "plus.circle.fill")
                    Label("Felder: Name, Ort, Bauherr, Architekt, Baugenehmigungsnummer, Zeitraum", systemImage: "doc.text")
                }
                Section("Löschen") {
                    Label("Wische eine Baustelle nach links → Löschen", systemImage: "trash")
                    Label("Oder tippe auf Bearbeiten (links oben) für Mehrfach-Auswahl", systemImage: "pencil")
                }
            }
            .navigationTitle("Hilfe: Baustellen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .tint(.orange)
                }
            }
        }
    }
}
