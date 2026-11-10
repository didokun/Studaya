import Foundation
import SwiftData

enum StudyPreferences {
    static var current: UserDefaults {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test") { return UserDefaults(suiteName: "Studaya.UITests")! }
        #endif
        return .standard
    }
}

@Model final class AcademicProfile {
    var id = UUID()
    var program = ""
    var institution = ""
    var level = "Licence"
    var organization = "Par semestre"
    var examMode = "Par semestre"
    var years = 1
    var firstDay = Date()
    var courses: [String] = []
    var usesSemesters: Bool { organization == "Par semestre" }
    init() {}

    func schedule(in db: ModelContext, availability: Availability, reserved: [Session], now: Date, calendar: Calendar) throws {
        guard !courses.isEmpty, availability.minutes > 0,
              let end = calendar.date(byAdding: .year, value: years, to: calendar.startOfDay(for: firstDay)) else { return }
        let subjects = try db.fetch(FetchDescriptor<Subject>())
        let unavailable = try db.fetch(FetchDescriptor<TimeBlock>())
        let chapters = try db.fetch(FetchDescriptor<Chapter>())
        let occupied = Dictionary(grouping: reserved) { calendar.startOfDay(for: $0.start) }
        var day = calendar.startOfDay(for: firstDay)
        var rotation = 0
        while day < end {
            let month = calendar.dateComponents([.month], from: calendar.startOfDay(for: firstDay), to: day).month ?? 0
            let currentYear = month / 12 + 1
            let currentSemester = month % 12 < 6 ? 1 : 2
            let active = courses.filter { name in
                let matches = subjects.filter { $0.name == name }
                return matches.isEmpty || matches.contains { subject in
                    let units = chapters.filter { $0.subjectID == subject.id }
                    return subject.year == currentYear && (!usesSemesters || subject.semester == currentSemester)
                        && units.isEmpty
                }
            }
            if !active.isEmpty, availability.weekdays.contains(calendar.component(.weekday, from: day)),
               let start = calendar.date(bySettingHour: availability.startHour, minute: 0, second: 0, of: day),
               let limit = calendar.date(bySettingHour: availability.endHour, minute: 0, second: 0, of: day) {
                let duration = Double(availability.minutes * 60)
                var slot = start
                let blocks = occupied[day] ?? []
                while day >= calendar.startOfDay(for: now) && slot.addingTimeInterval(duration) <= limit {
                    if slot < now || unavailable.contains(where: { $0.conflicts(start: slot, minutes: availability.minutes, calendar: calendar) }) { slot = slot.addingTimeInterval(duration); continue }
                    if !blocks.contains(where: { $0.start < slot.addingTimeInterval(duration) && $0.start.addingTimeInterval(Double($0.minutes * 60)) > slot }) {
                        if !blocks.contains(where: { $0.activity == "Révision de cours" && $0.done }) {
                            let name = active[rotation % active.count]
                            let session = Session(course: name, start: slot, minutes: availability.minutes)
                            session.subjectID = subjects.first { $0.name == name && $0.year == currentYear && (!usesSemesters || $0.semester == currentSemester) }?.id
                            db.insert(session)
                        }
                        break
                    }
                    slot = slot.addingTimeInterval(duration)
                }
                rotation += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }
}
