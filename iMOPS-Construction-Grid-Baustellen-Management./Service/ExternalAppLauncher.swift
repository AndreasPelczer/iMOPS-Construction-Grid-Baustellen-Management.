import UIKit

/// Oeffnet Dateien in externen Apps via UIActivityViewController.
/// Funktioniert auf iOS, iPadOS und Mac Catalyst (Designed for iPad).
class ExternalAppLauncher: NSObject {

    static let shared = ExternalAppLauncher()

    /// Oeffnet das Share-Sheet fuer eine Datei.
    /// Zeigt alle installierten Apps an, die diesen Dateityp unterstuetzen
    /// (z.B. SketchUp, Preview, Finder etc.).
    ///
    /// - Parameters:
    ///   - fileURL: Lokaler Pfad zur Datei
    ///   - completion: Wird aufgerufen mit `true` wenn das Sheet angezeigt wurde
    func openInExternalApp(fileURL: URL, completion: ((Bool) -> Void)? = nil) {
        guard let viewController = Self.topViewController() else {
            completion?(false)
            return
        }

        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )

        // Auf iPad/Mac: Popover-Anker setzen (sonst Crash)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true) {
            completion?(true)
        }
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
