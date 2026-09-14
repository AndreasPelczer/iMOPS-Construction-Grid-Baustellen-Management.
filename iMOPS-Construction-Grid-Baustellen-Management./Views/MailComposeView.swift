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
    var pdf: Data? = nil               // optional: ohne Anhang für einfache Mails
    var dateiname: String = "Anhang.pdf"
    var onFinish: () -> Void = {}

    static var kannMailSenden: Bool { MFMailComposeViewController.canSendMail() }

    /// Bequemer Aufruf für Mails ohne Anhang (ein Empfänger).
    init(recipient: String, subject: String, body: String, onFinish: @escaping () -> Void = {}) {
        self.empfaenger = recipient.isEmpty ? [] : [recipient]
        self.betreff = subject
        self.text = body
        self.pdf = nil
        self.onFinish = onFinish
    }

    /// Voller Aufruf mit PDF-Anhang (z. B. Angebot an Kunden).
    init(empfaenger: [String], betreff: String, text: String,
         pdf: Data? = nil, dateiname: String = "Anhang.pdf",
         onFinish: @escaping () -> Void = {}) {
        self.empfaenger = empfaenger
        self.betreff = betreff
        self.text = text
        self.pdf = pdf
        self.dateiname = dateiname
        self.onFinish = onFinish
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(empfaenger.filter { !$0.isEmpty })
        vc.setSubject(betreff)
        vc.setMessageBody(text, isHTML: false)
        if let pdf { vc.addAttachmentData(pdf, mimeType: "application/pdf", fileName: dateiname) }
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
