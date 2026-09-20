//
//  GAEBAnkunftsBerichtView.swift
//
//  Was nach einem GAEB-Import WIRKLICH in der Baustelle liegt — zurückgelesen, nicht
//  mitgezählt. Siehe `GAEBAnkunftsPruefung` für den Grund, warum es diesen Schirm gibt.
//
//  Der Bildschirm ist bewusst unfreundlich, wenn etwas fehlt: rote Kopfzeile, Fehlbetrag
//  in Euro, die teuerste Lücke zuerst. Ein Import, bei dem Preise verschwinden, darf sich
//  nicht anfühlen wie ein Import, der geklappt hat.
//

import SwiftUI

struct GAEBAnkunftsBerichtView: View {
    let bericht: GAEBAnkunftsPruefung.Bericht
    let dateiname: String
    @Environment(\.dismiss) private var dismiss

    private var eur: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }
    private func e(_ v: Double) -> String { (eur.string(from: NSNumber(value: v)) ?? "0,00") + " €" }

    var body: some View {
        NavigationStack {
            List {
                kopf

                Section("Was gelandet ist") {
                    zeile("Positionen übernommen", "\(bericht.positionen)",
                          symbol: "tray.and.arrow.down.fill", farbe: .secondary)
                    if bericht.preiseInDatei > 0 {
                        zeile("Preise in der Datei", "\(bericht.preiseInDatei)",
                              symbol: "doc.text", farbe: .secondary)
                        zeile("davon jetzt abrufbar", "\(bericht.preiseAbrufbar)",
                              symbol: bericht.vollstaendig ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                              farbe: bericht.vollstaendig ? .green : .red)
                    }
                    if bericht.ausKatalog > 0 {
                        zeile("aus dem Katalog gerechnet", "\(bericht.ausKatalog)",
                              symbol: "function", farbe: .blue)
                    }
                    if bericht.ohnePreis > 0 {
                        zeile("noch ohne Preis", "\(bericht.ohnePreis)",
                              symbol: "questionmark.circle", farbe: .orange)
                    }
                }

                if bericht.preiseInDatei > 0 {
                    Section("Summenprobe") {
                        zeile("in der Datei", e(bericht.summeInDatei),
                              symbol: "doc.text", farbe: .secondary)
                        zeile("in der Baustelle angekommen", e(bericht.summeAbrufbar),
                              symbol: "building.2", farbe: bericht.vollstaendig ? .green : .red)
                        if bericht.fehlbetrag > 0 {
                            zeile("fehlt", e(bericht.fehlbetrag),
                                  symbol: "minus.circle.fill", farbe: .red)
                        }
                    }
                }

                if !bericht.vermisst.isEmpty {
                    Section {
                        ForEach(bericht.vermisst) { v in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(v.posNr).font(.caption.monospaced()).foregroundStyle(.secondary)
                                    Text(v.bezeichnung).font(.subheadline).lineLimit(2)
                                    Spacer()
                                    Text(e(v.betrag)).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.red)
                                }
                                Text("\(e(v.preisInDatei)) je Einheit × \(v.menge.formatted()) — steht in der Datei, ist in der Baustelle nicht abrufbar")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Preise, die unterwegs verloren gingen")
                    } footer: {
                        Text("Diese Positionen haben in der Datei einen Einheitspreis, liefern aber "
                             + "beim Zurücklesen keinen. Solange das so ist, rechnet die Baustelle "
                             + "mit einer zu niedrigen Summe. Bitte melden — das ist ein Fehler im "
                             + "Import, nicht in deiner Datei.")
                    }
                }
            }
            .navigationTitle("Ankunfts-Bericht")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
        }
    }

    @ViewBuilder private var kopf: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: bericht.totalausfall ? "xmark.octagon.fill"
                      : (bericht.vollstaendig ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"))
                    .font(.largeTitle)
                    .foregroundStyle(bericht.totalausfall ? .red
                                     : (bericht.vollstaendig ? .green : .orange))
                VStack(alignment: .leading, spacing: 2) {
                    Text(ueberschrift).font(.headline)
                    Text(unterzeile).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var ueberschrift: String {
        if bericht.totalausfall { return "Kein einziger Preis angekommen" }
        if !bericht.vollstaendig { return "\(bericht.vermisst.count) Preise fehlen" }
        if bericht.preiseInDatei > 0 { return "Alle \(bericht.preiseInDatei) Preise sind da" }
        return "\(bericht.positionen) Positionen übernommen"
    }

    private var unterzeile: String {
        if bericht.totalausfall {
            return "\(bericht.preiseInDatei) Preise stehen in \(dateiname), in der Baustelle "
                 + "ist keiner abrufbar. Nicht weiterrechnen."
        }
        if !bericht.vollstaendig { return "Zurückgelesen aus \(dateiname) — es fehlt \(e(bericht.fehlbetrag))" }
        return "Zurückgelesen aus \(dateiname) — Soll und Ist stimmen überein"
    }

    private func zeile(_ titel: String, _ wert: String, symbol: String, farbe: Color) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(farbe).frame(width: 22)
            Text(titel)
            Spacer()
            Text(wert).font(.subheadline.weight(.semibold)).foregroundStyle(farbe == .secondary ? .primary : farbe)
        }
    }
}
