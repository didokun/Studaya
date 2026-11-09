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
    /// Rebuild pending work in one save. Completed blocks retain identity and reserve their time.
    @discardableResult static func rebuild(_ db: ModelContext, availability a: Availability = .saved,
                                           now: Date = .now, calendar: Calendar = .current) throws -> Int {
        let subjects = try db.fetch(FetchDescriptor<Subject>()).filter(\.hasExam)
        let chapters = try db.fetch(FetchDescriptor<Chapter>())
        let sessions = try db.fetch(FetchDescriptor<Session>())
        let completed = sessions.filter(\.done)
        var assigned = Dictionary(grouping: completed, by: \.chapterID).mapValues(\.count)
        let subjectByID = Dictionary(subjects.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let eligible = chapters.filter { subjectByID[$0.subjectID] != nil }
        var remaining = eligible.reduce(0) { $0 + max(0, $1.requiredSessions - assigned[$1.id, default: 0]) }
        for old in sessions where !old.done { db.delete(old) }
        var planned: [(Session, Date, Int, Int)] = []
        var day = calendar.startOfDay(for: now)
        let last = subjects.map(\.exam).max() ?? now
        while remaining > 0 && day < calendar.startOfDay(for: last) && !a.weekdays.isEmpty && a.minutes > 0 && a.endHour > a.startHour {
            if a.weekdays.contains(calendar.component(.weekday, from: day)),
               var slot = calendar.date(bySettingHour: a.startHour, minute: 0, second: 0, of: day),
               let end = calendar.date(bySettingHour: a.endHour, minute: 0, second: 0, of: day) {
                let duration = Double(a.minutes * 60)
                while remaining > 0 && slot.addingTimeInterval(duration) <= end {
                    defer { slot = slot.addingTimeInterval(duration) }
                    guard slot >= now, !completed.contains(where: {
                        $0.start < slot.addingTimeInterval(duration) && $0.start.addingTimeInterval(Double($0.minutes * 60)) > slot
                    }) else { continue }
                    let candidates = eligible.filter {
                        assigned[$0.id, default: 0] < $0.requiredSessions && day < calendar.startOfDay(for: subjectByID[$0.subjectID]!.exam)
                    }
                    guard let chapter = candidates.min(by: {
                        let left = (calendar.startOfDay(for: subjectByID[$0.subjectID]!.exam), assigned[$0.id, default: 0], $0.name, $0.id.uuidString)
                        let right = (calendar.startOfDay(for: subjectByID[$1.subjectID]!.exam), assigned[$1.id, default: 0], $1.name, $1.id.uuidString)
                        return left < right
                    }) else { break }
                    let subject = subjectByID[chapter.subjectID]!
                    let session = Session(chapter, subject: subject, start: slot, minutes: a.minutes)
                    let round = assigned[chapter.id, default: 0]
                    session.activity = round == 0 ? "Apprentissage" : (round == 1 ? "Entraînement" : "Rappel actif")
                    planned.append((session, subject.exam, round, chapter.requiredSessions))
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
                        if !occupied.contains(slot) && !completed.contains(where: {
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
            profile.schedule(in: db, availability: a, reserved: completed + planned.map { $0.0 }, now: now, calendar: calendar)
        }
        try db.save()
        return remaining
    }
}
