import XCTest
import UserNotifications
@testable import Studaya

@MainActor final class NotificationLocalizationTests: XCTestCase {
    func testEveryNotificationFamilyKeepsItsLocalizationKeysAndAllSixteenCatalogsCoverThem() throws {
        let now = Date()
        let subject = Subject("Analyse numérique", exam: now.addingTimeInterval(8 * 86400))
        let chapter = Chapter("Matrices", subject: subject.id, target: 2)
        chapter.kind = "TD"; chapter.completed = true
        let review = SpacedReview(chapter: chapter.id, due: now.addingTimeInterval(2 * 86400), days: 2)
        let deadline = StudyDeadline(subject: subject.id); deadline.due = now.addingTimeInterval(3 * 86400); deadline.chapterID = chapter.id
        let session = Session(chapter, subject: subject, start: now.addingTimeInterval(3600), minutes: 25)
        let log = FocusLog(minutes: 25, date: now)
        var notices = ReminderPlan.make(subjects: [subject], deadlines: [deadline], chapters: [chapter], reviews: [review], now: now)
        notices += StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [session], logs: [log], options: .init(), anchor: now, now: now)
        notices += StudentNotificationPlan.make(subjects: [], chapters: [], sessions: [], logs: [], options: .init(), anchor: now, now: now)
        notices += StudentNotificationPlan.make(subjects: [subject], chapters: [], sessions: [], logs: [], options: .init(), anchor: now, now: now)
        let timer = FocusTimerSnapshot(end: now.addingTimeInterval(1500).timeIntervalSince1970, length: 1500, remaining: 0, resting: false, runID: UUID().uuidString, breakSeconds: 300)
        notices += timer.notifications(now: now)
        for language in L10n.supportedLocales {
            let folder = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let catalog = try XCTUnwrap(NSDictionary(contentsOfFile: folder + "/Localizable.strings") as? [String: String])
            for notice in notices {
                for text in [try XCTUnwrap(notice.localizedTitle), try XCTUnwrap(notice.localizedBody)] {
                    let template = try XCTUnwrap(catalog[text.key], language + ": " + text.key)
                    let rendered = String(format: template, arguments: text.arguments.map(\.formatValue))
                    XCTAssertFalse(rendered.isEmpty, language + ": " + text.key)
                    XCTAssertFalse(rendered.contains("ZXQ"))
                    XCTAssertFalse(template.contains("lld"), language + ": numeric placeholder in deferred notification: " + text.key)
                    XCTAssertFalse(rendered.contains("%@"), language + ": " + text.key)
                }
            }
        }
    }
    func testEnglishTimerTextAndNotificationPayload() throws {
        XCTAssertEqual(Bundle.main.preferredLocalizations.first, "en")
        let now = Date()
        let timer = FocusTimerSnapshot(end: now.addingTimeInterval(1500).timeIntervalSince1970, length: 1500, remaining: 0, resting: false, runID: UUID().uuidString, breakSeconds: 300)
        let notice = try XCTUnwrap(timer.notifications(now: now).first)
        XCTAssertEqual(notice.title, "Focus finished · time to rest 🌿")
        XCTAssertTrue(notice.body.contains("5"))
        XCTAssertFalse(notice.body.contains("Ta pause"))
        let content = UNMutableNotificationContent()
        notice.apply(to: content)
        XCTAssertFalse(content.title.isEmpty)
        XCTAssertFalse(content.body.isEmpty)
        XCTAssertEqual(content.userInfo["tab"] as? Int, 2)
        let archive = try NSKeyedArchiver.archivedData(withRootObject: content, requiringSecureCoding: true)
        XCTAssertFalse(archive.isEmpty)
    }
    func testRevisionMinutesSurviveDeferredLocalizationAndNotificationSerialization() throws {
        let text = NotificationText("notification.session.body", [.text("CDG · Synthèse"), .integer(25)])
        XCTAssertEqual(text.rendered, "CDG · Synthèse · 25 min. A first exercise is enough to get you started.")
        let notice = StudyReminder(id: "session.test", title: NotificationText("C’est ton moment de révision"), body: text, date: .now)
        let content = UNMutableNotificationContent()
        notice.apply(to: content)
        XCTAssertTrue(content.body.contains("25 min"), content.body)
        XCTAssertFalse(content.body.contains("lld"), content.body)
        let data = try NSKeyedArchiver.archivedData(withRootObject: content, requiringSecureCoding: true)
        let restored = try XCTUnwrap(NSKeyedUnarchiver.unarchivedObject(ofClass: UNNotificationContent.self, from: data))
        XCTAssertTrue(restored.body.contains("25 min"), restored.body)
        XCTAssertFalse(restored.body.contains("lld"), restored.body)
    }

    func testLanguageMigrationOnlyTargetsStudayaNotifications() {
        XCTAssertTrue(NotificationLanguageMigration.owns("studaya.daily"))
        XCTAssertTrue(NotificationLanguageMigration.owns("studaya.event.morning.daily"))
        XCTAssertTrue(NotificationLanguageMigration.owns("studaya.focus.workEnd"))
        XCTAssertFalse(NotificationLanguageMigration.owns("studaya.eventual.other"))
        XCTAssertFalse(NotificationLanguageMigration.owns("calendar.personal"))
    }
}
