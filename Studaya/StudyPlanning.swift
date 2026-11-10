import SwiftUI
import SwiftData

@Model final class StudyDeadline {
    var id = UUID()
    var subjectID = UUID()
    var title = ""
    var kind = "Contrôle"
    var due = Date()
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
        if chapter.completed { return "Terminé et conservé dans ton historique. Priorité aux autres cours et TD." }
        if chapter.kind == "TD", progress(chapter, sessions: sessions) >= 1 {
            return "Refais un exercice de synthèse de bout en bout, sans correction, puis valide le TD."
        }
        if chapter.confidence == 1 { return "Reprends les points fragiles, puis teste-toi sans tes notes." }
        return chapter.kind == "TD" ? "Avance exercice par exercice et note tes erreurs avant de regarder la correction." : "Explique ce cours de mémoire, puis vérifie les points oubliés."
    }
}

struct DeadlineRow: View {
    @Bindable var item: StudyDeadline
    @Environment(\.modelContext) private var db
    @State private var error: String?
    var body: some View {
        HStack {
            Button {
                item.done.toggle()
                do { try Scheduler.rebuild(db) } catch { db.rollback(); self.error = error.localizedDescription }
            } label: { Image(systemName: item.done ? "checkmark.circle.fill" : "circle") }
                .buttonStyle(.borderless).accessibilityLabel(item.done ? "Remettre à faire" : "Marquer comme terminé")
            VStack(alignment: .leading, spacing: 5) {
                Text(item.kind + " · " + item.title).font(.headline)
                Text(item.due, format: .dateTime.day().month().hour().minute()).font(.caption)
                if !item.done {
                    Text(item.due < .now ? "En retard" : "Rappel " + item.reminderDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(item.due < .now ? .red : .secondary)
                }
            }
        }.alert("Planning", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
}

struct DeadlineEditor: View {
    let subject: Subject
    var existing: StudyDeadline? = nil
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind = "Contrôle"
    @State private var due = Date.now.addingTimeInterval(7 * 86400)
    @State private var sessions = 2
    @State private var days = 2
    @State private var message: String?
    @State private var saved = false
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section(subject.name) {
                    TextField("Titre", text: $title)
                    Picker("Type", selection: $kind) {
                        ForEach(["Examen", "Contrôle", "Présentation", "Rendu"], id: \.self) { Text($0) }
                    }
                    DatePicker("Date limite", selection: $due)
                    Stepper("Préparation · \(sessions) séances", value: $sessions, in: 1...30)
                    Stepper("Rappel · \(days) jour(s) avant", value: $days, in: 0...30)
                    Text("Le rappel apparaît dans l’accueil et le calendrier. Active les notifications d’échéance dans Réglages pour le recevoir même lorsque l’app est fermée.").font(.footnote)
                }
                if existing != nil { Button("Supprimer l’échéance", role: .destructive) { confirmDelete = true } }
            }.studyScreen().navigationTitle("Échéance").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() }.disabled(saved || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }.confirmationDialog("Supprimer cette échéance et ses séances de préparation ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                guard let existing else { return }
                do { try StudyActions.deleteDeadline(existing, db: db); try Scheduler.rebuild(db); dismiss() } catch { db.rollback(); message = error.localizedDescription }
            }
        }.onAppear {
            if let existing { title = existing.title; kind = existing.kind; due = existing.due; sessions = existing.preparationSessions; days = existing.reminderDays }
        }.alert("Planning", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { if saved { dismiss() } }
        } message: { Text(message ?? "") }
    }
    private func save() {
        let item = existing ?? StudyDeadline(subject: subject.id)
        if existing == nil { db.insert(item) }
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines); item.kind = kind
        item.due = due; item.preparationSessions = sessions; item.reminderDays = days
        do {
            let missing = try Scheduler.rebuild(db)
            saved = true
            if missing > 0 { message = "\(missing) séance(s) sans créneau. Élargis tes disponibilités." } else { dismiss() }
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
            Text("\(Int(progress * 100)) % du travail suivi · ajoute tes cours et TD pour affiner ce suivi")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StudyMonth: View {
    @Binding var selection: Date
    let marked: (Date) -> Bool
    var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    var body: some View {
        let first = calendar.dateInterval(of: .month, for: selection)!.start
        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        let count = calendar.range(of: .day, in: .month, for: selection)!.count
        VStack(spacing: 12) {
            HStack {
                Button("Mois précédent", systemImage: "chevron.left") { move(-1) }.labelStyle(.iconOnly)
                Spacer()
                Text(selection, format: .dateTime.month(.wide).year()).font(.headline)
                Spacer()
                Button("Mois suivant", systemImage: "chevron.right") { move(1) }.labelStyle(.iconOnly).accessibilityLabel("Mois suivant").accessibilityIdentifier("calendar.nextMonth")
            }.buttonStyle(StudyIconButtonStyle())
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Text(["L", "M", "M", "J", "V", "S", "D"][i]).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 4) {
                ForEach(0..<((offset + count + 6) / 7), id: \.self) { week in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { weekday in
                            let index = week * 7 + weekday
                            if index < offset || index >= offset + count {
                                Color.clear.frame(maxWidth: .infinity).frame(height: 44)
                            } else {
                                let day = calendar.date(byAdding: .day, value: index - offset, to: first)!
                                Button { selection = day } label: {
                                    VStack(spacing: 4) {
                                        Text(day, format: .dateTime.day())
                                        Circle().fill(marked(day) ? Color.mintBrand : .clear).frame(width: 5, height: 5)
                                    }.frame(maxWidth: .infinity).frame(height: 44)
                                        .background(calendar.isDate(day, inSameDayAs: selection) ? Color.mintBrand.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                                    .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (marked(day) ? ", rappel ou échéance" : ""))
                                    .accessibilityAddTraits(calendar.isDate(day, inSameDayAs: selection) ? .isSelected : [])
                            }
                        }
                    }.frame(height: 44)
                }
            }
            Label("Un point vert indique un rappel ou une échéance", systemImage: "circle.fill").font(.caption).foregroundStyle(.secondary)
        }
    }
    func move(_ months: Int) { selection = calendar.date(byAdding: .month, value: months, to: selection)! }
}
