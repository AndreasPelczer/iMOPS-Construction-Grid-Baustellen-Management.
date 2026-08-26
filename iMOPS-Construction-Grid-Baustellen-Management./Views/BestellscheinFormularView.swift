import SwiftUI
import CoreData
import MessageUI

/// Der Schritt vor der Mail: was auf dem Schein anzukreuzen ist.
///
/// Bewusst ein eigener Schritt statt Vorbelegung im Hintergrund — Kran und
/// Zeitfenster kosten Geld und Wartezeit, das soll jemand bewusst setzen.
struct BestellscheinFormularView: View {
    @Environment(\.dismiss) private var dismiss

    let event: Event
    let positionen: [LVPosition]

    @State private var angaben = BestellscheinAngaben()
    @State private var zeigeMail = false
    @State private var mailNichtVerfuegbar = false

    /// Eine Zeile, wie sie auf dem Zettel landet — nach Hand.
    ///
    /// Der Rechner schlägt vor, entschieden wird hier: Mengen lassen sich anpassen
    /// (Restbestand auf der Baustelle, angebrochene Palette) und Zeilen ganz
    /// abwählen. Was rausgeht, hat jemand gesehen.
    struct Posten: Identifiable {
        let basis: BestellscheinService.Zeile
        var menge: Double
        var dabei: Bool
        var id: String { basis.materialNr }

        var abweichend: Bool { abs(menge - basis.bestellmenge) > 0.005 }
    }

    @State private var posten: [Posten] = []
    @State private var ohneNummer: [LVPosition] = []
    @State private var geladen = false

    private var summe: Double {
        posten.filter(\.dabei).reduce(0) { $0 + $1.menge }
    }
    private var anzahlDabei: Int { posten.filter(\.dabei).count }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    zeile("Bauvorhaben", event.title ?? "—")
                    if let nr = event.eventNumber, !nr.isEmpty { zeile("BVH-Nr.", nr) }
                    if let bh = event.bauherr, !bh.isEmpty { zeile("Bauherr", bh) }
                    if let ort = event.location, !ort.isEmpty { zeile("Ort", ort) }
                } header: {
                    Text("Aus der Baustelle")
                } footer: {
                    Text("Diese Angaben übernimmt die App. Ändern lassen sie sich in der Baustelle.")
                }

                Section("Ergänzen") {
                    TextField("Straße", text: $angaben.strasse)
                    TextField("PLZ / Ort", text: $angaben.plzOrt)
                    TextField("Objekt-Nr. (Xella)", text: $angaben.objektNr)
                    TextField("Baustoffhandel", text: $angaben.baustoffhandel)
                }

                Section {
                    Picker("Lieferart", selection: $angaben.lieferart) {
                        ForEach(BestellscheinAngaben.Lieferart.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Mit Kran", isOn: $angaben.mitKran)
                    Picker("Zeitfenster", selection: $angaben.zeitfenster) {
                        ForEach(BestellscheinAngaben.Zeitfenster.allCases) { Text($0.rawValue).tag($0) }
                    }
                    DatePicker("Wunschtermin", selection: $angaben.wunschtermin, displayedComponents: .date)
                } header: {
                    Text("Lieferung")
                } footer: {
                    if angaben.vorlaufKnapp {
                        Label("Der Schein nennt mindestens 3 Werktage Vorlauf.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Bemerkung") {
                    TextField("optional", text: $angaben.bemerkung, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    ForEach($posten) { $p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Toggle(isOn: $p.dabei) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.basis.materialNr)
                                            .font(.system(.subheadline, design: .monospaced))
                                        Text(p.basis.bezeichnung)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if p.dabei {
                                HStack {
                                    Text("Menge").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    TextField("m³", value: $p.menge, format: .number.precision(.fractionLength(2)))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 90)
                                    Text("m³").font(.caption).foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    if p.abweichend {
                                        Label("Vorschlag war \(p.basis.bestellmenge.alsText) m³",
                                              systemImage: "pencil")
                                            .foregroundStyle(.orange)
                                    } else if p.basis.zuschlagProzent > 0 {
                                        Text("LV \(p.basis.mengeLV.alsText) m³ + "
                                             + "\(Int(p.basis.zuschlagProzent)) % Eck-/Laibungssteine")
                                    } else {
                                        Text("\(p.basis.positionen) LV-Position"
                                             + (p.basis.positionen == 1 ? "" : "en"))
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    HStack {
                        Text("Was bestellt wird")
                        Spacer()
                        Text("\(anzahlDabei) × · \(summe.alsText) m³")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mengen lassen sich anpassen — etwa wegen Restbestand auf der "
                             + "Baustelle. Geänderte Zeilen sind im PDF gekennzeichnet.")
                        if !ohneNummer.isEmpty {
                            Label("\(ohneNummer.count) Position(en) ohne Material-Nummer stehen "
                                  + "im PDF unter \u{201C}nicht über diesen Schein bestellbar\u{201D}.",
                                  systemImage: "questionmark.circle")
                        }
                    }
                }
            }
            .onAppear {
                guard !geladen else { return }
                let b = BestellscheinService.zeilen(aus: positionen)
                posten = b.zeilen.map { Posten(basis: $0, menge: $0.bestellmenge, dabei: true) }
                ohneNummer = b.ohneNummer
                geladen = true
            }
            .navigationTitle("Bestellschein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mail erstellen") {
                        if MFMailComposeViewController.canSendMail() { zeigeMail = true }
                        else { mailNichtVerfuegbar = true }
                    }
                    .disabled(anzahlDabei == 0)
                }
            }
            .fullScreenCover(isPresented: $zeigeMail) {
                BestellscheinMailView(event: event,
                                      zeilen: posten.filter(\.dabei).map {
                                          BestellscheinService.Zeile(
                                              materialNr: $0.basis.materialNr,
                                              bezeichnung: $0.basis.bezeichnung,
                                              mengeLV: $0.basis.mengeLV,
                                              zuschlagProzent: $0.basis.zuschlagProzent,
                                              bestellmengeManuell: $0.abweichend ? $0.menge : nil,
                                              positionen: $0.basis.positionen)
                                      },
                                      ohneNummer: ohneNummer,
                                      angaben: angaben) {
                    zeigeMail = false
                    dismiss()
                }
                .ignoresSafeArea()
            }
            .alert("Kein Mail-Konto eingerichtet", isPresented: $mailNichtVerfuegbar) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Auf diesem Gerät ist kein Mail-Konto hinterlegt. "
                     + "Richte eines in den Einstellungen ein oder verschicke das PDF anders.")
            }
        }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel)
            Spacer()
            Text(wert).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
    }
}


private extension Double {
    var alsText: String {
        let nf = NumberFormatter()
        nf.minimumFractionDigits = 2; nf.maximumFractionDigits = 2; nf.decimalSeparator = ","
        return nf.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
