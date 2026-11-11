import SwiftUI
import SwiftData

struct Library: View {
    var onPathCreated: () -> Void = {}
    @Query(sort: \Subject.name) var subjects: [Subject]
    @Query var profiles: [AcademicProfile]
    @Query var chapters: [Chapter]
    @Query var sessions: [Session]
    @State var add = false
    @State private var creatingPath = false
    @State private var search = ""
    @State private var removing: Subject?
    @State private var confirmDelete = false
    @State private var error: String?
    @Environment(\.modelContext) private var db
    var groups: [String] { Set(subjects.map(group)).sorted() }
    func group(_ subject: Subject) -> String {
        String(localized: "Année \(subject.year)") + (profiles.first?.usesSemesters == false ? "" : String(localized: " · Semestre \(subject.semester)"))
    }
    var body: some View {
        List {
            Banner(caption: String(localized: "TON CAMPUS"), value: String(localized: "De la curiosité à la maîtrise."), icon: "books.vertical.fill")
            Button(String(localized: "Créer mon Parcours de révision"), systemImage: "sparkles") { creatingPath = true }
            ForEach(groups, id: \.self) { key in
                Section(key) {
                    ForEach(subjects.filter { group($0) == key && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.displayCode.localizedCaseInsensitiveContains(search)) }) { subject in
                        subjectRow(subject)
                    }
                }
            }
            Button(String(localized: "Ajouter une matière"), systemImage: "plus") { add = true }
            NavigationLink(String(localized: "Retrouver mes archives")) { StudyArchive() }
        }.searchable(text: $search, prompt: String(localized: "Rechercher une matière"))
        .sheet(isPresented: $add) { RevisionEditor(kind: .subject(nil)) }
        .sheet(isPresented: $creatingPath) { RevisionPathBuilder(onCreated: onPathCreated) }
        .confirmationDialog(String(localized: "Supprimer cette matière et ses cours, TD, cartes et échéances ?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(String(localized: "Supprimer la matière"), role: .destructive) {
                guard let removing else { return }
                do { try StudyActions.deleteSubject(removing, db: db); try Scheduler.rebuild(db) } catch { db.rollback(); self.error = error.localizedDescription }
                self.removing = nil
            }
        }
        .alert(String(localized: "Suppression"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }
    private func subjectRow(_ subject: Subject) -> some View {
        let color = StudyDesign.color(for: subject.name)
        return NavigationLink { SubjectPage(subject: subject) } label: {
            HStack(alignment: .top, spacing: 14) {
                StudyBadge(symbol: StudyDesign.symbol(for: subject.name), color: color, size: 50)
                VStack(alignment: .leading, spacing: 12) {
                    Text(subject.displayCode).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(StudyDesign.ink)
                        .accessibilityLabel(subject.name + ", " + subject.displayCode)
                    Text(subject.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if subject.hasExam {
                        Label(subject.exam.formatted(.dateTime.day().month(.wide)), systemImage: "calendar").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    } else { Text(String(localized: "Date d’examen à préciser")).font(.caption).foregroundStyle(.secondary) }
                    SubjectProgress(subject: subject, chapters: chapters, sessions: sessions).tint(color)
                }
            }.padding(.vertical, 10)
        }.swipeActions {
            Button(String(localized: "Supprimer"), role: .destructive) { removing = subject; confirmDelete = true }
        }
    }

}

struct SubjectPage: View {
    let subject: Subject
    @Query(sort: \Chapter.name) var all: [Chapter]
    @Query var sessions: [Session]
    @Query(sort: \StudyDeadline.due) var deadlines: [StudyDeadline]
    @State var edit = false
    @State private var importPhoto = false
    @State var add = false
    @State var addDeadline = false
    @State var editingDeadline: StudyDeadline?
    @State private var removingChapter: Chapter?
    @State private var confirmChapterDelete = false
    @State var message: String?
    @Environment(\.modelContext) private var db
    var units: [Chapter] { all.filter { $0.subjectID == subject.id } }
    var body: some View {
        List {
            Section {
                Button { importPhoto = true } label: {
                    HStack(spacing: 12) {
                        Label(String(localized: "Importer une photo"), systemImage: "camera.viewfinder")
                    .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.85)
                        Spacer(minLength: 8)
                        Label("AI", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StudyDesign.mint)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(StudyDesign.mint.opacity(0.12), in: Capsule())
                    }
                }.accessibilityLabel(String(localized: "Importer un planning en photo"))
            }
            Section(String(localized: "Ma progression")) { SubjectProgress(subject: subject, chapters: all, sessions: sessions) }
            Section(String(localized: "Examen · ") + subject.examMode) {
                if subject.hasExam { LabeledContent(String(localized: "Date prévue")) { Text(subject.exam, format: .dateTime.day().month(.wide).year()) } } else { Text(String(localized: "Date à préciser")) }
                Button(String(localized: "Modifier la matière")) { edit = true }
            }
            Section(String(localized: "Contrôles, présentations et rendus")) {
                ForEach(deadlines.filter { $0.subjectID == subject.id && !$0.done }) { item in
                    VStack(alignment: .leading) {
                        DeadlineRow(item: item)
                        Button(String(localized: "Modifier l’échéance")) { editingDeadline = item }.font(.caption)
                    }
                }
                Button(String(localized: "Ajouter une échéance"), systemImage: "calendar.badge.plus") { addDeadline = true }
            }
            Section(String(localized: "Chronologie des cours et TD")) {
                let active = TimelineOrder.chapters(units.filter { !$0.completed })
                UnitTimeline(ids: active.map(\.id)) { order in
                    for (position, id) in order.enumerated() {
                        active.first { $0.id == id }?.timelineIndex = position
                    }
                    do { try db.save() } catch { db.rollback(); message = error.localizedDescription }
                } card: { id in
                    if let chapter = active.first(where: { $0.id == id }) {
                        VStack(alignment: .leading, spacing: 5) {
                            if let date = chapter.startDate { Text(date, format: .dateTime.day().month(.wide)).font(.caption) }
                            unitRow(chapter).buttonStyle(.plain)
                            Button(String(localized: "Supprimer"), role: .destructive) { removingChapter = chapter; confirmChapterDelete = true }.font(.caption).buttonStyle(.borderless)
                        }
                    }
                }
            }
            Button(String(localized: "Ajouter un cours ou un TD"), systemImage: "plus") { add = true }
            Section(String(localized: "Terminés · conservés séparément")) {
                ForEach(units.filter(\.completed)) { chapter in unitRow(chapter) }
                ForEach(deadlines.filter { $0.subjectID == subject.id && $0.done }) { DeadlineRow(item: $0) }
            }
        }.studyScreen().navigationTitle(subject.displayCode)
        .sheet(isPresented: $edit) { RevisionEditor(kind: .subject(subject)) }
        .sheet(isPresented: $importPhoto) { PhotoPlanningGate(subject: subject) }
        .sheet(isPresented: $add) { RevisionEditor(kind: .chapter(subject.id, nil)) }
        .sheet(isPresented: $addDeadline) { DeadlineEditor(subject: subject) }
        .sheet(item: $editingDeadline) { DeadlineEditor(subject: subject, existing: $0) }
        .confirmationDialog(String(localized: "Supprimer ce cours ou TD, ses cartes et son historique de séances ?"), isPresented: $confirmChapterDelete, titleVisibility: .visible) {
            Button(String(localized: "Supprimer le cours ou TD"), role: .destructive) {
                guard let removingChapter else { return }
                do { try StudyActions.deleteChapter(removingChapter, db: db); try Scheduler.rebuild(db) } catch { db.rollback(); message = error.localizedDescription }
                self.removingChapter = nil
            }
        }
        .alert(String(localized: "Planning"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
    func unitRow(_ chapter: Chapter) -> some View {
        NavigationLink { ChapterPage(chapter: chapter) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    StudyBadge(symbol: chapter.completed ? "checkmark.seal.fill" : chapter.kind == "TD" ? "pencil.and.outline" : "text.book.closed.fill", color: chapter.completed ? StudyDesign.mint : StudyDesign.color(for: subject.name), size: 38)
                    Text(chapter.name).font(.headline)
                    Spacer(minLength: 0)
                    StudyPill(title: subject.displayCode + " · " + L10n.key(chapter.kind), color: StudyDesign.color(for: subject.name))
                }
                ProgressView(value: StudyCoach.progress(chapter, sessions: sessions))
                Text(chapter.kind == "TD" ? String(localized: "\(chapter.exercisesDone) / \(chapter.exerciseCount) exercices") : String(localized: "\(Int(StudyCoach.progress(chapter, sessions: sessions) * 100)) % · \(chapter.requiredSessions) séances visées")).font(.caption)
            }
        }.swipeActions {
            Button(String(localized: "Supprimer"), role: .destructive) { removingChapter = chapter; confirmChapterDelete = true }
        }
    }
}

struct ChapterPage: View {
    @Bindable var chapter: Chapter
    @Query var sessions: [Session]
    @State var message: String?
    @Query(sort: \Flashcard.question) var all: [Flashcard]
    @State var add = false
    @State var edit = false
    @State var reviewing = false
    @State private var focus = false
    @Query(sort: \SpacedReview.due) private var reviews: [SpacedReview]
    @Environment(\.modelContext) var db
    var cards: [Flashcard] { all.filter { $0.chapterID == chapter.id } }
    var body: some View {
        List {
            Section(String(localized: "Progression · ") + L10n.key(chapter.kind)) {
                ProgressView(value: StudyCoach.progress(chapter, sessions: sessions))
                Text(StudyCoach.advice(chapter, sessions: sessions))
                if chapter.kind == "TD", !chapter.completed {
                    Stepper(String(localized: "\(chapter.exercisesDone) / \(chapter.exerciseCount) exercices terminés"), value: $chapter.exercisesDone, in: 0...chapter.exerciseCount)
                    if chapter.exercisesDone == chapter.exerciseCount {
                        Toggle(String(localized: "Synthèse refaite sans correction"), isOn: $chapter.synthesisDone)
                    }
                }
                Button(chapter.completed ? String(localized: "Remettre en cours") : String(localized: "Valider et classer comme terminé")) {
                    do { try StudyActions.complete(chapter, db: db) } catch { db.rollback(); message = error.localizedDescription }
                }.disabled(!chapter.completed && chapter.kind == "TD" && (chapter.exercisesDone < chapter.exerciseCount || !chapter.synthesisDone))
                Button(String(localized: "Travailler ce cours ou TD"), systemImage: "timer") { focus = true }.disabled(chapter.completed)
                Button(String(localized: "Modifier le cours ou TD")) { edit = true }
            }
            if chapter.completed {
                Section(String(localized: "Rappels espacés · le travail reste terminé")) {
                    ForEach(reviews.filter { $0.chapterID == chapter.id && !$0.done }) { ReviewRow(review: $0, chapter: chapter) }
                }
            }
            Section(String(localized: "Fiche de révision")) { Text(chapter.notes.isEmpty ? String(localized: "Ajoute tes notes en modifiant le chapitre.") : chapter.notes) }
            Section(String(localized: "Flashcards")) {
                ForEach(cards) { card in
                    DisclosureGroup {
                        Text(card.answer)
                        Button(card.known ? String(localized: "Remettre à réviser") : String(localized: "Marquer comme mémorisée")) { card.known.toggle() }
                    } label: { Label(card.question, systemImage: card.known ? "checkmark.circle.fill" : "rectangle.on.rectangle") }
                }.onDelete { offsets in let items = cards; for i in offsets { db.delete(items[i]) } }
                Button(String(localized: "Créer une flashcard"), systemImage: "plus") { add = true }
            }
            Button(String(localized: "Réviser les cartes")) { reviewing = true }.disabled(cards.isEmpty)
        }.studyScreen().navigationTitle(chapter.name)
        .alert(String(localized: "Planning"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
        .sheet(isPresented: $add) { RevisionEditor(kind: .card(chapter.id)) }
        .sheet(isPresented: $edit) { RevisionEditor(kind: .chapter(chapter.subjectID, chapter)) }
        .sheet(isPresented: $focus) { NavigationStack { Focus(initialChapterID: chapter.id).toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Fermer")) { focus = false } } } } }
        .sheet(isPresented: $reviewing) { ReviewDeck(cards: cards.sorted { !$0.known && $1.known }) }
    }
}

struct ReviewDeck: View {
    @State var cards: [Flashcard]
    @State var index = 0
    @State var revealed = false
    @State var response = ""
    @State var score = 0
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if index < cards.count {
                    Text(String(localized: "Carte \(index + 1) sur \(cards.count)")).foregroundStyle(.secondary)
                    Text(cards[index].question).font(.title.bold())
                    if !revealed { TextField(String(localized: "Ta réponse de mémoire"), text: $response, axis: .vertical).textFieldStyle(StudyTextFieldStyle(boxed: true)) }
                    if revealed {
                        if !response.isEmpty { Text(String(localized: "Ta réponse · ") + response).foregroundStyle(.secondary) }
                        Text(cards[index].answer).font(.title3)
                        Button(String(localized: "Mémorisée")) { advance(true) }.buttonStyle(Primary())
                        Button(String(localized: "À revoir")) { advance(false) }
                    } else { Button(String(localized: "Afficher la réponse")) { revealed = true }.buttonStyle(Primary()) }
                } else { Label(String(localized: "Série terminée · \(score) / \(cards.count)"), systemImage: "checkmark.circle.fill").font(.title) }
            }.padding().navigationTitle("Rappel actif").toolbar { Button(String(localized: "Fermer")) { dismiss() } }
        }
    }
    func advance(_ known: Bool) { cards[index].known = known; if known { score += 1 }; response = ""; index += 1; revealed = false }
}

enum EditorKind {
    case subject(Subject?)
    case chapter(UUID, Chapter?)
    case card(UUID)
}

struct RevisionEditor: View {
    let kind: EditorKind
    @State var name = ""
    @State private var code = ""
    @Query var profiles: [AcademicProfile]
    @State var year = 1
    @State var semester = 1
    @State var examMode = "Par semestre"
    @State var unitKind = "Cours"
    @State var unitStart = Date()
    @State var exerciseCount = 5
    @State var hasExam = true
    @State var exam = Calendar.current.date(byAdding: .day, value: 7, to: Date.now)!
    @State var notes = ""
    @State var confidence = 2
    @State var target = 2
    @State var answer = ""
    @State var notice: String?
    @State var saved = false
    @Environment(\.modelContext) var db
    @Environment(\.dismiss) var dismiss
    var clean: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var title: String {
        switch kind { case .subject: String(localized: "Matière"); case .chapter: String(localized: "Chapitre"); case .card: String(localized: "Flashcard") }
    }
    var valid: Bool {
        if case .card = kind { return !clean.isEmpty && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return !clean.isEmpty
    }
    var body: some View {
        NavigationStack {
            Form {
                switch kind {
                case .subject:
                    TextField(String(localized: "Nom de la matière"), text: $name)
                    SubjectCodeField(name: name, code: $code)
                    Stepper(String(localized: "Année \(year)"), value: $year, in: 1...max(year, profiles.first?.years ?? 8))
                    if profiles.first?.usesSemesters ?? true {
                        Picker(String(localized: "Semestre"), selection: $semester) { Text("S1").tag(1); Text("S2").tag(2) }
                    }
                    Picker(String(localized: "Examens"), selection: $examMode) { Text("Par semestre").tag("Par semestre"); Text("En fin de matière").tag("En fin de matière") }
                    Toggle(String(localized: "Date d’examen connue"), isOn: $hasExam)
                    if hasExam { DatePicker("Examen", selection: $exam, displayedComponents: .date) }
                case .chapter:
                    Picker(String(localized: "Type"), selection: $unitKind) { Text("Cours").tag("Cours"); Text("TD").tag("TD") }.accessibilityIdentifier("revision.unitKind")
                    TextField(String(localized: "Nom du cours ou TD"), text: $name)
                    DatePicker(String(localized: "Début du cours ou TD"), selection: $unitStart, displayedComponents: .date)
                    if unitKind == "TD" { Stepper(String(localized: "\(exerciseCount) exercices"), value: $exerciseCount, in: 1...100) }
                    TextField(String(localized: "Fiche de révision"), text: $notes, axis: .vertical).lineLimit(3...10)
                    Picker(String(localized: "Confiance"), selection: $confidence) {
                        Text(String(localized: "Fragile · 1 rappel en plus")).tag(1)
                        Text(String(localized: "En progression")).tag(2)
                        Text(String(localized: "À l’aise")).tag(3)
                    }
                    Stepper(String(localized: "Objectif · \(target) séance(s)"), value: $target, in: 1...30)
                case .card:
                    TextField(String(localized: "Question"), text: $name, axis: .vertical)
                    TextField(String(localized: "Réponse"), text: $answer, axis: .vertical)
                }
            }.studyScreen().navigationTitle(title).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Annuler")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(String(localized: "Enregistrer")) { save() }.disabled(!valid || saved) }
            }
        }.onAppear {
            switch kind {
            case .subject(let existing): if let existing { name = existing.name; code = existing.code; year = existing.year; semester = existing.semester; examMode = existing.examMode; hasExam = existing.hasExam; if existing.hasExam { exam = existing.exam } }
            case .chapter(_, let existing): if let existing { name = existing.name; unitStart = existing.startDate ?? .now; unitKind = existing.kind; exerciseCount = existing.exerciseCount; target = existing.target; notes = existing.notes; confidence = existing.confidence }
            case .card: break
            }
        }.alert(String(localized: "Planning"), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") { if saved { dismiss() } }
        } message: { Text(notice ?? "") }
    }
    func save() {
        do {
            switch kind {
            case .subject(let existing):
                let subject = existing ?? Subject(clean, exam: exam)
                subject.name = clean; subject.code = SubjectCode.normalize(code); subject.exam = exam; subject.hasExam = hasExam
                subject.year = year; subject.examMode = examMode
                if profiles.first?.usesSemesters ?? true { subject.semester = semester }
                if existing == nil { db.insert(subject) }
                if let profile = profiles.first {
                    profile.courses = Array(Set(try db.fetch(FetchDescriptor<Subject>()).map(\.name))).sorted()
                }
            case .chapter(let id, let existing):
                let chapter = existing ?? Chapter(clean, subject: id, target: target)
                chapter.name = clean; chapter.target = target
                chapter.kind = unitKind; chapter.startDate = unitStart; chapter.exerciseCount = exerciseCount
                chapter.exercisesDone = min(chapter.exercisesDone, exerciseCount)
                chapter.notes = notes; chapter.confidence = confidence
                if existing == nil { db.insert(chapter) }
            case .card(let id):
                db.insert(Flashcard(clean, answer: answer, chapter: id))
                try db.save(); dismiss(); return
            }
            let missing = try Scheduler.rebuild(db)
            saved = true
            if missing > 0 { notice = String(localized: "\(missing) séance(s) sans créneau avant examen. Tu peux élargir tes disponibilités dans les réglages.") }
            else { dismiss() }
        } catch { db.rollback(); notice = error.localizedDescription }
    }
}
