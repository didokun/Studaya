import XCTest
import SwiftData
@testable import Studaya

@MainActor final class StudentFeaturesTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1794211200)
    var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!; return c }
    let availability = Availability(weekdays: Set(1...7), startHour: 17, endHour: 19, minutes: 30)
    func testSubjectCodesUseEveryWordAndAllowCustomOverrides() {
        XCTAssertEqual(SubjectCode.initials("  Analyse numérique  "), "AN")
        XCTAssertEqual(SubjectCode.initials("Économie et gestion"), "EEG")
        XCTAssertEqual(SubjectCode.initials("Physique-chimie"), "PC")
        XCTAssertEqual(SubjectCode.initials(""), "")
        let subject = Subject("Analyse numérique", exam: now)
        XCTAssertEqual(subject.displayCode, "AN")
        XCTAssertEqual(subject.compactTitle("Analyse numérique · Analyse numérique"), "AN")
        subject.name = "Analyse numérique avancée"
        XCTAssertEqual(subject.displayCode, "ANA")
        subject.code = " math-101 "
        XCTAssertEqual(subject.displayCode, "MATH-101")
        subject.name = "Autre nom"
        XCTAssertEqual(subject.displayCode, "MATH-101")
        subject.code = ""
        XCTAssertEqual(subject.displayCode, "AN")
    }
    func testSubjectCodePersistsInPathAndBackupAndUpdatesExistingSessionLabels() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        var draft = PathSubject(); draft.name = "Analyse numérique"; draft.code = " ana "
        draft.units[0].name = "Matrices"; draft.units[0].start = nil
        try RevisionPath.create([draft], db: db, now: now)
        let subject = try XCTUnwrap(db.fetch(FetchDescriptor<Subject>()).first)
        let chapter = try XCTUnwrap(db.fetch(FetchDescriptor<Chapter>()).first)
        XCTAssertEqual(subject.code, "ANA")
        let session = Session(chapter, subject: subject, start: now, minutes: 30)
        XCTAssertEqual(StudyLabels.session(session, subjects: [subject], chapters: [chapter]), "ANA · Matrices")
        subject.code = "AN2"
        XCTAssertEqual(StudyLabels.session(session, subjects: [subject], chapters: [chapter]), "AN2 · Matrices")
        XCTAssertEqual(session.title, "Analyse numérique · Matrices")
        let backup = try StudyBackup.decode(JSONEncoder().encode(StudyBackup(db: db)))
        let restored = try Storage.container(memory: true)
        try backup.restore(into: restored.mainContext)
        XCTAssertEqual(try restored.mainContext.fetch(FetchDescriptor<Subject>()).first?.displayCode, "AN2")
        var legacy = backup
        legacy.subjects[0].code = nil
        let oldStore = try Storage.container(memory: true)
        try legacy.restore(into: oldStore.mainContext)
        XCTAssertEqual(try oldStore.mainContext.fetch(FetchDescriptor<Subject>()).first?.displayCode, "AN")
    }
    func testDeadlineCodeIsShownOnceWithOrWithoutUnitLink() {
        let subject = Subject("Analyse numérique", exam: now)
        let item = StudyDeadline(subject: subject.id); item.title = subject.name
        XCTAssertEqual(StudyLabels.deadline(item, subjects: [subject], chapters: []), "Contrôle · AN")
        let chapter = Chapter("Matrices", subject: subject.id, target: 2)
        item.chapterID = chapter.id
        XCTAssertEqual(StudyLabels.deadline(item, subjects: [subject], chapters: [chapter]), "Contrôle · AN · Matrices")
    }
    func seed(_ db: ModelContext) -> (Subject, Chapter) {
        let subject = Subject("Mathématiques", exam: calendar.date(byAdding: .day, value: 10, to: now)!)
        let chapter = Chapter("Intégrales", subject: subject.id, target: 3)
        db.insert(subject); db.insert(chapter)
        return (subject, chapter)
    }
    func testBlocksExcludeOverlappingSlotsIncludingSpacedSessionsAndRotation() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, _) = seed(db)
        let profile = AcademicProfile(); profile.firstDay = now; profile.courses = [subject.name]; db.insert(profile)
        let vacation = TimeBlock(); vacation.title = "Vacances"; vacation.start = now; vacation.end = now.addingTimeInterval(2 * 86400); db.insert(vacation)
        let weekly = TimeBlock(); weekly.title = "Cours"; weekly.start = calendar.date(bySettingHour: 17, minute: 15, second: 0, of: now)!; weekly.end = weekly.start.addingTimeInterval(45 * 60)
        weekly.weekday = calendar.component(.weekday, from: now); weekly.until = now.addingTimeInterval(30 * 86400); db.insert(weekly)
        try Scheduler.rebuild(db, availability: availability, now: now, calendar: calendar)
        let sessions = try db.fetch(FetchDescriptor<Session>())
        XCTAssertFalse(sessions.isEmpty)
        XCTAssertTrue(sessions.allSatisfy { !vacation.conflicts(start: $0.start, minutes: $0.minutes, calendar: calendar) && !weekly.conflicts(start: $0.start, minutes: $0.minutes, calendar: calendar) })
        XCTAssertFalse(weekly.conflicts(start: weekly.end, minutes: 30, calendar: calendar))
    }
    func testRescheduledSessionKeepsIdentityAndCountsTowardGoal() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (_, chapter) = seed(db)
        try Scheduler.rebuild(db, availability: availability, now: now, calendar: calendar)
        let session = try XCTUnwrap(db.fetch(FetchDescriptor<Session>()).first)
        let date = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now.addingTimeInterval(86400))!
        try StudyActions.reschedule(session, to: date, db: db, now: now)
        let id = session.id
        try Scheduler.rebuild(db, availability: availability, now: now, calendar: calendar)
        let items = try db.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(items.first { $0.id == id }?.start, date)
        XCTAssertTrue(items.first { $0.id == id }?.pinned == true)
        XCTAssertEqual(items.filter { $0.chapterID == chapter.id }.count, chapter.requiredSessions)
        let other = try XCTUnwrap(items.first { $0.id != id })
        XCTAssertThrowsError(try StudyActions.reschedule(other, to: date, db: db, now: now))
    }
    func testCompletingTDGeneratesSpacedReviewsWithoutReopeningIt() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (_, chapter) = seed(db)
        chapter.kind = "TD"
        XCTAssertThrowsError(try StudyActions.complete(chapter, db: db, now: now, calendar: calendar))
        chapter.exercisesDone = chapter.exerciseCount; chapter.synthesisDone = true
        try StudyActions.complete(chapter, db: db, now: now, calendar: calendar)
        let reviews = try db.fetch(FetchDescriptor<SpacedReview>())
        XCTAssertEqual(Set(reviews.map(\.intervalDays)), [2, 7, 21])
        XCTAssertTrue(chapter.completed)
        XCTAssertTrue(try db.fetch(FetchDescriptor<Session>()).isEmpty)
        reviews[0].done = true
        try StudyActions.complete(chapter, db: db, now: now, calendar: calendar)
        XCTAssertFalse(chapter.completed)
        XCTAssertEqual(try db.fetch(FetchDescriptor<SpacedReview>()).count, 1)
    }
    func testFocusRecordsOnceAndAdvancesOnlyLinkedCourse() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, chapter) = seed(db)
        let token = UUID()
        for _ in 0..<2 { try FocusRecorder.record(db: db, runID: token, subjectID: subject.id, chapterID: chapter.id, sessionID: nil, reviewID: nil, minutes: 25, date: now) }
        XCTAssertEqual(try db.fetch(FetchDescriptor<FocusLog>()).count, 1)
        let sessions = try db.fetch(FetchDescriptor<Session>())
        XCTAssertEqual(sessions.filter(\.done).count, 1)
        XCTAssertEqual(StudyCoach.progress(chapter, sessions: sessions), 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(chapter.exercisesDone, 0)
    }
    func testReminderPlanCancelsCompletedWorkAndUsesExactDeadlineTime() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, chapter) = seed(db)
        let item = StudyDeadline(subject: subject.id); item.title = "Présentation"; item.due = now.addingTimeInterval(5 * 86400 + 3600); item.reminderDays = 2
        db.insert(item)
        let review = SpacedReview(chapter: chapter.id, due: now.addingTimeInterval(2 * 86400), days: 2)
        chapter.completed = true
        let plan = ReminderPlan.make(subjects: [subject], deadlines: [item], chapters: [chapter], reviews: [review], now: now, calendar: calendar)
        XCTAssertEqual(plan.count, 6)
        XCTAssertTrue(plan.contains { $0.id == "deadline.\(item.id).due" && $0.date == item.due })
        item.done = true; review.done = true; subject.hasExam = false
        XCTAssertTrue(ReminderPlan.make(subjects: [subject], deadlines: [item], chapters: [chapter], reviews: [review], now: now, calendar: calendar).isEmpty)
    }
    func testBackupRoundTripPreservesIDsLinksAndHistory() throws {
        let source = try Storage.container(memory: true), db = source.mainContext
        let (subject, chapter) = seed(db)
        chapter.notes = "Méthode ∫"; chapter.kind = "TD"; chapter.exercisesDone = 2
        let card = Flashcard("Question", answer: "Réponse", chapter: chapter.id); db.insert(card)
        let deadline = StudyDeadline(subject: subject.id); deadline.title = "Rendu"; deadline.due = now.addingTimeInterval(5 * 86400); db.insert(deadline)
        let block = TimeBlock(); block.title = "Travail"; block.start = now; block.end = now.addingTimeInterval(3600); db.insert(block)
        let profile = AcademicProfile(); profile.program = "Licence"; profile.courses = [subject.name]; db.insert(profile)
        try FocusRecorder.record(db: db, runID: UUID(), subjectID: subject.id, chapterID: chapter.id, sessionID: nil, reviewID: nil, minutes: 25, date: now)
        let review = SpacedReview(chapter: chapter.id, due: now.addingTimeInterval(2 * 86400), days: 2); db.insert(review)
        try db.save()
        let original = try StudyBackup(db: db)
        let data = try JSONEncoder().encode(original)
        let decoded = try StudyBackup.decode(data)
        let destination = try Storage.container(memory: true)
        destination.mainContext.insert(Subject("Ancienne matière à remplacer", exam: now))
        try destination.mainContext.save()
        let old = BackupPreferences(); defer { old.apply() }
        try decoded.restore(into: destination.mainContext)
        let restored = try StudyBackup(db: destination.mainContext)
        XCTAssertEqual(restored.subjects.count, 1)
        XCTAssertEqual(restored.subjects.first?.id, subject.id)
        XCTAssertEqual(restored.chapters.first?.notes, "Méthode ∫")
        XCTAssertEqual(restored.chapters.first?.exercisesDone, 2)
        XCTAssertEqual(restored.cards.first?.chapterID, chapter.id)
        XCTAssertEqual(restored.deadlines.first?.id, deadline.id)
        XCTAssertEqual(Set(restored.sessions.map(\.id)), Set(original.sessions.map(\.id)))
        XCTAssertEqual(restored.logs.first?.chapterID, chapter.id)
        XCTAssertEqual(restored.reviews.first?.id, review.id)
        XCTAssertEqual(restored.blocks.first?.title, "Travail")
    }
    func testInvalidBackupCannotReplaceData() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, _) = seed(db); try db.save()
        var backup = try StudyBackup(db: db); backup.version = 99
        XCTAssertThrowsError(try backup.restore(into: db))
        XCTAssertEqual(try db.fetch(FetchDescriptor<Subject>()).first?.id, subject.id)
        backup.version = 1; backup.chapters[0].subjectID = UUID()
        XCTAssertThrowsError(try StudyBackup.decode(JSONEncoder().encode(backup)))
        XCTAssertEqual(try db.fetch(FetchDescriptor<Subject>()).count, 1)
    }
    func testSubjectDeletionCascadesAndPreservesUnrelatedWork() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, chapter) = seed(db)
        let other = Subject("Physique", exam: now); db.insert(other)
        db.insert(Flashcard("Q", answer: "A", chapter: chapter.id))
        db.insert(StudyDeadline(subject: subject.id))
        db.insert(SpacedReview(chapter: chapter.id, due: now.addingTimeInterval(86400), days: 2))
        try StudyActions.deleteSubject(subject, db: db); try db.save()
        XCTAssertEqual(try db.fetch(FetchDescriptor<Subject>()).map(\.id), [other.id])
        XCTAssertTrue(try db.fetch(FetchDescriptor<Chapter>()).isEmpty)
        XCTAssertTrue(try db.fetch(FetchDescriptor<Flashcard>()).isEmpty)
        XCTAssertTrue(try db.fetch(FetchDescriptor<StudyDeadline>()).isEmpty)
        XCTAssertTrue(try db.fetch(FetchDescriptor<SpacedReview>()).isEmpty)
    }
    func testReviewFocusKeepsArchiveSeparateFromCourseProgress() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let (subject, chapter) = seed(db)
        try StudyActions.complete(chapter, db: db, now: now, calendar: calendar)
        let review = try XCTUnwrap(db.fetch(FetchDescriptor<SpacedReview>()).first)
        try FocusRecorder.record(db: db, runID: UUID(), subjectID: subject.id, chapterID: chapter.id, sessionID: nil, reviewID: review.id, minutes: 25, date: now)
        XCTAssertTrue(chapter.completed)
        XCTAssertTrue(review.done)
        try StudyActions.complete(chapter, db: db, now: now, calendar: calendar)
        XCTAssertEqual(StudyCoach.progress(chapter, sessions: try db.fetch(FetchDescriptor<Session>())), 0)
    }

    func testRevisionPathCreatesLinkedWorkAndRespectsIndividualStartDates() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let profile = AcademicProfile(); profile.firstDay = now; profile.examMode = "En fin de matière"; db.insert(profile)
        let early = calendar.date(byAdding: .day, value: 3, to: now)!
        let late = calendar.date(byAdding: .day, value: 6, to: now)!
        var draft = PathSubject(); draft.name = "Maths"
        var course = PathUnit(); course.name = "Cours"; course.start = early
        var td = PathUnit(); td.name = "TD"; td.kind = "TD"; td.start = late
        draft.units = [course, td]
        var event = PathEvent(); event.title = "Exposé"; event.due = now.addingTimeInterval(14 * 86400)
        draft.presentations = [event]; draft.controls = [event]
        try RevisionPath.create([draft], db: db, now: now)
        let units = try db.fetch(FetchDescriptor<Chapter>())
        XCTAssertEqual(units.count, 2)
        XCTAssertEqual(Set(try db.fetch(FetchDescriptor<StudyDeadline>()).map(\.kind)), ["Présentation", "Contrôle"])
        let sessions = try db.fetch(FetchDescriptor<Session>())
        for unit in units {
            let work = sessions.filter { $0.chapterID == unit.id }
            XCTAssertEqual(work.count, unit.requiredSessions)
            XCTAssertTrue(work.allSatisfy { $0.start >= calendar.startOfDay(for: unit.startDate!) })
        }
        XCTAssertEqual(profile.courses, ["Maths"])
        XCTAssertEqual(try db.fetch(FetchDescriptor<Subject>()).first?.examMode, "En fin de matière")
        let backup = try StudyBackup.decode(JSONEncoder().encode(StudyBackup(db: db)))
        XCTAssertEqual(Set(backup.chapters.compactMap(\.startDate)), [early, late])
    }
    func testPathValidationRejectsExamBeforeLastCourseWithoutWriting() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        var draft = PathSubject(); draft.name = "Maths"; draft.hasExam = true; draft.exam = now
        draft.units[0].name = "TD"; draft.units[0].start = now.addingTimeInterval(86400)
        XCTAssertThrowsError(try RevisionPath.create([draft], db: db, now: now))
        XCTAssertTrue(try db.fetch(FetchDescriptor<Subject>()).isEmpty)
    }

    func testMatterOrganizationIgnoresLegacySemestersInCreationAndScheduling() throws {
        let container = try Storage.container(memory: true), db = container.mainContext
        let profile = AcademicProfile(); profile.organization = "Par matière"; profile.firstDay = now; db.insert(profile)
        let existing = Subject("Maths", exam: now.addingTimeInterval(10 * 86400))
        existing.semester = 2; existing.hasExam = false; db.insert(existing)
        var draft = PathSubject(); draft.name = "Maths"; draft.semester = 1
        draft.units[0].name = "TD"; draft.units[0].start = now
        try RevisionPath.create([draft], db: db, now: now)
        XCTAssertFalse(profile.usesSemesters)
        XCTAssertEqual(try db.fetch(FetchDescriptor<Subject>()).count, 1)
        XCTAssertEqual(existing.semester, 2)
        let sessions = try db.fetch(FetchDescriptor<Session>())
        XCTAssertFalse(sessions.isEmpty)
        XCTAssertTrue(sessions.allSatisfy { $0.start < now.addingTimeInterval(90 * 86400) })
        var duplicate = draft; duplicate.semester = 2
        XCTAssertThrowsError(try RevisionPath.validate([draft, duplicate], usesSemesters: false))
        XCTAssertNoThrow(try RevisionPath.validate([draft, duplicate], usesSemesters: true))
    }

}
