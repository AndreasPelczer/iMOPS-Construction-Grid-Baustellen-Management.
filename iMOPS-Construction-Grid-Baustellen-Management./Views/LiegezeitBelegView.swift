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
    var gespeichert: (LiegezeitBeleg) -> Void = { _ in }

    @State private var tage: Double = 0
    @State private var herkunft: LiegezeitHerkunft = .datenblatt
    @State private var quelle = ""
    @State private var wer = ""
    @State private var begruendung = ""
    @State private var geladen = false

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

    private func kurz(_ w: Double) -> String {
        w == w.rounded() ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }
}
