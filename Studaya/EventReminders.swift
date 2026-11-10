import Foundation
import SwiftData
import UserNotifications
import SwiftUI

struct StudyReminder: Equatable {
    let id: String
    let title: String
    let body: String
    let date: Date
}

enum ReminderPlan {
    static func make(subjects: [Subject], deadlines: [StudyDeadline], chapters: [Chapter], reviews: [SpacedReview], now: Date = .now, calendar: Calendar = .current) -> [StudyReminder] {
        var items: [StudyReminder] = []
        for subject in subjects where subject.hasExam {
            let morning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: subject.exam)!
            for days in [7, 1, 0] {
                let date = calendar.date(byAdding: .day, value: -days, to: morning)!
                items.append(StudyReminder(id: "exam.\(subject.id).\(days)", title: "Examen · " + subject.name, body: days == 0 ? "Ton examen est prévu aujourd’hui. Consulte ta préparation." : "Plus que \(days) jour(s) pour préparer cet examen.", date: date))
            }
        }
        for deadline in deadlines where !deadline.done {
            let name = subjects.first { $0.id == deadline.subjectID }?.name ?? ""
            let body = name + " · " + deadline.due.formatted(date: .abbreviated, time: .shortened)
            items.append(StudyReminder(id: "deadline.\(deadline.id).reminder", title: deadline.kind + " · " + deadline.title, body: body, date: deadline.reminderDate))
            if deadline.reminderDays != 0 { items.append(StudyReminder(id: "deadline.\(deadline.id).due", title: "Échéance · " + deadline.title, body: body, date: deadline.due)) }
        }
        for review in reviews where !review.done {
            guard let chapter = chapters.first(where: { $0.id == review.chapterID && $0.completed }) else { continue }
            items.append(StudyReminder(id: "review.\(review.id)", title: "Rappel espacé · " + chapter.name, body: "Teste-toi sans correction. Ce rappel ne remet pas ton travail parmi les cours ou TD en cours.", date: review.due))
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
        guard StudyPreferences.current.bool(forKey: "eventRemindersEnabled") else {
            center.removePendingNotificationRequests(withIdentifiers: own); status = "Notifications d’échéance désactivées."; return
        }
        let settings = await center.notificationSettings()
        guard revision == generation else { return }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            center.removePendingNotificationRequests(withIdentifiers: own)
            status = "Autorise les notifications de Studaya dans les réglages iOS."; return
        }
        do {
            let plan = ReminderPlan.make(subjects: try db.fetch(FetchDescriptor<Subject>()), deadlines: try db.fetch(FetchDescriptor<StudyDeadline>()), chapters: try db.fetch(FetchDescriptor<Chapter>()), reviews: try db.fetch(FetchDescriptor<SpacedReview>()))
            let capacity = max(0, 60 - pending.filter { !$0.identifier.hasPrefix("studaya.event.") }.count)
            let scheduled = Array(plan.prefix(capacity))
            // Keep stable identifiers, cancel removed or edited reminders, then replace the current plan.
            let keep = Set(scheduled.map { "studaya.event." + $0.id })
            center.removePendingNotificationRequests(withIdentifiers: own.filter { !keep.contains($0) })
            for item in scheduled {
                guard revision == generation, !Task.isCancelled else { return }
                let content = UNMutableNotificationContent()
                content.title = item.title; content.body = item.body; content.sound = .default
                let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
                try await center.add(UNNotificationRequest(identifier: "studaya.event." + item.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
            }
            status = "\(scheduled.count) rappel(s) programmé(s)." + (plan.count > scheduled.count ? " Les suivants seront programmés à la prochaine ouverture de l’app." : "")
        } catch { status = "Impossible de programmer les rappels : " + error.localizedDescription }
    }
    func enable(_ db: ModelContext) async {
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else {
                status = "Autorise les notifications de Studaya dans les réglages iOS."; return
            }
            StudyPreferences.current.set(true, forKey: "eventRemindersEnabled")
            await refresh(db)
        } catch { status = error.localizedDescription }
    }
}

struct EventReminderSettings: View {
    @ObservedObject private var reminders = EventReminders.shared
    @Environment(\.modelContext) private var db
    @AppStorage("eventRemindersEnabled") private var enabled = false
    @State private var busy = false
    var body: some View {
        Section("Examens, échéances et rappels espacés") {
            Text("Reçois les rappels même lorsque l’app est fermée. Examens : J−7, J−1 et le jour même à 9 h. Les autres échéances utilisent l’heure choisie.").font(.footnote)
            Button(enabled ? "Actualiser les notifications d’échéance" : "Activer les notifications d’échéance") {
                busy = true
                Task { await reminders.enable(db); busy = false }
            }.disabled(busy)
            if enabled {
                Button("Désactiver les notifications d’échéance") {
                    enabled = false
                    Task { await reminders.refresh(db) }
                }
            }
            if !reminders.status.isEmpty { Text(reminders.status).font(.footnote) }
        }
    }
}

@MainActor enum DailyReminder {
    static func sync() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["studaya.daily"])
        let preferences = StudyPreferences.current
        guard preferences.bool(forKey: "reminderEnabled") else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = "Ton planning Studaya"; content.body = "Retrouve tes révisions du jour."; content.sound = .default
        let hour = preferences.object(forKey: "reminderHour") as? Int ?? 18
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        try? await center.add(UNNotificationRequest(identifier: "studaya.daily", content: content, trigger: trigger))
    }
}

struct NotificationInvitation: View {
    @Environment(\.modelContext) private var db
    @ObservedObject private var reminders = EventReminders.shared
    @AppStorage("notificationPromptSeen") private var seen = false
    @State private var busy = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Examens, contrôles, présentations : reçois les rappels même lorsque Studaya est fermée.")
            Button("Activer les notifications", systemImage: "bell.badge") {
                busy = true
                Task { await reminders.enable(db); seen = true; busy = false }
            }.buttonStyle(Primary()).disabled(busy)
            if !reminders.status.isEmpty { Text(reminders.status).font(.callout) }
            Link("Ouvrir les réglages iOS", destination: URL(string: UIApplication.openSettingsURLString)!)
            Button("Plus tard") { seen = true }.frame(minHeight: 44)
            Text("Tu peux modifier ce choix dans Réglages → Rappels et notifications.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
