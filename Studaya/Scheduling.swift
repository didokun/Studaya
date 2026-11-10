import Foundation
import SwiftData

struct Availability {
    var weekdays: Set<Int>
    var startHour: Int
    var endHour: Int
    var minutes: Int

    static var saved: Self {
        let defaults = StudyPreferences.current
        return Self(weekdays: Set(defaults.array(forKey: "weekdays") as? [Int] ?? [2,3,4,5,6]),
                    startHour: defaults.object(forKey: "startHour") as? Int ?? 17,
                    endHour: defaults.object(forKey: "endHour") as? Int ?? 19,
                    minutes: defaults.object(forKey: "sessionMinutes") as? Int ?? 25)
    }
    func persist() {
        let defaults = StudyPreferences.current
        defaults.set(Array(weekdays), forKey: "weekdays")
        defaults.set(startHour, forKey: "startHour")
        defaults.set(endHour, forKey: "endHour")
        defaults.set(minutes, forKey: "sessionMinutes")
    }
}

enum Scheduler {
    private struct Work {
        let id: UUID
        let subject: Subject
        let chapter: Chapter?
        let deadline: StudyDeadline?
        let due: Date
        let availableFrom: Date
        let required: Int
        var name: String { chapter?.name ?? deadline?.title ?? "" }
        var confidence: Int { chapter?.confidence ?? 2 }
    }
    /// Rebuild pending work in one save. Completed blocks retain identity and reserve their time.
    @discardableResult static func rebuild(_ db: ModelContext, availability a: Availability = .saved,
                                           now: Date = .now, calendar: Calendar = .current) throws -> Int {
        let subjects = try db.fetch(FetchDescriptor<Subject>())
        let deadlines = try db.fetch(FetchDescriptor<StudyDeadline>()).filter { !$0.done }
        let chapters = try db.fetch(FetchDescriptor<Chapter>())
        let sessions = try db.fetch(FetchDescriptor<Session>())
        func relevant(_ session: Session) -> Bool {
            if let id = session.deadlineID { return deadlines.contains { $0.id == id } }
            if let chapter = chapters.first(where: { $0.id == session.chapterID }) { return !chapter.completed }
            return session.subjectID == nil || subjects.contains { $0.id == session.subjectID }
        }
        let completed = sessions.filter { $0.done || ($0.pinned && relevant($0)) }
        let unavailable = try db.fetch(FetchDescriptor<TimeBlock>())
        var assigned = Dictionary(grouping: completed.filter { $0.reviewID == nil }, by: { $0.deadlineID ?? $0.chapterID }).mapValues(\.count)
        let profile = try db.fetch(FetchDescriptor<AcademicProfile>()).first
        func availableFrom(_ subject: Subject) -> Date {
            guard let profile else { return .distantPast }
            let months = (subject.year - 1) * 12 + (profile.usesSemesters ? (subject.semester - 1) * 6 : 0)
            return calendar.date(byAdding: .month, value: months, to: calendar.startOfDay(for: profile.firstDay)) ?? now
        }
        let subjectByID = Dictionary(subjects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let eligible: [Work] = chapters.compactMap { chapter in
            guard !chapter.completed, let subject = subjectByID[chapter.subjectID] else { return nil }
            let dates = deadlines.filter { $0.subjectID == subject.id }.map(\.due) + (subject.hasExam ? [subject.exam] : [])
            let first = max(availableFrom(subject), calendar.startOfDay(for: chapter.startDate ?? .distantPast))
            let horizon = calendar.date(byAdding: .day, value: 90, to: max(first, now))!
            let due = dates.filter { calendar.startOfDay(for: $0) > first }.min() ?? dates.min() ?? horizon
            return Work(id: chapter.id, subject: subject, chapter: chapter, deadline: nil, due: due, availableFrom: first, required: chapter.requiredSessions)
        } + deadlines.compactMap { item in
            guard let subject = subjectByID[item.subjectID] else { return nil }
            return Work(id: item.id, subject: subject, chapter: nil, deadline: item, due: item.due, availableFrom: availableFrom(subject), required: item.preparationSessions)
        }
        var remaining = eligible.reduce(0) { $0 + max(0, $1.required - assigned[$1.id, default: 0]) }
        for old in sessions where !old.done && (!old.pinned || !relevant(old)) { db.delete(old) }
        var planned: [(Session, Date, Int, Int)] = []
        var day = calendar.startOfDay(for: now)
        let last = eligible.map(\.due).max() ?? now
        while remaining > 0 && day < calendar.startOfDay(for: last) && !a.weekdays.isEmpty && a.minutes > 0 && a.endHour > a.startHour {
            if a.weekdays.contains(calendar.component(.weekday, from: day)),
               var slot = calendar.date(bySettingHour: a.startHour, minute: 0, second: 0, of: day),
               let end = calendar.date(bySettingHour: a.endHour, minute: 0, second: 0, of: day) {
                let duration = Double(a.minutes * 60)
                while remaining > 0 && slot.addingTimeInterval(duration) <= end {
                    defer { slot = slot.addingTimeInterval(duration) }
                    guard slot >= now, !unavailable.contains(where: { $0.conflicts(start: slot, minutes: a.minutes, calendar: calendar) }), !completed.contains(where: {
                        $0.start < slot.addingTimeInterval(duration) && $0.start.addingTimeInterval(Double($0.minutes * 60)) > slot
                    }) else { continue }
                    let candidates = eligible.filter {
                        day >= $0.availableFrom && assigned[$0.id, default: 0] < $0.required && day < calendar.startOfDay(for: $0.due)
                    }
                    guard let chapter = candidates.min(by: {
                        let left = (calendar.startOfDay(for: $0.due), $0.confidence, assigned[$0.id, default: 0], $0.name, $0.id.uuidString)
                        let right = (calendar.startOfDay(for: $1.due), $1.confidence, assigned[$1.id, default: 0], $1.name, $1.id.uuidString)
                        return left < right
                    }) else { break }
                    let session: Session
                    if let unit = chapter.chapter {
                        session = Session(unit, subject: chapter.subject, start: slot, minutes: a.minutes)
                    } else {
                        session = Session(course: chapter.subject.name + " · " + chapter.name, start: slot, minutes: a.minutes)
                        session.deadlineID = chapter.id
                    }
                    session.subjectID = chapter.subject.id
                    let round = assigned[chapter.id, default: 0]
                    session.activity = chapter.deadline.map { "Préparation · " + $0.kind } ?? (round == 0 ? "Apprentissage" : (round == 1 ? "Entraînement" : "Rappel actif"))
                    planned.append((session, chapter.due, round, chapter.required))
                    db.insert(session)
                    assigned[chapter.id, default: 0] += 1
                    remaining -= 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        // Spread repeat exposures into free slots while preserving the feasible first pass.
        var occupied = Set(planned.map { $0.0.start })
        let firstDay = calendar.startOfDay(for: now)
        for (session, exam, round, total) in planned.reversed() where round > 0 {
            let days = calendar.dateComponents([.day], from: firstDay, to: calendar.startOfDay(for: exam)).day ?? 0
            let offset = max(0, days - 1) * round / max(1, total - 1)
            guard var candidate = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            search: while candidate > calendar.startOfDay(for: session.start) {
                if a.weekdays.contains(calendar.component(.weekday, from: candidate)),
                   var slot = calendar.date(bySettingHour: a.startHour, minute: 0, second: 0, of: candidate),
                   let end = calendar.date(bySettingHour: a.endHour, minute: 0, second: 0, of: candidate) {
                    let duration = Double(a.minutes * 60)
                    while slot.addingTimeInterval(duration) <= end {
                        if !occupied.contains(slot) && !unavailable.contains(where: { $0.conflicts(start: slot, minutes: a.minutes, calendar: calendar) }) && !completed.contains(where: {
                            $0.start < slot.addingTimeInterval(duration) && $0.start.addingTimeInterval(Double($0.minutes * 60)) > slot
                        }) {
                            occupied.remove(session.start)
                            occupied.insert(slot)
                            session.start = slot
                            break search
                        }
                        slot = slot.addingTimeInterval(duration)
                    }
                }
                guard let previous = calendar.date(byAdding: .day, value: -1, to: candidate) else { break }
                candidate = previous
            }
        }
        if let profile = try db.fetch(FetchDescriptor<AcademicProfile>()).first {
            try profile.schedule(in: db, availability: a, reserved: completed + planned.map { $0.0 }, now: now, calendar: calendar)
        }
        try db.save()
        return remaining
    }
}
