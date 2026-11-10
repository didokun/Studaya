import SwiftUI
import SwiftData

@Model final class TimeBlock {
    var id = UUID()
    var title = ""
    var start = Date()
    var end = Date().addingTimeInterval(3600)
    var weekday = 0 // 0 = one-off interval; 1...7 = weekly
    var until = Date().addingTimeInterval(365 * 86400)
    init() {}
    func interval(on day: Date, calendar: Calendar = .current) -> DateInterval? {
        if weekday == 0 {
            let date = DateInterval(start: start, end: max(start, end))
            return date.intersects(calendar.dateInterval(of: .day, for: day)!) ? date : nil
        }
        guard day >= calendar.startOfDay(for: start), day < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: until))!,
              calendar.component(.weekday, from: day) == weekday,
              let beginning = calendar.date(bySettingHour: calendar.component(.hour, from: start), minute: calendar.component(.minute, from: start), second: 0, of: day) else { return nil }
        return DateInterval(start: beginning, duration: end.timeIntervalSince(start))
    }
    func conflicts(start slot: Date, minutes: Int, calendar: Calendar = .current) -> Bool {
        let limit = slot.addingTimeInterval(Double(minutes * 60))
        return [calendar.startOfDay(for: slot), calendar.date(byAdding: .day, value: -1, to: slot)!].contains { day in
            guard let interval = interval(on: day, calendar: calendar) else { return false }
            return interval.start < limit && interval.end > slot
        }
    }
}

struct TimeBlockEditor: View {
    var existing: TimeBlock? = nil
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date()
    @State private var end = Date.now.addingTimeInterval(3600)
    @State private var weekly = false
    @State private var weekday = 2
    @State private var until = Date.now.addingTimeInterval(180 * 86400)
    @State private var message: String?
    @State private var saved = false
    var body: some View {
        NavigationStack {
            Form {
                TextField("Cours, travail, vacances…", text: $title)
                Toggle("Chaque semaine", isOn: $weekly)
                if weekly {
                    Picker("Jour", selection: $weekday) {
                        ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                    }
                }
                DatePicker("Début", selection: $start)
                DatePicker("Fin", selection: $end)
                if weekly { DatePicker("Répéter jusqu’au", selection: $until, displayedComponents: .date) }
                Text("Aucune révision automatique ne sera placée sur cette période. Pour des vacances, choisis une période sans répétition.").font(.footnote)
            }.studyScreen().navigationTitle("Indisponibilité").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() }.disabled(saved || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || end <= start || (weekly && (end.timeIntervalSince(start) > 86400 || until < start))) }
            }
        }.onAppear {
            if let existing { title = existing.title; start = existing.start; end = existing.end; weekday = max(1, existing.weekday); weekly = existing.weekday != 0; until = existing.until }
        }.alert("Planning", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") { if saved { dismiss() } } } message: { Text(message ?? "") }
    }
    private func save() {
        let block = existing ?? TimeBlock()
        if existing == nil { db.insert(block) }
        block.title = title.trimmingCharacters(in: .whitespacesAndNewlines); block.start = start; block.end = end
        block.weekday = weekly ? weekday : 0; block.until = until
        do {
            let sessions = try db.fetch(FetchDescriptor<Session>())
            guard !sessions.contains(where: { !$0.done && $0.pinned && block.conflicts(start: $0.start, minutes: $0.minutes) }) else {
                db.rollback(); message = "Une séance reportée occupe cette période. Déplace-la avant de bloquer ce créneau."; return
            }
            let missing = try Scheduler.rebuild(db); saved = true
            if missing > 0 { message = "\(missing) séances sans créneau après prise en compte de tes indisponibilités." } else { dismiss() }
        } catch { db.rollback(); message = error.localizedDescription }
    }
}

struct UnavailabilitySettings: View {
    @Query(sort: \TimeBlock.start) private var blocks: [TimeBlock]
    @Environment(\.modelContext) private var db
    @State private var add = false
    @State private var edit: TimeBlock?
    @State private var message: String?
    var body: some View {
        List {
            Text("Bloque tes cours, ton travail ou tes vacances pour garder un planning réaliste.")
            ForEach(blocks) { block in
                Button { edit = block } label: {
                    VStack(alignment: .leading) {
                        Text(block.title).font(.headline)
                        Text(block.weekday == 0 ? block.start.formatted() + " – " + block.end.formatted() : "Chaque " + Calendar.current.weekdaySymbols[block.weekday - 1] + " · " + block.start.formatted(date: .omitted, time: .shortened) + " – " + block.end.formatted(date: .omitted, time: .shortened)).font(.caption)
                    }
                }
            }.onDelete { offsets in
                for i in offsets { db.delete(blocks[i]) }
                do { try Scheduler.rebuild(db) } catch { db.rollback(); message = error.localizedDescription }
            }
            Button("Ajouter une indisponibilité", systemImage: "plus") { add = true }
        }.sheet(isPresented: $add) { TimeBlockEditor() }
        .sheet(item: $edit) { TimeBlockEditor(existing: $0) }
        .alert("Planning", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
}

struct SessionReschedule: View {
    let session: Session
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Text(session.title)
                DatePicker("Nouveau créneau", selection: $date, in: Date.now...)
                Text("Ce créneau sera conservé lors des recalculs du planning.").font(.footnote)
                Button("Reporter la séance") {
                    do { try StudyActions.reschedule(session, to: date, db: db); dismiss() }
                    catch { self.error = error.localizedDescription }
                }
            }.studyScreen().navigationTitle("Reporter").toolbar { Button("Fermer") { dismiss() } }
        }.onAppear { date = max(session.start, Date.now.addingTimeInterval(3600)) }
        .alert("Créneau indisponible", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
}
