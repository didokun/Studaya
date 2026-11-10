import SwiftUI
import SwiftData

struct PathUnit: Identifiable {
    var id = UUID()
    var name = ""
    var notes = ""
    var kind = "Cours"
    var start = Date()
    var sessions = 2
    var exercises = 5
}
struct PathEvent: Identifiable {
    var id = UUID()
    var title = ""
    var due = Date.now.addingTimeInterval(14 * 86400)
    var preparation = 2
}
struct PathSubject: Identifiable {
    var id = UUID()
    var name = ""
    var year = 1
    var semester = 1
    var units = [PathUnit()]
    var presentations: [PathEvent] = []
    var controls: [PathEvent] = []
    var hasExam = false
    var exam = Date.now.addingTimeInterval(60 * 86400)
}

@MainActor enum RevisionPath {
    static func validate(_ drafts: [PathSubject], usesSemesters: Bool = true) throws {
        guard !drafts.isEmpty else { throw StudyError.invalid("Ajoute au moins une matière.") }
        var keys = Set<String>()
        for subject in drafts {
            let name = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, (1...8).contains(subject.year), (!usesSemesters || (1...2).contains(subject.semester)), keys.insert("\(name.lowercased()):\(subject.year):\(usesSemesters ? subject.semester : 0)").inserted else {
                throw StudyError.invalid(usesSemesters ? "Chaque matière doit avoir un nom et ne figurer qu’une fois dans le même semestre." : "Chaque matière doit avoir un nom et ne figurer qu’une fois dans la même année.")
            }
            guard !subject.units.isEmpty, subject.units.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ["Cours", "TD"].contains($0.kind) && (1...30).contains($0.sessions) && (1...100).contains($0.exercises) }) else {
                throw StudyError.invalid("Ajoute et nomme les cours ou TD de \(name).")
            }
            guard (subject.presentations + subject.controls).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (1...30).contains($0.preparation) }) else { throw StudyError.invalid("Nomme chaque présentation et contrôle de \(name).") }
            if subject.hasExam, let latest = subject.units.map(\.start).max(), Calendar.current.startOfDay(for: subject.exam) <= Calendar.current.startOfDay(for: latest) {
                throw StudyError.invalid("L’examen de \(name) doit avoir lieu après le début de tous ses cours et TD.")
            }
        }
    }
    @discardableResult static func create(_ drafts: [PathSubject], db: ModelContext, now: Date = .now) throws -> Int {
        let profile = try db.fetch(FetchDescriptor<AcademicProfile>()).first
        let usesSemesters = profile?.usesSemesters ?? true
        try validate(drafts, usesSemesters: usesSemesters)
        let old = try db.fetch(FetchDescriptor<Subject>())
        do {
            for draft in drafts {
                let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let existing = old.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame && $0.year == draft.year && (!usesSemesters || $0.semester == draft.semester) }
                let subject = existing ?? Subject(name, exam: draft.exam)
                if existing == nil { db.insert(subject); subject.hasExam = draft.hasExam; subject.examMode = profile?.examMode ?? "Par semestre" }
                subject.year = draft.year
                if usesSemesters { subject.semester = draft.semester }
                if draft.hasExam { subject.exam = draft.exam; subject.hasExam = true }
                for unit in draft.units {
                    let chapter = Chapter(unit.name.trimmingCharacters(in: .whitespacesAndNewlines), subject: subject.id, target: unit.sessions)
                    chapter.notes = unit.notes
                    chapter.kind = unit.kind; chapter.startDate = unit.start; chapter.exerciseCount = unit.exercises
                    db.insert(chapter)
                }
                for (kind, events) in [("Présentation", draft.presentations), ("Contrôle", draft.controls)] {
                    for event in events {
                        let item = StudyDeadline(subject: subject.id)
                        item.kind = kind; item.title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        item.due = event.due; item.preparationSessions = event.preparation
                        db.insert(item)
                    }
                }
            }
            let names = try db.fetch(FetchDescriptor<Subject>()).map(\.name)
            for profile in try db.fetch(FetchDescriptor<AcademicProfile>()) { profile.courses = Array(Set(names)).sorted() }
            return try Scheduler.rebuild(db, now: now)
        } catch { db.rollback(); throw error }
    }
}

private struct PathPhotoTarget: Identifiable {
    let id: UUID
    let name: String
    let exam: Date?
}

struct RevisionPathBuilder: View {
    var onCreated: () -> Void = {}
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var profiles: [AcademicProfile]
    @State private var subjects = [PathSubject()]
    @State private var step = 0
    @State private var index = 0
    @State private var phase = 0
    @State private var missing = 0
    @State private var error: String?
    @State private var creating = false
    @State private var photoTarget: PathPhotoTarget?
    private let titles = ["Tes matières", "Cours et TD", "Présentations", "Contrôles", "Examen final", "Ton parcours est prêt", "Création de ton parcours…", "À toi de jouer !"]
    private var currentValid: Bool {
        if step == 0 { return subjects.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        if step == 1 { return subjects[index].units.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
        if step == 2 || step == 3 {
            let events = step == 2 ? subjects[index].presentations : subjects[index].controls
            return events.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        return true
    }
    private var progress: Double { step == 0 ? 1 : step == 5 ? Double(4 * subjects.count + 2) : Double(2 + (step - 1) * subjects.count + index) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step < 6 { ProgressView(value: progress, total: Double(4 * subjects.count + 2)).tint(.mintBrand).padding() }
                if step >= 6 {
                    PlanningTimeline(subjects: subjects, stage: phase, missing: missing)
                } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StudyPill(title: step == 0 ? "TON CAMPUS" : "TON PARCOURS", symbol: "sparkles")
                        Text(titles[step]).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        if (1...4).contains(step) {
                            Text(subjects[index].name).font(.title2.weight(.semibold))
                            Text("Matière \(index + 1) sur \(subjects.count)").foregroundStyle(.secondary)
                        }
                        content
                    }.padding(24).frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                }
                if step < 6 {
                    HStack {
                        if step > 0 { Button("Retour") { back() }.frame(minHeight: 44) }
                        Button(step == 5 ? "Créer mon planning" : "Continuer") { next() }.buttonStyle(Primary()).disabled(!currentValid)
                    }.padding()
                } else if step == 7 {
                    Button("Découvrir mon planning") { onCreated(); dismiss() }.buttonStyle(Primary()).padding()
                }
            }.studyScreen().navigationTitle("Parcours de révision").navigationBarTitleDisplayMode(.inline)
            .toolbar { if step < 6 { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } } }
            .sheet(item: $photoTarget) { target in
                PremiumAccess(title: "Import photo Premium") {
                    if target.name.isEmpty {
                        ContentUnavailableView("Nomme d’abord cette matière", systemImage: "books.vertical", description: Text("Reviens au parcours et renseigne le nom de la matière pour analyser sa photo de planning."))
                    } else {
                        PhotoPlanningImporter(subject: nil, draftSubjectName: target.name, draftExamDate: target.exam) { rows, replaceExam in
                            guard let position = subjects.firstIndex(where: { $0.id == target.id }) else { throw StudyError.invalid("Cette matière a été retirée du parcours.") }
                            subjects[position] = try RevisionPath.mergingPhoto(rows, into: subjects[position], replaceExam: replaceExam)
                        }
                    }
                }
            }
            .interactiveDismissDisabled(creating)
            .task(id: step) { if step == 6 { await generate() } }
            .alert("Parcours", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
        }
    }
    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            Text("Ajoute tes matières. Pour chacune, on préparera les cours et TD, puis les présentations, contrôles et l’examen final.")
            ForEach($subjects) { $subject in
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Nom de la matière", text: $subject.name).textFieldStyle(StudyTextFieldStyle(boxed: true))
                    photoButton(subject)
                    Stepper("Année \(subject.year)", value: $subject.year, in: 1...max(1, profiles.first?.years ?? 8))
                    if profiles.first?.usesSemesters ?? true {
                        Picker("Semestre", selection: $subject.semester) { Text("S1").tag(1); Text("S2").tag(2) }.studyMenu("Semestre", value: "S\(subject.semester)")
                    }
                    if subjects.count > 1 { Button("Retirer la matière", role: .destructive) { subjects.removeAll { $0.id == subject.id } } }
                }.padding().background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
            Button("Ajouter une autre matière", systemImage: "plus") { subjects.append(PathSubject()) }.buttonStyle(.bordered)
        case 1:
            photoButton(subjects[index])
            Text("À quelle date commence chaque cours ou TD ? Les révisions ne démarreront pas avant cette date.")
            ForEach($subjects[index].units) { $unit in
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Nom du cours ou TD", text: $unit.name).textFieldStyle(StudyTextFieldStyle(boxed: true))
                    Picker("Type", selection: $unit.kind) { Text("Cours").tag("Cours"); Text("TD").tag("TD") }.studyMenu("Type", value: unit.kind)
                    DatePicker("Date de début", selection: $unit.start, displayedComponents: .date)
                    Stepper("Objectif · \(unit.sessions) séances", value: $unit.sessions, in: 1...30)
                    if unit.kind == "TD" { Stepper("\(unit.exercises) exercices", value: $unit.exercises, in: 1...100) }
                    if subjects[index].units.count > 1 { Button("Retirer ce cours ou TD", role: .destructive) { subjects[index].units.removeAll { $0.id == unit.id } } }
                }.padding().background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
            Button("Ajouter un cours ou TD", systemImage: "plus") { subjects[index].units.append(PathUnit()) }.buttonStyle(.bordered)
        case 2:
            Text("Des présentations à préparer ? Ajoute leur titre et leur date limite, ou continue si tu n’en as pas.")
            events($subjects[index].presentations)
            Button("Ajouter une présentation", systemImage: "plus") { subjects[index].presentations.append(PathEvent()) }.buttonStyle(.bordered)
        case 3:
            Text("Des contrôles sont déjà prévus ? Ils sont distincts de l’examen final. Tu peux aussi les ajouter plus tard.")
            events($subjects[index].controls)
            Button("Ajouter un contrôle", systemImage: "plus") { subjects[index].controls.append(PathEvent()) }.buttonStyle(.bordered)
        case 4:
            Toggle("Date de l’examen final connue", isOn: $subjects[index].hasExam)
            if subjects[index].hasExam { DatePicker("Examen final", selection: $subjects[index].exam, displayedComponents: .date) }
            else { Text("Tu pourras renseigner la date dans la matière dès qu’elle sera annoncée.").foregroundStyle(.secondary) }
        case 5:
            ForEach(subjects) { subject in
                VStack(alignment: .leading, spacing: 8) {
                    Text(subject.name).font(.title3.bold())
                    ForEach(subject.units) { unit in Text("\(unit.kind) · \(unit.name) · début \(unit.start.formatted(date: .abbreviated, time: .omitted))") }
                    Text("\(subject.presentations.count) présentations · \(subject.controls.count) contrôles")
                    Text(subject.hasExam ? "Examen final · " + subject.exam.formatted(date: .abbreviated, time: .omitted) : "Examen final à préciser")
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
            Text("Le planning tiendra compte de tes disponibilités et des échéances les plus proches. Rien n’est enregistré avant la création.")
        default:
            EmptyView()
        }
    }
    private func photoButton(_ subject: PathSubject) -> some View {
        Button {
            photoTarget = PathPhotoTarget(id: subject.id, name: subject.name.trimmingCharacters(in: .whitespacesAndNewlines), exam: subject.hasExam ? subject.exam : nil)
        } label: {
            PremiumFeatureLabel(title: "Importer un planning en photo", symbol: "camera.viewfinder")
        }.accessibilityLabel("Importer un planning en photo").buttonStyle(.bordered).frame(minHeight: 52)
    }
    private func events(_ binding: Binding<[PathEvent]>) -> some View {
        ForEach(binding) { $event in
            VStack(alignment: .leading, spacing: 14) {
                TextField("Titre", text: $event.title).textFieldStyle(StudyTextFieldStyle(boxed: true))
                DatePicker("Date limite", selection: $event.due)
                Stepper("Préparation · \(event.preparation) séances", value: $event.preparation, in: 1...30)
                Button("Retirer", role: .destructive) { binding.wrappedValue.removeAll { $0.id == event.id } }
            }.padding().background(.white, in: RoundedRectangle(cornerRadius: 24))
        }
    }
    private func next() {
        if step == 5 {
            do { try RevisionPath.validate(subjects, usesSemesters: profiles.first?.usesSemesters ?? true); creating = true; step = 6 } catch { self.error = error.localizedDescription }
        } else if (1...4).contains(step), index + 1 < subjects.count { index += 1 }
        else { step += 1; index = 0 }
    }
    private func back() {
        if (1...4).contains(step), index > 0 { index -= 1 }
        else { step -= 1; index = (1...4).contains(step) ? subjects.count - 1 : 0 }
    }
    private func generate() async {
        do {
            phase = 0
            for value in PlanningTimeline.stages.indices {
                try await Task.sleep(for: .milliseconds(2500))
                if value < PlanningTimeline.stages.count - 1 {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { phase = value + 1 }
                }
            }
            missing = try RevisionPath.create(subjects, db: db)
            await EventReminders.shared.refresh(db)
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                phase = PlanningTimeline.stages.count
                creating = false; step = 7
            }
        } catch is CancellationError { creating = false; step = 5 }
        catch { creating = false; step = 5; self.error = error.localizedDescription }
    }
}
