import SwiftUI

/// Karte „Vorgaben aus dem Bebauungsplan": zeigt die aus einem ausgewerteten B-Plan
/// gespeicherten Fakten (`extras.auswertungen`, doctype „bebauungsplan") als klare
/// Vorgaben-Liste. Erscheint nur, wenn ein B-Plan ausgewertet & gespeichert wurde.
///
/// Bewusst REINE ZITATE aus dem Dokument — kein Abgleich mit Projektwerten (das wäre die
/// spätere „Ampel", Stufe 2). Konsistent mit der iMOPS-Philosophie: dokumentiert statt geschätzt.
struct BPlanVorgabenCard: View {
    let event: Event

    private struct Vorgabe: Identifiable {
        var id: String { label }
        let label: String
        let wert: String
    }

    /// Jüngste gespeicherte Bebauungsplan-Auswertung (falls vorhanden).
    private var bplan: ExtractDocResult? {
        (EventExtrasPayload.laden(aus: event).auswertungen ?? [])
            .map(\.ergebnis)
            .last { $0.doctypeErkannt == "bebauungsplan" }
    }

    var body: some View {
        if let res = bplan {
            let vorgaben = vorgabenListe(res.felder)
            if !vorgaben.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "checklist").foregroundStyle(.orange)
                        Text("Vorgaben aus dem Bebauungsplan").font(.headline)
                    }

                    ForEach(vorgaben) { v in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5)).foregroundStyle(.orange)
                                .padding(.top, 6)
                            Text(v.label).font(.subheadline).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Text(v.wert).font(.subheadline.bold())
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Text("Quelle: \(res.quelle) · KI-Auslesung, im Zweifel am Plan prüfen")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    /// Baut die Vorgaben-Zeilen aus dem doctype-spezifischen `felder`-Baum (B-Plan-Schema
    /// aus `api/services/doc_extract.py`). Fehlt ein Feld → weglassen (keine Leerzeilen).
    private func vorgabenListe(_ f: JSONValue) -> [Vorgabe] {
        var out: [Vorgabe] = []
        func w(_ jv: JSONValue?) -> String? {
            guard let s = jv?.skalarText, s != "—", !s.isEmpty else { return nil }
            return s
        }
        func wm(_ jv: JSONValue?, _ einheit: String) -> String? { w(jv).map { "\($0) \(einheit)" } }
        func add(_ label: String, _ wert: String?) {
            if let wert { out.append(Vorgabe(label: label, wert: wert)) }
        }

        add("Zone", w(f["zone"]))
        add("GRZ", w(f["grz"]))
        add("GFZ", w(f["gfz"]))
        add("Wandhöhe max.", wm(f["hoehen"]?["wand_max_m"], "m"))
        add("Firsthöhe max.", wm(f["hoehen"]?["first_max_m"], "m"))
        add("Abgrabung max.", wm(f["erdarbeiten"]?["abgrabung_max_m"], "m"))
        add("Auffüllung max.", wm(f["erdarbeiten"]?["auffuellung_max_m"], "m"))
        add("Stützwand max.", wm(f["erdarbeiten"]?["stuetzwand_max_m"], "m"))
        if let form = w(f["dach"]?["formen"]?.erstesArrayElement) {
            if let neigung = w(f["dach"]?["neigung_grad"]) {
                add("Dach", "\(form), \(neigung)°")
            } else {
                add("Dach", form)
            }
        }
        add("Stellplätze Pflicht", w(f["stellplaetze_pflicht"]))
        add("Pflanzgebot", w(f["pflanzgebot"]))
        return out
    }
}
