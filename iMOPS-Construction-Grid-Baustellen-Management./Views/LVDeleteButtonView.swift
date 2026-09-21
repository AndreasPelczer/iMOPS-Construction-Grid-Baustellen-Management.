//
//  LVDeleteButtonView.swift
//
//  Auftrag löschen — klein, ehrlich, mit benannten Folgen.
//
//  Vorher (Rest aus der Testphase, 21.09.2026 von Andreas bemerkt):
//  ein knallroter Balken über die volle Breite, der GRÖSSTE Knopf auf dem Bildschirm,
//  beschriftet mit „Komplette Materialliste unwiderruflich löschen" — und er löschte
//  in Wirklichkeit den **ganzen Auftrag** (`ctx.delete(currentLV)`). Die gefährlichste
//  Aktion an der auffälligsten Stelle, unter falschem Namen. Dazu landete die
//  eingegebene PIN im Klartext im Protokoll.
//
//  Andreas' eigene Regel für so etwas: kein Vollbreit-Wisch, `.alert` statt
//  `confirmationDialog` (am iPad), und **die Folgen benennen**.
//

import SwiftUI
import CoreData

struct LVDeleteButtonView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var currentLV: Auftrag

    @State private var zeigeFrage = false
    @State private var zeigeCode  = false
    @State private var pin = ""
    @State private var fehler = ""

    /// Was mit dem Auftrag verschwindet — wird VOR dem Löschen gezeigt, nicht danach.
    private var folgen: [String] {
        var f: [String] = []
        let extras = AuftragExtrasPayload.from(currentLV.extras)
        if !extras.checklist.isEmpty {
            f.append("\(extras.checklist.count) Arbeitsschritte")
        }
        if let u = extras.uebergehungen, !u.isEmpty {
            f.append("\(u.count) Übernahme-Nachweis\(u.count == 1 ? "" : "e") — die sind ein Beleg")
        }
        if !extras.lineItems.isEmpty {
            f.append("\(extras.lineItems.count) Materialpositionen")
        }
        let kanten = currentLV.istVoraussetzungFuerArray.count
        if kanten > 0 {
            f.append("\(kanten) Auftrag/Aufträge warten darauf — die werden frei")
        }
        return f
    }

    private var hatNachweise: Bool {
        !(AuftragExtrasPayload.from(currentLV.extras).uebergehungen ?? []).isEmpty
    }

    var body: some View {
        VStack(spacing: 10) {
            // Klein und unten. Nicht der auffälligste Knopf auf dem Bildschirm.
            Button(role: .destructive) {
                pin = ""; fehler = ""; zeigeFrage = true
            } label: {
                Label("Diesen Auftrag löschen", systemImage: "trash")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.red)

            if zeigeCode { codeFeld }
        }
        .alert("Auftrag löschen?", isPresented: $zeigeFrage) {
            Button("Abbrechen", role: .cancel) { }
            Button("Weiter", role: .destructive) { zeigeCode = true }
        } message: {
            Text(loeschText)
        }
    }

    private var loeschText: String {
        var t = "„\(Kausalkette.bezeichnung(currentLV))“ wird vollständig entfernt."
        if !folgen.isEmpty {
            t += "\n\nDamit verschwinden:\n• " + folgen.joined(separator: "\n• ")
        }
        if hatNachweise {
            t += "\n\n⚠️ Dieser Auftrag trägt eine übernommene Verantwortung. "
               + "Der Satz, mit dem jemand dafür geradesteht, ist danach weg."
        }
        t += "\n\nDas lässt sich nicht rückgängig machen."
        return t
    }

    private var codeFeld: some View {
        VStack(spacing: 10) {
            Text("Zum Bestätigen den vierstelligen Code eingeben.")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                SecureField("Code", text: $pin)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 110)
                    .multilineTextAlignment(.center)
                    .id("loesch-code")
                    .onChange(of: pin) { _, neu in
                        if neu.count > 4 { pin = String(neu.prefix(4)) }
                    }
                Button("Löschen") { loeschen() }
                    .buttonStyle(.borderedProminent).tint(.red)
                    .disabled(pin.count != 4)
                Button("Abbrechen") { zeigeCode = false; pin = ""; fehler = "" }
                    .buttonStyle(.bordered)
            }
            if !fehler.isEmpty {
                Text(fehler).font(.caption.bold()).foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loeschen() {
        // 🔴 Die eingegebene PIN wird NICHT protokolliert. Vorher stand sie im Klartext
        //    in der Konsole — ein Geheimnis gehört nicht ins Log.
        guard MopsSecurityCore.istGoatCode(pin) else {
            fehler = "Code stimmt nicht."
            pin = ""
            return
        }
        ctx.delete(currentLV)
        do {
            try ctx.save()
            zeigeCode = false
            dismiss()
        } catch {
            ctx.rollback()
            fehler = "Konnte nicht gelöscht werden: \(error.localizedDescription)"
        }
    }
}
