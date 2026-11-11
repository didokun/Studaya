import Foundation
import SwiftData

@Model final class SpacedReview {
    var id = UUID()
    var chapterID = UUID()
    var due = Date()
    var done = false
    var intervalDays = 2
    init(chapter: UUID, due: Date, days: Int) { chapterID = chapter; self.due = due; intervalDays = days }
}

enum StudyError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

@MainActor enum StudyActions {
    static func complete(_ chapter: Chapter, db: ModelContext, now: Date = .now, calendar: Calendar = .current) throws {
        if !chapter.completed && chapter.kind == "TD" && (chapter.exercisesDone < chapter.exerciseCount || !chapter.synthesisDone) {
            throw StudyError.invalid("Termine les exercices et valide la synthèse avant de classer ce TD.")
        }
        let reviews = try db.fetch(FetchDescriptor<SpacedReview>()).filter { $0.chapterID == chapter.id && !$0.done }
        for review in reviews { db.delete(review) }
        chapter.completed.toggle()
        if chapter.completed {
            for days in [2, 7, 21] {
                let day = calendar.date(byAdding: .day, value: days, to: now)!
                let due = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day)!
                db.insert(SpacedReview(chapter: chapter.id, due: due, days: days))
            }
        }
        try Scheduler.rebuild(db)
    }
    static func reschedule(_ session: Session, to date: Date, db: ModelContext, now: Date = .now) throws {
        guard !session.done, date >= now else { throw StudyError.invalid("Choisis un créneau futur pour une séance à faire.") }
        let limit = date.addingTimeInterval(Double(session.minutes * 60))
        let others = try db.fetch(FetchDescriptor<Session>())
        let blocks = try db.fetch(FetchDescriptor<TimeBlock>())
        guard !others.contains(where: { $0.id != session.id && $0.start < limit && $0.start.addingTimeInterval(Double($0.minutes * 60)) > date }),
              !blocks.contains(where: { $0.conflicts(start: date, minutes: session.minutes) }) else {
            throw StudyError.invalid("Ce créneau chevauche une séance ou une indisponibilité.")
        }
        let subjects = try db.fetch(FetchDescriptor<Subject>())
        let chapters = try db.fetch(FetchDescriptor<Chapter>())
        if let start = chapters.first(where: { $0.id == session.chapterID })?.startDate,
           date < Calendar.current.startOfDay(for: start) { throw StudyError.invalid("La séance doit avoir lieu après la date de début du cours ou TD.") }
        let subjectID = session.subjectID ?? chapters.first(where: { $0.id == session.chapterID })?.subjectID
        var due: Date?
        if let deadlineID = session.deadlineID { due = try db.fetch(FetchDescriptor<StudyDeadline>()).first { $0.id == deadlineID && $0.hasDueDate }?.due }
        else if let subject = subjects.first(where: { $0.id == subjectID }), subject.hasExam { due = subject.exam }
        if let due, limit > due { throw StudyError.invalid("La séance doit se terminer avant son échéance.") }
        session.start = date; session.pinned = true
        try Scheduler.rebuild(db)
    }
    static func deleteChapter(_ chapter: Chapter, db: ModelContext) throws {
        for x in try db.fetch(FetchDescriptor<Flashcard>()) where x.chapterID == chapter.id { db.delete(x) }
        for x in try db.fetch(FetchDescriptor<SpacedReview>()) where x.chapterID == chapter.id { db.delete(x) }
        for x in try db.fetch(FetchDescriptor<Session>()) where x.chapterID == chapter.id { db.delete(x) }
        for x in try db.fetch(FetchDescriptor<FocusLog>()) where x.chapterID == chapter.id { x.chapterID = nil; x.sessionID = nil }
        let subjectName = try db.fetch(FetchDescriptor<Subject>()).first { $0.id == chapter.subjectID }?.name ?? "Matière"
        for item in try db.fetch(FetchDescriptor<StudyDeadline>()) where item.chapterID == chapter.id { item.chapterID = nil; item.title = subjectName }
        db.delete(chapter)
    }
    static func deleteDeadline(_ item: StudyDeadline, db: ModelContext) throws {
        for x in try db.fetch(FetchDescriptor<Session>()) where x.deadlineID == item.id { db.delete(x) }
        db.delete(item)
    }
    static func deleteSubject(_ subject: Subject, db: ModelContext) throws {
        for x in try db.fetch(FetchDescriptor<Chapter>()) where x.subjectID == subject.id { try deleteChapter(x, db: db) }
        for x in try db.fetch(FetchDescriptor<StudyDeadline>()) where x.subjectID == subject.id { try deleteDeadline(x, db: db) }
        for x in try db.fetch(FetchDescriptor<Session>()) where x.subjectID == subject.id || (x.subjectID == nil && x.activity == "Révision de cours" && x.title == subject.name) { db.delete(x) }
        for x in try db.fetch(FetchDescriptor<FocusLog>()) where x.subjectID == subject.id { x.subjectID = nil; x.sessionID = nil }
        db.delete(subject)
        let names = try db.fetch(FetchDescriptor<Subject>()).filter { $0.id != subject.id }.map(\.name)
        for profile in try db.fetch(FetchDescriptor<AcademicProfile>()) { profile.courses = Array(Set(names)).sorted() }
    }
}

@MainActor enum FocusRecorder {
    @discardableResult static func record(db: ModelContext, runID: UUID, subjectID: UUID?, chapterID: UUID?, sessionID: UUID?, reviewID: UUID?, minutes: Int, date: Date) throws -> FocusLog {
        if let old = try db.fetch(FetchDescriptor<FocusLog>()).first(where: { $0.runID == runID }) { return old }
        let subjects = try db.fetch(FetchDescriptor<Subject>())
        let chapters = try db.fetch(FetchDescriptor<Chapter>())
        let sessions = try db.fetch(FetchDescriptor<Session>())
        let chapter = chapters.first { $0.id == chapterID }
        let session = sessions.first { $0.id == sessionID }
        let review = try db.fetch(FetchDescriptor<SpacedReview>()).first { $0.id == reviewID }
        let actualSubjectID = chapter?.subjectID ?? session?.subjectID ?? subjectID
        let log = FocusLog(minutes: minutes, date: date)
        log.runID = runID; log.subjectID = subjects.first { $0.id == actualSubjectID }?.id
        log.chapterID = chapter?.id; log.sessionID = session?.id
        db.insert(log)
        if let review { review.done = true }
        if let session, !session.done { session.done = true }
        else if let chapter, let subject = subjects.first(where: { $0.id == chapter.subjectID }), session == nil {
            let completed = Session(chapter, subject: subject, start: date.addingTimeInterval(Double(-minutes * 60)), minutes: minutes)
            completed.done = true; completed.reviewID = review?.id
            completed.activity = review == nil ? "Focus · " + chapter.kind : "Rappel espacé"
            db.insert(completed); log.sessionID = completed.id
        }
        try Scheduler.rebuild(db, now: date)
        return log
    }
}
