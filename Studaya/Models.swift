import Foundation
import SwiftData
import StoreKit

@Model final class Subject {
    var id = UUID()
    var name = ""
    var code = ""
    var displayCode: String { SubjectCode.resolve(code, name: name) }
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


// Empty storage means automatic initials, including for existing subjects.
enum SubjectCode {
    static func initials(_ name: String) -> String {
        name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .compactMap(\.first).map(String.init).joined().uppercased()
    }
    static func normalize(_ code: String) -> String {
        code.filter { !$0.isWhitespace }.uppercased()
    }
    static func resolve(_ code: String, name: String) -> String {
        let custom = normalize(code)
        return custom.isEmpty ? initials(name) : custom
    }
}

extension Subject {
    func compactTitle(_ title: String) -> String {
        if title == name || title == name + " · " + name { return displayCode }
        let prefix = name + " · "
        return title.hasPrefix(prefix) ? displayCode + " · " + title.dropFirst(prefix.count) : title
    }
}

enum StudyLabels {
    static func deadline(_ item: StudyDeadline, subjects: [Subject], chapters: [Chapter]) -> String {
        guard let subject = subjects.first(where: { $0.id == item.subjectID }) else { return L10n.key(item.kind) + " · " + item.title }
        let target = chapters.first { $0.id == item.chapterID }?.name ?? subject.compactTitle(item.title)
        return L10n.key(item.kind) + " · " + subject.displayCode + (target == subject.displayCode ? "" : " · " + target)
    }

    static func session(_ session: Session, subjects: [Subject], chapters: [Chapter] = []) -> String {
        guard let subject = subjects.first(where: { $0.id == session.subjectID }) else { return session.title }
        if let chapter = chapters.first(where: { $0.id == session.chapterID }) {
            return subject.displayCode + " · " + chapter.name
        }
        return subject.compactTitle(session.title)
    }
}
