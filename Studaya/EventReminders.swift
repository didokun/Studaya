import Foundation
import SwiftData
import UserNotifications
import SwiftUI

struct StudyReminder: Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date
    var tab = 1
    var repeatsDaily = false
}

enum ReminderPlan {
    static func make(subjects: [Subject], deadlines: [StudyDeadline], chapters: [Chapter], reviews: [SpacedReview], now: Date = .now, calendar: Calendar = .current) -> [StudyReminder] {
        var items: [StudyReminder] = []
        for subject in subjects where subject.hasExam {
            let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: subject.exam)!
            for days in [7, 1, 0] {
                let date = calendar.date(byAdding: .day, value: -days, to: morning)!
                items.append(StudyReminder(id: "exam.\(subject.id).\(days)", title: String(localized: "Examen · ") + subject.displayCode, body: days == 0 ? String(localized: "Ton examen est prévu aujourd’hui. Consulte ta préparation.") : String(localized: "Plus que \(days) jour(s) pour préparer cet examen."), date: date))
            }
        }
        for deadline in deadlines where !deadline.done && deadline.hasDueDate {
            let name = subjects.first { $0.id == deadline.subjectID }?.displayCode ?? ""
            let body = name + " · " + deadline.due.formatted(date: .abbreviated, time: .shortened)
            items.append(StudyReminder(id: "deadline.\(deadline.id).reminder", title: StudyLabels.deadline(deadline, subjects: subjects, chapters: chapters), body: body, date: deadline.reminderDate))
            if deadline.reminderDays != 0 { items.append(StudyReminder(id: "deadline.\(deadline.id).due", title: String(localized: "Échéance · ") + StudyLabels.deadline(deadline, subjects: subjects, chapters: chapters), body: body, date: deadline.due)) }
        }
        for review in reviews where !review.done {
            guard let chapter = chapters.first(where: { $0.id == review.chapterID && $0.completed }) else { continue }
            items.append(StudyReminder(id: "review.\(review.id)", title: String(localized: "Rappel espacé · ") + (subjects.first { $0.id == chapter.subjectID }?.displayCode ?? "") + " · " + chapter.name, body: String(localized: "Teste-toi sans correction. Ce rappel ne remet pas ton travail parmi les cours ou TD en cours."), date: review.due))
        }
        return items.filter { $0.date > now }.sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }
}

@MainActor final class EventReminders: ObservableObject {
    static let shared = EventReminders()
    @Published var status = ""
    private var generation = 0
    func refresh(_ db: ModelContext) async {
        generation += 1
        let revision = generation
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        guard revision == generation else { return }
        let own = pending.filter { $0.identifier.hasPrefix("studaya.event.") }.map(\.identifier)
        guard StudyPreferences.current.bool(forKey: "eventRemindersEnabled") || StudyPreferences.current.bool(forKey: "reminderEnabled") else {
            center.removePendingNotificationRequests(withIdentifiers: own); status = String(localized: "Rappels de planning désactivés."); return
        }
        let settings = await center.notificationSettings()
        guard revision == generation else { return }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: own)
            status = String(localized: "Autorise les notifications de Studaya dans les réglages iOS."); return
        }
        do {
            let preferences = StudyPreferences.current
            let options = StudentNotificationOptions.load()
            let subjects = try db.fetch(FetchDescriptor<Subject>())
            let chapters = try db.fetch(FetchDescriptor<Chapter>())
            let anchor = preferences.object(forKey: "notificationAnchor") as? Date ?? .now
            preferences.set(anchor, forKey: "notificationAnchor")
            let academic = options.academic ? ReminderPlan.make(subjects: subjects, deadlines: try db.fetch(FetchDescriptor<StudyDeadline>()), chapters: chapters, reviews: try db.fetch(FetchDescriptor<SpacedReview>())) : []
            let plan = academic + StudentNotificationPlan.make(subjects: subjects, chapters: chapters, sessions: try db.fetch(FetchDescriptor<Session>()), logs: try db.fetch(FetchDescriptor<FocusLog>()), options: options, anchor: anchor)
            // Four slots remain reserved for Focus, even before a timer is started.
            let capacity = max(0, 56 - pending.filter { !$0.identifier.hasPrefix("studaya.event.") && !$0.identifier.hasPrefix("studaya.focus.") && $0.identifier != "studaya.daily" }.count)
            let scheduled = StudentNotificationPlan.limited(plan, capacity: capacity)
            // Keep stable identifiers, cancel removed or edited reminders, then replace the current plan.
            let keep = Set(scheduled.map { "studaya.event." + $0.id })
            center.removePendingNotificationRequests(withIdentifiers: own.filter { !keep.contains($0) })
            for item in scheduled {
                guard revision == generation, !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = item.title; content.body = item.body; content.sound = .default; content.userInfo = ["tab": item.tab]
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
                try await center.add(UNNotificationRequest(identifier: "studaya.event." + item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: item.repeatsDaily ? Calendar.current.dateComponents([.hour, .minute], from: item.date) : components, repeats: item.repeatsDaily)))
            }
            status = String(localized: "\(scheduled.count) rappel(s) programmé(s).") + (plan.count > scheduled.count ? String(localized: " Les suivants seront programmés à la prochaine ouverture de l’app.") : "")
        } catch { status = String(localized: "Impossible de programmer les rappels : ") + error.localizedDescription }
    }
    func enable(_ db: ModelContext) async {
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else {
                status = String(localized: "Autorise les notifications de Studaya dans les réglages iOS."); return
            }
            StudyPreferences.current.set(true, forKey: "eventRemindersEnabled")
            StudyPreferences.current.set(false, forKey: "reminderEnabled")
            await DailyReminder.sync()
            await refresh(db)
        } catch { status = error.localizedDescription }
    }
}

struct EventReminderSettings: View {
    @ObservedObject private var focus = FocusCompanion.shared
    @ObservedObject private var reminders = EventReminders.shared
    @Environment(\.modelContext) private var db
    @AppStorage("eventRemindersEnabled") private var enabled = false
    @State private var options = StudentNotificationOptions.load()
    @State private var busy = false
    var body: some View {
        Section(String(localized: "Un compagnon pour tes révisions")) {
            Text(String(localized: "Des invitations concrètes à avancer, sans culpabiliser. Le bilan du soir t’invite à cocher ce qui est fait et à ajuster la suite.")).font(.footnote)
            Button(enabled ? String(localized: "Vérifier et actualiser les notifications") : String(localized: "Activer les notifications")) {
                busy = true
                Task { await reminders.enable(db); busy = false }
            }.disabled(busy)
            if enabled {
                Button(String(localized: "Désactiver les rappels de planning")) {
                    enabled = false; StudyPreferences.current.set(false, forKey: "reminderEnabled")
                    Task { await DailyReminder.sync(); await reminders.refresh(db) }
                }
            }
            if !reminders.status.isEmpty { Text(reminders.status).font(.footnote) }
            Link(String(localized: "Autorisations dans les réglages iOS"), destination: URL(string: UIApplication.openSettingsURLString)!)
        }
        Section(String(localized: "Ton rythme")) {
            Toggle(String(localized: "Planning du matin"), isOn: $options.morning)
            if options.morning { Stepper(String(localized: "Matin · \(options.morningHour) h"), value: $options.morningHour, in: 0...23) }
            Toggle(String(localized: "Bilan du soir"), isOn: $options.evening)
            if options.evening { Stepper(String(localized: "Soir · \(options.eveningHour) h"), value: $options.eveningHour, in: 0...23) }
            Toggle(String(localized: "À l’heure des séances"), isOn: $options.sessions)
            Toggle(String(localized: "Contrôles, présentations, examens et rappels espacés"), isOn: $options.academic)
            Toggle(String(localized: "Petits coups de pouce et reprise après une pause"), isOn: $options.coaching)
            Toggle(String(localized: "Messages d’accompagnement entre 8 h et 22 h"), isOn: $options.quiet)
            Text(String(localized: "Les horaires explicites de tes séances, échéances et minuteurs restent prioritaires. Les prochains rappels sont renouvelés à chaque ouverture.")).font(.footnote).foregroundStyle(.secondary)
        }
        Section(String(localized: "Focus et repos")) {
            Toggle(String(localized: "Fin de Focus, début et fin du repos"), isOn: $options.focus)
            Text(String(localized: "Le repos démarre automatiquement à la fin du Focus. Le minuteur reste visible sur l’écran verrouillé si les activités en direct sont autorisées.")).font(.footnote)
            if !focus.status.isEmpty { Text(focus.status).font(.footnote) }
        }
        .onChange(of: options) { _, value in
            value.persist()
            Task { await reminders.refresh(db); await FocusCompanion.shared.sync(db) }
        }
    }
}

@MainActor enum DailyReminder {
    static func sync() async {
        // Preserve the opt-in of students who used the former single daily reminder.
        let preferences = StudyPreferences.current
        if preferences.bool(forKey: "reminderEnabled") {
            preferences.set(true, forKey: "eventRemindersEnabled")
            preferences.set(false, forKey: "reminderEnabled")
        }
        // Retire the former generic daily alarm; the student plan now covers mornings and evenings.
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["studaya.daily"])
    }
}

struct NotificationInvitation: View {
    @Environment(\.modelContext) private var db
    @ObservedObject private var reminders = EventReminders.shared
    @AppStorage("notificationPromptSeen") private var seen = false
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Ton planning le matin, un point le soir, tes séances et échéances au bon moment. Choisis les rappels qui t’aident à avancer."))
            Button(String(localized: "Activer les notifications"), systemImage: "bell.badge") {
                busy = true
                Task { await reminders.enable(db); seen = true; busy = false }
            }.buttonStyle(Primary()).disabled(busy)
            if !reminders.status.isEmpty { Text(reminders.status).font(.callout) }
            Link(String(localized: "Ouvrir les réglages iOS"), destination: URL(string: UIApplication.openSettingsURLString)!)
            Button(String(localized: "Plus tard")) { seen = true }.frame(minHeight: 44)
            Text(String(localized: "Tu peux modifier ce choix dans Réglages → Rappels et notifications.")).font(.footnote).foregroundStyle(.secondary)
        }
    }
}
