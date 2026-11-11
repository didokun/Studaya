import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SubjectData: Codable {
    var id: UUID
    var name: String
    var code: String?
    var year: Int
    var semester: Int
    var examMode: String
    var hasExam: Bool
    var exam: Date
    init(_ model: Subject) {
        id = model.id
        name = model.name
        code = model.code
        year = model.year
        semester = model.semester
        examMode = model.examMode
        hasExam = model.hasExam
        exam = model.exam
    }
    @MainActor func insert(into db: ModelContext) {
        let model = Subject(name, exam: exam)
        model.id = id
        model.name = name
        model.code = code ?? ""
        model.year = year
        model.semester = semester
        model.examMode = examMode
        model.hasExam = hasExam
        model.exam = exam
        db.insert(model)
    }
}

struct ChapterData: Codable {
    var startDate: Date?
    var id: UUID
    var subjectID: UUID
    var name: String
    var notes: String
    var kind: String
    var completed: Bool
    var synthesisDone: Bool
    var timelineIndex: Int?
    var exerciseCount: Int
    var exercisesDone: Int
    var confidence: Int
    var target: Int
    init(_ model: Chapter) {
        startDate = model.startDate
        id = model.id
        subjectID = model.subjectID
        name = model.name
        notes = model.notes
        kind = model.kind
        completed = model.completed
        synthesisDone = model.synthesisDone
        timelineIndex = model.timelineIndex
        exerciseCount = model.exerciseCount
        exercisesDone = model.exercisesDone
        confidence = model.confidence
        target = model.target
    }
    @MainActor func insert(into db: ModelContext) {
        let model = Chapter(name, subject: subjectID, target: target)
        model.startDate = startDate
        model.id = id
        model.subjectID = subjectID
        model.name = name
        model.notes = notes
        model.kind = kind
        model.completed = completed
        model.synthesisDone = synthesisDone
        model.timelineIndex = timelineIndex
        model.exerciseCount = exerciseCount
        model.exercisesDone = exercisesDone
        model.confidence = confidence
        model.target = target
        db.insert(model)
    }
}

struct FlashcardData: Codable {
    var id: UUID
    var chapterID: UUID
    var question: String
    var answer: String
    var known: Bool
    init(_ model: Flashcard) {
        id = model.id
        chapterID = model.chapterID
        question = model.question
        answer = model.answer
        known = model.known
    }
    @MainActor func insert(into db: ModelContext) {
        let model = Flashcard(question, answer: answer, chapter: chapterID)
        model.id = id
        model.chapterID = chapterID
        model.question = question
        model.answer = answer
        model.known = known
        db.insert(model)
    }
}

struct SessionData: Codable {
    var id: UUID
    var subjectID: UUID?
    var reviewID: UUID?
    var pinned: Bool
    var chapterID: UUID
    var deadlineID: UUID?
    var activity: String
    var title: String
    var start: Date
    var minutes: Int
    var done: Bool
    init(_ model: Session) {
        id = model.id
        subjectID = model.subjectID
        reviewID = model.reviewID
        pinned = model.pinned
        chapterID = model.chapterID
        deadlineID = model.deadlineID
        activity = model.activity
        title = model.title
        start = model.start
        minutes = model.minutes
        done = model.done
    }
    @MainActor func insert(into db: ModelContext) {
        let model = Session(course: title, start: start, minutes: minutes)
        model.id = id
        model.subjectID = subjectID
        model.reviewID = reviewID
        model.pinned = pinned
        model.chapterID = chapterID
        model.deadlineID = deadlineID
        model.activity = activity
        model.title = title
        model.start = start
        model.minutes = minutes
        model.done = done
        db.insert(model)
    }
}

struct FocusLogData: Codable {
    var id: UUID
    var chapterID: UUID?
    var sessionID: UUID?
    var runID: UUID?
    var subjectID: UUID?
    var date: Date
    var minutes: Int
    init(_ model: FocusLog) {
        id = model.id
        chapterID = model.chapterID
        sessionID = model.sessionID
        runID = model.runID
        subjectID = model.subjectID
        date = model.date
        minutes = model.minutes
    }
    @MainActor func insert(into db: ModelContext) {
        let model = FocusLog(minutes: minutes, date: date)
        model.id = id
        model.chapterID = chapterID
        model.sessionID = sessionID
        model.runID = runID
        model.subjectID = subjectID
        model.date = date
        model.minutes = minutes
        db.insert(model)
    }
}

struct AcademicProfileData: Codable {
    var id: UUID
    var program: String
    var institution: String
    var level: String
    var organization: String
    var examMode: String
    var years: Int
    var firstDay: Date
    var courses: [String]
    init(_ model: AcademicProfile) {
        id = model.id
        program = model.program
        institution = model.institution
        level = model.level
        organization = model.organization
        examMode = model.examMode
        years = model.years
        firstDay = model.firstDay
        courses = model.courses
    }
    @MainActor func insert(into db: ModelContext) {
        let model = AcademicProfile()
        model.id = id
        model.program = program
        model.institution = institution
        model.level = level
        model.organization = organization
        model.examMode = examMode
        model.years = years
        model.firstDay = firstDay
        model.courses = courses
        db.insert(model)
    }
}

struct StudyDeadlineData: Codable {
    var id: UUID
    var subjectID: UUID
    var chapterID: UUID?
    var title: String
    var kind: String
    var due: Date
    var hasDueDate: Bool?
    var done: Bool
    var preparationSessions: Int
    var reminderDays: Int
    init(_ model: StudyDeadline) {
        id = model.id
        subjectID = model.subjectID
        chapterID = model.chapterID
        title = model.title
        kind = model.kind
        due = model.due
        hasDueDate = model.hasDueDate
        done = model.done
        preparationSessions = model.preparationSessions
        reminderDays = model.reminderDays
    }
    @MainActor func insert(into db: ModelContext) {
        let model = StudyDeadline(subject: subjectID)
        model.id = id
        model.subjectID = subjectID
        model.chapterID = chapterID
        model.title = title
        model.kind = kind
        model.due = due
        model.hasDueDate = hasDueDate ?? true
        model.done = done
        model.preparationSessions = preparationSessions
        model.reminderDays = reminderDays
        db.insert(model)
    }
}

struct TimeBlockData: Codable {
    var id: UUID
    var title: String
    var start: Date
    var end: Date
    var weekday: Int
    var until: Date
    init(_ model: TimeBlock) {
        id = model.id
        title = model.title
        start = model.start
        end = model.end
        weekday = model.weekday
        until = model.until
    }
    @MainActor func insert(into db: ModelContext) {
        let model = TimeBlock()
        model.id = id
        model.title = title
        model.start = start
        model.end = end
        model.weekday = weekday
        model.until = until
        db.insert(model)
    }
}

struct SpacedReviewData: Codable {
    var id: UUID
    var chapterID: UUID
    var due: Date
    var done: Bool
    var intervalDays: Int
    init(_ model: SpacedReview) {
        id = model.id
        chapterID = model.chapterID
        due = model.due
        done = model.done
        intervalDays = model.intervalDays
    }
    @MainActor func insert(into db: ModelContext) {
        let model = SpacedReview(chapter: chapterID, due: due, days: intervalDays)
        model.id = id
        model.chapterID = chapterID
        model.due = due
        model.done = done
        model.intervalDays = intervalDays
        db.insert(model)
    }
}

struct BackupPreferences: Codable {
    var studentName: String
    var weeklyHours: Int
    var focusMinutes: Int
    var breakMinutes: Int
    var weekdays: [Int]
    var startHour: Int
    var endHour: Int
    var sessionMinutes: Int
    var reminderHour: Int
    var reminderEnabled: Bool
    var eventRemindersEnabled: Bool
    var notificationOptions: StudentNotificationOptions?
    init() {
        let p = StudyPreferences.current
        let rhythm = Availability.saved
        studentName = p.string(forKey: "studentName") ?? ""
        weeklyHours = p.object(forKey: "weeklyHours") as? Int ?? 5
        focusMinutes = p.object(forKey: "focusMinutes") as? Int ?? 25
        breakMinutes = p.object(forKey: "breakMinutes") as? Int ?? 5
        weekdays = Array(rhythm.weekdays).sorted(); startHour = rhythm.startHour; endHour = rhythm.endHour; sessionMinutes = rhythm.minutes
        reminderHour = p.object(forKey: "reminderHour") as? Int ?? 18
        notificationOptions = StudentNotificationOptions.load(p)
        reminderEnabled = p.bool(forKey: "reminderEnabled"); eventRemindersEnabled = p.bool(forKey: "eventRemindersEnabled")
    }
    func apply() {
        let p = StudyPreferences.current
        p.set(studentName, forKey: "studentName"); p.set(weeklyHours, forKey: "weeklyHours")
        p.set(focusMinutes, forKey: "focusMinutes"); p.set(breakMinutes, forKey: "breakMinutes")
        p.set(reminderHour, forKey: "reminderHour"); p.set(reminderEnabled, forKey: "reminderEnabled")
        p.set(eventRemindersEnabled, forKey: "eventRemindersEnabled")
        p.set(try? JSONEncoder().encode(notificationOptions ?? StudentNotificationOptions()), forKey: StudentNotificationOptions.key)
        p.set(Date(), forKey: "notificationAnchor")
        Availability(weekdays: Set(weekdays), startHour: startHour, endHour: endHour, minutes: sessionMinutes).persist()
        for key in ["timerEnd", "timerRemaining", "timerLength", "timerRest", "focusSubject", "focusChapter", "focusSession", "focusReview", "focusRunID"] { p.removeObject(forKey: key) }
    }
}

struct StudyBackup: Codable {
    var format = "Studaya"
    var version = 1
    var createdAt = Date()
    var preferences: BackupPreferences
    var subjects: [SubjectData]
    var chapters: [ChapterData]
    var cards: [FlashcardData]
    var sessions: [SessionData]
    var logs: [FocusLogData]
    var profiles: [AcademicProfileData]
    var deadlines: [StudyDeadlineData]
    var blocks: [TimeBlockData]
    var reviews: [SpacedReviewData]
    @MainActor init(db: ModelContext) throws {
        preferences = BackupPreferences()
        subjects = try db.fetch(FetchDescriptor<Subject>()).map(SubjectData.init)
        chapters = try db.fetch(FetchDescriptor<Chapter>()).map(ChapterData.init)
        cards = try db.fetch(FetchDescriptor<Flashcard>()).map(FlashcardData.init)
        sessions = try db.fetch(FetchDescriptor<Session>()).map(SessionData.init)
        logs = try db.fetch(FetchDescriptor<FocusLog>()).map(FocusLogData.init)
        profiles = try db.fetch(FetchDescriptor<AcademicProfile>()).map(AcademicProfileData.init)
        deadlines = try db.fetch(FetchDescriptor<StudyDeadline>()).map(StudyDeadlineData.init)
        blocks = try db.fetch(FetchDescriptor<TimeBlock>()).map(TimeBlockData.init)
        reviews = try db.fetch(FetchDescriptor<SpacedReview>()).map(SpacedReviewData.init)
    }
    @MainActor func insert(into db: ModelContext) {
        for item in subjects { item.insert(into: db) }
        for item in chapters { item.insert(into: db) }
        for item in cards { item.insert(into: db) }
        for item in sessions { item.insert(into: db) }
        for item in logs { item.insert(into: db) }
        for item in profiles { item.insert(into: db) }
        for item in deadlines { item.insert(into: db) }
        for item in blocks { item.insert(into: db) }
        for item in reviews { item.insert(into: db) }
    }
    func validate() throws {
        func require(_ condition: Bool) throws { if !condition { throw StudyError.invalid("Sauvegarde Studaya invalide ou incompatible. Aucune donnée n’a été remplacée.") } }
        try require(format == "Studaya" && version == 1 && profiles.count <= 1)
        try require(subjects.count + chapters.count + cards.count + sessions.count + logs.count + deadlines.count + blocks.count + reviews.count < 50000)
        try require(Set(subjects.map(\.id)).count == subjects.count)
        try require(Set(chapters.map(\.id)).count == chapters.count)
        try require(Set(cards.map(\.id)).count == cards.count)
        try require(Set(sessions.map(\.id)).count == sessions.count)
        try require(Set(logs.map(\.id)).count == logs.count)
        try require(Set(profiles.map(\.id)).count == profiles.count)
        try require(Set(deadlines.map(\.id)).count == deadlines.count)
        try require(Set(blocks.map(\.id)).count == blocks.count)
        try require(Set(reviews.map(\.id)).count == reviews.count)
        let subjectIDs = Set(subjects.map(\.id)), chapterIDs = Set(chapters.map(\.id))
        let deadlineIDs = Set(deadlines.map(\.id)), reviewIDs = Set(reviews.map(\.id))
        func dateOK(_ date: Date) -> Bool { date.timeIntervalSince1970.isFinite && (-2208988800...7258118400).contains(date.timeIntervalSince1970) }
        try require(subjects.allSatisfy { (1...8).contains($0.year) && (1...2).contains($0.semester) && !$0.name.isEmpty && dateOK($0.exam) })
        try require(chapters.allSatisfy { subjectIDs.contains($0.subjectID) && ($0.startDate == nil || dateOK($0.startDate!)) && ["Cours", "TD"].contains($0.kind) && (1...100).contains($0.exerciseCount) && (0...$0.exerciseCount).contains($0.exercisesDone) && (1...3).contains($0.confidence) && (1...30).contains($0.target) })
        try require(cards.allSatisfy { chapterIDs.contains($0.chapterID) })
        try require(deadlines.allSatisfy { item in subjectIDs.contains(item.subjectID) && (item.chapterID == nil || chapters.contains { $0.id == item.chapterID && $0.subjectID == item.subjectID }) && dateOK(item.due) && (1...30).contains(item.preparationSessions) && (0...30).contains(item.reminderDays) })
        try require(reviews.allSatisfy { chapterIDs.contains($0.chapterID) && dateOK($0.due) && [2, 7, 21].contains($0.intervalDays) })
        try require(sessions.allSatisfy { dateOK($0.start) && (1...1440).contains($0.minutes) && ($0.subjectID == nil || subjectIDs.contains($0.subjectID!)) && ($0.deadlineID == nil || deadlineIDs.contains($0.deadlineID!)) && ($0.reviewID == nil || reviewIDs.contains($0.reviewID!)) })
        try require(logs.allSatisfy { dateOK($0.date) && (1...1440).contains($0.minutes) && ($0.subjectID == nil || subjectIDs.contains($0.subjectID!)) && ($0.chapterID == nil || chapterIDs.contains($0.chapterID!)) })
        try require(blocks.allSatisfy { dateOK($0.start) && dateOK($0.end) && dateOK($0.until) && $0.end > $0.start && (0...7).contains($0.weekday) && ($0.weekday == 0 || ($0.end.timeIntervalSince($0.start) <= 86400 && $0.until >= $0.start)) })
        try require(profiles.allSatisfy { (1...8).contains($0.years) && dateOK($0.firstDay) })
        let p = preferences
        try require(p.notificationOptions?.valid ?? true)
        try require((1...60).contains(p.weeklyHours) && (5...90).contains(p.focusMinutes) && (1...30).contains(p.breakMinutes) && p.weekdays.allSatisfy { (1...7).contains($0) } && (0...22).contains(p.startHour) && p.endHour > p.startHour && p.endHour <= 23 && (5...60).contains(p.sessionMinutes) && (0...23).contains(p.reminderHour))
    }
    static func decode(_ data: Data) throws -> Self {
        guard data.count <= 20 * 1024 * 1024 else { throw StudyError.invalid("Le fichier dépasse 20 Mo.") }
        let backup = try JSONDecoder().decode(Self.self, from: data)
        try backup.validate()
        return backup
    }
    @MainActor func restore(into db: ModelContext) throws {
        try validate()
        let auto = db.autosaveEnabled; db.autosaveEnabled = false
        defer { db.autosaveEnabled = auto }
        try db.save()
        do {
            try Self.removeAll(db)
            insert(into: db)
            try db.save()
            preferences.apply()
            StudyPreferences.current.set("Parcours restauré.", forKey: "dataChangeReason")
            StudyPreferences.current.set(UUID().uuidString, forKey: "dataRevision")
        } catch { db.rollback(); throw error }
    }
    @MainActor static func removeAll(_ db: ModelContext) throws {
        for item in try db.fetch(FetchDescriptor<Subject>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<Chapter>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<Flashcard>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<Session>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<FocusLog>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<AcademicProfile>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<StudyDeadline>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<TimeBlock>()) { db.delete(item) }
        for item in try db.fetch(FetchDescriptor<SpacedReview>()) { db.delete(item) }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw StudyError.invalid("Fichier illisible.") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupSettings: View {
    @Environment(\.modelContext) private var db
    @State private var document = BackupDocument(data: Data())
    @State private var exporting = false
    @State private var importing = false
    @State private var pending: StudyBackup?
    @State private var confirm = false
    @State private var message: String?
    var body: some View {
        Form {
            Text("Sauvegarde le parcours complet : matières, cours, TD, flashcards, échéances, séances, Focus, indisponibilités, rappels espacés et préférences. Le fichier reste sous ton contrôle dans Fichiers ou iCloud Drive.")
            Button("Exporter une sauvegarde complète", systemImage: "square.and.arrow.up") {
                do {
                    try db.save()
                    let backup = try StudyBackup(db: db)
                    try backup.validate()
                    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    document = BackupDocument(data: try encoder.encode(backup)); exporting = true
                } catch { message = error.localizedDescription }
            }
            Button("Restaurer une sauvegarde", systemImage: "square.and.arrow.down") { importing = true }
            Text("La restauration remplace les données locales. Exporte d’abord ton état actuel pour le conserver. Les achats Premium restent gérés par Apple ; aucune séance Focus en cours n’est restaurée.").font(.footnote)
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Studaya-sauvegarde") { result in
            switch result { case .success: message = "Sauvegarde exportée."; case .failure(let error): message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 20 * 1024 * 1024 else { throw StudyError.invalid("Le fichier dépasse 20 Mo.") }
                pending = try StudyBackup.decode(Data(contentsOf: url)); confirm = true
            } catch { pending = nil; message = error.localizedDescription }
        }
        .confirmationDialog("Remplacer les données par cette sauvegarde ?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Remplacer et restaurer", role: .destructive) {
                guard let pending else { return }
                do {
                    try pending.restore(into: db)
                    self.pending = nil
                    Task { await DailyReminder.sync(); await EventReminders.shared.refresh(db); await FocusCompanion.shared.sync(db) }
                    message = "Parcours restauré. Vérifie les autorisations de notifications sur cet appareil."
                } catch { message = error.localizedDescription }
            }
            Button("Annuler", role: .cancel) { pending = nil }
        } message: {
            if let pending { Text("\(pending.subjects.count) matières · \(pending.chapters.count) cours/TD · \(pending.sessions.count) séances. Sauvegarde du \(pending.createdAt.formatted(date: .abbreviated, time: .shortened)).") }
        }
        .alert("Sauvegarde", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
}
