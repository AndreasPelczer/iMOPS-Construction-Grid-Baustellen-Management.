import SwiftUI
import CoreData

// MARK: - UebergangszeitenCard (Wartezeit auf der Verbindung setzen)
//
// Der fehlende Kern von „Zeit im Canvas": die Wartezeit, in der NIEMAND arbeitet
// (Beton härten, Estrich trocknen), sitzt auf der KANTE zwischen zwei Aufträgen.
// Hier wird sie eingegeben — je Abhängigkeit (Vorgänger → Nachfolger) ein Stepper.
// Ohne diese Zeiten rechnet der Terminplan/Zeitstrahl nur die reinen Arbeitsdauern;
// mit ihnen schiebt sich der Nachfolger korrekt nach hinten.
//
// Nutzt die vorhandenen Voraussetzung-Kanten (quelle → auftrag) + das Feld
// `wartezeitTage`. Kein neues Datenmodell, kein Eingriff in die Grap8-Leinwand.
struct UebergangszeitenCard: View {
    let jobs: [Auftrag]
    @Environment(\.managedObjectContext) private var ctx
    @State private var tick = 0
    @State private var belegBearbeiten: Kante?

    private struct Kante: Identifiable {
        let id: NSManagedObjectID
        let v: Voraussetzung
        let von: String
        let zu: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Übergangszeiten", systemImage: "hourglass").font(.headline)
            Text("Wartezeit auf einer Verbindung — Zeit ohne Arbeit (Beton härten, Estrich trocknen). Schiebt den Nachfolger nach hinten.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            let kanten = self.kanten
            if kanten.isEmpty {
                Text("Noch keine Abhängigkeiten zwischen Aufträgen — die entstehen über die Verbindungen im Canvas.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(kanten) { k in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(k.von)  →  \(k.zu)").font(.caption).lineLimit(2)
                        Stepper(value: bindung(k.v), in: 0...365, step: 1) {
                            Text(k.v.wartezeitTage > 0
                                 ? "\(zahl(k.v.wartezeitTage)) Tage warten"
                                 : "keine Wartezeit")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(k.v.wartezeitTage > 0 ? .orange : .secondary)
                        }

                        // 🔴 Ein BELEG schlägt den Katalog. Steht auf dem Sack 2 Tage,
                        // sagt der Mops nicht „bei mir stehen 3" — dann gelten 2.
                        // Gemeldet wird nur, wenn jemand UNTER einen Beleg geht.
                        lageZeile(k)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(item: $belegBearbeiten) { k in
            LiegezeitBelegView(
                kanteID: k.v.id?.uuidString ?? k.v.objectID.uriRepresentation().absoluteString,
                von: k.von, zu: k.zu, aktuelleTage: k.v.wartezeitTage
            ) { beleg in
                // Der Beleg setzt die Zahl auch an der Kante — eine Wahrheit.
                k.v.wartezeitTage = beleg.tage
                try? ctx.save()
                tick += 1
            }
        }
    }

    @ViewBuilder
    private func lageZeile(_ k: Kante) -> some View {
        let kid = k.v.id?.uuidString ?? k.v.objectID.uriRepresentation().absoluteString
        switch LiegezeitBuch.shared.lage(kanteID: kid,
                                          eingetragen: k.v.wartezeitTage,
                                          nachVorgaenger: k.von) {

        case .belegtUndEingehalten(let b):
            // Kein Hinweis, nur die Herkunft. Wer nachgesehen hat, soll das sehen.
            Label("\(zahl(b.tage)) Tage \(b.herkunft.kurz)"
                  + (b.quelle.isEmpty ? "" : " · \(b.quelle)"),
                  systemImage: "checkmark.seal")
                .font(.caption2).foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)

        case .unterschritten(let b):
            // 🔴 Der Fall, um den es Andreas geht: dokumentiert, mit Namen.
            VStack(alignment: .leading, spacing: 3) {
                Label("\(zahl(b.tage)) statt \(zahl(b.stattBelegTage ?? 0)) Tage — so entschieden",
                      systemImage: "signature")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                if !b.begruendung.isEmpty {
                    Text(b.begruendung).font(.caption2)
                }
                Text("\(b.von), \(b.am.formatted(.dateTime.day().month().year()))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .unterschrittenOhneGrund(let b, let jetzt):
            // Der Beleg sagt mehr, jemand hat gekürzt — und nichts dazu geschrieben.
            VStack(alignment: .leading, spacing: 4) {
                Label("\(zahl(jetzt)) Tage, belegt sind \(zahl(b.tage))",
                      systemImage: "exclamationmark.triangle")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                Text((b.quelle.isEmpty ? b.herkunft.kurz : b.quelle)
                     + " — wer kürzer plant, sollte dazuschreiben warum.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Grund eintragen") { belegBearbeiten = k }
                    .buttonStyle(.bordered).controlSize(.small)
            }

        case .nurRichtwert(let z):
            VStack(alignment: .leading, spacing: 4) {
                Label(z.satz, systemImage: "hourglass")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Text(z.katalog.hinweis).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(z.wasFehlt).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("\(zahl(z.katalog.tage)) Tage nehmen") {
                        k.v.wartezeitTage = z.katalog.tage
                        try? ctx.save(); tick += 1
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    Button("Woher die Zahl kommt") { belegBearbeiten = k }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }

        case .still:
            Button("Woher die Zahl kommt") { belegBearbeiten = k }
                .font(.caption2).buttonStyle(.borderless)
        }
    }

    private func bindung(_ v: Voraussetzung) -> Binding<Double> {
        Binding(
            get: { v.wartezeitTage },
            set: { neu in
                v.wartezeitTage = max(0, neu)
                try? ctx.save()
                tick += 1                 // Ansicht (Label) auffrischen
            }
        )
    }

    /// Die Abhängigkeits-Kanten innerhalb dieser Baustelle (Voraussetzung mit quelle).
    private var kanten: [Kante] {
        _ = tick                          // Neu-Berechnung nach dem Setzen anstoßen
        let ids = Set(jobs.map { $0.objectID })
        var out: [Kante] = []
        var gesehen = Set<NSManagedObjectID>()
        for j in jobs {
            let vs = (j.voraussetzungen as? Set<Voraussetzung>) ?? []
            for v in vs {
                guard let q = v.quelle, ids.contains(q.objectID), !gesehen.contains(v.objectID) else { continue }
                gesehen.insert(v.objectID)
                out.append(Kante(id: v.objectID, v: v,
                                 von: q.processingDetails ?? "—",
                                 zu: v.auftrag?.processingDetails ?? (j.processingDetails ?? "—")))
            }
        }
        return out.sorted { $0.von.localizedCompare($1.von) == .orderedAscending }
    }

    private func zahl(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }
}
