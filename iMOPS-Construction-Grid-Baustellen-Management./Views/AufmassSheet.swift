import SwiftUI
import CoreData

// Welle 5.2 — Aufmaß-Verwaltung pro LV-Position. Geöffnet über eine Leading-Swipe-
// Aktion (wie LVFortschrittSheet), kein eigenes Detail-View-Paradigma (Kap 2/11).
// Zeigt Soll/Ist-Karte + Aufmaß-Liste + „+ neues Aufmaß".
struct AufmassSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var position: LVPosition

    @State private var zeigeNeuesAufmass = false
    @State private var showHelp = false // NEU: Für den Hilfe-Button

    var body: some View {
        NavigationStack {
            List {
                Section { sollIstKarte }

                Section {
                    if position.aufmassArray.isEmpty {
                        Text("Noch kein Aufmaß erfasst.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        ForEach(position.aufmassArray, id: \.objectID) { a in
                            AufmassRowView(aufmass: a)
                        }
                    }
                } header: {
                    Text("Aufmaße (\(position.aufmassArray.count))")
                }
            }
            .navigationTitle("Aufmaß")
            .navigationBarTitleDisplayMode(.inline)
            // NEU: Nur EINE Toolbar mit beiden Buttons
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .tint(.orange)
                }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button { zeigeNeuesAufmass = true } label: {
                    Label("Neues Aufmaß", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .padding()
            }
            .sheet(isPresented: $zeigeNeuesAufmass) {
                NeuesAufmassSheet(position: position)
                    .environment(\.managedObjectContext, viewContext)
            }
            // NEU: Das Sheet für die Hilfe
            .sheet(isPresented: $showHelp) {
                AufmassHelpView()
            }
        }
    }
    
    struct AufmassHelpView: View {
        @Environment(\.dismiss) var dismiss
        var body: some View {
            NavigationStack {
                List {
                    Section("Wozu dient das Aufmaß?") {
                        Text("Hier vergleicht Raffi die geplante Menge (SOLL) mit der echten, gemessenen Menge (IST) auf der Baustelle.")
                    }
                    Section("Die Ampel") {
                        Label("Grün: Abweichung unter 5%", systemImage: "circle.fill").foregroundStyle(.green)
                        Label("Orange: Abweichung 5-15%", systemImage: "circle.fill").foregroundStyle(.orange)
                        Label("Rot: Abweichung über 15% (Mehr- oder Mindermenge)", systemImage: "circle.fill").foregroundStyle(.red)
                    }
                }
                .navigationTitle("Hilfe: Aufmaß")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
            }
        }
    }

    // MARK: - Soll/Ist-Karte

    private var sollIstKarte: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(position.bezeichnung ?? "–").font(.headline).lineLimit(2)
                Spacer()
                if position.istGeschaetzt {
                    PhilosophieTooltip(
                        buchKapitel: "Buch Kap 6",
                        text: "Geschätzt, noch nicht gemessen. Damit du den Unterschied siehst, ohne nachfragen zu müssen."
                    )
                }
            }
            HStack(alignment: .top) {
                wert("SOLL", position.sollMenge)
                Spacer()
                wert("IST", position.istMengeSumme)
            }
            HStack(spacing: 8) {
                Text("ABWEICHUNG").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(abweichungText)
                    .font(.callout.monospacedDigit())
                Circle().fill(position.aufmassAmpel.farbe).frame(width: 12, height: 12)
            }
        }
        .padding(.vertical, 4)
    }

    private func wert(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(value.formatted(.number.precision(.fractionLength(0...2)))) \(position.einheit ?? "")")
                .font(.title3.monospacedDigit().weight(.semibold))
        }
    }

    private var abweichungText: String {
        let menge = position.abweichung.formatted(.number.precision(.fractionLength(0...2)))
        let proz  = (position.abweichungProzent * 100).formatted(.number.precision(.fractionLength(0...1)))
        return "\(menge) \(position.einheit ?? "") (\(proz) %)"
    }
}

// Farb-Mapping der Ampel — SwiftUI-Schicht, damit das Modell UI-agnostisch bleibt.
extension AufmassAmpel {
    var farbe: Color {
        switch self {
        case .keinAufmass: return .gray
        case .gruen:       return .green
        case .orange:      return .orange
        case .rot:         return .red
        }
    }
}
