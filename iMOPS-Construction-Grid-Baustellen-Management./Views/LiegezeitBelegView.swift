//
//  LiegezeitBelegView.swift
//
//  „Wenn auf dem Zement steht, er braucht 2 Tage, dann braucht er 2 Tage. Wenn der
//   Chef anders entscheidet, dann muss das doch dokumentiert werden."
//   (Andreas, 21.09.2026)
//
//  Hier wird beides eingetragen: woher die Zahl kommt — und, falls jemand darunter
//  geht, warum. Die Unterschreitung braucht Grund und Namen, sonst geht sie nicht.
//

import SwiftUI

struct LiegezeitBelegView: View {
    @Environment(\.dismiss) private var dismiss

    let kanteID: String
    let von: String
    let zu: String
    let aktuelleTage: Double
    /// Für die Dokumente dieser Baustelle.
    var event: Event?
    var gespeichert: (LiegezeitBeleg) -> Void = { _ in }

    @State private var tage: Double = 0
    @State private var herkunft: LiegezeitHerkunft = .datenblatt
    @State private var quelle = ""
    @State private var wer = ""
    @State private var begruendung = ""
    @State private var geladen = false
    @State private var gefunden = LiegezeitSucher.Ergebnis()
    @State private var suchtImFundus = false

    /// Der vorhandene Beleg — gegen den wird gemessen, ob jemand darunter geht.
    private var bestehend: LiegezeitBeleg? { LiegezeitBuch.shared.beleg(fuer: kanteID) }

    /// 🔴 Geht die eingetragene Zeit unter einen BELEGTEN Wert?
    private var unterschreitetBeleg: Double? {
        guard let b = bestehend, b.herkunft.istBelegt, aktuelleTage < b.tage else { return nil }
        return b.tage
    }

    private var kannSpeichern: Bool {
        if herkunft.brauchtNamen && wer.trimmingCharacters(in: .whitespaces).isEmpty { return false }
        // Wer unter einen Beleg geht, braucht einen Grund. Ohne den geht es nicht —
        // das ist die eine Stelle, an der der Mops wirklich etwas verlangt.
        if unterschreitetBeleg != nil
            && begruendung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(von)  →  \(zu)").font(.subheadline)
                } header: {
                    Text("Zwischen diesen beiden")
                }

                // 🔴 „wenn eine Auswahl besteht, entscheidet der Mensch." Der Mops
                // trägt zusammen, sortiert nach Nähe zu DIESER Baustelle — und sagt,
                // wenn die Quellen sich widersprechen, statt heimlich die erste zu nehmen.
                Section {
                    if gefunden.kandidaten.isEmpty && !suchtImFundus {
                        Text("Keine belegte Zahl gefunden.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(gefunden.kandidaten) { k in
                        Button {
                            tage = k.tage
                            herkunft = k.herkunft
                            quelle = k.quelle
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: tage == k.tage && quelle == k.quelle
                                      ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("\(kurz(k.tage)) Tage").font(.body.weight(.semibold))
                                        Text(k.herkunft.kurz)
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 6).padding(.vertical, 2)
                                            .background(k.herkunft.istBelegt
                                                        ? Color.green.opacity(0.16)
                                                        : Color.gray.opacity(0.16),
                                                        in: Capsule())
                                            .foregroundStyle(k.herkunft.istBelegt ? .green : .secondary)
                                    }
                                    if !k.quelle.isEmpty {
                                        Text(k.quelle).font(.caption).foregroundStyle(.secondary)
                                    }
                                    if !k.hinweis.isEmpty {
                                        Text(k.hinweis).font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if suchtImFundus {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Der Mops fragt seinen Fundus…")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await fundusFragen() }
                        } label: {
                            Label("Den Fundus fragen", systemImage: "questionmark.bubble")
                                .font(.subheadline)
                        }
                    }
                    if let fehler = gefunden.fundusFehler {
                        Text("Fundus nicht erreichbar: \(fehler)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Was der Mops gefunden hat")
                } footer: {
                    if gefunden.widersprechenSich {
                        Label(gefunden.satz, systemImage: "exclamationmark.triangle")
                            .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                    } else if !gefunden.kandidaten.isEmpty {
                        Text(gefunden.satz)
                    }
                }

                Section {
                    Stepper(value: $tage, in: 0...365, step: 0.5) {
                        Text(tage > 0 ? "\(kurz(tage)) Tage" : "keine Wartezeit")
                            .font(.body.monospacedDigit())
                    }
                    Picker("Woher", selection: $herkunft) {
                        ForEach(LiegezeitHerkunft.allCases, id: \.self) { h in
                            Text(h.kurz).tag(h)
                        }
                    }
                    if herkunft != .katalog {
                        TextField(herkunft == .datenblatt
                                  ? "z. B. CEM I 42,5 R, Merkblatt S. 2"
                                  : herkunft == .statiker ? "z. B. Statik Pos. 4.3"
                                  : "worauf stützt sich das?",
                                  text: $quelle)
                    }
                } header: {
                    Text("Die Zahl und ihre Herkunft")
                } footer: {
                    if herkunft.istBelegt {
                        Text("Belegt heisst: da hat jemand nachgesehen. Der Richtwert des "
                             + "Mops schweigt dann — deine Zahl gilt.")
                    }
                }

                if let belegt = unterschreitetBeleg {
                    Section {
                        Label("Belegt sind \(kurz(belegt)) Tage, eingetragen \(kurz(aktuelleTage)).",
                              systemImage: "signature")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        TextField("Warum geht es kürzer?", text: $begruendung, axis: .vertical)
                            .lineLimit(2...5)
                    } header: {
                        Text("Das ist eine Entscheidung")
                    } footer: {
                        Text("Sie bleibt an dieser Verbindung stehen, mit Namen und Datum. "
                             + "Nicht als Vorwurf — als Nachweis, dass jemand es gewusst "
                             + "und entschieden hat.")
                    }
                }

                Section {
                    TextField("Dein Name", text: $wer)
                }
            }
            .navigationTitle("Woher die Zahl kommt")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard !geladen else { return }
                geladen = true
                tage = aktuelleTage
                if let b = bestehend, !b.istUnterschreitung {
                    herkunft = b.herkunft; quelle = b.quelle; wer = b.von
                }
                // Dokumente und Katalog sofort — der Fundus nur auf Knopfdruck,
                // er kostet bis zu drei Minuten.
                Task {
                    gefunden = await LiegezeitSucher.suche(nach: von, event: event,
                                                            mitFundus: false)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merken") { merken() }.disabled(!kannSpeichern)
                }
            }
        }
    }

    private func merken() {
        var b = LiegezeitBeleg(
            id: kanteID,
            tage: tage,
            herkunft: unterschreitetBeleg != nil ? .entschieden : herkunft,
            quelle: quelle.trimmingCharacters(in: .whitespacesAndNewlines),
            von: wer.trimmingCharacters(in: .whitespaces))
        if let belegt = unterschreitetBeleg {
            b.stattBelegTage = belegt
            b.begruendung = begruendung.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        LiegezeitBuch.shared.merken(b)
        gespeichert(b)
        dismiss()
    }

    private func fundusFragen() async {
        suchtImFundus = true
        defer { suchtImFundus = false }
        gefunden = await LiegezeitSucher.suche(nach: von, event: event, mitFundus: true)
    }

    private func kurz(_ w: Double) -> String {
        w == w.rounded() ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
