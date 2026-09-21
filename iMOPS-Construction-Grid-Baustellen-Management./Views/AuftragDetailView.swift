import SwiftUI
import CoreData
import UniformTypeIdentifiers

// MARK: - Master = AuftragExtrasPayload
typealias JobExtrasPayload = AuftragExtrasPayload

// MARK: - AuftragDetailView
struct AuftragDetailView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(AppSession.self) private var session   // wer ist angemeldet (der "wer" der Übergabe)
    @ObservedObject var job: Auftrag

    @State private var extras = JobExtrasPayload()
    @State private var newStepText: String = ""
    @State private var zeigeImportPicker = false
    @State private var importFehler: [String] = []
    @State private var zeigeImportFehler = false

    // Voraussetzungen — welcher Auftrag muss vorher fertig sein?
    @State private var zeigeVoraussetzungWahl = false
    @State private var kettenFehler: String?

    /// „Wer ein Nein übergeht, unterschreibt." — der Dialog erscheint, wenn jemand
    /// fertig meldet, obwohl Voraussetzungen offen sind. Er sperrt NICHT: er verlangt
    /// einen Satz. Wer gesperrt wird, arbeitet am Mops vorbei.
    @State private var zeigeUebernahme = false
    @State private var begruendung = ""


    private var doneCount: Int { extras.checklist.filter { $0.isDone }.count }
    private var totalCount: Int { extras.checklist.count }
    private var progress: Double { totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount) }

    private var nextOpenStepTitle: String? {
        extras.checklist.first(where: { !$0.isDone })?.title
    }

    private var whatToDoText: String {
        if let d = job.processingDetails, !d.isEmpty { return d }
        if let first = extras.lineItems.first?.title, !first.isEmpty { return first }
        return "Auftrag"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                productionListCard
                modeCard
                checklistCard
                uebernahmenCard
                voraussetzungenCard
                LVDeleteButtonView(currentLV: job)
                    .padding(.horizontal, 4)
                
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(whatToDoText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { extras = loadExtras() }
        .sheet(isPresented: $zeigeImportPicker) {
            MaterialImportPickerView { result in
                verarbeiteImport(result)
            }
        }
        .alert("Import-Hinweise", isPresented: $zeigeImportFehler) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importFehler.joined(separator: "\n"))
        }
        .sheet(isPresented: $zeigeVoraussetzungWahl) {
            VoraussetzungWaehlenView(auftrag: job) { gewaehlt in
                verknuepfeMit(gewaehlt)
            }
        }
        // Der Zyklus-Fehler MUSS sichtbar sein: ein stumm verworfener Versuch
        // sähe für den Nutzer aus wie ein kaputter Knopf.
        .alert("Geht nicht", isPresented: Binding(
            get: { kettenFehler != nil },
            set: { if !$0 { kettenFehler = nil } }
        )) {
            Button("Verstanden", role: .cancel) { kettenFehler = nil }
        } message: {
            Text(kettenFehler ?? "")
        }
        .sheet(isPresented: $zeigeUebernahme) { uebernahmeDialog }
    }

    // MARK: - „Ich übernehme das"

    /// Kein Sperrdialog. Er nennt, was offen ist, sagt die Folge ehrlich, gibt zu, dass
    /// der Mops nicht davorsteht — und verlangt einen Satz.
    private var uebernahmeDialog: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(job.offeneVoraussetzungen, id: \.objectID) { v in
                        Label(v.anzeigename, systemImage: "clock")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Worauf dieser Auftrag noch wartet")
                }

                Section {
                    Text("Du stehst davor. Ich nicht.")
                        .font(.headline)
                    Text("Wenn du recht hast, ist nichts passiert. Wenn nicht, steht in "
                         + "zehn Jahren niemand mehr dafür gerade — außer dem, der es "
                         + "freigegeben hat. Deshalb bleibt dein Satz an diesem Auftrag.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Ich bin nur der Mops. Ab hier entscheidest du.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Section {
                    TextField("z. B. „CM-Messung 1,8 % gemessen, belegreif\"",
                              text: $begruendung, axis: .vertical)
                        .lineLimit(2...5)
                        .id("uebernahme-begruendung")
                } header: {
                    Text("Warum ist es trotzdem in Ordnung?")
                } footer: {
                    Text("Pflichtfeld. Das ist kein Geständnis — das ist dein Nachweis.")
                }
            }
            .navigationTitle("Voraussetzung offen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ich warte") { begruendung = ""; zeigeUebernahme = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ich übernehme das") { uebernehmenUndFertig() }
                        .disabled(begruendung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - UI Cards

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JETZT").font(.caption).foregroundStyle(.secondary)
            Text(whatToDoText).font(.title2.bold()).lineLimit(3)

            HStack(spacing: 10) {
                if !extras.orderNumber.isEmpty {
                    Label(extras.orderNumber, systemImage: "number")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !extras.station.isEmpty {
                    Label(extras.station, systemImage: "mappin.and.ellipse")
                        .font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                }
            }

            HStack(spacing: 12) {
                if let deadline = extras.deadline {
                    Label(deadline.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if extras.persons > 0 {
                    Label("\(extras.persons) Pers.", systemImage: "person.2")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let emp = job.employeeName, !emp.isEmpty {
                    Label(emp, systemImage: "person.fill")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let kg = job.kostenGruppeNummer, !kg.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                    Text(kg)
                    if let bez = job.kostenGruppeBezeichnung, !bez.isEmpty {
                        Text("·")
                        Text(bez).lineLimit(1)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .foregroundStyle(Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if extras.trainingMode, let next = nextOpenStepTitle, !job.istFertig {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Jetzt: \(next)").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.secondary).padding(.top, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var modeCard: some View {
        HStack {
            Text(extras.trainingMode ? "Schrittweise" : "Schnellmodus")
                .font(.headline)
            Spacer()
            Toggle("", isOn: Binding(
                get: { extras.trainingMode },
                set: { extras.trainingMode = $0; saveExtras(extras) }
            ))
            .labelsHidden()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var productionListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Materialliste").font(.headline)
                Spacer()
                Text("\(extras.lineItems.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Button {
                    zeigeImportPicker = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if extras.lineItems.isEmpty {
                Text("Keine Positionen hinterlegt.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                materialStand   // „X/Y geprüft · Z fehlt" — der Ist-da-Überblick
                VStack(spacing: 10) {
                    ForEach(extras.lineItems) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(item.title).font(.body.weight(.semibold))
                                Spacer()
                                if !item.kostenGruppeNummer.isEmpty {
                                    Text(item.kostenGruppeNummer)
                                        .font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.12))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            if !(item.amount.isEmpty && item.unit.isEmpty) {
                                Text("\(item.amount) \(item.unit)".trimmingCharacters(in: .whitespaces))
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            if !item.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(item.note).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                            }
                            // Polier-Check: ist das auf der Baustelle? (Zustand + Nachweis)
                            HStack(spacing: 8) {
                                materialKnopf(item, da: true)
                                materialKnopf(item, da: false)
                                Spacer()
                                if let von = item.geprueftVon, let am = item.geprueftAm {
                                    Text("\(von) · \(am.formatted(.dateTime.day().month().hour().minute()))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.top, 4)
                        }
                        .padding(10)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // „X/Y geprüft · Z fehlt" — der Ist-da-Überblick fürs Material.
    private var materialStand: some View {
        let geprueft = extras.lineItems.filter { $0.vorhanden != nil }.count
        let fehlt = extras.lineItems.filter { $0.vorhanden == false }.count
        return HStack(spacing: 6) {
            Text("\(geprueft)/\(extras.lineItems.count) geprüft")
                .font(.caption).foregroundStyle(.secondary)
            if fehlt > 0 {
                Text("· \(fehlt) fehlt").font(.caption.weight(.semibold)).foregroundStyle(.orange)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func materialKnopf(_ item: AuftragLineItem, da: Bool) -> some View {
        let label = Label(da ? "Da" : "Fehlt",
                          systemImage: da ? "checkmark.circle.fill" : "xmark.circle").font(.caption)
        if item.vorhanden == da {
            Button { pruefeMaterial(item.id, vorhanden: da) } label: { label }
                .buttonStyle(.borderedProminent).tint(da ? .green : .orange).controlSize(.small)
        } else {
            Button { pruefeMaterial(item.id, vorhanden: da) } label: { label }
                .buttonStyle(.bordered).tint(da ? .green : .orange).controlSize(.small)
        }
    }

    /// Polier-Check: Material da/fehlt setzen — mit Nachweis (wer/wann). Nochmal tippen
    /// auf denselben Zustand → zurück auf „ungeprüft".
    private func pruefeMaterial(_ id: String, vorhanden: Bool) {
        guard let idx = extras.lineItems.firstIndex(where: { $0.id == id }) else { return }
        if extras.lineItems[idx].vorhanden == vorhanden {
            extras.lineItems[idx].vorhanden = nil
            extras.lineItems[idx].geprueftVon = nil
            extras.lineItems[idx].geprueftAm = nil
        } else {
            extras.lineItems[idx].vorhanden = vorhanden
            extras.lineItems[idx].geprueftVon = session.role.title
            extras.lineItems[idx].geprueftAm = Date()
        }
        saveExtras(extras)
    }

    // (Die Übergabe lebt jetzt an EINER Stelle: der Baustelle — SchichtUebergabeCard.
    //  Der einzelne Auftrag ist zum Tun da: JETZT → Schritte → Material.)

    private var checklistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Arbeitsschritte").font(.headline)
                Spacer()
                Menu {
                    ForEach(AuftragTemplate.allCases) { tpl in
                        Button("Vorlage: \(tpl.rawValue)") {
                            applyTemplate(tpl, mode: .append)
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        extras.checklist.removeAll()
                        job.setzeFertig(false)
                        saveExtras(extras)
                    } label: {
                        Label("Leeren", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                }
            }

            if extras.trainingMode {
                HStack(spacing: 10) {
                    TextField("Neuer Schritt...", text: $newStepText)
                        .textFieldStyle(.roundedBorder)
                    Button { addStep(newStepText) } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .disabled(newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if extras.checklist.isEmpty {
                    Text("Noch keine Schritte. Nutze eine Vorlage oder fuege Schritte hinzu.")
                        .foregroundStyle(.secondary).font(.subheadline)
                } else {
                    VStack(spacing: 8) {
                        ForEach(extras.checklist) { item in
                            trainingStepRow(item)
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Button { markJobCompleted() } label: {
                        Label(job.istFertig
                                ? "Auftrag ist fertig"
                                : "Ich bestätige, dass jeder einzelne Schritt erledigt ist",
                              systemImage: job.istFertig ? "checkmark.seal.fill" : "checkmark.circle.fill")
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) { resetCompletion() } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(!job.istFertig)
                }

                if extras.checklist.isEmpty {
                    Text("Keine Arbeitsschritte hinterlegt.")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
                } else {
                    DisclosureGroup("Schritte anzeigen (\(extras.checklist.count))") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(extras.checklist) { item in
                                proStepRow(item)
                            }
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 6)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Übernommene Verantwortung

    /// Was hier steht, hat jemand bewusst übergangen — mit seinem Satz.
    /// Sichtbar, weil ein Nachweis, den nur der Chef sieht, kein Nachweis ist,
    /// sondern eine Akte. Wer es geschrieben hat, muss es auch lesen können.
    @ViewBuilder private var uebernahmenCard: some View {
        let liste = extras.uebergehungen ?? []
        if !liste.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Verantwortung übernommen", systemImage: "signature")
                    .font(.headline)
                ForEach(liste) { u in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(u.woraufGewartet)
                            .font(.subheadline.weight(.semibold))
                        Text("„\(u.begruendung)\"")
                            .font(.subheadline)
                        Text("\(u.von) · \(u.am, format: .dateTime.day().month().year().hour().minute())")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
                }
                Text("Bleibt an diesem Auftrag. Nicht löschbar — das ist der Sinn.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.orange.opacity(0.5), lineWidth: 1))
        }
    }

    // MARK: - Voraussetzungen (Grap8-Kanten)

    /// „Worauf wartet dieser Auftrag?" — die Aufträge, die vorher fertig sein müssen.
    ///
    /// Zeigt **nur** echte Graph-Kanten (`istKante`). Eine `Voraussetzung` ohne Quelle
    /// ist ein manuelles Geschoss-Häkchen aus Welle 9 und gehört nicht hierher.
    private var voraussetzungenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Wartet auf").font(.headline)
                Spacer()
                Button { zeigeVoraussetzungWahl = true } label: {
                    Label("Voraussetzung", systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .disabled(moeglicheVorgaenger.isEmpty)
            }

            if kanten.isEmpty {
                Text(job.event == nil
                     ? "Dieser Auftrag hängt an keiner Baustelle — ohne Geschwister gibt es nichts zu verknüpfen."
                     : "Keine — kann sofort starten.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(kanten, id: \.objectID) { kante in
                        vorgaengerZeile(kante)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func vorgaengerZeile(_ kante: Voraussetzung) -> some View {
        HStack(spacing: 12) {
            // Der Haken sagt, ob der Vorgänger fertig ist — live gerechnet,
            // nicht gespeichert (siehe `Voraussetzung.istErfuellt`).
            Image(systemName: kante.istErfuellt ? "checkmark.circle.fill" : "clock")
                .foregroundStyle(kante.istErfuellt ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(kante.quelle.map(Kausalkette.bezeichnung) ?? "Unbekannter Auftrag")
                Text(kante.istErfuellt ? "fertig" : "läuft noch")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(role: .destructive) {
                loese(kante)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
    }

    /// Die echten Kanten dieses Auftrags, in Reihenfolge.
    private var kanten: [Voraussetzung] {
        job.voraussetzungenArray.filter(\.istKante)
    }

    /// Wen kann man noch als Vorgänger wählen: Geschwister derselben Baustelle,
    /// ohne sich selbst und ohne die schon verknüpften.
    private var moeglicheVorgaenger: [Auftrag] {
        AuftragDetailView.moeglicheVorgaenger(fuer: job)
    }

    /// Als `static`, damit das Auswahl-Blatt dieselbe Regel benutzt — eine Quelle
    /// dafür, wer wählbar ist, statt zwei, die auseinanderlaufen können.
    static func moeglicheVorgaenger(fuer job: Auftrag) -> [Auftrag] {
        let geschwister = (job.event?.jobs?.allObjects as? [Auftrag]) ?? []
        let schonVerknuepft = Set(job.voraussetzungenArray.compactMap { $0.quelle }.map(ObjectIdentifier.init))
        return geschwister
            .filter { $0 !== job && !schonVerknuepft.contains(ObjectIdentifier($0)) }
            .sorted { Kausalkette.bezeichnung($0) < Kausalkette.bezeichnung($1) }
    }

    private func verknuepfeMit(_ vorgaenger: Auftrag) {
        do {
            try Kausalkette.verknuepfe(job, brauchtVorher: vorgaenger, in: ctx)
            try ctx.save()
        } catch let fehler as KausalketteFehler {
            // Der Text aus `KausalketteFehler` erklärt den Kreis mit beiden Namen —
            // besser als alles, was hier neu erfunden würde.
            ctx.rollback()
            kettenFehler = fehler.errorDescription
        } catch {
            ctx.rollback()
            kettenFehler = "Die Voraussetzung ließ sich nicht sichern: \(error.localizedDescription)"
        }
    }

    private func loese(_ kante: Voraussetzung) {
        guard let quelle = kante.quelle else { return }
        Kausalkette.entknuepfe(job, brauchtNichtMehr: quelle, in: ctx)
        do {
            try ctx.save()
        } catch {
            ctx.rollback()
            kettenFehler = "Die Voraussetzung ließ sich nicht lösen: \(error.localizedDescription)"
        }
    }

    private func trainingStepRow(_ item: AuftragChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Button { toggleStep(item.id) } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle").font(.title2)
                }
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                Spacer()
                Button(role: .destructive) { deleteStep(item.id) } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
            }
            if let beleg = uebergabeBeleg(item) {
                Label(beleg, systemImage: "signature")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.leading, 34)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func proStepRow(_ item: AuftragChecklistItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(systemName: "text.badge.checkmark").foregroundStyle(.secondary)
                Text(item.title)
                Spacer()
            }
            if let beleg = uebergabeBeleg(item) {
                Label(beleg, systemImage: "signature")
                    .font(.caption2).foregroundStyle(.secondary)
                    .padding(.leading, 26)
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    /// Der Übergabe-Nachweis eines Schritts als Text („übernommen von … · …"), oder nil.
    private func uebergabeBeleg(_ item: AuftragChecklistItem) -> String? {
        guard let von = item.uebernommenVon else { return nil }
        guard let am = item.uebernommenAm else { return "übernommen von \(von)" }
        return "übernommen von \(von) · \(am.formatted(.dateTime.day().month().hour().minute()))"
    }

    // MARK: - Data: load/save extras
    private func loadExtras() -> AuftragExtrasPayload {
        guard let s = job.extras, let data = s.data(using: .utf8) else { return AuftragExtrasPayload() }
        return (try? JSONDecoder().decode(AuftragExtrasPayload.self, from: data)) ?? AuftragExtrasPayload()
    }

    private func saveExtras(_ payload: AuftragExtrasPayload) {
        do {
            let data = try JSONEncoder().encode(payload)
            job.extras = String(data: data, encoding: .utf8)
            try ctx.save()
        } catch {
            print("Auftrag extras save error: \(error)")
        }
    }

    // MARK: - Checklist actions
    private func addStep(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        extras.checklist.append(AuftragChecklistItem(title: t))
        newStepText = ""
        job.setzeFertig(false)
        saveExtras(extras)
    }

    private func toggleStep(_ id: String) {
        guard let idx = extras.checklist.firstIndex(where: { $0.id == id }) else { return }
        let jetztErledigt = !extras.checklist[idx].isDone
        extras.checklist[idx].isDone = jetztErledigt
        if jetztErledigt {
            // Bewusste Übergabe: der eingeloggte Nutzer übernimmt diesen Schritt.
            extras.checklist[idx].uebernommenVon = session.role.title
            extras.checklist[idx].uebernommenAm = Date()
        } else {
            // Zurückgenommen → der Beleg gilt nicht mehr.
            extras.checklist[idx].uebernommenVon = nil
            extras.checklist[idx].uebernommenAm = nil
        }
        let allDone = !extras.checklist.isEmpty && extras.checklist.allSatisfy { $0.isDone }
        job.setzeFertig(allDone)
        saveExtras(extras)
    }

    private func deleteStep(_ id: String) {
        extras.checklist.removeAll { $0.id == id }
        let allDone = !extras.checklist.isEmpty && extras.checklist.allSatisfy { $0.isDone }
        job.setzeFertig(allDone)
        saveExtras(extras)
    }

    private func markJobCompleted() {
        // 🔴 DER RIEGEL. `istStartbar` war gebaut, 26× getestet und wurde hier nie
        // gefragt — der Auftrag ließ sich fertig melden, während oben auf demselben
        // Bildschirm „läuft noch" stand. Jetzt wird gefragt. Nicht gesperrt: wer
        // gesperrt wird, arbeitet am Mops vorbei, und dann weiß niemand mehr etwas.
        guard job.istStartbar else {
            zeigeUebernahme = true
            return
        }
        schliesseAb()
    }

    /// Die Übernahme: Satz festhalten, dann abschließen.
    private func uebernehmenUndFertig() {
        let satz = begruendung.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !satz.isEmpty else { return }
        let offene = job.offeneVoraussetzungen
        let jetzt = Date()
        var liste = extras.uebergehungen ?? []
        for v in offene {
            liste.append(Uebergehung(
                woraufGewartet: v.anzeigename,
                begruendung: satz,
                von: session.role.title,
                am: jetzt,
                offeneVoraussetzungenGesamt: offene.count))
        }
        extras.uebergehungen = liste
        begruendung = ""
        zeigeUebernahme = false
        schliesseAb()
    }

    private func schliesseAb() {
        // Sammel-Übergabe: der angemeldete Nutzer übernimmt alle Schritte auf einmal —
        // mit Beleg (wer/wann), auch die, die vorher noch keinen hatten.
        let jetzt = Date()
        for i in extras.checklist.indices {
            extras.checklist[i].isDone = true
            if extras.checklist[i].uebernommenVon == nil {
                extras.checklist[i].uebernommenVon = session.role.title
                extras.checklist[i].uebernommenAm = jetzt
            }
        }
        job.status = .completed
        saveExtras(extras)
    }

    private func resetCompletion() {
        job.setzeFertig(false)
        for i in extras.checklist.indices { extras.checklist[i].isDone = false }
        saveExtras(extras)
    }

    // MARK: - Templates
    private enum TemplateInsertMode { case replace, append }

    private func applyTemplate(_ template: AuftragTemplate, mode: TemplateInsertMode) {
        let newItems = template.steps.map { AuftragChecklistItem(title: $0) }
        if mode == .replace {
            extras.checklist = newItems
        } else {
            extras.checklist.append(contentsOf: newItems)
        }
        job.setzeFertig(false)
        saveExtras(extras)
    }

    // MARK: - Material Import

    private func verarbeiteImport(_ result: MaterialImportResult) {
        extras.lineItems.append(contentsOf: result.items)
        saveExtras(extras)
        if !result.fehler.isEmpty {
            importFehler = result.fehler
            zeigeImportFehler = true
        }
    }
}

// MARK: - Document Picker für Materiallisten (CSV / JSON)

struct MaterialImportPickerView: UIViewControllerRepresentable {
    let onImport: (MaterialImportResult) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let typen: [UTType] = [.commaSeparatedText, .json, .plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: typen)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: (MaterialImportResult) -> Void
        let dismiss: DismissAction

        init(onImport: @escaping (MaterialImportResult) -> Void, dismiss: DismissAction) {
            self.onImport = onImport
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            let result = MaterialImportService.shared.importiere(von: url)
            onImport(result)
            dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}
