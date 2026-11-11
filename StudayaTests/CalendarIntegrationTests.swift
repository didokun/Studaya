import XCTest
import SwiftData
import EventKit
@testable import Studaya

@MainActor final class CalendarIntegrationTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1794380400)
    func testDayMarkersDifferentiateTypesAndDoNotDuplicateSubjectSessions() {
        let subject = Subject("Analyse numérique", exam: now)
        let chapter = Chapter("Matrices", subject: subject.id, target: 2)
        let first = Session(chapter, subject: subject, start: now, minutes: 25)
        let second = Session(chapter, subject: subject, start: now.addingTimeInterval(3600), minutes: 25)
        let control = StudyDeadline(subject: subject.id); control.due = now; control.kind = "Contrôle"
        let presentation = StudyDeadline(subject: subject.id); presentation.due = now; presentation.kind = "Présentation"
        let undated = StudyDeadline(subject: subject.id); undated.due = now; undated.hasDueDate = false
        let markers = CalendarDayPlan.markers(on: now, subjects: [subject], sessions: [first, second], deadlines: [control, presentation, undated], reviews: [], chapters: [chapter])
        XCTAssertEqual(markers.map(\.kind), [.exam, .control, .presentation, .revision])
        XCTAssertTrue(markers.allSatisfy { $0.code == "AN" && $0.symbol == StudyDesign.symbol(for: subject.name) })
        XCTAssertEqual(markers.filter { $0.kind == .revision }.count, 1)
    }
    func testExportUsesStableIDsNewDatesAndCodesAndSkipsUndatedDeadlines() {
        let subject = Subject("Analyse numérique", exam: now); subject.code = "ANA"
        let chapter = Chapter("Matrices", subject: subject.id, target: 2)
        let session = Session(chapter, subject: subject, start: now, minutes: 25)
        let control = StudyDeadline(subject: subject.id); control.due = now; control.chapterID = chapter.id
        let undated = StudyDeadline(subject: subject.id); undated.hasDueDate = false
        let first = CalendarExportPlan.make(subjects: [subject], sessions: [session], deadlines: [control, undated], chapters: [chapter], reviews: [])
        XCTAssertEqual(first.count, 3)
        let exported = first.first { $0.id.hasPrefix("session.") }!
        XCTAssertEqual(exported.title, "ANA · Matrices")
        XCTAssertEqual(exported.end.timeIntervalSince(exported.start), 1500)
        XCTAssertTrue(first.first { $0.id.hasPrefix("exam.") }!.allDay)
        session.start = now.addingTimeInterval(7200); session.done = true; subject.code = "AN2"
        let second = CalendarExportPlan.make(subjects: [subject], sessions: [session], deadlines: [control], chapters: [chapter], reviews: [])
        XCTAssertEqual(Set(first.map(\.id)), Set(second.map(\.id)))
        XCTAssertEqual(second.first { $0.id == exported.id }?.title, "✓ AN2 · Matrices")
        XCTAssertEqual(second.first { $0.id == exported.id }?.start, session.start)
    }
    func testOwnershipCannotTargetAnotherInstallOrPersonalEvent() {
        let owner = CalendarExportOwnership(owner: UUID().uuidString)
        let other = CalendarExportOwnership(owner: UUID().uuidString)
        let key = "session." + UUID().uuidString
        XCTAssertEqual(owner.key(owner.url(key)), key)
        XCTAssertNil(owner.key(other.url(key)))
        XCTAssertNil(owner.key(URL(string: "https://example.com/" + key)))
        XCTAssertNil(owner.key(URL(string: "studaya://calendar-export/\(owner.owner)/session.invalid")))
        XCTAssertNil(owner.key(URL(string: owner.url(key).absoluteString + "?personal=1")))
        XCTAssertNil(owner.key(nil))
    }
    func testRealEventStoreUpdatesWithoutDuplicatesAndDeletesOnlyOwnedEvents() async throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { throw XCTSkip("Grant Calendar access in the simulator UI test first.") }
        let suite = "Studaya.CalendarTests." + UUID().uuidString
        let preferences = UserDefaults(suiteName: suite)!
        let store = EKEventStore()
        defer {
            if let id = preferences.string(forKey: "appleCalendarID"), let calendar = store.calendar(withIdentifier: id) { try? store.removeCalendar(calendar, commit: true) }
            preferences.removePersistentDomain(forName: suite)
        }
        let container = try Storage.container(memory: true), db = container.mainContext
        let subject = Subject("Analyse numérique", exam: now.addingTimeInterval(86400))
        let chapter = Chapter("Matrices", subject: subject.id, target: 2)
        let session = Session(chapter, subject: subject, start: now, minutes: 25)
        db.insert(subject); db.insert(chapter); db.insert(session); try db.save()
        let sync = AppleCalendarSync(store: store, preferences: preferences)
        await sync.connect(db)
        let id = try XCTUnwrap(preferences.string(forKey: "appleCalendarID"), sync.status)
        let calendar = try XCTUnwrap(store.calendar(withIdentifier: id))
        func events() -> [EKEvent] { store.events(matching: store.predicateForEvents(withStart: now.addingTimeInterval(-86400), end: now.addingTimeInterval(10 * 86400), calendars: [calendar])) }
        XCTAssertEqual(events().count, 2, sync.status)
        let originalIDs = Set(events().compactMap(\.eventIdentifier))
        session.start = now.addingTimeInterval(7200); subject.code = "ANA"
        sync.refresh(db)
        XCTAssertEqual(events().count, 2, sync.status)
        XCTAssertEqual(Set(events().compactMap(\.eventIdentifier)), originalIDs)
        XCTAssertTrue(events().contains { $0.title == "ANA · Matrices" && $0.startDate == session.start })
        let personal = EKEvent(eventStore: store)
        personal.calendar = calendar; personal.title = "Rendez-vous personnel"; personal.startDate = now; personal.endDate = now.addingTimeInterval(3600)
        try store.save(personal, span: .thisEvent, commit: true)
        sync.deleteExported()
        XCTAssertEqual(events().map(\.title), ["Rendez-vous personnel"])
        XCTAssertFalse(preferences.bool(forKey: AppleCalendarSync.enabledKey))
        sync.refresh(db)
        XCTAssertEqual(events().count, 1)
        XCTAssertEqual(try db.fetch(FetchDescriptor<Subject>()).count, 1)
        XCTAssertEqual(try db.fetch(FetchDescriptor<Session>()).count, 1)
    }
    func testRepresentedSpacedReviewDoesNotDuplicateItsSession() {
        let subject = Subject("Maths", exam: now); subject.hasExam = false
        let chapter = Chapter("TD intégrales", subject: subject.id, target: 2)
        let review = SpacedReview(chapter: chapter.id, due: now, days: 2)
        let session = Session(chapter, subject: subject, start: now, minutes: 25); session.reviewID = review.id
        let items = CalendarExportPlan.make(subjects: [subject], sessions: [session], deadlines: [], chapters: [chapter], reviews: [review])
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].id.hasPrefix("session."))
    }
}
