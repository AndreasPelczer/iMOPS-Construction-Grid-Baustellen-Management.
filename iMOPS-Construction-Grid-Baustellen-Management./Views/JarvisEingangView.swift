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
    @State private var angelegt: Event?
    @State private var zeigeCanvas = false
    @State private var hinweis: String?

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
            .navigationDestination(isPresented: $zeigeCanvas) {
                if let angelegt { EventDetailView(event: angelegt) }
            }
        }
    }

    @ViewBuilder
    private func zeile(_ s: JarvisEingang.Schritt) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: s.zustand == "uebernommen" ? "checkmark.circle.fill" : s.zustand == "verworfen" ? "xmark.circle" : "circle")
                .foregroundStyle(s.zustand == "uebernommen" ? .green : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(titel(s)).font(.body.weight(.semibold))
                Text(details(s)).font(.caption).foregroundStyle(.secondary)
                if s.offen {
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
        default:
            return angelegt == nil ? "geht, sobald die Baustelle angelegt ist" : "Baustelle ist da"
        }
    }

    private func knopf(_ s: JarvisEingang.Schritt) -> String {
        switch s.art {
        case "baustelle": return "Im Planer öffnen"
        case "termin": return "In den Kalender"
        default: return "Canvas öffnen"
        }
    }

    private func ausfuehren(_ s: JarvisEingang.Schritt) {
        switch s.art {
        case "baustelle": zeigePlaner = true
        case "termin": zeigeTermin = true
        default:
            zeigeCanvas = true
            quittiere(s, "uebernommen")
        }
    }

    /// Wurde die Baustelle schon früher übernommen (anderes Öffnen), sie wiederfinden – sonst ginge der Canvas nie auf.
    private func angelegtSuchen() {
        guard angelegt == nil, let bid = entwurf.baustelle?.baustelle_id, !bid.isEmpty else { return }
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
                // Passiert ist es hier trotzdem (z. B. Baustelle angelegt) – zeigen, aber sagen, dass die Box es nicht weiß.
                if let i = entwurf.schritte.firstIndex(where: { $0.nr == s.nr }) { entwurf.schritte[i].zustand = zustand }
                hinweis = "Box nicht erreicht – der Entwurf kann beim nächsten Öffnen wieder auftauchen."
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
