import UserNotifications
import CoreData

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    enum Keys {
        static let fristenEnabled = "notif_fristen_enabled"
        static let vorwarnTage    = "notif_vorwarn_tage"
    }

    private var isEnabled: Bool {
        // Default true if key not yet written
        if UserDefaults.standard.object(forKey: Keys.fristenEnabled) == nil { return true }
        return UserDefaults.standard.bool(forKey: Keys.fristenEnabled)
    }

    private var vorwarnTage: Int {
        let stored = UserDefaults.standard.integer(forKey: Keys.vorwarnTage)
        return stored > 0 ? stored : 1
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Schedule Frist-day (08:00) + N-days-before (08:00) notifications.
    // Respects Settings toggles; silently skips past/terminal Mängel.
    func schedule(for mangel: Mangel) {
        cancel(for: mangel)
        guard isEnabled,
              let frist = mangel.frist,
              mangel.status != .behoben,
              mangel.status != .abgenommen,
              frist > Date() else { return }

        let id     = mangel.id?.uuidString ?? UUID().uuidString
        let center = UNUserNotificationCenter.current()
        let titel  = mangel.titel ?? "Mangel ohne Titel"

        // --- Frist-Tag ---
        let onDay        = UNMutableNotificationContent()
        onDay.title      = "Mangel-Frist heute"
        onDay.body       = titel
        onDay.sound      = .default
        var comps        = Calendar.current.dateComponents([.year, .month, .day], from: frist)
        comps.hour = 8; comps.minute = 0
        center.add(UNNotificationRequest(
            identifier: "\(id)_frist",
            content: onDay,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))

        // --- N Tage davor ---
        let offset = -vorwarnTage
        guard let vorherDatum = Calendar.current.date(byAdding: .day, value: offset, to: frist),
              vorherDatum > Date() else { return }
        let before       = UNMutableNotificationContent()
        before.title     = vorwarnTage == 1
            ? "Mangel-Frist morgen"
            : "Mangel-Frist in \(vorwarnTage) Tagen"
        before.body      = titel
        before.sound     = .default
        var compsBefore  = Calendar.current.dateComponents([.year, .month, .day], from: vorherDatum)
        compsBefore.hour = 8; compsBefore.minute = 0
        center.add(UNNotificationRequest(
            identifier: "\(id)_vorher",
            content: before,
            trigger: UNCalendarNotificationTrigger(dateMatching: compsBefore, repeats: false)))
    }

    func cancel(for mangel: Mangel) {
        let id = mangel.id?.uuidString ?? ""
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["\(id)_frist", "\(id)_vorher"])
    }

    // Sets the app badge to the number of overdue open Mängel.
    func updateBadge(context: NSManagedObjectContext) {
        let req: NSFetchRequest<Mangel> = Mangel.fetchRequest()
        req.predicate = NSPredicate(
            format: "frist != nil AND frist < %@ AND statusRawValue != %@ AND statusRawValue != %@",
            Date() as CVarArg,
            MangelStatus.behoben.rawValue,
            MangelStatus.abgenommen.rawValue)
        let count = (try? context.count(for: req)) ?? 0
        UNUserNotificationCenter.current().setBadgeCount(count) { _ in }
    }
}
