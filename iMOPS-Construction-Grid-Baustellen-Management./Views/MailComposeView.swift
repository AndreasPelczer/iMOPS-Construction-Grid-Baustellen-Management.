//
//  MailComposeView.swift
//  Ein generischer Mail-Entwurf mit PDF-Anhang. Öffnet den System-Mail-Composer;
//  abgeschickt wird von Hand (Ersatz fürs Faxgerät, nicht für die Prüfung).
//
//  Wo Mail nicht verfügbar ist (z. B. Mac ohne eingerichtetes Mail-Konto), fällt
//  der Aufrufer auf das Teilen-Blatt zurück — `MailComposeView.kannMailSenden`.
//

import SwiftUI
import MessageUI

struct MailComposeView: UIViewControllerRepresentable {
    let empfaenger: [String]
    let betreff: String
    let text: String
    let pdf: Data
    let dateiname: String
    var onFinish: () -> Void = {}

    static var kannMailSenden: Bool { MFMailComposeViewController.canSendMail() }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(empfaenger.filter { !$0.isEmpty })
        vc.setSubject(betreff)
        vc.setMessageBody(text, isHTML: false)
        vc.addAttachmentData(pdf, mimeType: "application/pdf", fileName: dateiname)
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true) { self.onFinish() }
        }
    }
}
