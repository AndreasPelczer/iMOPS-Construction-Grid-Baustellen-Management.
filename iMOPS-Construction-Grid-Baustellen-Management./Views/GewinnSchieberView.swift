//
//  GewinnSchieberView.swift
//  „Wo verdient der Boss wirklich?" — die eine ehrliche Schraube.
//
//  Links stehen die Vollkosten (was die Mannstunde KOSTET — fest, gemessen).
//  In der Mitte der EINE Schieber: Wagnis & Gewinn. BGK, AGK und Skonto bleiben
//  fest, weil das eigentlich gemessene Kosten sind, keine Stellschraube.
//  Rechts das Ergebnis — der Verrechnungssatz (was der Betrieb VERLANGT) — und
//  daneben die 74-Orakel-Linie: der bekannt-wahre Satz, den die Rechnung treffen soll.
//
//  Schiebt man, bis die Nadel auf dem Orakel sitzt, hat man abgelesen, wie groß
//  der echte Gewinn-Aufschlag wirklich ist. Diese Zahl ist Firmensache — sie lebt
//  in den Einstellungen (UserDefaults), nie im Code.
//
//  Der alte 74-Fehler, sichtbar gemacht: der Lohn steigt NICHT. Fest bleibt, was
//  kostet; der Schieber bewegt nur, was verlangt wird.
//

import SwiftUI

struct GewinnSchieberView: View {

    // Die eine Schraube — schreibt denselben Firmenwert wie die Einstellungen.
    @AppStorage(FirmenSettings.Keys.wagnisGewinn) private var gewinn = 0.08

    // Fest (gemessene Kosten, hier nur zur Anzeige — geändert wird in den Einstellungen).
    @AppStorage(FirmenSettings.Keys.bgk)    private var bgk    = 0.12
    @AppStorage(FirmenSettings.Keys.agk)    private var agk    = 0.10
    @AppStorage(FirmenSettings.Keys.skonto) private var skonto = 0.025

    // Referenz-Vollkosten (was eine Mannstunde kostet) und das Orakel (Ziel-Satz).
    // 0 → generischer Vorgabewert. Die echten Firmenzahlen tippt der Chef hier ein.
    @AppStorage("firma_vollkosten_referenz")      private var vollkostenEingabe = 0.0
    @AppStorage("firma_verrechnungssatz_orakel")  private var orakel            = 74.0

    // MARK: - Rechnung

    /// Generische Vorgabe: Facharbeiter-Vollkosten (Brutto × Nebenkosten-Faktor).
    /// Öffentlicher Richtwert, keine Firmenzahl.
    private var referenzVollkosten: Double {
        let fa = LohnkalkulationDefaults.lohngruppen.first { $0.kuerzel == "LG3" }
            ?? LohnkalkulationDefaults.lohngruppen[0]
        return fa.vollkosten(nebenkostenFaktor: LohnkalkulationDefaults.nebenkostenFaktor)
    }

    private var vollkosten: Double { vollkostenEingabe > 0 ? vollkostenEingabe : referenzVollkosten }

    /// Der feste Teil der Kette (BGK · AGK · Skonto) — ohne Gewinn.
    private var festFaktor: Double { (1 + bgk) * (1 + agk) * (1 + skonto) }

    /// Was der Betrieb verlangt: Vollkosten × fester Aufschlag × (1 + Gewinn).
    private var verrechnungssatz: Double { vollkosten * festFaktor * (1 + gewinn) }

    /// Der gesamte, außen sichtbare Firmenzuschlag (fest + Gewinn), als EIN Prozentwert.
    private var firmenzuschlag: Double { festFaktor * (1 + gewinn) - 1 }

    private var luecke: Double { orakel - verrechnungssatz }
    private var passt: Bool { abs(luecke) < 0.5 }

    /// Welcher Gewinn träfe das Orakel exakt? (fester Teil herausgerechnet.)
    private var gewinnFuersOrakel: Double {
        let nenner = vollkosten * festFaktor
        return nenner > 0 ? max(0, orakel / nenner - 1) : 0
    }

    // MARK: - View

    var body: some View {
        Form {
            eingabeSection
            schraubeSection
            ergebnisSection
            aufschluesselungSection
        }
        .navigationTitle("Wo verdient der Boss?")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var eingabeSection: some View {
        Section {
            LabeledContent("Vollkosten je Stunde") {
                euroFeld($vollkostenEingabe, platzhalter: referenzVollkosten)
            }
            LabeledContent("Orakel (Ziel-Satz)") {
                euroFeld($orakel, platzhalter: 74)
            }
        } header: {
            Text("Fest — was gemessen ist")
        } footer: {
            Text("""
            Die Vollkosten sind, was die Mannstunde den Betrieb KOSTET (Brutto-Lohn × \
            Nebenkosten). Fest — hier wird nicht geschraubt. Leer = Richtwert \
            (\(euro(referenzVollkosten)), generischer Facharbeiter).

            Das Orakel ist der bekannt-wahre Verrechnungssatz, den die Rechnung treffen \
            soll — die Zahl aus der Praxis, gegen die wir prüfen.
            """)
            .font(.caption)
        }
    }

    private var schraubeSection: some View {
        Section {
            HStack {
                Text("Wagnis & Gewinn")
                Spacer()
                Text("\(Int((gewinn * 100).rounded())) %")
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(.orange)
            }
            Slider(value: $gewinn, in: 0...1.5, step: 0.01)
                .tint(.orange)

            Button {
                gewinn = (gewinnFuersOrakel * 100).rounded() / 100
            } label: {
                Label("Auf das Orakel einrasten (\(Int((gewinnFuersOrakel * 100).rounded())) %)",
                      systemImage: "scope")
            }
        } header: {
            Text("Die Schraube — Gewinn")
        } footer: {
            Text("""
            Die einzige echte Stellschraube. BGK, AGK und Skonto bleiben fest, weil das \
            gemessene Kosten sind, keine Entscheidung. Nach rechts steigt der \
            Verrechnungssatz, nach links sinkt er — der Lohn bleibt, wo er ist.
            """)
            .font(.caption)
        }
    }

    private var ergebnisSection: some View {
        Section {
            LabeledContent("Verrechnungssatz") {
                Text(euro(verrechnungssatz))
                    .font(.title3.monospacedDigit().bold())
                    .foregroundStyle(passt ? .green : .primary)
            }
            LabeledContent("Orakel") {
                Text(euro(orakel)).font(.body.monospacedDigit()).foregroundStyle(.secondary)
            }
            LabeledContent(luecke >= 0 ? "Lücke bis zum Orakel" : "über dem Orakel") {
                if passt {
                    Label("passt", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else {
                    Text("\(luecke >= 0 ? "+" : "")\(euro(luecke))")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Ergebnis — was der Betrieb verlangt")
        } footer: {
            Text(passt
                 ? "Die Nadel sitzt auf dem Orakel. Der abgelesene Gewinn ist der echte."
                 : "Schraube am Gewinn, bis die Lücke null ist — dann passt die Rechnung zur Praxis.")
            .font(.caption)
        }
    }

    private var aufschluesselungSection: some View {
        Section {
            zeile("Vollkosten (fest)", euro(vollkosten))
            zeile("BGK", prozent(bgk), grau: true)
            zeile("AGK", prozent(agk), grau: true)
            zeile("Skonto", prozent(skonto), grau: true)
            zeile("Wagnis & Gewinn", prozent(gewinn), farbe: .orange)
            Divider()
            zeile("Firmenzuschlag gesamt", prozent(firmenzuschlag), farbe: .orange, fett: true)
            zeile("= Verrechnungssatz", euro(verrechnungssatz), fett: true)
        } header: {
            Text("Intern — die Aufschlüsselung")
        } footer: {
            Text("""
            Das sieht nur der Betrieb. Nach außen ist all das EIN „Firmenzuschlag" von \
            \(prozent(firmenzuschlag)) — die Aufteilung ist Geschäftsgeheimnis. \
            Auf dem Angebot steht Selbstkosten + Firmenzuschlag, nicht wovon.
            """)
            .font(.caption)
        }
    }

    // MARK: - Bausteine

    private func euroFeld(_ wert: Binding<Double>, platzhalter: Double) -> some View {
        HStack(spacing: 4) {
            TextField(euro(platzhalter), value: wert,
                      format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 90)
            Text("€/h").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func zeile(_ titel: String, _ wert: String,
                       farbe: Color = .primary, grau: Bool = false, fett: Bool = false) -> some View {
        HStack {
            Text(titel).foregroundStyle(grau ? .secondary : .primary)
            Spacer()
            Text(wert)
                .font(fett ? .body.monospacedDigit().bold() : .body.monospacedDigit())
                .foregroundStyle(farbe)
        }
    }

    private func euro(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(2))) + " €"
    }
    private func prozent(_ v: Double) -> String {
        (v * 100).formatted(.number.precision(.fractionLength(1))) + " %"
    }
}

#Preview {
    NavigationStack { GewinnSchieberView() }
}
