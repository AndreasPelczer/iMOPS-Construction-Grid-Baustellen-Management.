//
//  FirmenprofilUebersichtView.swift
//  C: Goldschmitt vs. Mops auf einen Blick — Selbstkosten UND Rechnung nebeneinander.
//
//  Die Seite macht den Selbstkostenpreis SICHTBAR (Lohn+Material+Geräte = was es kostet)
//  und zeigt darüber, wie jede Firma daraus eine Rechnung macht:
//   • Goldschmitt: Lohn über den Verrechnungssatz (Orakel, 74 €/h) — der Boss verdient hier.
//   • Mops: die Echtzahl — Selbstkosten + transparente Zuschläge je Kostenart.
//  Gleiche Arbeit, ehrlicher Weg ist günstiger. Alles aus einem editierbaren Beispiel,
//  keine erfundenen Zahlen — die Sätze kommen aus Firmenprofil + Firmen-Zuschlägen.
//

import SwiftUI
import CoreData

struct FirmenprofilUebersichtView: View {
    @Environment(\.managedObjectContext) private var ctx
    @AppStorage(Firmenprofil.defaultsKey) private var aktivRaw = Firmenprofil.goldschmitt.rawValue

    // Editierbares Beispiel (bleibt erhalten).
    @AppStorage("uebersicht_stunden")  private var stunden = 20.0
    @AppStorage("uebersicht_material") private var materialEUR = 200.0
    @AppStorage("uebersicht_geraete")  private var geraeteEUR = 100.0
    // Goldschmitts Verrechnungssatz = das Orakel aus dem Gewinn-Schieber.
    @AppStorage("firma_verrechnungssatz_orakel") private var orakel = 74.0

    private var aktiv: Firmenprofil { Firmenprofil(rawValue: aktivRaw) ?? .goldschmitt }

    // Lohn-KOSTEN je Stunde (Vollkosten aus dem Firmenprofil).
    private var lohnKostenGold: Double { Firmenprofil.goldschmitt.satz(fuer: .facharbeiter, in: ctx) }
    private var lohnKostenMops: Double { Firmenprofil.mops.satz(fuer: .facharbeiter, in: ctx) }
    private var zM: Double { FirmenSettings.zuschlagMaterial }
    private var zG: Double { FirmenSettings.zuschlagGeraet }
    private var zL: Double { FirmenSettings.zuschlagLohn }

    // Selbstkosten je Spalte.
    private var selbstkostenGold: Double { stunden * lohnKostenGold + materialEUR + geraeteEUR }
    private var selbstkostenMops: Double { stunden * lohnKostenMops + materialEUR + geraeteEUR }
    // Rechnung je Spalte.
    private var lohnRechnungGold: Double { stunden * orakel }                     // Verrechnungssatz
    private var lohnRechnungMops: Double { stunden * lohnKostenMops * (1 + zL) }   // Kosten + ehrlicher Zuschlag
    private var rechnungGold: Double { lohnRechnungGold + materialEUR * (1 + zM) + geraeteEUR * (1 + zG) }
    private var rechnungMops: Double { lohnRechnungMops + materialEUR * (1 + zM) + geraeteEUR * (1 + zG) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kopf
                basis
                tabelle
                fazit
                fussnote
            }
            .padding()
        }
        .navigationTitle("Goldschmitt vs. Mops")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Kopf

    private var kopf: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Was kostet die Arbeit — und was steht in der Rechnung. Links wie Goldschmitt abrechnet (Verrechnungssatz \(euro(orakel))/h für den Lohn), rechts die Echtzahl vom Mops (Selbstkosten + transparente Zuschläge).")
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Beispiel-Basis (editierbar)

    private var basis: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Beispiel").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            feld("Facharbeiter-Stunden", wert: $stunden, einheit: "h")
            feld("Material", wert: $materialEUR, einheit: "€")
            feld("Geräte", wert: $geraeteEUR, einheit: "€")
        }
        .padding().background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func feld(_ titel: String, wert: Binding<Double>, einheit: String) -> some View {
        HStack {
            Text(titel).font(.subheadline)
            Spacer()
            TextField("", value: wert, format: .number)
                .frame(width: 90).multilineTextAlignment(.trailing)
                #if !os(macOS)
                .keyboardType(.decimalPad)
                #endif
            Text(einheit).foregroundStyle(.secondary)
        }
    }

    // MARK: - Zwei-Spalten-Tabelle

    private var tabelle: some View {
        VStack(spacing: 0) {
            spalteKopf
            gruppe("Selbstkosten — was es KOSTET") {
                zeile("Lohn (\(fmt(stunden)) h)", stunden * lohnKostenGold, stunden * lohnKostenMops,
                      unter: "\(euro(lohnKostenGold))/h", "\(euro(lohnKostenMops))/h")
                zeile("Material", materialEUR, materialEUR)
                zeile("Geräte", geraeteEUR, geraeteEUR)
                summeZeile("Selbstkosten", selbstkostenGold, selbstkostenMops)
            }
            gruppe("Rechnung — was der Kunde ZAHLT") {
                zeile("Lohn", lohnRechnungGold, lohnRechnungMops,
                      unter: "Verrechnung \(euro(orakel))/h", "Kosten +\(prozent(zL))")
                zeile("Material", materialEUR * (1 + zM), materialEUR * (1 + zM),
                      unter: "+\(prozent(zM))", "+\(prozent(zM))")
                zeile("Geräte", geraeteEUR * (1 + zG), geraeteEUR * (1 + zG),
                      unter: "+\(prozent(zG))", "+\(prozent(zG))")
                summeZeile("Rechnung", rechnungGold, rechnungMops)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var spalteKopf: some View {
        HStack(spacing: 8) {
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            spalteTitel("🏢 Goldschmitt", aktiv: aktiv == .goldschmitt)
            spalteTitel("🐶 Mops · Echtzahl", aktiv: aktiv == .mops)
        }
        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 4)
    }

    private func spalteTitel(_ t: String, aktiv: Bool) -> some View {
        Text(t).font(.caption.weight(.semibold))
            .foregroundStyle(aktiv ? Color.orange : .secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func gruppe<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(titel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
            inhalt()
        }
    }

    private func zeile(_ titel: String, _ gold: Double, _ mops: Double,
                       unter goldU: String? = nil, _ mopsU: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(titel).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
            spaltenWert(euro(gold), goldU, aktiv: aktiv == .goldschmitt)
            spaltenWert(euro(mops), mopsU, aktiv: aktiv == .mops)
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
    }

    private func spaltenWert(_ wert: String, _ unter: String?, aktiv: Bool) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(wert).font(.callout.monospacedDigit())
                .foregroundStyle(aktiv ? Color.primary : .secondary)
            if let unter { Text(unter).font(.caption2).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func summeZeile(_ titel: String, _ gold: Double, _ mops: Double) -> some View {
        HStack(spacing: 8) {
            Text(titel).font(.callout.weight(.bold)).frame(maxWidth: .infinity, alignment: .leading)
            Text(euro(gold)).font(.callout.weight(.bold).monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(aktiv == .goldschmitt ? Color.orange : .primary)
            Text(euro(mops)).font(.callout.weight(.bold).monospacedDigit())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .foregroundStyle(aktiv == .mops ? Color.orange : .primary)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
    }

    // MARK: - Fazit

    private var fazit: some View {
        let diff = rechnungGold - rechnungMops
        let guenstiger = diff >= 0
        return VStack(alignment: .leading, spacing: 4) {
            Text(guenstiger
                 ? "Mops bietet \(euro(abs(diff))) günstiger an als Goldschmitt — und deckt trotzdem die Selbstkosten (\(euro(selbstkostenMops)))."
                 : "Mops liegt \(euro(abs(diff))) über Goldschmitt. Prüf die Zuschläge (Settings).")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            Text("Der Unterschied steckt im Lohn: Goldschmitt verrechnet \(euro(orakel))/h, die Arbeit kostet aber \(euro(lohnKostenGold))/h. Die Lücke ist der Firmenzuschlag — „wo der Boss verdient“.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding().background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var fussnote: some View {
        Text("Kosten aus dem Firmenprofil (Brutto × Nebenkosten), Zuschläge aus den Firmen-Einstellungen, Verrechnungssatz aus dem Orakel (Gewinn-Schieber). Kein erfundener Wert.")
            .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Format

    private func euro(_ d: Double) -> String { String(format: "%.2f €", d) }
    private func prozent(_ d: Double) -> String { String(format: "%g %%", (d * 100).rounded()) }
    private func fmt(_ d: Double) -> String { String(format: "%g", d) }
}
