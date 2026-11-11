import XCTest
import SwiftData
@testable import Studaya

@MainActor final class StudentNotificationTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1794380400)
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    func hour(_ value: Int, day: Int = 0) -> Date {
        calendar.date(bySettingHour: value, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: day, to: now)!)!
    }
    func fixture() -> (Subject, Chapter, Session) {
        let subject = Subject("Analyse numérique", exam: hour(12, day: 8))
        let chapter = Chapter("Matrices", subject: subject.id, target: 2)
        return (subject, chapter, Session(chapter, subject: subject, start: hour(17), minutes: 25))
    }
    func testDailyAndSessionNoticesReflectCompletedWork() {
        let (subject, chapter, session) = fixture()
        let initial = StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [session], logs: [], options: .init(), anchor: now, now: hour(7), calendar: calendar)
        XCTAssertTrue(initial.contains { $0.id.hasPrefix("morning.") && calendar.isDate($0.date, inSameDayAs: now) })
        XCTAssertEqual(initial.filter(\.repeatsDaily).count, 2)
        XCTAssertTrue(initial.contains { $0.id.hasPrefix("session.") && $0.body.contains("AN · Matrices") && $0.date == session.start })
        session.done = true
        let updated = StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [session], logs: [], options: .init(), anchor: now, now: hour(7), calendar: calendar)
        XCTAssertFalse(updated.contains { $0.id.hasPrefix("session.") })
        XCTAssertEqual(updated.filter(\.repeatsDaily).count, 2)
    }
    func testEmptySetupGetsOnlyActionableCoachingAndRespectsOptOut() {
        let plan = StudentNotificationPlan.make(subjects: [], chapters: [], sessions: [], logs: [], options: .init(), anchor: now, now: now, calendar: calendar)
        XCTAssertEqual(plan.count, 3)
        XCTAssertTrue(plan.allSatisfy { $0.id.hasPrefix("coach.subject.") && $0.tab == 3 })
        var options = StudentNotificationOptions(); options.coaching = false
        XCTAssertTrue(StudentNotificationPlan.make(subjects: [], chapters: [], sessions: [], logs: [], options: options, anchor: now, now: now, calendar: calendar).isEmpty)
    }
    func testQuietHoursDoNotMoveExplicitSessionTimeAndCategoriesAreIndependent() {
        let (subject, chapter, session) = fixture(); session.start = hour(23)
        var options = StudentNotificationOptions(); options.morningHour = 2; options.evening = false; options.coaching = false
        let plan = StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [session], logs: [], options: options, anchor: now, now: hour(0), calendar: calendar)
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan.first?.date, session.start)
        options.sessions = false
        XCTAssertTrue(StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [session], logs: [], options: options, anchor: now, now: hour(0), calendar: calendar).isEmpty)
    }
    func testStudyingResetsTheInactivityMilestones() {
        let (subject, chapter, _) = fixture()
        let log = FocusLog(minutes: 25, date: hour(10))
        let plan = StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [], logs: [log], options: .init(), anchor: now.addingTimeInterval(-10 * 86400), now: hour(12), calendar: calendar)
        let nudges = plan.filter { $0.id.hasPrefix("coach.return.") }
        XCTAssertEqual(nudges.count, 2)
        XCTAssertTrue(nudges.allSatisfy { $0.date >= hour(18, day: 3) })
    }
    func testWeeklyEncouragementAndNotificationPreferencesSurviveBackup() throws {
        let (subject, chapter, _) = fixture()
        let log = FocusLog(minutes: 25, date: hour(10))
        let plan = StudentNotificationPlan.make(subjects: [subject], chapters: [chapter], sessions: [], logs: [log], options: .init(), anchor: now, now: hour(12), calendar: calendar)
        XCTAssertTrue(plan.contains { $0.id == "coach.weekly" && $0.body.contains("25 min") && $0.tab == 4 })
        let container = try Storage.container(memory: true)
        var backup = try StudyBackup(db: container.mainContext)
        var options = StudentNotificationOptions(); options.morningHour = 9; options.evening = false
        backup.preferences.notificationOptions = options
        let restored = try StudyBackup.decode(JSONEncoder().encode(backup))
        XCTAssertEqual(restored.preferences.notificationOptions, options)
        options.morningHour = 27
        backup.preferences.notificationOptions = options
        XCTAssertThrowsError(try StudyBackup.decode(JSONEncoder().encode(backup)))
    }
    func testCapacityKeepsEachNotificationFamilyAndStableIdentifiers() {
        var notices = (0..<100).map { StudyReminder(id: "session.\($0)", title: "Séance", body: "", date: now.addingTimeInterval(Double($0))) }
        for family in ["morning", "evening", "exam", "deadline", "review", "coach"] {
            notices.append(StudyReminder(id: family + ".one", title: family, body: "", date: now.addingTimeInterval(1000)))
        }
        let selected = StudentNotificationPlan.limited(notices, capacity: 56)
        XCTAssertEqual(selected.count, 56)
        XCTAssertEqual(Set(selected.map(\.id)).count, 56)
        XCTAssertTrue(selected.contains { $0.id == "exam.one" })
        XCTAssertTrue(selected.contains { $0.id == "evening.one" })
        XCTAssertTrue(StudentNotificationPlan.limited(notices, capacity: 0).isEmpty)
    }
    func testTimerPlansBothTransitionsAndCancelsWhenPausedOrReset() {
        var timer = FocusTimerSnapshot(end: now.addingTimeInterval(1500).timeIntervalSince1970, length: 1500, remaining: 0, resting: false, runID: UUID().uuidString, breakSeconds: 300)
        let notifications = timer.notifications(now: now)
        XCTAssertEqual(notifications.count, 2)
        XCTAssertEqual(notifications[0].date, now.addingTimeInterval(1500))
        XCTAssertEqual(notifications[1].date, now.addingTimeInterval(1800))
        timer.resting = true
        XCTAssertEqual(timer.notifications(now: now).map(\.id), ["restEnd"])
        timer.end = 0; timer.remaining = 100
        XCTAssertTrue(timer.notifications(now: now).isEmpty)
        timer.length = 0
        XCTAssertTrue(timer.notifications(now: now).isEmpty)
    }
    func testExpiredFocusRecordsOnceAndStartsRestAtTheOriginalEnd() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let suite = "Studaya.TimerTests." + UUID().uuidString
        let p = UserDefaults(suiteName: suite)!
        defer { p.removePersistentDomain(forName: suite) }
        p.set(1500, forKey: "timerLength"); p.set(now.timeIntervalSince1970 - 10, forKey: "timerEnd")
        p.set(UUID().uuidString, forKey: "focusRunID"); p.set(5, forKey: "breakMinutes")
        XCTAssertNotNil(try FocusLifecycle.reconcile(db, preferences: p, now: now))
        XCTAssertTrue(p.bool(forKey: "timerRest"))
        XCTAssertEqual(p.double(forKey: "timerEnd"), now.timeIntervalSince1970 + 290)
        XCTAssertNil(try FocusLifecycle.reconcile(db, preferences: p, now: now))
        XCTAssertEqual(try db.fetch(FetchDescriptor<FocusLog>()).count, 1)
        XCTAssertEqual(try db.fetch(FetchDescriptor<FocusLog>()).first?.minutes, 25)
        try FocusLifecycle.reconcile(db, preferences: p, now: now.addingTimeInterval(400))
        XCTAssertEqual(p.integer(forKey: "timerLength"), 0)
        XCTAssertFalse(p.bool(forKey: "timerRest"))
        XCTAssertEqual(try db.fetch(FetchDescriptor<FocusLog>()).count, 1)
    }
    func testDelayedReturnRebuildsFutureSessionsFromReturnTime() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, chapter, _) = fixture()
        db.insert(subject); db.insert(chapter); try db.save()
        let suite = "Studaya.TimerTests." + UUID().uuidString
        let p = UserDefaults(suiteName: suite)!; defer { p.removePersistentDomain(forName: suite) }
        p.set(1500, forKey: "timerLength"); p.set(now.timeIntervalSince1970 - 7200, forKey: "timerEnd")
        p.set(UUID().uuidString, forKey: "focusRunID")
        p.set(subject.id.uuidString, forKey: "focusSubject"); p.set(chapter.id.uuidString, forKey: "focusChapter")
        try FocusLifecycle.reconcile(db, preferences: p, now: now)
        let sessions = try db.fetch(FetchDescriptor<Session>())
        XCTAssertTrue(sessions.filter { !$0.done }.allSatisfy { $0.start >= now })
        XCTAssertEqual(try db.fetch(FetchDescriptor<FocusLog>()).count, 1)
    }
    func testReturningAfterWholeCycleDoesNotStartALateBreak() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let suite = "Studaya.TimerTests." + UUID().uuidString
        let p = UserDefaults(suiteName: suite)!; defer { p.removePersistentDomain(forName: suite) }
        p.set(1500, forKey: "timerLength"); p.set(now.timeIntervalSince1970 - 3600, forKey: "timerEnd")
        p.set(UUID().uuidString, forKey: "focusRunID")
        try FocusLifecycle.reconcile(db, preferences: p, now: now)
        XCTAssertEqual(p.double(forKey: "timerEnd"), 0)
        XCTAssertEqual(p.integer(forKey: "timerLength"), 0)
        XCTAssertEqual(try db.fetch(FetchDescriptor<FocusLog>()).count, 1)
    }
}
