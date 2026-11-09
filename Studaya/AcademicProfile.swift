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
    var program = ""
    var institution = ""
    var level = "Licence"
    var years = 1
    var firstDay = Date()
    var courses: [String] = []
    init() {}

    func schedule(in db: ModelContext, availability: Availability, reserved: [Session], now: Date, calendar: Calendar) {
        guard !courses.isEmpty, availability.minutes > 0,
              let end = calendar.date(byAdding: .year, value: years, to: calendar.startOfDay(for: firstDay)) else { return }
        let occupied = Dictionary(grouping: reserved) { calendar.startOfDay(for: $0.start) }
        var day = calendar.startOfDay(for: firstDay)
        var rotation = 0
        while day < end {
            if availability.weekdays.contains(calendar.component(.weekday, from: day)),
               let start = calendar.date(bySettingHour: availability.startHour, minute: 0, second: 0, of: day),
               let limit = calendar.date(bySettingHour: availability.endHour, minute: 0, second: 0, of: day) {
                let duration = Double(availability.minutes * 60)
                var slot = start
                let blocks = occupied[day] ?? []
                while day >= calendar.startOfDay(for: now) && slot.addingTimeInterval(duration) <= limit {
                    if slot < now { slot = slot.addingTimeInterval(duration); continue }
                    if !blocks.contains(where: { $0.start < slot.addingTimeInterval(duration) && $0.start.addingTimeInterval(Double($0.minutes * 60)) > slot }) {
                        if !blocks.contains(where: { $0.activity == "Révision de cours" && $0.done }) {
                            db.insert(Session(course: courses[rotation % courses.count], start: slot, minutes: availability.minutes))
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
