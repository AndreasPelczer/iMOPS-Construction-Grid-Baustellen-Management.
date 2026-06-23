import SwiftUI
import MessageUI
import CoreData
import UIKit

// MARK: - Lieferanten-Kontakte

private struct LieferantInfo {
    let name: String
    let email: String
    let betreffPrefix: String
}

private let lieferantInfos: [String: LieferantInfo] = [
    "Scharpegge": LieferantInfo(
        name: "Scharpegge GmbH",
        email: "info@scharpegge-gmbh.de",
        betreffPrefix: "Preisanfrage"
    ),
    "Hauff": LieferantInfo(
        name: "Hauff-Technik",
        email: "anfrage@hauff-technik.de",
        betreffPrefix: "Materialanfrage"
    ),
]

// MARK: - Hauptview

struct LieferantenBestelllisteView: View {
    let event: Event
    let positionen: [LVPosition]

    @Environment(\.dismiss) private var dismiss

    @State private var activeMailLieferant: String?
    @State private var showMailCompose = false
    @State private var previewAnfrage: AnfrageTextPreview?

    private var demoAnfragenByPositionId: [NSManagedObjectID: UniversalAnfrage] {
        LieferwarnungDemoFactory.anfragenByPositionId(for: positionen)
    }

    private var grouped: [(lieferant: String, positionen: [LVPosition])] {
        let known = ["Scharpegge", "Hauff", "Baumarkt", "Sonstige"]
        var dict: [String: [LVPosition]] = [:]
        for pos in positionen {
            let key = pos.lieferant ?? "Ohne Lieferant"
            dict[key, default: []].append(pos)
        }
        // Sortierung: bekannte zuerst, dann alphabetisch
        let sorted = dict.keys.sorted { a, b in
            let ia = known.firstIndex(of: a) ?? 99
            let ib = known.firstIndex(of: b) ?? 99
            return ia == ib ? a < b : ia < ib
        }
        return sorted.map { (lieferant: $0, positionen: dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                ForEach(grouped, id: \.lieferant) { gruppe in
                    lieferantSection(gruppe)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Bestellliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.tint(.orange)
                }
            }
            .sheet(isPresented: $showMailCompose) {
                if let lieferant = activeMailLieferant {
                    MailComposeView(
                        recipient: lieferantInfos[lieferant]?.email ?? "",
                        subject: mailBetreff(lieferant: lieferant),
                        body: mailBody(lieferant: lieferant)
                    )
                    .ignoresSafeArea()
                }
            }
            .sheet(item: $previewAnfrage) { preview in
                AnfrageTextPreviewView(preview: preview)
            }
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(positionen.count) Positionen gesamt")
                        .font(.headline)
                    Text(event.title ?? "Baustelle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(grouped.count) Lieferant\(grouped.count == 1 ? "" : "en")")
                        .font(.subheadline.bold()).foregroundStyle(.orange)
                    Text(positionen.filter { $0.lieferant != nil && !($0.lieferant!.isEmpty) }.count == positionen.count
                         ? "alle zugeordnet" : "teilweise zugeordnet")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Pro-Lieferant Section

    @ViewBuilder
    private func lieferantSection(_ gruppe: (lieferant: String, positionen: [LVPosition])) -> some View {
        let info = lieferantInfos[gruppe.lieferant]
        Section {
            ForEach(gruppe.positionen, id: \.objectID) { pos in
                VStack(alignment: .leading, spacing: 4) {
                    Text(pos.bezeichnung ?? "–")
                        .font(.body)
                    HStack(spacing: 6) {
                        if let anfrage = demoAnfragenByPositionId[pos.objectID] {
                            LieferwarnungBadge(warnstufe: anfrage.aktuelleWarnstufe)
                        }
                        if let art = pos.artikelNummer, !art.isEmpty {
                            Text(art).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text("·").foregroundStyle(.secondary)
                        }
                        Text("\(pos.menge.formatted(.number.precision(.fractionLength(0...2)))) \(pos.einheit ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                        if let kg = pos.kostenGruppeNummer, !kg.isEmpty {
                            Text("· KG \(kg)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            if let info {
                Button {
                    activeMailLieferant = gruppe.lieferant
                    previewAnfrage = AnfrageTextPreview(
                        empfaenger: lieferantInfos[gruppe.lieferant]?.email ?? "",
                        betreff: mailBetreff(lieferant: gruppe.lieferant),
                        body: mailBody(lieferant: gruppe.lieferant)
                    )
                } label: {
                    Label("Mail an \(info.name)", systemImage: "envelope.badge")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            HStack {
                if let info {
                    Image(systemName: "building.2").font(.caption)
                    Text(info.name)
                } else {
                    Image(systemName: "questionmark.circle").font(.caption)
                    Text(gruppe.lieferant)
                }
                Spacer()
                Text("\(gruppe.positionen.count) Pos.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Mail-Inhalte

    private func mailBetreff(lieferant: String) -> String {
        LieferantenAnfrageFormatter.betreff(
            kontakt: kontakt(for: lieferant),
            kontext: anfrageKontext()
        )
    }

    private func mailBody(lieferant: String) -> String {
        let pos = grouped.first(where: { $0.lieferant == lieferant })?.positionen ?? []
        return LieferantenAnfrageFormatter.text(
            kontakt: kontakt(for: lieferant),
            kontext: anfrageKontext(),
            anfrage: anfrage(positionen: pos)
        )
    }

    private func kontakt(for lieferant: String) -> LieferantenAnfrageKontakt {
        let info = lieferantInfos[lieferant]
        return LieferantenAnfrageKontakt(
            name: info?.name ?? lieferant,
            email: info?.email ?? "",
            betreffPrefix: info?.betreffPrefix ?? "Anfrage"
        )
    }

    private func anfrageKontext() -> LieferantenAnfrageKontext {
        LieferantenAnfrageKontext(
            baustelle: event.title ?? "Baustelle",
            baustellenNummer: event.eventNumber,
            standort: event.location,
            bauherr: event.bauherr
        )
    }

    private func anfrage(positionen: [LVPosition]) -> UniversalAnfrage {
        UniversalAnfrage(
            baustelleId: event.objectID.uriRepresentation().absoluteString,
            status: .angefragt,
            positionen: positionen.enumerated().map { index, pos in
                BedarfsPosition(
                    lvPositionId: pos.objectID.uriRepresentation().absoluteString,
                    posNr: pos.posNr ?? "\(index + 1)",
                    material: pos.bezeichnung ?? "Material",
                    menge: pos.menge,
                    einheit: pos.einheit ?? "",
                    bedarfsquelle: BedarfsQuelle(
                        typ: .lv,
                        ref: pos.posNr ?? "\(index + 1)",
                        datei: pos.quellDatei,
                        planblatt: nil,
                        notiz: pos.artikelNummer.map { "Artikel: \($0)" },
                        geprueftVon: nil
                    )
                )
            },
            lieferung: LieferDetails(
                lieferfensterVon: Date(),
                lieferfensterBis: Date().addingTimeInterval(48 * 3_600)
            )
        )
    }
}

// MARK: - Anfrage Text Preview

private struct AnfrageTextPreview: Identifiable {
    let id = UUID()
    let empfaenger: String
    let betreff: String
    let body: String

    var kopierText: String {
        [
            empfaenger.isEmpty ? nil : "An: \(empfaenger)",
            "Betreff: \(betreff)",
            "",
            body
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

private struct AnfrageTextPreviewView: View {
    let preview: AnfrageTextPreview

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        NavigationStack {
            List {
                Section("Empfänger") {
                    Text(preview.empfaenger.isEmpty ? "Nicht hinterlegt" : preview.empfaenger)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }

                Section("Betreff") {
                    Text(preview.betreff)
                        .textSelection(.enabled)
                }

                Section("Anfrage-Text") {
                    Text(preview.body)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("Anfrage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        Button {
                            UIPasteboard.general.string = preview.kopierText
                            didCopy = true
                        } label: {
                            Label(didCopy ? "Kopiert" : "Kopieren", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        }

                        if let mailURL = preview.mailtoURL {
                            Button {
                                openURL(mailURL)
                            } label: {
                                Label("Mail öffnen", systemImage: "envelope")
                            }
                        }
                    } label: {
                        Label("Senden", systemImage: "square.and.arrow.up")
                    }
                    .tint(.orange)
                }
            }
        }
    }
}

private extension AnfrageTextPreview {
    var mailtoURL: URL? {
        guard !empfaenger.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = empfaenger
        components.queryItems = [
            URLQueryItem(name: "subject", value: betreff),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

// MARK: - Lieferwarnung Preview-Bausteine

private struct LieferwarnungBadge: View {
    let warnstufe: WarnStufe

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .accessibilityLabel(label)
    }

    private var label: String {
        switch warnstufe {
        case .keine:
            "OK"
        case .lieferungUnbestaetigt:
            "48h"
        case .terminKritisch:
            "KRIT"
        }
    }

    private var icon: String {
        switch warnstufe {
        case .keine:
            "checkmark"
        case .lieferungUnbestaetigt:
            "exclamationmark"
        case .terminKritisch:
            "exclamationmark.triangle.fill"
        }
    }

    private var foreground: Color {
        switch warnstufe {
        case .keine:
            .green
        case .lieferungUnbestaetigt:
            .orange
        case .terminKritisch:
            .red
        }
    }

    private var background: Color {
        foreground.opacity(0.14)
    }
}

private enum LieferwarnungDemoFactory {
    static func anfragenByPositionId(for positionen: [LVPosition], now: Date = Date()) -> [NSManagedObjectID: UniversalAnfrage] {
        var result: [NSManagedObjectID: UniversalAnfrage] = [:]
        for (index, position) in positionen.enumerated() {
            result[position.objectID] = makeAnfrage(for: position, index: index, now: now)
        }
        return result
    }

    private static func makeAnfrage(for position: LVPosition, index: Int, now: Date) -> UniversalAnfrage {
        let warnschwelle: TimeInterval = 48 * 3_600
        let offset: TimeInterval
        switch index % 3 {
        case 0: offset = warnschwelle + 24 * 3_600
        case 1: offset = 24 * 3_600
        default: offset = -6 * 3_600
        }

        return UniversalAnfrage(
            baustelleId: position.event?.objectID.uriRepresentation().absoluteString ?? "demo-baustelle",
            status: .beauftragt,
            positionen: [
                BedarfsPosition(
                    lvPositionId: position.objectID.uriRepresentation().absoluteString,
                    posNr: position.posNr ?? "",
                    material: position.bezeichnung ?? "Material",
                    menge: position.menge,
                    einheit: position.einheit ?? "",
                    bedarfsquelle: BedarfsQuelle(
                        typ: .lv,
                        ref: position.posNr ?? "LV",
                        datei: position.quellDatei,
                        planblatt: nil,
                        notiz: "Demo-Lieferwarnung",
                        geprueftVon: nil
                    )
                )
            ],
            lieferung: LieferDetails(
                beauftragtAm: now.addingTimeInterval(-24 * 3_600),
                lieferfensterVon: now.addingTimeInterval(offset),
                lieferfensterBis: now.addingTimeInterval(offset + 4 * 3_600)
            )
        )
    }
}

// MARK: - Mail Compose Wrapper

struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        if !recipient.isEmpty { vc.setToRecipients([recipient]) }
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mailComposeController(_ c: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            dismiss()
        }
    }
}
