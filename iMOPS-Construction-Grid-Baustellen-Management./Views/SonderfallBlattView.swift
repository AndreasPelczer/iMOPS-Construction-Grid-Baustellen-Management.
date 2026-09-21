//
//  SonderfallBlattView.swift
//
//  „Das ist hier anders" — Andreas' „jaaa, des musst du so sehen"-Knopf.
//
//  Kein Formular, keine Pflichtfelder ausser dem einen Satz, um den es geht.
//  Wer mitten in der Arbeit etwas erklärt, hat keine Lust auf eine Maske.
//

import SwiftUI

struct SonderfallBlattView: View {
    @Environment(\.dismiss) private var dismiss

    let thema: String
    let wasDerMopsSagte: String
    let baustelle: String
    let betrifft: String
    /// Wird mit dem eingetragenen Fall gerufen — die aufrufende Ansicht entscheidet,
    /// was sie damit tut (meist: Meldung verstummen lassen).
    var fertig: (Sonderfall) -> Void = { _ in }

    @State private var wasGilt = ""
    @State private var wer = ""
    @State private var nurHier = true

    private var kannSpeichern: Bool {
        !wasGilt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !wer.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Wie oft wurde das schon erklärt? Steht VOR dem Speichern da — wer zum dritten
    /// Mal dasselbe schreibt, soll das sehen, bevor er es tut.
    private var bisher: Int { SonderfallBuch.shared.anzahl(thema: thema) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(wasDerMopsSagte)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Der Mops sagt")
                }

                Section {
                    TextField("Zum Beispiel: läuft über den Pauschalposten in Titel 1",
                              text: $wasGilt, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Was gilt hier stattdessen?")
                }

                Section {
                    TextField("Dein Name", text: $wer)
                    Picker("Gilt", selection: $nurHier) {
                        Text("nur hier").tag(true)
                        Text("immer").tag(false)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(nurHier
                         ? "Der Mops schweigt dazu auf dieser Baustelle, bei diesem Ding."
                         : "Der Mops schweigt dazu überall. Nimm das nur, wenn es wirklich "
                           + "immer so ist.")
                }

                if bisher >= SonderfallBuch.regelSchwelle - 1 {
                    Section {
                        Label(bisher + 1 >= SonderfallBuch.regelSchwelle
                              ? "Das erklärst du dem Mops zum \(bisher + 1). Mal."
                              : "Das hast du schon \(bisher)× erklärt.",
                              systemImage: "repeat")
                            .font(.subheadline.weight(.semibold))
                        Text("Was dreimal vorkommt, ist keine Ausnahme mehr — da fehlt "
                             + "eine Regel. Der Mops legt es auf den Stapel: das sollte "
                             + "er können.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Das ist hier anders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Merken") {
                        let fall = Sonderfall(
                            thema: thema,
                            wasDerMopsSagte: wasDerMopsSagte,
                            wasGilt: wasGilt.trimmingCharacters(in: .whitespacesAndNewlines),
                            baustelle: baustelle,
                            betrifft: betrifft,
                            von: wer.trimmingCharacters(in: .whitespaces),
                            nurHier: nurHier)
                        SonderfallBuch.shared.eintragen(fall)
                        fertig(fall)
                        dismiss()
                    }
                    .disabled(!kannSpeichern)
                }
            }
        }
    }
}

// MARK: - Die Liste: was der Mops können sollte

/// Themen, die oft genug erklärt wurden, um eine Regel zu verdienen.
/// 🔴 Der Mops baut die Regel NICHT selbst — er sammelt nur den Beleg dafür,
/// dass eine fehlt. Was daraus wird, entscheidet ein Mensch.
struct SonderfaelleView: View {
    @State private var stand = UUID()

    var body: some View {
        List {
            let reif = SonderfallBuch.shared.reifeThemen()
            if !reif.isEmpty {
                Section {
                    ForEach(reif, id: \.thema) { eintrag in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(eintrag.thema).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(eintrag.anzahl)×")
                                    .font(.caption.weight(.bold)).foregroundStyle(.orange)
                            }
                            Text(eintrag.letzte.wasGilt)
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Das sollte der Mops können")
                } footer: {
                    Text("Dreimal oder öfter erklärt — das ist keine Ausnahme mehr, "
                         + "sondern eine Regel, die fehlt.")
                }
            }

            Section {
                ForEach(SonderfallBuch.shared.alle) { f in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(f.wasGilt).font(.subheadline)
                        Text("\(f.betrifft) · \(f.baustelle)")
                            .font(.caption).foregroundStyle(.secondary)
                        let wann = f.am.formatted(.dateTime.day().month().year())
                        Text("\(f.von), \(wann)" + (f.nurHier ? "" : " · gilt immer"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Alles Erklärte")
            }
        }
        .navigationTitle("Sonderfälle")
        .id(stand)
        .refreshable { stand = UUID() }
    }
}
