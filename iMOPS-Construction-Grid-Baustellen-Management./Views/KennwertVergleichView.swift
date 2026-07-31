import SwiftUI
import CoreData

/// Stellt das kalkulierte LV der Grobkostenschaetzung gegenueber — nur fuer die
/// Gewerke, die das LV abdeckt. Ersetzt den frueheren Knopf „Soll/Planer-Schaetzung
/// ansehen", der die Gesamtschaetzung fuers ganze Haus neben die LV-Summe stellte
/// und damit einen Vergleich nahelegte, den es nicht gibt.
///
/// Bewusst OHNE gut/schlecht-Faerbung: unter dem Kennwert zu liegen ist kein Erfolg,
/// es kann genauso heissen, dass etwas vergessen wurde. Die Ansicht zeigt die
/// Abweichung, das Urteil bleibt beim Menschen.
struct KennwertVergleichView: View {
    let event: Event

    private var ergebnis: KennwertVergleich.Ergebnis? {
        KennwertVergleich.berechne(fuer: event)
    }

    var body: some View {
        Group {
            if let e = ergebnis, !e.zeilen.isEmpty {
                inhalt(e)
            } else if ergebnis != nil {
                hinweis("Keine Überschneidung",
                        "Das LV deckt keine Gewerke ab, die die Schätzung kennt. Prüfe die Kostengruppen der Positionen.")
            } else {
                hinweis("Noch keine Schätzung",
                        "Im Planer ist für diese Baustelle nichts konfiguriert. Ohne Schätzung gibt es nichts zu vergleichen.")
            }
        }
        .navigationTitle("Gegen Kennwert prüfen")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Inhalt

    @ViewBuilder
    private func inhalt(_ e: KennwertVergleich.Ergebnis) -> some View {
        List {
            Section {
                zeile("Schätzung (dein Anteil)", e.sollGesamt, fett: false)
                zeile("Dein kalkuliertes LV", e.istGesamt, fett: false)
                Divider()
                HStack {
                    Text("Abweichung").font(.subheadline.bold())
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(e.abweichung.formatted(.currency(code: "EUR")))
                            .font(.subheadline.bold().monospacedDigit())
                        if let p = e.abweichungProzent {
                            Text(p.formatted(.percent.precision(.fractionLength(0...1))))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Summe")
            } footer: {
                Text("Verglichen wird nur, was dein LV abdeckt. Liegst du darunter, kann das gut kalkuliert heißen — oder dass etwas fehlt. Die Zahl beantwortet die Frage nicht, sie stellt sie.")
                    .font(.caption)
            }

            Section("Je Gewerk") {
                ForEach(e.zeilen) { z in
                    VStack(spacing: 4) {
                        HStack {
                            Text(z.topf).font(.subheadline)
                            Spacer()
                            Text(z.abweichung.formatted(.currency(code: "EUR")))
                                .font(.subheadline.monospacedDigit())
                        }
                        HStack {
                            Text("Schätzung \(z.soll.formatted(.currency(code: "EUR")))")
                            Spacer()
                            Text("LV \(z.ist.formatted(.currency(code: "EUR")))")
                        }
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            if !e.nichtAbgedeckt.isEmpty {
                Section {
                    Text(e.nichtAbgedeckt.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Nicht im LV — nicht mitgerechnet")
                } footer: {
                    Text("Diese Gewerke stecken in der Schätzung fürs ganze Haus, aber nicht in deinem LV. Sie bleiben draußen, sonst vergleichst du dein Angebot mit fremder Leistung.")
                        .font(.caption)
                }
            }

            Section {
                LabeledContent("Wohnfläche", value: "\(e.wohnflaeche.formatted(.number.precision(.fractionLength(0...1)))) m²")
                LabeledContent("Ausstattung", value: e.ausstattung)
                LabeledContent("Kennwert", value: "\(e.kennwertJeQm.formatted(.currency(code: "EUR")))/m²")
            } header: {
                Text("Grundlage der Schätzung")
            } footer: {
                Text("Der Kennwert ist ein Firmenwert aus den Einstellungen — **kein lizenzierter BKI-Wert**. Auch die Verteilung auf die Gewerke ist eine Faustformel. Der Vergleich taugt für die Größenordnung, nicht als Nachweis.")
                    .font(.caption)
            }
        }
    }

    private func zeile(_ titel: String, _ wert: Double, fett: Bool) -> some View {
        HStack {
            Text(titel).font(fett ? .subheadline.bold() : .subheadline)
            Spacer()
            Text(wert.formatted(.currency(code: "EUR")))
                .font((fett ? Font.subheadline.bold() : .subheadline).monospacedDigit())
        }
    }

    private func hinweis(_ titel: String, _ text: String) -> some View {
        ContentUnavailableView {
            Label(titel, systemImage: "pencil.and.ruler")
        } description: {
            Text(text)
        } actions: {
            NavigationLink {
                HouseConfiguratorView(spezielesEvent: event)
            } label: {
                Text("Planer öffnen")
            }
        }
    }
}
