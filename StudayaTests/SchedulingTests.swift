import XCTest
import SwiftData
@testable import Studaya

@MainActor final class SchedulingTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1794211200)
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    let window = Availability(weekdays: Set(1...7), startHour: 17, endHour: 18, minutes: 30)
    func seed(_ db: ModelContext, days: Int, target: Int) -> Chapter {
        let subject = Subject("Matière \(days)", exam: calendar.date(byAdding: .day, value: days, to: now)!)
        db.insert(subject)
        let chapter = Chapter("Chapitre", subject: subject.id, target: target)
        db.insert(chapter)
        return chapter
    }
    func testPriorityCapacityAndExamCutoff() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        let urgent = seed(db, days: 1, target: 3)
        _ = seed(db, days: 2, target: 3)
        XCTAssertEqual(try Scheduler.rebuild(db, availability: window, now: now, calendar: calendar), 2)
        let items = try db.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.start)]))
        XCTAssertEqual(items.count, 4)
        XCTAssertEqual(items.prefix(2).map(\.chapterID), [urgent.id, urgent.id])
        XCTAssertEqual(Set(items.map(\.start)).count, 4)
        XCTAssertTrue(items.allSatisfy { calendar.component(.hour, from: $0.start) == 17 })
    }
    func testReplanPreservesHistoryAndIsRepeatable() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        _ = seed(db, days: 3, target: 4)
        try Scheduler.rebuild(db, availability: window, now: now, calendar: calendar)
        let first = try XCTUnwrap(db.fetch(FetchDescriptor<Session>(sortBy: [SortDescriptor(\.start)])).first)
        first.done = true
        let later = calendar.date(byAdding: .day, value: 1, to: now)!
        for _ in 0..<2 {
            XCTAssertEqual(try Scheduler.rebuild(db, availability: window, now: later, calendar: calendar), 0)
            let sessions = try db.fetch(FetchDescriptor<Session>())
            XCTAssertEqual(sessions.count, 4)
            XCTAssertEqual(sessions.filter(\.done).first?.persistentModelID, first.persistentModelID)
            XCTAssertTrue(sessions.filter { !$0.done }.allSatisfy { $0.start >= later })
        }
    }
    func testTwoYearCourseRotationSurvivesReplanning() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        let profile = AcademicProfile()
        profile.firstDay = now; profile.years = 2; profile.courses = ["Biologie", "Chimie"]
        db.insert(profile)
        let mondays = Availability(weekdays: [2], startHour: 17, endHour: 18, minutes: 30)
        try Scheduler.rebuild(db, availability: mondays, now: now, calendar: calendar)
        let query = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.start)])
        let items = try db.fetch(query)
        XCTAssertEqual(items.count, 105)
        XCTAssertEqual(items.prefix(2).map(\.title), profile.courses)
        XCTAssertTrue(items.allSatisfy { calendar.component(.weekday, from: $0.start) == 2 })
        let first = try XCTUnwrap(items.first)
        first.done = true
        _ = seed(db, days: 1, target: 1)
        try Scheduler.rebuild(db, availability: mondays, now: now, calendar: calendar)
        let rebuilt = try db.fetch(query)
        XCTAssertEqual(rebuilt.count, 106)
        XCTAssertEqual(Set(rebuilt.map(\.start)).count, rebuilt.count)
        XCTAssertEqual(rebuilt.filter(\.done).first?.persistentModelID, first.persistentModelID)
        XCTAssertLessThan(try XCTUnwrap(rebuilt.last).start, calendar.date(byAdding: .year, value: 2, to: now)!)
    }
    func testUnavailableWeekdaysAndPastExam() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        _ = seed(db, days: -1, target: 2)
        _ = seed(db, days: 1, target: 1)
        var unavailable = window
        unavailable.weekdays = [calendar.component(.weekday, from: calendar.date(byAdding: .day, value: 1, to: now)!)]
        XCTAssertEqual(try Scheduler.rebuild(db, availability: unavailable, now: now, calendar: calendar), 3)
        XCTAssertTrue(try db.fetch(FetchDescriptor<Session>()).isEmpty)
    }
    func testDeadlinePreparationWinsBeforeLaterExamAndStopsWhenDone() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        _ = seed(db, days: 5, target: 2)
        let subject = Subject("Projet", exam: now)
        subject.hasExam = false
        db.insert(subject)
        let item = StudyDeadline(subject: subject.id)
        item.title = "Présentation"; item.due = calendar.date(byAdding: .day, value: 1, to: now)!
        item.preparationSessions = 2
        db.insert(item)
        try Scheduler.rebuild(db, availability: window, now: now, calendar: calendar)
        let query = FetchDescriptor<Session>(sortBy: [SortDescriptor(\.start)])
        let sessions = try db.fetch(query)
        XCTAssertEqual(sessions.prefix(2).map(\.deadlineID), [item.id, item.id])
        let first = try XCTUnwrap(sessions.first)
        first.done = true; item.done = true
        try Scheduler.rebuild(db, availability: window, now: now, calendar: calendar)
        let rebuilt = try db.fetch(query)
        XCTAssertEqual(rebuilt.filter { $0.deadlineID == item.id }.count, 1)
        XCTAssertTrue(rebuilt.contains { $0.persistentModelID == first.persistentModelID && $0.done })
    }

    func testCompletedTDIsExcludedAndProgressRecommendsSynthesis() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        let td = seed(db, days: 3, target: 2)
        td.kind = "TD"; td.exerciseCount = 3; td.exercisesDone = 3
        XCTAssertEqual(StudyCoach.progress(td, sessions: []), 1)
        XCTAssertTrue(StudyCoach.advice(td, sessions: []).contains("synthèse"))
        td.synthesisDone = true; td.completed = true
        XCTAssertEqual(try Scheduler.rebuild(db, availability: window, now: now, calendar: calendar), 0)
        XCTAssertTrue(try db.fetch(FetchDescriptor<Session>()).isEmpty)
        XCTAssertEqual(try db.fetch(FetchDescriptor<Chapter>()).count, 1)
    }

    func testFutureAcademicYearDoesNotSchedulePreparationEarly() throws {
        let container = try Storage.container(memory: true)
        let db = container.mainContext
        let profile = AcademicProfile()
        profile.firstDay = now; profile.years = 2
        db.insert(profile)
        let chapter = seed(db, days: 370, target: 2)
        let subject = try XCTUnwrap(db.fetch(FetchDescriptor<Subject>()).first)
        subject.year = 2
        try Scheduler.rebuild(db, availability: window, now: now, calendar: calendar)
        let sessions = try db.fetch(FetchDescriptor<Session>())
        let secondYear = calendar.date(byAdding: .year, value: 1, to: now)!
        XCTAssertEqual(sessions.count, chapter.requiredSessions)
        XCTAssertTrue(sessions.allSatisfy { $0.start >= secondYear })
    }

}
