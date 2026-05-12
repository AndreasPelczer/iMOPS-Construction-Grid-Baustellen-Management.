import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Schedule Frist-day (08:00) + 1-day-before (08:00) notifications.
    // Silently skips when frist is in the past or status is terminal.
    func schedule(for mangel: Mangel) {
        cancel(for: mangel)
        guard let frist = mangel.frist,
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

        // --- Tag davor ---
        guard let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: frist),
              dayBefore > Date() else { return }
        let before        = UNMutableNotificationContent()
        before.title      = "Mangel-Frist morgen"
        before.body       = titel
        before.sound      = .default
        var compsBefore   = Calendar.current.dateComponents([.year, .month, .day], from: dayBefore)
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
}
