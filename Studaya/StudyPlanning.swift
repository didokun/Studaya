import SwiftUI
import SwiftData

struct PlanningUnitOption: Identifiable {
    let id: UUID
    let name: String
    let kind: String
}

@Model final class StudyDeadline {
    var id = UUID()
    var subjectID = UUID()
    var chapterID: UUID?
    var title = ""
    var kind = "Contrôle"
    var due = Date()
    var hasDueDate = true
    var done = false
    var preparationSessions = 2
    var reminderDays = 2
    var reminderDate: Date { Calendar.current.date(byAdding: .day, value: -reminderDays, to: due) ?? due }
    init(subject: UUID) { subjectID = subject }
}

enum StudyCoach {
    static func progress(_ chapter: Chapter, sessions: [Session]) -> Double {
        if chapter.completed { return 1 }
        if chapter.kind == "TD" { return Double(min(chapter.exercisesDone, chapter.exerciseCount)) / Double(max(1, chapter.exerciseCount)) }
        return Double(min(chapter.requiredSessions, sessions.filter { $0.chapterID == chapter.id && $0.done && $0.reviewID == nil }.count)) / Double(max(1, chapter.requiredSessions))
    }
    static func progress(subject: Subject, chapters: [Chapter], sessions: [Session]) -> Double {
        let units = chapters.filter { $0.subjectID == subject.id }
        guard !units.isEmpty else { return 0 }
        return units.reduce(0) { $0 + progress($1, sessions: sessions) } / Double(units.count)
    }
    static func advice(_ chapter: Chapter, sessions: [Session]) -> String {
        if chapter.completed { return String(localized: "Terminé et conservé dans ton historique. Priorité aux autres cours et TD.") }
        if chapter.kind == "TD", progress(chapter, sessions: sessions) >= 1 {
            return String(localized: "Refais un exercice de synthèse de bout en bout, sans correction, puis valide le TD.")
        }
        if chapter.confidence == 1 { return String(localized: "Reprends les points fragiles, puis teste-toi sans tes notes.") }
        return chapter.kind == "TD" ? String(localized: "Avance exercice par exercice et note tes erreurs avant de regarder la correction.") : String(localized: "Explique ce cours de mémoire, puis vérifie les points oubliés.")
    }
}

struct DeadlineRow: View {
    @Bindable var item: StudyDeadline
    @Environment(\.modelContext) private var db
    @Query private var chapters: [Chapter]
    @Query private var subjects: [Subject]
    @State private var error: String?
    var body: some View {
        HStack {
            Button {
                item.done.toggle()
                do { try Scheduler.rebuild(db) } catch { db.rollback(); self.error = error.localizedDescription }
            } label: { Image(systemName: item.done ? "checkmark.circle.fill" : "circle") }
                .buttonStyle(.borderless).accessibilityLabel(item.done ? String(localized: "Remettre à faire") : String(localized: "Marquer comme terminé"))
            VStack(alignment: .leading, spacing: 5) {
                Text(StudyLabels.deadline(item, subjects: subjects, chapters: chapters)).font(.headline)
                if item.hasDueDate {
                    Text(item.due, format: .dateTime.day().month().hour().minute()).font(.caption)
                } else { Text(String(localized: "Date à préciser")).font(.caption).foregroundStyle(.secondary) }
                if !item.done && item.hasDueDate {
                    Text(item.due < .now ? String(localized: "En retard") : String(localized: "Rappel ") + item.reminderDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(item.due < .now ? .red : .secondary)
                }
            }
        }.alert(String(localized: "Planning"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
}

struct DeadlineEditor: View {
    let subject: Subject
    var existing: StudyDeadline? = nil
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Chapter.name) private var chapters: [Chapter]
    @State private var chapterID: UUID?
    @State private var kind = "Contrôle"
    @State private var hasDueDate = true
    @State private var due = Date.now.addingTimeInterval(7 * 86400)
    @State private var sessions = 2
    @State private var days = 2
    @State private var message: String?
    @State private var saved = false
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section(subject.displayCode) {
                    Picker(String(localized: "Type"), selection: $kind) {
                        ForEach(["Examen", "Examen final", "Contrôle", "Présentation", "Rendu"], id: \.self) { Text(L10n.key($0)) }
                    }
                    if kind == "Présentation" || kind == "Contrôle" {
                        Picker(String(localized: "Cours ou TD lié"), selection: $chapterID) {
                            Text(String(localized: "Toute la matière")).tag(nil as UUID?)
                            ForEach(chapters.filter { $0.subjectID == subject.id }) { chapter in
                                Text(L10n.key(chapter.kind) + " · " + chapter.name).tag(Optional(chapter.id))
                            }
                        }
                    } else { Label(subject.displayCode, systemImage: "books.vertical") }
                    Toggle(String(localized: "Date connue"), isOn: $hasDueDate)
                    if hasDueDate { DatePicker(String(localized: "Date limite"), selection: $due) }
                    Stepper(String(localized: "Préparation · \(sessions) séances"), value: $sessions, in: 1...30)
                    Stepper(String(localized: "Rappel · \(days) jour(s) avant"), value: $days, in: 0...30)
                    Text(String(localized: "Le rappel apparaît dans l’accueil et le calendrier. Active les notifications d’échéance dans Réglages pour le recevoir même lorsque l’app est fermée.")).font(.footnote)
                }
                if existing != nil { Button(String(localized: "Supprimer l’échéance"), role: .destructive) { confirmDelete = true } }
            }.studyScreen().navigationTitle(String(localized: "Échéance")).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Annuler")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Enregistrer")) { save() }.disabled(saved) }
            }
        }.confirmationDialog(String(localized: "Supprimer cette échéance et ses séances de préparation ?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(String(localized: "Supprimer"), role: .destructive) {
                guard let existing else { return }
                do { try StudyActions.deleteDeadline(existing, db: db); try Scheduler.rebuild(db); dismiss() } catch { db.rollback(); message = error.localizedDescription }
            }
        }.onAppear {
            if let existing { chapterID = existing.chapterID; kind = existing.kind; due = existing.due; hasDueDate = existing.hasDueDate; sessions = existing.preparationSessions; days = existing.reminderDays }
        }.alert(String(localized: "Planning"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { if saved { dismiss() } }
        } message: { Text(message ?? "") }
    }
    private func save() {
        let item = existing ?? StudyDeadline(subject: subject.id)
        if existing == nil { db.insert(item) }
        let linked = (kind == "Présentation" || kind == "Contrôle") ? chapters.first { $0.id == chapterID && $0.subjectID == subject.id } : nil
        item.chapterID = linked?.id
        item.title = linked?.name ?? subject.name
        item.kind = kind
        item.due = due; item.hasDueDate = hasDueDate; item.preparationSessions = sessions; item.reminderDays = days
        do {
            let missing = try Scheduler.rebuild(db)
            saved = true
            if missing > 0 { message = String(localized: "\(missing) séance(s) sans créneau. Élargis tes disponibilités.") } else { dismiss() }
        } catch { db.rollback(); message = error.localizedDescription }
    }
}

struct SubjectProgress: View {
    let subject: Subject
    let chapters: [Chapter]
    let sessions: [Session]
    var body: some View {
        let progress = StudyCoach.progress(subject: subject, chapters: chapters, sessions: sessions)
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
            Text(String(localized: "\(Int(progress * 100)) % du travail suivi · ajoute tes cours et TD pour affiner ce suivi"))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StudyMonth: View {
    @Binding var selection: Date
    let marked: (Date) -> Bool
    var markers: (Date) -> [CalendarDayMarker] = { _ in [] }
    var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    var body: some View {
        let first = calendar.dateInterval(of: .month, for: selection)!.start
        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        let count = calendar.range(of: .day, in: .month, for: selection)!.count
        VStack(spacing: 12) {
            HStack {
                Button(String(localized: "Mois précédent"), systemImage: "chevron.backward") { move(-1) }.labelStyle(.iconOnly)
                Spacer()
                Text(selection, format: .dateTime.month(.wide).year()).font(.headline)
                Spacer()
                Button(String(localized: "Mois suivant"), systemImage: "chevron.forward") { move(1) }.labelStyle(.iconOnly).accessibilityLabel(String(localized: "Mois suivant")).accessibilityIdentifier("calendar.nextMonth")
            }.buttonStyle(StudyIconButtonStyle())
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Text(calendar.veryShortStandaloneWeekdaySymbols[(i + 1) % 7]).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 4) {
                ForEach(0..<((offset + count + 6) / 7), id: \.self) { week in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let index = week * 7 + weekday
                            if index < offset || index >= offset + count {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 72)
                            } else {
                                let day = calendar.date(byAdding: .day, value: index - offset, to: first)!
                                let dayMarkers = markers(day)
                                let hasReminder = marked(day)
                                Button { selection = day } label: {
                                    VStack(spacing: 4) {
                                        Text(day, format: .dateTime.day())
                                        CalendarDayIcons(markers: dayMarkers, showCode: true)
                                        Circle().fill(hasReminder ? StudyDesign.accent : .clear).frame(width: 4, height: 4)
                                    }.frame(maxWidth: .infinity).frame(height: 72)
                                        .background((dayMarkers.first?.kind.color ?? Color.clear).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(calendar.isDate(day, inSameDayAs: selection) ? StudyDesign.accent : .clear, lineWidth: 2))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", " + dayMarkers.map { L10n.key($0.kind.rawValue) + " " + $0.code }.joined(separator: ", ") + (hasReminder ? String(localized: ", rappel ou échéance") : ""))
                                    .accessibilityAddTraits(calendar.isDate(day, inSameDayAs: selection) ? .isSelected : [])
                            }
                        }
                    }.frame(height: 72)
                }
            }
            CalendarLegend()
            Text(String(localized: "Icônes et codes : matières prévues · point violet : rappel ou échéance")).font(.caption2).foregroundStyle(.secondary)
        }
    }
    func move(_ months: Int) { selection = calendar.date(byAdding: .month, value: months, to: selection)! }
}
