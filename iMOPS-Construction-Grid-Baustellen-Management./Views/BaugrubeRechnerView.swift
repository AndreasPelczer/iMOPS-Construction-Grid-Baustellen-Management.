import SwiftUI

/// Baugruben-Aushub schätzen: Länge × Breite × Tiefe, optional Arbeitsraum + Böschung.
/// Für die Grube fürs Bauwerk (nicht die ganze Geländemodellierung).
struct BaugrubeRechnerView: View {
    @State private var laengeT = ""
    @State private var breiteT = ""
    @State private var tiefeT  = ""
    @State private var arbeitsraumT = "0,50"
    @State private var boeschung: Baugrube.Boeschung = .senkrecht

    private func zahl(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private var ergebnis: Baugrube.Ergebnis {
        Baugrube.aushub(laenge: zahl(laengeT), breite: zahl(breiteT), tiefe: zahl(tiefeT),
                        arbeitsraum: zahl(arbeitsraumT), boeschung: boeschung)
    }

    var body: some View {
        List {
            Section {
                feld("Länge", $laengeT, "m")
                feld("Breite", $breiteT, "m")
                feld("Aushubtiefe", $tiefeT, "m")
            } header: {
                Text("Bauwerk / Grube")
            } footer: {
                Text("Aushubtiefe = GOK (Geländehöhe) − Aushubsohle. Aushubsohle = OK Bodenplatte − "
                   + "Bodenaufbau (Bodenplatte + Sauberkeit + Frostschutz, grob 0,5–0,7 m). "
                   + "Beispiel Setiadji: OKFB 196,10 m → Aushubsohle ~195,5 m.")
            }

            Section {
                feld("Arbeitsraum (je Seite)", $arbeitsraumT, "m")
                Picker("Böschung", selection: $boeschung) {
                    ForEach(Baugrube.Boeschung.allCases) { b in Text(b.text).tag(b) }
                }
            } header: {
                Text("Zuschläge (DIN 4124)")
            } footer: {
                Text("Arbeitsraum: Platz zum Arbeiten rund um das Bauwerk (meist 0,50 m). "
                   + "Böschung: geneigte Wände brauchen mehr Aushub — senkrecht nur mit Verbau.")
            }

            Section {
                zeile("Grundfläche (Bauwerk)", "\(z(ergebnis.grundflaeche, 1)) m²")
                zeile("Sohlfläche (mit Arbeitsraum)", "\(z(ergebnis.sohleFlaeche, 1)) m²")
                if boeschung != .senkrecht {
                    zeile("Obere Fläche (mit Böschung)", "\(z(ergebnis.obenFlaeche, 1)) m²")
                }
                HStack {
                    Label("Aushub", systemImage: "arrow.up.bin").foregroundStyle(.orange)
                    Spacer()
                    Text("\(z(ergebnis.volumen, 0)) m³")
                        .font(.title2.bold().monospacedDigit()).foregroundStyle(.orange)
                }
            } header: {
                Text("Aushub (Schätzung)")
            } footer: {
                Text("Rechteckige Näherung, Böschung linear. Ehrlich eine Schätzung — für die "
                   + "Abrechnung misst der Vermesser. Der Aushub geht als Menge in Bagger/LKW.")
            }
            .listRowBackground(Color.orange.opacity(0.06))
        }
        .navigationTitle("Baugrube (Fläche × Tiefe)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func feld(_ label: String, _ text: Binding<String>, _ einheit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                #if !os(macOS)
                .keyboardType(.decimalPad)
                #endif
            Text(einheit).foregroundStyle(.secondary)
        }
    }

    private func zeile(_ label: String, _ wert: String) -> some View {
        HStack { Text(label); Spacer(); Text(wert).monospacedDigit().foregroundStyle(.secondary) }
    }

    private func z(_ d: Double, _ stellen: Int) -> String {
        d.formatted(.number.precision(.fractionLength(0...stellen)).grouping(.automatic))
    }
}
