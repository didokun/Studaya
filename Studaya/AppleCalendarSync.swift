import EventKit
import SwiftData
import SwiftUI

struct CalendarExportItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let notes: String
}
@MainActor enum CalendarExportPlan {
    static func make(subjects: [Subject], sessions: [Session], deadlines: [StudyDeadline], chapters: [Chapter], reviews: [SpacedReview], calendar: Calendar = .current) -> [CalendarExportItem] {
        var items: [CalendarExportItem] = []
        for session in sessions {
            items.append(CalendarExportItem(id: "session.\(session.id)", title: (session.done ? "✓ " : "") + StudyLabels.session(session, subjects: subjects, chapters: chapters), start: session.start, end: session.start.addingTimeInterval(Double(session.minutes * 60)), allDay: false, notes: String(localized: "Studaya · ") + session.activity))
        }
        for subject in subjects where subject.hasExam {
            let start = calendar.startOfDay(for: subject.exam)
            items.append(CalendarExportItem(id: "exam.\(subject.id)", title: String(localized: "Examen · ") + subject.displayCode, start: start, end: calendar.date(byAdding: .day, value: 1, to: start)!, allDay: true, notes: subject.name + String(localized: "\nDate d’examen ; horaire non renseigné dans Studaya.")))
        }
        for deadline in deadlines where deadline.hasDueDate {
            items.append(CalendarExportItem(id: "deadline.\(deadline.id)", title: (deadline.done ? "✓ " : "") + StudyLabels.deadline(deadline, subjects: subjects, chapters: chapters), start: deadline.due, end: deadline.due.addingTimeInterval(15 * 60), allDay: false, notes: String(localized: "Studaya · Repère d’échéance de 15 min, pas la durée réelle de l’épreuve.")))
        }
        for review in reviews where !sessions.contains(where: { $0.reviewID == review.id }) {
            guard let chapter = chapters.first(where: { $0.id == review.chapterID }) else { continue }
            let code = subjects.first { $0.id == chapter.subjectID }?.displayCode ?? ""
            items.append(CalendarExportItem(id: "review.\(review.id)", title: (review.done ? "✓ " : "") + String(localized: "Rappel · ") + code + " · " + chapter.name, start: review.due, end: review.due.addingTimeInterval(15 * 60), allDay: false, notes: String(localized: "Studaya · Rappel espacé, durée indicative de 15 min.")))
        }
        return items.sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }
}
struct CalendarExportOwnership {
    let owner: String
    func url(_ key: String) -> URL { URL(string: "studaya://calendar-export/\(owner)/\(key)")! }
    func key(_ url: URL?) -> String? {
        guard let url, url.scheme == "studaya", url.host == "calendar-export" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == owner, url.query == nil, url.fragment == nil else { return nil }
        let key = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard key.count == 2, ["session", "exam", "deadline", "review"].contains(String(key[0])), UUID(uuidString: String(key[1])) != nil else { return nil }
        return parts[1]
    }
}

@MainActor final class AppleCalendarSync: ObservableObject {
    static let shared = AppleCalendarSync()
    static let enabledKey = "appleCalendarSyncEnabled"
    @Published var busy = false
    @Published var status = ""
    private let store: EKEventStore
    private let preferences: UserDefaults?
    init(store: EKEventStore = EKEventStore(), preferences: UserDefaults? = nil) {
        self.store = store; self.preferences = preferences
    }
    private var p: UserDefaults { preferences ?? StudyPreferences.current }
    private var ownership: CalendarExportOwnership {
        if let owner = p.string(forKey: "appleCalendarOwner") { return CalendarExportOwnership(owner: owner) }
        let owner = UUID().uuidString; p.set(owner, forKey: "appleCalendarOwner")
        return CalendarExportOwnership(owner: owner)
    }
    private var mapping: [String: String] {
        get { p.dictionary(forKey: "appleCalendarEvents") as? [String: String] ?? [:] }
        set { p.set(newValue, forKey: "appleCalendarEvents") }
    }
    func connect(_ db: ModelContext) async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        do {
            guard try await store.requestFullAccessToEvents() else { throw StudyError.invalid(String(localized: "Autorise l’accès complet à Calendrier dans les réglages iOS pour synchroniser et supprimer les événements Studaya.")) }
            p.set(true, forKey: Self.enabledKey)
            try reconcile(db)
        } catch { store.reset(); status = error.localizedDescription }
    }
    func refresh(_ db: ModelContext) {
        guard p.bool(forKey: Self.enabledKey), !busy else { return }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            status = String(localized: "Synchronisation suspendue : autorise l’accès complet à Calendrier dans les réglages iOS."); return
        }
        busy = true; defer { busy = false }
        do { try reconcile(db) } catch { store.reset(); status = String(localized: "Synchronisation interrompue : ") + error.localizedDescription }
    }
    private func exportCalendar() throws -> EKCalendar {
        if let id = p.string(forKey: "appleCalendarID"), let calendar = store.calendar(withIdentifier: id) {
            guard calendar.allowsContentModifications else { throw StudyError.invalid(String(localized: "Le calendrier Studaya est en lecture seule.")) }
            return calendar
        }
        let sources = store.sources
        var candidates: [EKSource] = []
        if let source = store.defaultCalendarForNewEvents?.source, source.sourceType == .local || source.sourceType == .calDAV { candidates.append(source) }
        candidates += sources.filter { $0.sourceType == .local || $0.sourceType == .calDAV }.filter { source in !candidates.contains { $0.sourceIdentifier == source.sourceIdentifier } }
        var failure: Error?
        for source in candidates {
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = "Studaya"; calendar.source = source
            calendar.cgColor = UIColor(red: 0.39, green: 0.32, blue: 0.85, alpha: 1).cgColor
            do {
                try store.saveCalendar(calendar, commit: true)
                p.set(calendar.calendarIdentifier, forKey: "appleCalendarID")
                return calendar
            } catch { failure = error }
        }
        throw failure ?? StudyError.invalid(String(localized: "Aucun compte calendrier ne permet de créer le calendrier Studaya. Active un calendrier local ou iCloud dans iOS."))
    }
    private func ownedEvents(in calendar: EKCalendar?, items: [CalendarExportItem]) -> [EKEvent] {
        var byID: [String: EKEvent] = [:]
        for id in mapping.values {
            if let event = store.event(withIdentifier: id), ownership.key(event.url) != nil { byID[event.eventIdentifier] = event }
        }
        guard let calendar else { return Array(byID.values) }
        let starts = items.map(\.start) + byID.values.compactMap(\.startDate) + [p.object(forKey: "appleCalendarRangeStart") as? Date ?? .now]
        let ends = items.map(\.end) + byID.values.compactMap(\.endDate) + [p.object(forKey: "appleCalendarRangeEnd") as? Date ?? .now]
        var start = (starts.min() ?? .now).addingTimeInterval(-86400)
        let end = (ends.max() ?? .now).addingTimeInterval(86400)
        // EventKit predicates are bounded; query in chunks shorter than four years.
        while start < end {
            let limit = min(Calendar.current.date(byAdding: .year, value: 3, to: start)!, end)
            let predicate = store.predicateForEvents(withStart: start, end: limit, calendars: [calendar])
            for event in store.events(matching: predicate) where ownership.key(event.url) != nil { byID[event.eventIdentifier] = event }
            start = limit
        }
        return Array(byID.values)
    }
    private func reconcile(_ db: ModelContext) throws {
        let items = CalendarExportPlan.make(subjects: try db.fetch(FetchDescriptor<Subject>()), sessions: try db.fetch(FetchDescriptor<Session>()), deadlines: try db.fetch(FetchDescriptor<StudyDeadline>()), chapters: try db.fetch(FetchDescriptor<Chapter>()), reviews: try db.fetch(FetchDescriptor<SpacedReview>()))
        let calendar = try exportCalendar()
        let existing = ownedEvents(in: calendar, items: items)
        let grouped = Dictionary(grouping: existing) { ownership.key($0.url)! }
        var retained: [EKEvent] = []
        var changes = false
        for item in items {
            let event = grouped[item.id]?.first ?? EKEvent(eventStore: store)
            if event.calendar == nil || event.title != item.title || abs((event.startDate ?? .distantPast).timeIntervalSince(item.start)) >= 1 || abs((event.endDate ?? .distantPast).timeIntervalSince(item.end)) >= 1 || event.isAllDay != item.allDay || event.notes != item.notes || event.recurrenceRules?.isEmpty == false || event.calendar.calendarIdentifier != calendar.calendarIdentifier {
                event.calendar = calendar; event.title = item.title; event.startDate = item.start; event.endDate = item.end
                event.isAllDay = item.allDay; event.notes = item.notes; event.url = ownership.url(item.id)
                // App notifications already cover reminders. Do not add duplicate Calendar alarms.
                event.alarms = []; event.recurrenceRules = []
                try store.save(event, span: .thisEvent, commit: false); changes = true
            }
            retained.append(event)
        }
        let retainedIDs = Set(retained.compactMap(\.eventIdentifier))
        for event in existing where !retainedIDs.contains(event.eventIdentifier) {
            try store.remove(event, span: .thisEvent, commit: false); changes = true
        }
        if changes { try store.commit() }
        mapping = Dictionary(uniqueKeysWithValues: retained.compactMap { event in
            guard let key = ownership.key(event.url), let id = event.eventIdentifier else { return nil }
            return (key, id)
        })
        if let min = items.map(\.start).min() { p.set(min, forKey: "appleCalendarRangeStart") }
        if let max = items.map(\.end).max() { p.set(max, forKey: "appleCalendarRangeEnd") }
        status = String(localized: "\(items.count) événement(s) synchronisé(s) dans le calendrier Studaya.")
    }
    func stop() { p.set(false, forKey: Self.enabledKey); status = String(localized: "Synchronisation arrêtée. Les événements exportés restent dans Calendrier Apple.") }
    func deleteExported() {
        guard !busy else { return }
        // Disable first: a model refresh must never recreate events during deletion.
        p.set(false, forKey: Self.enabledKey)
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            status = String(localized: "Autorise l’accès complet dans les réglages iOS pour supprimer les événements exportés. La synchronisation est arrêtée."); return
        }
        busy = true; defer { busy = false }
        do {
            let calendar = p.string(forKey: "appleCalendarID").flatMap { store.calendar(withIdentifier: $0) }
            let events = ownedEvents(in: calendar, items: [])
            for event in events { try store.remove(event, span: .thisEvent, commit: false) }
            if !events.isEmpty { try store.commit() }
            mapping = [:]
            p.removeObject(forKey: "appleCalendarRangeStart"); p.removeObject(forKey: "appleCalendarRangeEnd")
            status = String(localized: "\(events.count) événement(s) Studaya supprimé(s) de Calendrier Apple. Synchronisation désactivée.")
        } catch { store.reset(); status = String(localized: "Suppression incomplète, réessaie : ") + error.localizedDescription }
    }
}

struct CalendarSyncSettings: View {
    @Environment(\.modelContext) private var db
    @ObservedObject private var sync = AppleCalendarSync.shared
    @AppStorage(AppleCalendarSync.enabledKey) private var enabled = false
    @State private var confirmDelete = false
    var body: some View {
        Form {
            Section(String(localized: "Studaya → Calendrier Apple")) {
                Text(String(localized: "Retrouve tes séances, examens, contrôles, présentations et rappels espacés dans un calendrier dédié Studaya."))
                Text(String(localized: "Les modifications se font dans Studaya puis sont répercutées à l’ouverture de l’app. Les changements faits dans Calendrier Apple ne sont pas importés.")).font(.footnote).foregroundStyle(.secondary)
                Button(enabled ? String(localized: "Synchroniser maintenant") : String(localized: "Activer la synchronisation"), systemImage: "calendar.badge.plus") { Task { await sync.connect(db) } }.disabled(sync.busy)
                if enabled { Button(String(localized: "Arrêter la synchronisation")) { sync.stop() }.disabled(sync.busy) }
                if sync.busy { ProgressView("Synchronisation…") }
                if !sync.status.isEmpty { Text(sync.status).font(.footnote).accessibilityIdentifier("calendar.sync.status") }
            }
            Section(String(localized: "Supprimer les événements exportés")) {
                Button(String(localized: "Tout supprimer de Calendrier Apple"), role: .destructive) { confirmDelete = true }.disabled(sync.busy)
                Text(String(localized: "Retire les événements exportés par cette installation de Studaya et arrête la synchronisation. Le planning dans Studaya reste disponible.")).font(.footnote).foregroundStyle(.secondary)
            }
            Section(String(localized: "À savoir")) {
                Text(String(localized: "iOS demande un accès complet pour retrouver, mettre à jour et supprimer nos événements. Studaya gère uniquement ses propres événements exportés."))
                Text(String(localized: "Les examens sans horaire occupent la journée. Les contrôles, présentations et rappels sont des repères de 15 minutes, pas leur durée réelle. Les séances conservent leur durée prévue.")).font(.footnote)
                Link(String(localized: "Autorisations Calendrier dans les réglages iOS"), destination: URL(string: UIApplication.openSettingsURLString)!)
            }
        }.studyScreen().navigationTitle(String(localized: "Calendrier Apple")).navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(String(localized: "Supprimer tous les événements exportés par Studaya ?"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(String(localized: "Supprimer les événements Studaya"), role: .destructive) { sync.deleteExported() }
            } message: { Text(String(localized: "Cette action retire les événements exportés depuis cet appareil et désactive la synchronisation.")) }
    }
}
