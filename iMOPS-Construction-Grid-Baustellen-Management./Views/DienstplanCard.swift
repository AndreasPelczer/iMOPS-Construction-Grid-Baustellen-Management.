import SwiftUI
import CoreData

// MARK: - DienstplanCard (wer macht was, wann)
//
// Der dritte Teil neben Terminplan (WANN läuft eine Aufgabe) und BrigadePlanung
// (WIE VIELE Leute): hier wird sichtbar, WELCHER Mensch WELCHE Aufgabe macht — und
// dank dem Netzplan-Motor auch WANN (früheste Tage). Gruppiert die Aufträge dieser
// Baustelle nach zugewiesenem Mitarbeiter (`employeeName`); „Nicht zugewiesen" steht
// oben, damit offene Arbeit auffällt.
//
// Nutzt, was schon da ist: die Zuordnung (Auftrag.employeeName) und den Terminplan
// (Bauablauf.terminplan). Kein neues Datenmodell.
struct DienstplanCard: View {
    let jobs: [Auftrag]

    @State private var termine: [String: AblaufTermin] = [:]

    private struct Gruppe: Identifiable {
        let id: String          // Mitarbeitername (oder "—")
        let name: String
        let zugewiesen: Bool
        let jobs: [Auftrag]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dienstplan", systemImage: "person.2.badge.gearshape").font(.headline)

            if jobs.isEmpty {
                Text("Noch keine Aufträge auf dieser Baustelle.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(gruppen) { g in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: g.zugewiesen ? "person.fill" : "person.fill.questionmark")
                                .foregroundStyle(g.zugewiesen ? .orange : .secondary)
                            Text(g.name).font(.subheadline.weight(.semibold))
                                .foregroundStyle(g.zugewiesen ? .primary : .secondary)
                            Spacer()
                            Text("\(g.jobs.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ForEach(g.jobs, id: \.objectID) { j in jobZeile(j) }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(g.zugewiesen ? Color(.tertiarySystemBackground) : Color.orange.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: jobs.count) {
            let e = Bauablauf.terminplan(fuer: jobs)
            termine = Dictionary(uniqueKeysWithValues: e.termine.map { ($0.knotenID, $0) })
        }
    }

    private func jobZeile(_ j: Auftrag) -> some View {
        let key = j.objectID.uriRepresentation().absoluteString
        let t = termine[key]
        return HStack(spacing: 8) {
            Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.secondary)
            Text(j.processingDetails ?? "—").font(.caption).lineLimit(1)
            Spacer(minLength: 6)
            if let t, t.fruehestesEndeTag > t.fruehesterStartTag {
                Text("Tag \(tag(t.fruehesterStartTag))–\(tag(t.fruehestesEndeTag))")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private func tag(_ d: Double) -> String { d.formatted(.number.precision(.fractionLength(0...1))) }

    private var gruppen: [Gruppe] {
        let byName = Dictionary(grouping: jobs) { (j: Auftrag) -> String in
            let n = (j.employeeName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return n.isEmpty ? "" : n
        }
        return byName.map { name, js in
            Gruppe(id: name.isEmpty ? "—" : name,
                   name: name.isEmpty ? "Nicht zugewiesen" : name,
                   zugewiesen: !name.isEmpty,
                   jobs: js)
        }
        .sorted { a, b in
            if a.zugewiesen != b.zugewiesen { return !a.zugewiesen }   // Nicht zugewiesen oben
            return a.name.localizedCompare(b.name) == .orderedAscending
        }
    }
}
