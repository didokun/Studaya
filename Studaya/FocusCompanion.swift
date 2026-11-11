import Foundation
import SwiftData
import SwiftUI
import ActivityKit
import UserNotifications

struct FocusTimerSnapshot: Equatable {
    var end: TimeInterval
    var length: Int
    var remaining: Int
    var resting: Bool
    var runID: String
    var breakSeconds: Int
    static func read(_ p: UserDefaults = StudyPreferences.current) -> Self {
        Self(end: p.double(forKey: "timerEnd"), length: p.integer(forKey: "timerLength"), remaining: p.integer(forKey: "timerRemaining"), resting: p.bool(forKey: "timerRest"), runID: p.string(forKey: "focusRunID") ?? "", breakSeconds: max(1, p.object(forKey: "breakMinutes") as? Int ?? 5) * 60)
    }
    func notifications(now: Date = .now) -> [StudyReminder] {
        guard length > 0, end > now.timeIntervalSince1970 else { return [] }
        let finish = Date(timeIntervalSince1970: end)
        if resting { return [StudyReminder(id: "restEnd", title: NotificationText("Ta pause est terminée"), body: NotificationText("Prêt pour une nouvelle étape ? Reviens dans Focus quand tu veux."), date: finish, tab: 2)] }
        return [
            StudyReminder(id: "workEnd", title: NotificationText("Focus terminé · place au repos 🌿"), body: NotificationText("Bravo pour ce temps de révision. Ta pause de %lld min commence maintenant.", [.integer(breakSeconds / 60)]), date: finish, tab: 2),
            StudyReminder(id: "restEnd", title: NotificationText("Ta pause est terminée"), body: NotificationText("Tu peux repartir sur une séance ou t’arrêter ici. Ton effort compte déjà."), date: finish.addingTimeInterval(Double(breakSeconds)), tab: 2)
        ]
    }
}

@MainActor enum FocusLifecycle {
    struct Completion { let chapterID: UUID? }
    @discardableResult static func reconcile(_ db: ModelContext, preferences p: UserDefaults = StudyPreferences.current, now: Date = .now) throws -> Completion? {
        let timer = FocusTimerSnapshot.read(p)
        guard timer.length > 0, timer.end > 0, timer.end <= now.timeIntervalSince1970 else { return nil }
        var completed: Completion?
        if !timer.resting {
            let token = UUID(uuidString: timer.runID) ?? UUID()
            p.set(token.uuidString, forKey: "focusRunID")
            let log = try FocusRecorder.record(db: db, runID: token, subjectID: UUID(uuidString: p.string(forKey: "focusSubject") ?? ""), chapterID: UUID(uuidString: p.string(forKey: "focusChapter") ?? ""), sessionID: UUID(uuidString: p.string(forKey: "focusSession") ?? ""), reviewID: UUID(uuidString: p.string(forKey: "focusReview") ?? ""), minutes: max(1, timer.length / 60), date: Date(timeIntervalSince1970: timer.end))
            // The log keeps the real end time; future sessions must be rebuilt from the actual return time.
            if now.timeIntervalSince1970 - timer.end > 60 { try Scheduler.rebuild(db, now: now) }
            completed = Completion(chapterID: log.chapterID)
            p.set("", forKey: "focusSession"); p.set("", forKey: "focusReview")
            let restEnd = timer.end + Double(timer.breakSeconds)
            p.set(true, forKey: "timerRest"); p.set(timer.breakSeconds, forKey: "timerLength")
            p.set(0, forKey: "timerRemaining"); p.set(restEnd, forKey: "timerEnd")
            if restEnd > now.timeIntervalSince1970 { return completed }
        }
        p.set(0.0, forKey: "timerEnd"); p.set(0, forKey: "timerRemaining"); p.set(0, forKey: "timerLength")
        p.set(false, forKey: "timerRest"); p.set("", forKey: "focusRunID")
        return completed
    }
}

@MainActor final class FocusCompanion: ObservableObject {
    static let shared = FocusCompanion()
    @Published var status = ""
    @Published var completion: FocusLifecycle.Completion?
    private var generation = 0
    func reconcile(_ db: ModelContext, now: Date = .now) throws {
        if let result = try FocusLifecycle.reconcile(db, now: now) { completion = result }
    }
    func sync(_ db: ModelContext, requestPermission: Bool = false) async {
        generation += 1; let revision = generation
        await NotificationLanguageMigration.prepare()
        guard revision == generation else { return }
        let center = UNUserNotificationCenter.current()
        let p = StudyPreferences.current
        let timer = FocusTimerSnapshot.read(p)
        let options = StudentNotificationOptions.load()
        var settings = await center.notificationSettings()
        if requestPermission && options.focus && settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            settings = await center.notificationSettings()
        }
        guard revision == generation else { return }
        let pending = await center.pendingNotificationRequests()
        guard revision == generation else { return }
        let own = pending.filter { $0.identifier.hasPrefix("studaya.focus.") }
        let notices = options.focus && (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) ? timer.notifications() : []
        let keep = Set(notices.map { "studaya.focus." + $0.id })
        // Do not race the system by cancelling an end alarm that is already due for delivery.
        center.removePendingNotificationRequests(withIdentifiers: own.filter {
            !keep.contains($0.identifier) && (($0.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate() ?? .distantPast) > .now
        }.map(\.identifier))
        do {
            for notice in notices {
                guard revision == generation else { return }
                let content = UNMutableNotificationContent()
                notice.apply(to: content)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, notice.date.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: "studaya.focus." + notice.id, content: content, trigger: trigger))
            }
            status = options.focus && settings.authorizationStatus == .denied ? String(localized: "Autorise les notifications dans les réglages iOS pour entendre la fin du minuteur.") : ""
        } catch { status = String(localized: "Notifications Focus : ") + error.localizedDescription }
        guard revision == generation else { return }
        let activities = Activity<FocusActivityAttributes>.activities
        guard timer.length > 0 else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        let subjects = (try? db.fetch(FetchDescriptor<Subject>())) ?? []
        let chapters = (try? db.fetch(FetchDescriptor<Chapter>())) ?? []
        let subject = subjects.first { $0.id.uuidString == p.string(forKey: "focusSubject") }
        let chapter = chapters.first { $0.id.uuidString == p.string(forKey: "focusChapter") }
        let title = (subject?.displayCode ?? String(localized: "Focus libre")) + (chapter.map { " · " + $0.name } ?? "")
        let end = Date(timeIntervalSince1970: timer.end)
        let restEnd = timer.resting ? end : end.addingTimeInterval(Double(timer.breakSeconds))
        let state = FocusActivityAttributes.ContentState(title: title, resting: timer.resting, end: end, restEnd: restEnd, pausedSeconds: timer.remaining, paused: timer.end == 0, isFreeFocus: subject == nil && chapter == nil)
        let content = ActivityContent(state: state, staleDate: timer.end > 0 ? end : nil)
        let matching = activities.first { $0.attributes.runID == timer.runID }
        for activity in activities where activity.id != matching?.id { await activity.end(nil, dismissalPolicy: .immediate) }
        guard revision == generation else { return }
        if let matching { await matching.update(content) }
        else if ActivityAuthorizationInfo().areActivitiesEnabled && UIApplication.shared.applicationState == .active {
            do { _ = try Activity.request(attributes: FocusActivityAttributes(runID: timer.runID), content: content, pushType: nil) }
            catch { status = String(localized: "Écran verrouillé : ") + error.localizedDescription }
        } else if !ActivityAuthorizationInfo().areActivitiesEnabled { status = String(localized: "Active les activités en direct dans les réglages iOS de Studaya pour voir le minuteur verrouillé.") }
    }
}
