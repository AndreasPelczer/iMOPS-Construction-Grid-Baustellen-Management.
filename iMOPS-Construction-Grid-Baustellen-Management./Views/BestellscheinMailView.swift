import SwiftUI
import MessageUI
import CoreData

/// Öffnet einen Mail-Entwurf mit dem Bestellvorschlag als PDF-Anhang.
///
/// Ersetzt das Faxgerät, nicht die Prüfung: Der Entwurf öffnet sich, abgeschickt
/// wird von Hand. Empfänger ist vorausgefüllt und vor dem Senden änderbar.
struct BestellscheinMailView: UIViewControllerRepresentable {

    /// Steht so in der Fußzeile des T&C-Bestellscheins SÜD 2022:
    /// „Nur für den Baustoffhandel: Faxbestellung … oder per Mail an: …"
    /// Vorschlag, kein Zwang — im Entwurf änderbar.
    static let empfaengerVorschlag = "servicecenter.suedwest@xella.com"

    let event: Event
    let positionen: [LVPosition]
    let angaben: BestellscheinAngaben
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator

        let (zeilen, ohne) = BestellscheinService.zeilen(aus: positionen)
        let baustelle = event.title ?? event.name ?? "Baustelle"

        vc.setToRecipients([Self.empfaengerVorschlag])
        vc.setSubject("Bestellvorschlag Ytong — \(baustelle)")

        let df = DateFormatter(); df.dateFormat = "dd.MM.yyyy"
        let summe = zeilen.reduce(0) { $0 + $1.bestellmenge }
        var text = """
        Guten Tag,

        anbei ein Bestellvorschlag für die Baustelle \(baustelle).

        """
        for z in zeilen {
            text += "\n\(z.materialNr)  \(z.bezeichnung)  —  "
                 + String(format: "%.2f", z.bestellmenge).replacingOccurrences(of: ".", with: ",")
                 + " m³"
            if z.zuschlagProzent > 0 { text += "  (inkl. \(Int(z.zuschlagProzent)) % Eck-/Laibungssteine)" }
        }
        text += "\n\nGesamt: " + String(format: "%.2f", summe).replacingOccurrences(of: ".", with: ",") + " m³"
        if !ohne.isEmpty {
            text += "\n\n\(ohne.count) Position(en) konnten keiner Material-Nummer "
                  + "zugeordnet werden — siehe PDF."
        }
        let tf = DateFormatter(); tf.dateFormat = "dd.MM.yyyy"
        text += "\n\nLieferung: \(angaben.lieferart.rawValue), "
             + (angaben.mitKran ? "mit Kran" : "ohne Kran")
             + ", \(angaben.zeitfenster.rawValue)"
             + "\nWunschtermin: \(tf.string(from: angaben.wunschtermin))"
        if !angaben.bemerkung.isEmpty { text += "\n\nBemerkung: \(angaben.bemerkung)" }
        text += "\n\nDie Einzelheiten stehen im angehängten PDF.\n\nMit freundlichen Grüßen\n"
        vc.setMessageBody(text, isHTML: false)

        let pdf = BestellscheinPDFExporter.generate(
            zeilen: zeilen, ohneNummer: ohne,
            kontext: .init(baustelle: baustelle,
                           bvhNr: event.eventNumber,
                           bauherr: event.bauherr,
                           strasse: angaben.strasse.isEmpty ? nil : angaben.strasse,
                           plzOrt: angaben.plzOrt.isEmpty ? event.location : angaben.plzOrt,
                           objektNr: angaben.objektNr.isEmpty ? nil : angaben.objektNr,
                           baustoffhandel: angaben.baustoffhandel.isEmpty ? nil : angaben.baustoffhandel,
                           angaben: angaben,
                           datum: Date()))
        let dateiname = "Bestellvorschlag_\(baustelle.ersetzeSonderzeichen)_\(df.string(from: Date())).pdf"
        vc.addAttachmentData(pdf, mimeType: "application/pdf", fileName: dateiname)

        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) { onFinish() }
    }
}

private extension String {
    /// Dateinamen-tauglich: Leerzeichen und Sonderzeichen zu Unterstrichen.
    var ersetzeSonderzeichen: String {
        let erlaubt = CharacterSet.alphanumerics
        return String(unicodeScalars.map { erlaubt.contains($0) ? Character($0) : "_" })
    }
}
