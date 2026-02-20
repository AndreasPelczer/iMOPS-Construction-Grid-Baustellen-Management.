import UIKit

/// Oeffnet Dateien in externen Apps via UIDocumentInteractionController.
/// Zeigt automatisch alle installierten Apps an, die den Dateityp unterstuetzen
/// (z.B. SketchUp for iPad fuer SKP-Dateien).
class ExternalAppLauncher: NSObject, UIDocumentInteractionControllerDelegate {

    static let shared = ExternalAppLauncher()

    private var documentController: UIDocumentInteractionController?

    /// Oeffnet das "Oeffnen in..."-Menue fuer eine Datei.
    /// Zeigt alle installierten Apps an, die diesen Dateityp unterstuetzen.
    ///
    /// - Parameters:
    ///   - fileURL: Lokaler Pfad zur Datei
    ///   - completion: Wird aufgerufen mit `true` wenn mindestens eine App verfuegbar war
    func openInExternalApp(fileURL: URL, completion: ((Bool) -> Void)? = nil) {
        guard let viewController = Self.topViewController() else {
            completion?(false)
            return
        }

        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        self.documentController = controller

        let presented = controller.presentOpenInMenu(
            from: viewController.view.bounds,
            in: viewController.view,
            animated: true
        )

        completion?(presented)
    }

    /// Zeigt eine Vorschau der Datei an (Quick Look).
    func previewFile(fileURL: URL) {
        guard let viewController = Self.topViewController() else { return }

        let controller = UIDocumentInteractionController(url: fileURL)
        controller.delegate = self
        self.documentController = controller

        controller.presentPreview(animated: true)
    }

    // MARK: - UIDocumentInteractionControllerDelegate

    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        Self.topViewController() ?? UIViewController()
    }

    func documentInteractionControllerDidDismissOpenInMenu(
        _ controller: UIDocumentInteractionController
    ) {
        documentController = nil
    }

    // MARK: - Helper: Top ViewController finden

    private static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }

        return findTop(from: rootVC)
    }

    private static func findTop(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return findTop(from: presented)
        }
        if let nav = vc as? UINavigationController, let top = nav.topViewController {
            return findTop(from: top)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTop(from: selected)
        }
        return vc
    }
}
