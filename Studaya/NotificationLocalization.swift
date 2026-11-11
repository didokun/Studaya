import Foundation
import UserNotifications

/// Keep the localization key until delivery: changing the phone language must not
/// leave a repeating notification frozen in the language used when it was scheduled.
struct NotificationText: Equatable {
    enum Argument: Equatable {
        case text(String)
        case integer(Int)
        var object: Any {
            switch self { case .text(let value): value; case .integer(let value): NSNumber(value: value) }
        }
        var formatValue: CVarArg {
            switch self { case .text(let value): value; case .integer(let value): Int64(value) }
        }
    }
    let key: String
    var arguments: [Argument] = []
    init(_ key: String, _ arguments: [Argument] = []) { self.key = key; self.arguments = arguments }
    var rendered: String {
        let template = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        return String(format: template, locale: Locale.current, arguments: arguments.map(\.formatValue))
    }
    var deferred: String {
        NSString.localizedUserNotificationString(forKey: key, arguments: arguments.map(\.object))
    }
}

extension StudyReminder {
    init(id: String, title: NotificationText, body: NotificationText, date: Date, tab: Int = 1, repeatsDaily: Bool = false) {
        self.init(id: id, title: title.rendered, body: body.rendered, date: date, tab: tab, repeatsDaily: repeatsDaily, localizedTitle: title, localizedBody: body)
    }
    func apply(to content: UNMutableNotificationContent) {
        content.title = localizedTitle?.deferred ?? title
        content.body = localizedBody?.deferred ?? body
        content.sound = .default
        content.userInfo = ["tab": tab]
    }
}

@MainActor enum NotificationLanguageMigration {
    private static var preparation: Task<Void, Never>?
    private static let preferenceKey = "notificationLocalizationVersion"
    static var version: String { "delivery-localization-v2:" + (Bundle.main.preferredLocalizations.first ?? "en") }
    static func owns(_ identifier: String) -> Bool {
        identifier == "studaya.daily" || identifier.hasPrefix("studaya.event.") || identifier.hasPrefix("studaya.focus.")
    }
    static func prepare() async {
        let preferences = StudyPreferences.current
        guard preferences.string(forKey: preferenceKey) != version else { return }
        if let preparation { await preparation.value; return }
        let stamp = version
        let task = Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            let delivered = await center.deliveredNotifications()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter(owns))
            center.removeDeliveredNotifications(withIdentifiers: delivered.map { $0.request.identifier }.filter(owns))
            preferences.set(stamp, forKey: preferenceKey)
        }
        preparation = task
        await task.value
        preparation = nil
    }
}
