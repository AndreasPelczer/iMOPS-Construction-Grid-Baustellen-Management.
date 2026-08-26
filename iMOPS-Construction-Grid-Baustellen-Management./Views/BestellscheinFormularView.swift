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

    private var berechnet: (zeilen: [BestellscheinService.Zeile], ohneNummer: [LVPosition]) {
        BestellscheinService.zeilen(aus: positionen)
    }

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
                    let b = berechnet
                    zeile("Positionen", "\(b.zeilen.count)")
                    zeile("Gesamtmenge",
                          String(format: "%.2f m³", b.zeilen.reduce(0) { $0 + $1.bestellmenge })
                            .replacingOccurrences(of: ".", with: ","))
                    if !b.ohneNummer.isEmpty {
                        Label("\(b.ohneNummer.count) Position(en) ohne Material-Nummer — "
                              + "sie stehen im PDF, zählen aber nicht mit.",
                              systemImage: "questionmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Was bestellt wird")
                }
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
                    .disabled(berechnet.zeilen.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $zeigeMail) {
                BestellscheinMailView(event: event, positionen: positionen, angaben: angaben) {
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
