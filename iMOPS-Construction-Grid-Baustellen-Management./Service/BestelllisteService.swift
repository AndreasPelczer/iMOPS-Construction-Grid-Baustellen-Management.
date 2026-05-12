import SwiftUI
import MessageUI

// MARK: - SwiftUI wrapper

struct BestelllisteMailView: View {
    @Environment(\.dismiss) private var dismiss
    let event: Event
    let positionen: [LVPosition]

    var body: some View {
        MailComposerViewController(event: event, positionen: positionen) {
            dismiss()
        }
        .ignoresSafeArea()
    }
}

// MARK: - UIViewControllerRepresentable

private struct MailComposerViewController: UIViewControllerRepresentable {
    let event: Event
    let positionen: [LVPosition]
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let datumStr = formatter.string(from: Date())
        let baustelle = event.title ?? "Baustelle"

        vc.setSubject("Preisanfrage – \(baustelle) – \(datumStr)")

        let gruppen = Dictionary(grouping: positionen, by: { $0.lieferant ?? "Sonstige" })
        let sortedGruppen = gruppen.sorted { a, _ in a.key == "Scharpegge" }

        if gruppen["Scharpegge"] != nil {
            vc.setToRecipients(["info@scharpegge.gmbh"])
        }

        vc.setMessageBody(buildBody(baustelle: baustelle, datum: datumStr, gruppen: sortedGruppen), isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    // MARK: - Mail Body

    private func buildBody(
        baustelle: String,
        datum: String,
        gruppen: [(key: String, value: [LVPosition])]
    ) -> String {
        var body = "Sehr geehrte Damen und Herren,\n\nhiermit senden wir Ihnen unsere Preisanfrage für folgendes Projekt:\n\n"
        body += "Projekt:   \(baustelle)\n"
        body += "Datum:     \(datum)\n"
        if let nr = event.eventNumber, !nr.isEmpty  { body += "Baust.-Nr.: \(nr)\n" }
        if let ort = event.location, !ort.isEmpty   { body += "Standort:  \(ort)\n" }
        body += "\n"

        for gruppe in gruppen {
            let sep = String(repeating: "═", count: 60)
            body += "\(sep)\n"
            body += "Lieferant: \(gruppe.key)\n"
            body += "\(sep)\n"
            body += pad("Art.-Nr.", 12) + pad("Bezeichnung", 36) + pad("Menge", 8) + "Einh.\n"
            body += String(repeating: "─", count: 60) + "\n"

            for pos in gruppe.value.sorted(by: { ($0.posNr ?? "") < ($1.posNr ?? "") }) {
                let art = pad(pos.artikelNummer ?? "–", 12)
                let bez = pad(String((pos.bezeichnung ?? "–").prefix(36)), 36)
                let mng = String(format: "%7.2f ", pos.menge)
                let ein = pos.einheit ?? "–"
                body += "\(art)\(bez)\(mng)\(ein)\n"
            }
            body += "\n"
        }

        body += "Bitte teilen Sie uns Ihre Preise und Verfügbarkeiten mit.\n\nMit freundlichen Grüßen\n"
        return body
    }

    private func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? String(s.prefix(width)) : s + String(repeating: " ", count: width - s.count)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}
