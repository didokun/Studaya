import Foundation
import SwiftData
import StoreKit

@Model final class Subject {
    var id = UUID()
    var name = ""
    var year = 1
    var semester = 1
    var examMode = "Par semestre"
    var hasExam = true
    var exam = Date()
    init(_ name: String, exam: Date) { self.name = name; self.exam = exam }
}

@Model final class Chapter {
    var id = UUID()
    var subjectID = UUID()
    var name = ""
    var notes = ""
    var startDate: Date?
    var kind = "Cours"
    var completed = false
    var synthesisDone = false
    var timelineIndex: Int?
    var exerciseCount = 5
    var exercisesDone = 0
    var confidence = 2
    var target = 2
    var requiredSessions: Int { target + (confidence == 1 ? 1 : 0) }
    init(_ name: String, subject: UUID, target: Int) {
        self.name = name; subjectID = subject; self.target = target
    }
}

@Model final class Flashcard {
    var id = UUID()
    var chapterID = UUID()
    var question = ""
    var answer = ""
    var known = false
    init(_ question: String, answer: String, chapter: UUID) {
        self.question = question; self.answer = answer; chapterID = chapter
    }
}

@Model final class Session {
    var id = UUID()
    var subjectID: UUID?
    var reviewID: UUID?
    var pinned = false
    var chapterID = UUID()
    var deadlineID: UUID?
    var activity = "Apprentissage"
    var title = ""
    var start = Date()
    var minutes = 25
    var done = false
    init(course: String, start: Date, minutes: Int) {
        title = course; activity = "Révision de cours"; self.start = start; self.minutes = minutes
    }
    init(_ chapter: Chapter, subject: Subject, start: Date, minutes: Int) {
        subjectID = subject.id; chapterID = chapter.id; title = subject.name + " · " + chapter.name
        self.start = start; self.minutes = minutes
    }
}

@Model final class FocusLog {
    var id = UUID()
    var chapterID: UUID?
    var sessionID: UUID?
    var runID: UUID?
    var subjectID: UUID?
    var date = Date()
    var minutes = 25
    init(minutes: Int, date: Date = .now) { self.minutes = minutes; self.date = date }
}

enum Storage {
    static let schema = Schema([Subject.self, Chapter.self, Flashcard.self, Session.self, FocusLog.self, AcademicProfile.self, StudyDeadline.self, TimeBlock.self, SpacedReview.self])
    static func container(memory: Bool = false, cloud: ModelConfiguration.CloudKitDatabase = .none) throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: memory, cloudKitDatabase: cloud)])
    }
}

