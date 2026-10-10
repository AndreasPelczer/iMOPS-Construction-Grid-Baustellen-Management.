//
//  OfflineUnterlagenCard.swift
//  In der Baustelle: die Unterlagen aus der Freigabe – mitnehmen, abgleichen, offline ansehen.
//

import SwiftUI
import QuickLook

struct OfflineUnterlagenCard: View {
    @ObservedObject var event: Event
    @State private var stand: OfflineUnterlagen.Stand?
    @State private var laeuft = false
    @State private var fortschritt = (0, 0)
    @State private var meldung: String?
    @State private var vorschau: URL?
    @State private var vergessenFragen = false

    private var bid: String { BaustellenMeldung.id(fuer: event) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Unterlagen (Freigabe)", systemImage: "externaldrive.connected.to.line.below").font(.headline)
                Spacer()
                if laeuft { ProgressView().controlSize(.small) }
            }
            if let s = stand {
                Text("Offline dabei: \(s.dateien.count) Dateien, \(ByteCountFormatter.string(fromByteCount: Int64(s.bytes), countStyle: .file)) · Stand \(s.geholt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Dictionary(grouping: s.dateien, by: \.fach).sorted { $0.key < $1.key }, id: \.key) { fach, dateien in
                    Text(fach.isEmpty ? "Ohne Fach" : fach).font(.caption.weight(.semibold)).padding(.top, 4)
                    ForEach(dateien) { d in
                        Button { vorschau = OfflineUnterlagen.lokal(d, bid: bid) } label: {
                            HStack {
                                Image(systemName: "doc").foregroundStyle(.secondary)
                                Text(d.name).font(.subheadline).lineLimit(1)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: Int64(d.groesse), countStyle: .file))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Text("Noch nichts mitgenommen. Vor der Fahrt auf eine Baustelle ohne Empfang: einmal „Offline mitnehmen“.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if laeuft, fortschritt.1 > 0 {
                ProgressView(value: Double(fortschritt.0), total: Double(fortschritt.1))
                Text("\(fortschritt.0) von \(fortschritt.1) Dateien").font(.caption2).foregroundStyle(.secondary)
            }
            if let meldung { Text(meldung).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button(stand == nil ? "Offline mitnehmen" : "Abgleichen") { Task { await holen() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(laeuft)
                if stand != nil {
                    Button("Vom iPad löschen", role: .destructive) { vergessenFragen = true }
                        .buttonStyle(.bordered)
                        .disabled(laeuft)
                }
            }
            Text("Nur mitnehmen – Änderungen auf dem iPad gehen nicht zurück in die Freigabe.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear { stand = OfflineUnterlagen.stand(fuer: bid) }
        .quickLookPreview($vorschau)
        .alert("Offline-Kopie löschen?", isPresented: $vergessenFragen) {
            Button("Löschen", role: .destructive) { OfflineUnterlagen.vergessen(bid: bid); stand = nil; meldung = nil }
            Button("Behalten", role: .cancel) {}
        } message: {
            Text("Nur die Kopie auf diesem iPad wird gelöscht. In der Freigabe auf der Box bleibt alles.")
        }
    }

    private func holen() async {
        laeuft = true; meldung = nil; fortschritt = (0, 0)
        let id = bid
        let ergebnis = await OfflineUnterlagen.mitnehmen(bid: id) { fertig, gesamt in
            Task { @MainActor in fortschritt = (fertig, gesamt) }
        }
        switch ergebnis {
        case .ok(let neu, let gleich, let entfernt):
            meldung = neu + entfernt == 0 ? "Alles aktuell (\(gleich) Dateien)." : "\(neu) geholt, \(gleich) unverändert, \(entfernt) entfernt."
        case .keinOrdner:
            meldung = "Für diese Baustelle gibt es noch keinen Ordner in der Freigabe – er entsteht beim nächsten Melden."
        case .nichtErreicht(let grund):
            meldung = grund
        }
        stand = OfflineUnterlagen.stand(fuer: id)
        laeuft = false
    }
}
