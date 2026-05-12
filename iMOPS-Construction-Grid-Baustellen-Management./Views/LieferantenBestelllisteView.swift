import SwiftUI
import MessageUI

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
    @State private var showMailUnavailable = false

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
            .alert("Mail nicht verfügbar", isPresented: $showMailUnavailable) {
                Button("OK") {}
            } message: {
                Text("Auf diesem Gerät ist kein Mail-Account eingerichtet.")
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(pos.bezeichnung ?? "–").font(.body)
                    HStack(spacing: 6) {
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
                    if MFMailComposeViewController.canSendMail() {
                        showMailCompose = true
                    } else {
                        showMailUnavailable = true
                    }
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
        let prefix = lieferantInfos[lieferant]?.betreffPrefix ?? "Anfrage"
        return "\(prefix) – \(event.title ?? "Baustelle")"
    }

    private func mailBody(lieferant: String) -> String {
        let pos = grouped.first(where: { $0.lieferant == lieferant })?.positionen ?? []
        let info = lieferantInfos[lieferant]
        var lines: [String] = []
        lines.append("Guten Tag,")
        lines.append("")
        lines.append("für unser Bauprojekt \"\(event.title ?? "Baustelle")\"\(event.location.map { " in \($0)" } ?? "") benötigen wir folgende Materialien:")
        lines.append("")
        lines.append(String(repeating: "-", count: 60))

        for (i, p) in pos.enumerated() {
            let nr = p.posNr ?? "\(i+1)"
            let bez = p.bezeichnung ?? "–"
            let menge = p.menge.formatted(.number.precision(.fractionLength(0...2)))
            let einheit = p.einheit ?? ""
            let art = p.artikelNummer.map { " [Art.-Nr.: \($0)]" } ?? ""
            lines.append("\(nr). \(bez)\(art)")
            lines.append("   Menge: \(menge) \(einheit)")
            if let kg = p.kostenGruppeNummer, !kg.isEmpty {
                lines.append("   KG \(kg)")
            }
            lines.append("")
        }

        lines.append(String(repeating: "-", count: 60))
        lines.append("")
        lines.append("Bitte senden Sie uns ein Angebot zu.")
        lines.append("")
        lines.append("Mit freundlichen Grüßen")
        if let bauherr = event.bauherr, !bauherr.isEmpty {
            lines.append(bauherr)
        }

        return lines.joined(separator: "\n")
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
