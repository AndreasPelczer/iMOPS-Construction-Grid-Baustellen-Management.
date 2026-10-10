//
//  JarvisEingangView.swift
//  Oben in der Baustellen-Liste: „Entwurf von Jarvis · von heute 11:20 – Müller, Sachsenhausen".
//
//  Antippen öffnet die Schrittliste. Jeder Schritt hat seinen eigenen Zustand – so bleibt
//  ein halbfertiger Entwurf sichtbar (Baustelle angelegt, Termin noch offen) statt still.
//  Angelegt wird im Planer, mit dessen eigener Bestätigung. Nichts passiert ohne Fingertipp.
//

import SwiftUI
import CoreData
import EventKit
import EventKitUI

struct JarvisEingangZeile: View {
    @Environment(\.scenePhase) private var phase
    @State private var entwuerfe: [JarvisEingang.Entwurf] = []
    @State private var offen: JarvisEingang.Entwurf?

    var body: some View {
        Group {
            if !entwuerfe.isEmpty {
                Section {
                    ForEach(entwuerfe) { e in
                        Button { offen = e } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "tray.and.arrow.down.fill")
                                    .font(.title3).foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Entwurf von Jarvis · \(JarvisEingang.alter(e.erstelltDatum))")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(e.kurz).font(.body.weight(.semibold))
                                    Text("\(e.schritte.filter(\.offen).count) von \(e.schritte.count) Schritten offen")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .task { await laden() }
        .onChange(of: phase) { _, neu in if neu == .active { Task { await laden() } } }
        .sheet(item: $offen, onDismiss: { Task { await laden() } }) { e in
            JarvisEntwurfView(entwurf: e)
        }
    }

    private func laden() async { entwuerfe = await JarvisEingang.offene() }
}

struct JarvisEntwurfView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State var entwurf: JarvisEingang.Entwurf
    @State private var zeigePlaner = false
    @State private var zeigeTermin = false
    @State private var zeigeBaustellenWahl = false
    @State private var angelegt: Event?
    @State private var zeigeCanvas = false
    @State private var hinweis: String?
    @State private var ausstehendStand = 0   // neu zeichnen, wenn eine Quittung zum Nachschicken dazukam

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("„\(entwurf.satz)“").font(.callout).foregroundStyle(.secondary)
                } header: {
                    Text("Entwurf von Jarvis · \(JarvisEingang.alter(entwurf.erstelltDatum))")
                } footer: {
                    Text("Angelegt ist noch nichts. Tipp jeden Schritt an – die Baustelle entsteht im Planer.")
                }
                Section("Schritte") {
                    ForEach(entwurf.schritte) { s in zeile(s) }
                }
                if let hinweis {
                    Section { Label(hinweis, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                }
                if entwurf.schritte.contains(where: \.offen) {
                    Section {
                        Button("Rest verwerfen", role: .destructive) {
                            Task {
                                switch await JarvisEingang.verwerfe(entwurf) {
                                case .angekommen(let neu): entwurf = neu; dismiss()
                                case .abgelehnt(let box): if let box { entwurf = box }; hinweis = "Die Box hat einen anderen Stand – so steht es dort."
                                case .nichtErreicht: hinweis = "Box nicht erreicht – nichts verworfen."
                                }
                            }
                        }
                    } footer: {
                        Text("Räumt nur, was noch offen ist. Schon Angelegtes bleibt.")
                    }
                }
            }
            .navigationTitle(entwurf.kurz)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            .sheet(isPresented: $zeigePlaner) {
                NavigationStack {
                    HouseConfiguratorView(vorgabe: entwurf.baustelle.map { JarvisEingang.Vorgabe($0.felder) }) { event in
                        baustelleAngelegt(event)
                    }
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Zurück") { zeigePlaner = false } } }
                }
                .environment(\.managedObjectContext, viewContext)
            }
            .sheet(isPresented: $zeigeTermin) {
                if let s = entwurf.schritte.first(where: { $0.art == "termin" }) {
                    TerminDialog(felder: s.felder) { gespeichert in
                        zeigeTermin = false
                        if gespeichert { quittiere(s, "uebernommen") }
                    }
                }
            }
            .onAppear { angelegtSuchen() }
            .sheet(isPresented: $zeigeBaustellenWahl) {
                if let s = entwurf.schritte.first(where: { $0.art == "kalkulation" }) {
                    BaustellenWahl { event in
                        zeigeBaustellenWahl = false
                        let r = JarvisEingang.legeKalkulation(s.felder, in: event, ctx: viewContext)
                        do {
                            try viewContext.save()
                            hinweis = "\(r.angelegt) Positionen in „\(event.title ?? "")“ übernommen, \(r.mitRezept) davon mit Rezept – das iPad rechnet sie selbst."
                            quittiere(s, "uebernommen", baustelleID: BaustellenMeldung.id(fuer: event))
                            Task { await BaustellenMeldung.meldeAlle(context: viewContext) }
                        } catch {
                            hinweis = "Konnte die Positionen nicht speichern: \(error.localizedDescription)"
                        }
                    }
                    .environment(\.managedObjectContext, viewContext)
                }
            }
            .navigationDestination(isPresented: $zeigeCanvas) {
                if let angelegt { EventDetailView(event: angelegt) }
            }
        }
    }

    @ViewBuilder
    private func zeile(_ s: JarvisEingang.Schritt) -> some View {
        let wartet = s.offen && ausstehendStand >= 0 && JarvisEingang.istAusstehend(entwurf, s)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: wartet ? "clock.badge.exclamationmark" : s.zustand == "uebernommen" ? "checkmark.circle.fill" : s.zustand == "verworfen" ? "xmark.circle" : "circle")
                .foregroundStyle(wartet ? .orange : s.zustand == "uebernommen" ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(titel(s)).font(.body.weight(.semibold))
                Text(details(s)).font(.caption).foregroundStyle(.secondary)
                if wartet {
                    Text("hier erledigt – die Box weiß es noch nicht").font(.caption2).foregroundStyle(.orange)
                } else if s.offen {
                    HStack {
                        Button(knopf(s)) { ausfuehren(s) }
                            .buttonStyle(.borderedProminent)
                            .disabled(s.art == "canvas" && angelegt == nil)
                        // Kein „Verwerfen" neben einem Knopf, der noch gar nicht geht – daneben tippt man aus Versehen.
                        if !(s.art == "canvas" && angelegt == nil) {
                            Button("Verwerfen") { quittiere(s, "verworfen") }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.top, 2)
                } else {
                    Text(s.zustand == "uebernommen" ? "übernommen" : "verworfen").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func titel(_ s: JarvisEingang.Schritt) -> String {
        switch s.art {
        case "baustelle": return "Baustelle \(s.felder["name"] ?? "")"
        case "termin": return s.felder["titel"] ?? "Termin"
        case "abwesenheit": return "\(s.felder["art"] == "abwesend" ? "Abwesend" : "Urlaub"): \(s.felder["name"] ?? "")"
        case "kalkulation": return "Schnellkalkulation · \(JarvisEingang.kalkPositionen(s.felder).count) Positionen"
        default: return "Canvas der Baustelle öffnen"
        }
    }

    private func details(_ s: JarvisEingang.Schritt) -> String {
        switch s.art {
        case "baustelle":
            let v = JarvisEingang.Vorgabe(s.felder)
            return [v.ort.isEmpty ? nil : v.ort,
                    v.start.map { "Start \($0.formatted(date: .abbreviated, time: .omitted))" },
                    v.vorlageText,
                    v.angebotText].compactMap { $0 }.joined(separator: " · ")
        case "termin":
            guard let t = JarvisEingang.termin(s.felder) else { return "Tag fehlt" }
            return t.ganztags ? "\(t.start.formatted(.dateTime.weekday(.wide).day().month().year())) · Uhrzeit offen"
                              : t.start.formatted(.dateTime.weekday(.wide).day().month().year().hour().minute())
        case "kalkulation":
            let p = JarvisEingang.kalkPositionen(s.felder)
            let liste = p.prefix(4).map { "\($0.menge.formatted()) \(JarvisEingang.einheit($0.einheit)) \($0.rezept.isEmpty ? $0.text : $0.rezept)" }
            let summe = Double(s.felder["summe"] ?? "") ?? 0
            return liste.joined(separator: " · ") + (p.count > 4 ? " …" : "")
                + (summe > 0 ? " · in Jarvis nachgeschlagen: \(summe.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE"))))" : "")
                + " · das iPad rechnet nach"
        case "abwesenheit":
            guard let a = abwesenheit(s) else { return "Zeitraum fehlt" }
            return a.zeitraum + (mitarbeiterBekannt(a.name) ? "" : " · ⚠ „\(a.name)“ steht nicht in der Mitarbeiterliste")
        default:
            return angelegt == nil ? "geht, sobald die Baustelle angelegt ist" : "Baustelle ist da"
        }
    }

    private func abwesenheit(_ s: JarvisEingang.Schritt) -> Abwesenheit? {
        guard let name = s.felder["name"], !name.isEmpty,
              let von = s.felder["von"].flatMap(JarvisEingang.tag), let bis = s.felder["bis"].flatMap(JarvisEingang.tag) else { return nil }
        return Abwesenheit(name: name, von: von, bis: max(bis, von), art: s.felder["art"] == "abwesend" ? .abwesend : .urlaub)
    }

    /// Der Name ist der Schlüssel (wie `Auftrag.employeeName`) – ein Tippfehler fände nie einen Auftrag.
    private func mitarbeiterBekannt(_ name: String) -> Bool {
        let req = NSFetchRequest<Employee>(entityName: "Employee")
        req.predicate = NSPredicate(format: "name ==[c] %@", name)
        return ((try? viewContext.count(for: req)) ?? 0) > 0
    }

    private func knopf(_ s: JarvisEingang.Schritt) -> String {
        switch s.art {
        case "baustelle": return "Im Planer öffnen"
        case "termin": return "In den Kalender"
        case "abwesenheit": return "Eintragen"
        case "kalkulation": return "Baustelle wählen"
        default: return "Canvas öffnen"
        }
    }

    private func ausfuehren(_ s: JarvisEingang.Schritt) {
        switch s.art {
        case "baustelle": zeigePlaner = true
        case "termin": zeigeTermin = true
        case "kalkulation": zeigeBaustellenWahl = true
        case "abwesenheit":
            guard let a = abwesenheit(s) else { hinweis = "Zeitraum fehlt – so kann ich es nicht eintragen."; return }
            AbwesenheitenStore.shared.hinzu(a)   // doppelt übernommen bleibt ein Eintrag
            quittiere(s, "uebernommen")
        default:
            zeigeCanvas = true
            quittiere(s, "uebernommen")
        }
    }

    /// Wurde die Baustelle schon früher übernommen (anderes Öffnen), sie wiederfinden – sonst ginge der Canvas nie auf.
    private func angelegtSuchen() {
        let vonBox = entwurf.baustelle?.baustelle_id ?? ""
        let gemerkt = JarvisEingang.ausstehend.first { $0.entwurf == entwurf.id && $0.schritt == entwurf.baustelle?.nr }?.baustelleID ?? ""
        let bid = vonBox.isEmpty ? gemerkt : vonBox
        guard angelegt == nil, !bid.isEmpty else { return }
        let req = NSFetchRequest<Event>(entityName: "Event")
        req.predicate = NSPredicate(format: "eventNumber == %@", bid)
        req.fetchLimit = 1
        angelegt = (try? viewContext.fetch(req))?.first
    }

    private func baustelleAngelegt(_ event: Event) {
        zeigePlaner = false
        let v = entwurf.baustelle.map { JarvisEingang.Vorgabe($0.felder) }
        if let v, v.angebotBetrag != nil || v.angebotBis != nil {
            var extras = event.extras.flatMap { try? JSONDecoder().decode(EventExtrasPayload.self, from: Data($0.utf8)) } ?? EventExtrasPayload()
            v.uebertrage(in: &extras)
            if let data = try? JSONEncoder().encode(extras) { event.extras = String(data: data, encoding: .utf8) }
            try? viewContext.save()
        }
        angelegt = event
        Task { await BaustellenMeldung.meldeAlle(context: viewContext) }   // gleich melden – Jarvis soll sie sofort kennen
        if let s = entwurf.baustelle { quittiere(s, "uebernommen", baustelleID: BaustellenMeldung.id(fuer: event)) }
    }

    private func quittiere(_ s: JarvisEingang.Schritt, _ zustand: String, baustelleID: String = "") {
        Task {
            switch await JarvisEingang.quittiere(entwurf, schritt: s.nr, zustand: zustand, baustelleID: baustelleID) {
            case .angekommen(let neu):
                entwurf = neu
                hinweis = nil
            case .abgelehnt(let box):
                // Die Box weiß es anders – ihren Stand zeigen, nicht unseren Wunsch.
                if let box { entwurf = box }
                hinweis = "„\(titel(s))“ war auf der Box schon erledigt – so steht es dort."
            case .nichtErreicht:
                // Kein Grün erfinden. Passiert ist es hier trotzdem – merken und nachschicken.
                JarvisEingang.merke(.init(entwurf: entwurf.id, schritt: s.nr, zustand: zustand, baustelleID: baustelleID))
                ausstehendStand += 1
                hinweis = "Box nicht erreicht – die Quittung wird nachgeschickt, sobald sie wieder da ist."
            }
        }
    }
}

/// Der Kalender-Dialog des Systems, vorausgefüllt. Gespeichert wird erst, wenn man dort „Hinzufügen" tippt.
struct TerminDialog: UIViewControllerRepresentable {
    let felder: [String: String]
    let fertig: (Bool) -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let vc = EKEventEditViewController()
        vc.eventStore = store
        let ev = EKEvent(eventStore: store)
        ev.title = felder["titel"] ?? "Treffen vor Ort"
        ev.location = felder["ort"]
        if let t = JarvisEingang.termin(felder) {
            ev.isAllDay = t.ganztags
            ev.startDate = t.start
            ev.endDate = t.ganztags ? t.start : t.start.addingTimeInterval(3600)
        }
        ev.notes = "Aus einem Jarvis-Entwurf"
        vc.event = ev
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}
    func makeCoordinator() -> Koordinator { Koordinator(fertig) }

    final class Koordinator: NSObject, EKEventEditViewDelegate {
        let fertig: (Bool) -> Void
        init(_ f: @escaping (Bool) -> Void) { fertig = f }
        func eventEditViewController(_ c: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            fertig(action == .saved)
        }
    }
}


/// Welche Baustelle? Die Liste aus der App – angelegt wird nur, was hier angetippt wird.
struct BaustellenWahl: View {
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "title", ascending: true)]) private var baustellen: FetchedResults<Event>
    let gewaehlt: (Event) -> Void

    var body: some View {
        NavigationStack {
            List(baustellen) { e in
                Button { gewaehlt(e) } label: {
                    VStack(alignment: .leading) {
                        Text(e.title ?? "Unbenannt").font(.body.weight(.semibold))
                        Text("\(e.lvPositionen?.count ?? 0) LV-Positionen · \(e.location ?? "")").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Welche Baustelle?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
        }
    }
}
