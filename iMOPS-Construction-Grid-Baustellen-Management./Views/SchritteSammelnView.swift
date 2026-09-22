//
//  SchritteSammelnView.swift
//
//  „Ich muss jetzt aber jeden einzeln anklicken zum Übertragen." (Andreas, 22.09.2026)
//
//  Ein Durchgang statt 34. Zuerst alles, was nichts kostet (Katalog, Vorlage,
//  Rezept), dann der Prof für den Rest — einer nach dem anderen, sichtbar und
//  abbrechbar, weil eine Anfrage bis zu drei Minuten dauern kann.
//
//  🔴 Ungeprüftes ist NICHT vorausgewählt. Was aus dem Katalog kommt, hat ein Mensch
//  abgenommen — das darf mit. Eine Vorlage aus der Anfangszeit nicht.
//

import SwiftUI
import CoreData

struct SchritteSammelnView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    let event: Event

    @State private var funde: [SchritteSammeln.Fund] = []
    @State private var geladen = false
    @State private var fragtGerade: String?
    @State private var abbrechen = false
    @State private var gefragt = 0

    private var offene: [SchritteSammeln.Fund] { funde.filter { $0.quelle == .offen } }
    private var gewaehlt: Int { funde.filter { $0.uebernehmen && !$0.schritte.isEmpty }.count }

    var body: some View {
        NavigationStack {
            List {
                if funde.isEmpty && geladen {
                    ContentUnavailableView("Alle Aufträge haben Schritte",
                                           systemImage: "checkmark.circle",
                                           description: Text("Hier ist nichts zu holen."))
                } else {
                    kopf
                    ForEach($funde) { $f in zeile($f) }
                }
            }
            .navigationTitle("Schritte für alle")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !geladen else { return }
                geladen = true
                funde = SchritteSammeln.sofort(fuer: event)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { abbrechen = true; dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(gewaehlt) übernehmen") {
                        SchritteSammeln.uebernehmen(funde, in: ctx)
                        try? ctx.save()
                        dismiss()
                    }
                    .disabled(gewaehlt == 0)
                }
            }
        }
    }

    // MARK: - Kopf

    @ViewBuilder private var kopf: some View {
        let ausKatalog = funde.filter { $0.quelle == .katalog }.count
        let ausVorlage = funde.filter { $0.quelle == .vorlage }.count
        let ausRezept  = funde.filter { $0.quelle == .rezept }.count

        Section {
            if ausKatalog > 0 {
                Label("\(ausKatalog) aus dem Katalog — schon von jemandem abgenommen",
                      systemImage: "checkmark.seal.fill")
                    .font(.subheadline).foregroundStyle(.green)
            }
            if ausVorlage > 0 {
                Label("\(ausVorlage) aus einer Vorlage — ungeprüft, nicht vorausgewählt",
                      systemImage: "sparkles")
                    .font(.subheadline).foregroundStyle(.orange)
            }
            if ausRezept > 0 {
                Label("\(ausRezept) nur als Gerüst aus dem Rezept",
                      systemImage: "list.bullet.indent")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if !offene.isEmpty {
                if let name = fragtGerade {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Der Mops fragt: \(name)").font(.caption)
                            Text("\(gefragt) von \(offene.count) · kann bis zu drei Minuten je Auftrag dauern")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Stopp") { abbrechen = true }
                            .font(.caption).buttonStyle(.bordered).controlSize(.mini)
                    }
                } else {
                    Button {
                        Task { await alleFragen() }
                    } label: {
                        Label("\(offene.count) beim Mops nachfragen", systemImage: "questionmark.bubble")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        } header: {
            Text("\(funde.count) Aufträge ohne Schritte")
        } footer: {
            Text("Übernommen wird nur, was angehakt ist. Abgenommen ist damit nichts — "
                 + "das machst du im Auftrag, und erst dann merkt der Mops es sich.")
        }
    }

    // MARK: - Eine Zeile

    @ViewBuilder private func zeile(_ f: Binding<SchritteSammeln.Fund>) -> some View {
        let fund = f.wrappedValue
        Section {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    f.uebernehmen.wrappedValue.toggle()
                } label: {
                    Image(systemName: fund.uebernehmen ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(fund.uebernehmen
                                         ? AnyShapeStyle(Color.accentColor)
                                         : AnyShapeStyle(.secondary))
                }
                .buttonStyle(.plain)
                .disabled(fund.schritte.isEmpty)

                VStack(alignment: .leading, spacing: 3) {
                    Text(fund.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    HStack(spacing: 6) {
                        Text(fund.quelle.kurz)
                            .font(.caption2)
                            .foregroundStyle(fund.quelle == .katalog ? .green : .secondary)
                        if !fund.schritte.isEmpty {
                            Text("· \(fund.schritte.count) Schritte")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(fund.schritte.prefix(3)) { s in
                        Text("\(s.ampel) \(s.text)")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    if fund.schritte.count > 3 {
                        Text("und \(fund.schritte.count - 3) weitere")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Der Prof, einer nach dem anderen

    private func alleFragen() async {
        abbrechen = false
        gefragt = 0
        for (i, f) in funde.enumerated() where f.quelle == .offen {
            if abbrechen { break }
            fragtGerade = f.name
            let schritte = await SchritteSammeln.frageProf(fuer: f.job)
            gefragt += 1
            if !schritte.isEmpty {
                funde[i].schritte = schritte
                funde[i].quelle = .vorlage      // ungeprüft, wie eine Vorlage
                funde[i].uebernehmen = false    // 🔴 nicht vorauswählen
            }
        }
        fragtGerade = nil
    }
}
