import SwiftUI
import SwiftData

struct Library: View {
    @Query(sort: \Subject.exam) var subjects: [Subject]
    @State var add = false
    var body: some View {
        List {
            Banner(caption: "Bibliothèque", value: "Mes matières", icon: "books.vertical")
            ForEach(subjects) { subject in
                NavigationLink { SubjectPage(subject: subject) } label: {
                    VStack(alignment: .leading) { Text(subject.name).font(.headline); if subject.hasExam { Text(subject.exam, format: .dateTime.day().month(.wide).year()).foregroundStyle(.secondary) } else { Text("Date d’examen à préciser").foregroundStyle(.secondary) } }
                }
            }
            Button("Ajouter une matière", systemImage: "plus") { add = true }
        }.sheet(isPresented: $add) { RevisionEditor(kind: .subject(nil)) }
    }
}

struct SubjectPage: View {
    let subject: Subject
    @Query(sort: \Chapter.name) var all: [Chapter]
    @State var edit = false
    @State var add = false
    var body: some View {
        List {
            Section("Examen") {
                if subject.hasExam { LabeledContent("Date") { Text(subject.exam, format: .dateTime.day().month(.wide).year()) } } else { Text("Date à préciser") }
                Button("Modifier la matière") { edit = true }
            }
            Section("Chapitres") {
                ForEach(all.filter { $0.subjectID == subject.id }) { chapter in
                    NavigationLink { ChapterPage(chapter: chapter) } label: {
                        VStack(alignment: .leading) {
                            Text(chapter.name)
                            Text("\(chapter.requiredSessions) séance(s) à prévoir").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Ajouter un chapitre", systemImage: "plus") { add = true }
            }
        }.navigationTitle(subject.name)
        .sheet(isPresented: $edit) { RevisionEditor(kind: .subject(subject)) }
        .sheet(isPresented: $add) { RevisionEditor(kind: .chapter(subject.id, nil)) }
    }
}

struct ChapterPage: View {
    let chapter: Chapter
    @Query(sort: \Flashcard.question) var all: [Flashcard]
    @State var add = false
    @State var edit = false
    @State var reviewing = false
    @Environment(\.modelContext) var db
    var cards: [Flashcard] { all.filter { $0.chapterID == chapter.id } }
    var body: some View {
        List {
            Button("Modifier le chapitre") { edit = true }
            Section("Fiche de révision") { Text(chapter.notes.isEmpty ? "Ajoute tes notes en modifiant le chapitre." : chapter.notes) }
            Section("Flashcards") {
                ForEach(cards) { card in
                    DisclosureGroup {
                        Text(card.answer)
                        Button(card.known ? "Remettre à réviser" : "Marquer comme mémorisée") { card.known.toggle() }
                    } label: { Label(card.question, systemImage: card.known ? "checkmark.circle.fill" : "rectangle.on.rectangle") }
                }.onDelete { offsets in let items = cards; for i in offsets { db.delete(items[i]) } }
                Button("Créer une flashcard", systemImage: "plus") { add = true }
            }
            Button("Réviser les cartes") { reviewing = true }.disabled(cards.isEmpty)
        }.navigationTitle(chapter.name)
        .sheet(isPresented: $add) { RevisionEditor(kind: .card(chapter.id)) }
        .sheet(isPresented: $edit) { RevisionEditor(kind: .chapter(chapter.subjectID, chapter)) }
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
                    Text("Carte \(index + 1) sur \(cards.count)").foregroundStyle(.secondary)
                    Text(cards[index].question).font(.title.bold())
                    if !revealed { TextField("Ta réponse de mémoire", text: $response, axis: .vertical).textFieldStyle(.roundedBorder) }
                    if revealed {
                        if !response.isEmpty { Text("Ta réponse · " + response).foregroundStyle(.secondary) }
                        Text(cards[index].answer).font(.title3)
                        Button("Mémorisée") { advance(true) }.buttonStyle(Primary())
                        Button("À revoir") { advance(false) }
                    } else { Button("Afficher la réponse") { revealed = true }.buttonStyle(Primary()) }
                } else { Label("Série terminée · \(score) / \(cards.count)", systemImage: "checkmark.circle.fill").font(.title) }
            }.padding().navigationTitle("Rappel actif").toolbar { Button("Fermer") { dismiss() } }
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
        switch kind { case .subject: "Matière"; case .chapter: "Chapitre"; case .card: "Flashcard" }
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
                    TextField("Nom de la matière", text: $name)
                    Toggle("Date d’examen connue", isOn: $hasExam)
                    if hasExam { DatePicker("Examen", selection: $exam, displayedComponents: .date) }
                case .chapter:
                    TextField("Nom du chapitre", text: $name)
                    TextField("Fiche de révision", text: $notes, axis: .vertical).lineLimit(3...10)
                    Picker("Confiance", selection: $confidence) {
                        Text("Fragile · 1 rappel en plus").tag(1)
                        Text("En progression").tag(2)
                        Text("À l’aise").tag(3)
                    }
                    Stepper("Objectif · \(target) séance(s)", value: $target, in: 1...30)
                case .card:
                    TextField("Question", text: $name, axis: .vertical)
                    TextField("Réponse", text: $answer, axis: .vertical)
                }
            }.navigationTitle(title).toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { save() }.disabled(!valid || saved) }
            }
        }.onAppear {
            switch kind {
            case .subject(let existing): if let existing { name = existing.name; hasExam = existing.hasExam; if existing.hasExam { exam = existing.exam } }
            case .chapter(_, let existing): if let existing { name = existing.name; target = existing.target; notes = existing.notes; confidence = existing.confidence }
            case .card: break
            }
        }.alert("Planning", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK") { if saved { dismiss() } }
        } message: { Text(notice ?? "") }
    }
    func save() {
        do {
            switch kind {
            case .subject(let existing):
                let subject = existing ?? Subject(clean, exam: exam)
                subject.name = clean; subject.exam = exam; subject.hasExam = hasExam
                if existing == nil { db.insert(subject) }
            case .chapter(let id, let existing):
                let chapter = existing ?? Chapter(clean, subject: id, target: target)
                chapter.name = clean; chapter.target = target
                chapter.notes = notes; chapter.confidence = confidence
                if existing == nil { db.insert(chapter) }
            case .card(let id):
                db.insert(Flashcard(clean, answer: answer, chapter: id))
                try db.save(); dismiss(); return
            }
            let missing = try Scheduler.rebuild(db)
            saved = true
            if missing > 0 { notice = "\(missing) séance(s) sans créneau avant examen. Tu peux élargir tes disponibilités dans les réglages." }
            else { dismiss() }
        } catch { db.rollback(); notice = error.localizedDescription }
    }
}
