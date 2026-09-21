//
//  ArbeitspaketeVorschlagView.swift
//
//  Die Liste zum Durchsehen, bevor irgendetwas angelegt wird. Sie nimmt das Tippen ab,
//  nicht die Entscheidung.
//
//  Jede Zeile lässt sich abwählen und in der Dauer ändern. Eine geschätzte Dauer ist
//  als geschätzt markiert — dieselbe Regel wie im Hausplaner: man muss sehen, welche
//  Zahl gerechnet und welche geraten ist.
//

import SwiftUI
import CoreData

struct ArbeitspaketeVorschlagView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var event: Event

    @State private var vorschlaege: [Arbeitspakete.Vorschlag] = []
    @State private var kolonne = 2
    @State private var verketten = true

    private var gewaehlt: [Arbeitspakete.Vorschlag] { vorschlaege.filter(\.uebernehmen) }
    private var summeTage: Double { gewaehlt.reduce(0) { $0 + $1.dauerTage } }
    private var geschaetzte: Int { gewaehlt.filter(\.dauerIstGeschaetzt).count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Aus dem LV") {
                        Text("\(vorschlaege.reduce(0) { $0 + $1.anzahlPositionen }) Positionen")
                    }
                    LabeledContent("Vorgeschlagen") {
                        Text("\(gewaehlt.count) von \(vorschlaege.count) Paketen")
                            .fontWeight(.semibold)
                    }
                    Stepper("Kolonne: \(kolonne) \(kolonne == 1 ? "Mann" : "Leute")",
                            value: $kolonne, in: 1...12)
                        .onChange(of: kolonne) { _, _ in laden() }
                    Toggle("In dieser Reihenfolge verketten", isOn: $verketten)
                } footer: {
                    Text("Die Reihenfolge kommt aus den Titelnummern und folgt der DIN 276. "
                         + "Das ist ein Entwurf, kein Bauablauf: Gerüst gehört vor das Dach, "
                         + "Grundleitungen vor die Bodenplatte. Umhängen geht danach in der "
                         + "Auftragsansicht unter „Wartet auf“.")
                }

                Section {
                    ForEach($vorschlaege) { $v in
                        zeile($v)
                    }
                } header: {
                    HStack {
                        Text("Arbeitspakete")
                        Spacer()
                        Text("\(summeTage.formatted(.number.precision(.fractionLength(0...1)))) Tage")
                            .foregroundStyle(.orange).fontWeight(.bold)
                    }
                } footer: {
                    if geschaetzte > 0 {
                        Label("\(geschaetzte) Paket\(geschaetzte == 1 ? "" : "e") ohne "
                              + "Aufwandswerte — die Dauer ist dort geraten, nicht gerechnet.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Arbeitspakete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(gewaehlt.count) anlegen") { anlegen() }
                        .disabled(gewaehlt.isEmpty)
                }
            }
            .onAppear { if vorschlaege.isEmpty { laden() } }
        }
    }

    private func zeile(_ v: Binding<Arbeitspakete.Vorschlag>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle(isOn: v.uebernehmen) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(v.wrappedValue.titelNr)
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(v.wrappedValue.name).font(.body.weight(.semibold))
                        Text("\(v.wrappedValue.anzahlPositionen) Positionen · "
                             + v.wrappedValue.summe.formatted(.currency(code: "EUR")))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if v.wrappedValue.uebernehmen {
                HStack(spacing: 10) {
                    Stepper(value: v.dauerTage, in: 0.5...120, step: 0.5) {
                        HStack(spacing: 6) {
                            Text("\(v.wrappedValue.dauerTage.formatted(.number.precision(.fractionLength(0...1)))) Tage")
                                .font(.subheadline.monospacedDigit())
                            if v.wrappedValue.dauerIstGeschaetzt {
                                Text("geschätzt")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.orange.opacity(0.18), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .padding(.leading, 34)
            }
        }
        .padding(.vertical, 2)
    }

    private func laden() {
        vorschlaege = Arbeitspakete.vorschlagen(fuer: event, kolonne: kolonne)
    }

    private func anlegen() {
        Arbeitspakete.anlegen(vorschlaege, event: event, verketten: verketten, in: ctx)
        try? ctx.save()
        dismiss()
    }
}
