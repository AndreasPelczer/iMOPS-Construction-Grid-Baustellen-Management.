//
//  AblaufplanView.swift
//  Bogen 3: der Ablaufplan einer Baustelle als Gantt. Aufträge in Bauablauf-Reihenfolge,
//  Dauer aus den Manntagen ÷ Kolonne, über die Bauzeit gelegt. Nutzt die vorhandene
//  BauzeitenplanView unverändert — hier kommt nur der Kopf (Bauzeit-Abgleich) dazu.
//

import SwiftUI
import CoreData

struct AblaufplanView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var event: Event

    @State private var kolonne = 3

    private var phasen: [Bauphase] { EventBauphasen.fuer(event: event, kolonne: kolonne) }
    private var geplantWochen: Int { phasen.map(\.endeWoche).max() ?? 0 }

    /// Verfügbare Arbeitswochen aus Baubeginn→Fertigstellung, oder nil wenn nicht gesetzt.
    private var verfuegbarWochen: Int? {
        guard let s = event.eventStartTime, let e = event.eventEndTime else { return nil }
        let tage = BrigadePlanung.arbeitstageZwischen(s, e)
        return tage > 0 ? Int((Double(tage) / 5.0).rounded(.up)) : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if phasen.isEmpty {
                    leer
                } else {
                    kopf
                    BauzeitenplanView(phasen: phasen)
                    fuss
                }
            }
            .padding()
        }
        .navigationTitle("Ablaufplan")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var leer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Noch kein Ablauf", systemImage: "calendar.badge.exclamationmark").font(.headline)
            Text("Der Ablaufplan entsteht aus den Aufträgen der Baustelle in Bauablauf-Reihenfolge. Sobald Aufträge (mit Vorgängern) angelegt sind, erscheint hier der Terminplan.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let s = event.eventStartTime {
                Text("Baubeginn: \(s.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline.weight(.semibold))
            }
            Stepper(value: $kolonne, in: 1...12) {
                Text("Kolonne: \(kolonne) \(kolonne == 1 ? "Person" : "Personen")").font(.subheadline)
            }
            HStack(spacing: 6) {
                Text("Geplant: \(geplantWochen) Woche\(geplantWochen == 1 ? "" : "n")")
                    .font(.subheadline.monospacedDigit())
                if let v = verfuegbarWochen {
                    Text("· Bauzeit gibt \(v) her")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let v = verfuegbarWochen, geplantWochen > v {
                Text("⚠️ Der Plan braucht \(geplantWochen) Wochen, die Bauzeit gibt nur \(v) her. Mehr Leute (Kolonne ↑), mehr Zeit, oder parallel arbeiten.")
                    .font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding().background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var fuss: some View {
        Text("Reihenfolge aus den Vorgänger-Kanten (Bauablauf), Dauer aus den Manntagen der zugeordneten LV-Position ÷ Kolonne. KW n = Woche ab Baubeginn. Schätzung — Aufträge ohne Aufwand tragen 1 Woche Platzhalter.")
            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
