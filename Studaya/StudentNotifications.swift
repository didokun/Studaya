import Foundation
import SwiftData
import SwiftUI
import UserNotifications
import UIKit

struct StudentNotificationOptions: Codable, Equatable {
    var morning = true
    var evening = true
    var sessions = true
    var coaching = true
    var focus = true
    var academic = true
    var quiet = true
    var morningHour = 8
    var eveningHour = 20
    var valid: Bool { (0...23).contains(morningHour) && (0...23).contains(eveningHour) }
    static let key = "studentNotificationOptions"
    static func load(_ preferences: UserDefaults = StudyPreferences.current) -> Self {
        guard let data = preferences.data(forKey: key), let value = try? JSONDecoder().decode(Self.self, from: data), value.valid else { return Self() }
        return value
    }
    func persist() { StudyPreferences.current.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}

@MainActor enum StudentNotificationPlan {
    static func make(subjects: [Subject], chapters: [Chapter], sessions: [Session], logs: [FocusLog], options: StudentNotificationOptions, anchor: Date, now: Date = .now, calendar: Calendar = .current) -> [StudyReminder] {
        var result: [StudyReminder] = []
        func moment(_ offset: Int, hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: offset, to: now)!)!
        }
        func append(_ id: String, _ title: String, _ body: String, _ date: Date, tab: Int) {
            guard date > now else { return }
            let hour = calendar.component(.hour, from: date)
            guard !options.quiet || (8..<22).contains(hour) else { return }
            result.append(StudyReminder(id: id, title: title, body: body, date: date, tab: tab))
        }
        if !subjects.isEmpty && (!chapters.isEmpty || !sessions.isEmpty) {
            let tomorrowMorning = (0...1).map { moment($0, hour: options.morningHour) }.first { $0 > now }!
            let tonight = (0...1).map { moment($0, hour: options.eveningHour) }.first { $0 > now }!
            if options.morning && (!options.quiet || (8..<22).contains(options.morningHour)) {
                result.append(StudyReminder(id: "morning.daily", title: "Ta journée, à ton rythme ☀️", body: "Ouvre ton planning, choisis ta première étape et commence par un petit exercice.", date: tomorrowMorning, tab: 1, repeatsDaily: true))
            }
            if options.evening && (!options.quiet || (8..<22).contains(options.eveningHour)) {
                result.append(StudyReminder(id: "evening.daily", title: "On fait le point ?", body: "Coche tes séances réalisées, regarde ce qui reste et ajuste tranquillement demain. Chaque petit pas compte.", date: tonight, tab: 0, repeatsDaily: true))
            }
        }

        if options.sessions {
            let horizon = calendar.date(byAdding: .day, value: 14, to: now)!
            for session in sessions where !session.done && session.start > now && session.start < horizon {
                // A revision time explicitly chosen by the student may fall outside coaching quiet hours.
                result.append(StudyReminder(id: "session.\(session.id)", title: "C’est ton moment de révision", body: StudyLabels.session(session, subjects: subjects, chapters: chapters) + " · \(session.minutes) min. Un premier exercice suffit pour te lancer.", date: session.start, tab: 1))
            }
        }
        if options.coaching {
            let lastStudy = (logs.map(\.date) + sessions.filter(\.done).map(\.start)).filter { $0 <= now }.max() ?? anchor
            let milestones = subjects.isEmpty ? [1, 3, 7] : (chapters.isEmpty ? [2, 5] : [3, 7])
            for day in milestones {
                let base = subjects.isEmpty || chapters.isEmpty ? anchor : lastStudy
                let target = calendar.date(byAdding: .day, value: day, to: base)!
                let date = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: target)!
                if subjects.isEmpty {
                    append("coach.subject.\(day)", "Ton parcours commence par une matière", "Ajoute ta première matière. Tu peux importer une photo du planning pour gagner du temps.", date, tab: 3)
                } else if chapters.isEmpty {
                    append("coach.course.\(day)", "Tes matières attendent leur première étape", "Ajoute un cours ou un TD : on pourra ensuite construire tes séances de révision.", date, tab: 3)
                } else {
                    append("coach.return.\(day)", "On reprend doucement ?", "Pas besoin de rattraper tout d’un coup. Ouvre un TD et accorde-toi 10 minutes aujourd’hui.", date, tab: 2)
                }
            }
            if !subjects.isEmpty && !subjects.contains(where: \.hasExam) {
                let date = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 4, to: anchor)!)!
                append("coach.exam", "Une date d’examen annoncée ?", "Ajoute-la à ta matière pour répartir les révisions. Si elle est encore inconnue, tu peux continuer sans date.", date, tab: 3)
            }
            let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
            let minutes = logs.filter { $0.date >= weekStart && $0.date <= now }.reduce(0) { $0 + $1.minutes }
            if minutes > 0 {
                let sunday = (0..<7).map { moment($0, hour: 16) }.first { calendar.component(.weekday, from: $0) == 1 && $0 > now }
                if let sunday { append("coach.weekly", "Regarde le chemin parcouru", "Tu as déjà étudié \(minutes) min ces derniers jours. Fais ton bilan et choisis ta priorité pour la suite.", sunday, tab: 4) }
            }
            // One actionable suggestion for today's fragile or completed TD, never an extra daily series.
            if let td = chapters.first(where: { $0.kind == "TD" && !$0.completed && $0.exercisesDone >= $0.exerciseCount }) {
                append("coach.synthesis.\(td.id)", "Tu as fait tous les exercices 👏", "\(td.name) : refais un exercice de synthèse sans correction, puis classe ce TD comme terminé.", moment(0, hour: 18), tab: 3)
            }
        }
        return result.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
    static func limited(_ plan: [StudyReminder], capacity: Int) -> [StudyReminder] {
        guard capacity > 0 else { return [] }
        let ordered = plan.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
        // Reserve room for each family, so an intensive timetable cannot crowd out exams or the evening check-in.
        let families = ["exam.", "deadline.", "review.", "morning.", "evening.", "session.", "coach."]
        var chosen: [StudyReminder] = []
        for prefix in families {
            if chosen.count < capacity, let first = ordered.first(where: { $0.id.hasPrefix(prefix) }) { chosen.append(first) }
        }
        let used = Set(chosen.map(\.id))
        chosen += ordered.filter { !used.contains($0.id) }.prefix(max(0, capacity - chosen.count))
        return chosen.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
}

@MainActor final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var tab: Int?
}

final class StudyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound, .list] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let tab = response.notification.request.content.userInfo["tab"] as? Int ?? 0
        await MainActor.run { NotificationRouter.shared.tab = tab }
    }
}
