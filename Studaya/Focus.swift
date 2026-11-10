import SwiftUI
import SwiftData

struct Focus: View {
    var initialChapterID: UUID? = nil
    var initialSessionID: UUID? = nil
    var initialReviewID: UUID? = nil
    @Query(sort: \Chapter.name) var chapters: [Chapter]
    @Query var sessions: [Session]
    @Query var reviews: [SpacedReview]
    @AppStorage("focusChapter") var selectedChapter = ""
    @AppStorage("focusSession") var selectedSession = ""
    @AppStorage("focusReview") var selectedReview = ""
    @AppStorage("focusRunID") var runID = ""
    @State var summary = false
    @State var finishedChapter: UUID?
    @State var loaded = false
    @State private var choosingTarget = false
    @Query(sort: \Subject.name) var subjects: [Subject]
    @AppStorage("focusSubject") var subject = ""
    @Environment(\.modelContext) var db
    @AppStorage("focusMinutes") var work = 25
    @AppStorage("breakMinutes") var rest = 5
    @AppStorage("timerEnd") var end = 0.0
    @AppStorage("timerRemaining") var paused = 0
    @AppStorage("timerLength") var length = 0
    @AppStorage("timerRest") var isRest = false
    @State var error: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var duration: Int { length > 0 ? length : (isRest ? rest : work) * 60 }
    func remaining(_ now: Date) -> Int {
        end > 0 ? max(0, Int(ceil(end - now.timeIntervalSince1970))) : (paused > 0 ? paused : duration)
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { clock in
            let seconds = remaining(clock.date)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 22) {
                        StudyPill(title: isRest ? "RESPIRE UN INSTANT" : "DANS TA BULLE", symbol: isRest ? "leaf.fill" : "headphones", color: isRest ? StudyDesign.mint : StudyDesign.accent)
                        Text(isRest ? "Tu l’as bien mérité." : "Une chose à la fois.").font(.system(.title, design: .rounded, weight: .bold))
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                StudyBadge(symbol: "books.vertical.fill", size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(subjects.first { $0.id.uuidString == subject }?.name ?? "Focus libre").font(.headline)
                                    if let chapter = chapters.first(where: { $0.id.uuidString == selectedChapter }) { Text(chapter.name).font(.subheadline).foregroundStyle(.secondary) }
                                }
                            }
                            DisclosureGroup("Modifier la matière et le cours / TD", isExpanded: $choosingTarget) {
                        Picker("Matière", selection: Binding(get: { subject }, set: { subject = $0; selectedChapter = ""; selectedSession = ""; selectedReview = "" })) {
                            Text("Focus libre").tag("")
                            ForEach(subjects) { Text($0.name).tag($0.id.uuidString) }
                        }.studyMenu("Matière", value: subjects.first { $0.id.uuidString == subject }?.name ?? "Focus libre").disabled(length > 0)
                        Picker("Cours ou TD", selection: $selectedChapter) {
                            Text("Sans cours ou TD précis").tag("")
                            ForEach(chapters.filter { $0.subjectID.uuidString == subject && (!$0.completed || $0.id.uuidString == selectedChapter) }) { Text($0.kind + " · " + $0.name).tag($0.id.uuidString) }
                        }.studyMenu("Cours ou TD", value: chapters.first { $0.id.uuidString == selectedChapter }?.name ?? "Sans cours ou TD précis").disabled(length > 0 || !selectedSession.isEmpty || !selectedReview.isEmpty)
                            }
                        }.studyCard()
                        if let session = sessions.first(where: { $0.id.uuidString == selectedSession }) { Text(session.title).font(.caption) }
                        if !selectedReview.isEmpty { Label("Rappel espacé · sans rouvrir le travail terminé", systemImage: "brain.head.profile").font(.caption) }
                        ZStack {
                            Circle().fill(.white).shadow(color: StudyDesign.accent.opacity(0.08), radius: 24, y: 10)
                            Circle().stroke(StudyDesign.line.opacity(0.5), lineWidth: 12).padding(14)
                            Circle().trim(from: 0, to: min(1, Double(seconds) / Double(duration)))
                                .stroke(LinearGradient(colors: [isRest ? StudyDesign.mint : StudyDesign.accent, Color(red: 0.69, green: 0.59, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(-90)).padding(14)
                            VStack(spacing: 10) {
                                Image(systemName: isRest ? "cup.and.saucer.fill" : "headphones").font(.title2).foregroundStyle(isRest ? StudyDesign.mint : StudyDesign.accent)
                                Text(String(format: "%02d:%02d", seconds/60, seconds%60)).font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(StudyDesign.ink)
                                Text(isRest ? "Recharge tes batteries" : "Ton temps, ton attention").font(.caption).foregroundStyle(.secondary)
                            }
                        }.aspectRatio(1, contentMode: .fit).frame(maxWidth: 250).padding(.vertical, 10)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isRest)
                    }.padding(24).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                VStack(spacing: 12) {
                    Button(end > 0 ? "Mettre en pause" : (paused > 0 ? "Reprendre" : "Commencer")) {
                        if end > 0 {
                            let left = remaining(.now)
                            if left == 0 { finish() } else { paused = left; end = 0 }
                        } else {
                            if length == 0 { runID = UUID().uuidString }
                            length = duration
                            end = Date.now.timeIntervalSince1970 + Double(remaining(.now))
                            paused = 0
                        }
                    }.buttonStyle(Primary())
                    Button("Réinitialiser") { end = 0; paused = 0; length = 0; isRest = false; selectedSession = ""; selectedReview = ""; runID = "" }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 10).background(StudyDesign.canvas)
            }
            .onChange(of: seconds, initial: true) { _, seconds in if end > 0 && seconds == 0 { finish() } }
        }
        .studyScreen()
        .onAppear { loadTarget() }
        .sheet(isPresented: $summary) { FocusSummary(chapterID: finishedChapter) }
    }
    func loadTarget() {
        guard !loaded else { return }; loaded = true
        guard initialChapterID != nil || initialSessionID != nil || initialReviewID != nil else { return }
        guard length == 0 else { error = "Une séance est déjà en cours. Termine-la ou réinitialise-la avant de changer de travail."; return }
        let session = sessions.first { $0.id == initialSessionID }
        let review = reviews.first { $0.id == initialReviewID }
        let chapter = chapters.first { $0.id == (initialChapterID ?? review?.chapterID ?? session?.chapterID) }
        subject = (chapter?.subjectID ?? session?.subjectID)?.uuidString ?? ""
        selectedChapter = chapter?.id.uuidString ?? ""
        selectedSession = session?.id.uuidString ?? ""
        selectedReview = review?.id.uuidString ?? ""
    }
    func finish() {
        if !isRest {
            let token = UUID(uuidString: runID) ?? UUID()
            runID = token.uuidString
            do {
                let log = try FocusRecorder.record(db: db, runID: token, subjectID: UUID(uuidString: subject), chapterID: UUID(uuidString: selectedChapter), sessionID: UUID(uuidString: selectedSession), reviewID: UUID(uuidString: selectedReview), minutes: duration / 60, date: Date(timeIntervalSince1970: end))
                finishedChapter = log.chapterID; summary = true
                selectedSession = ""; selectedReview = ""
            } catch { db.rollback(); self.error = error.localizedDescription; return }
        }
        end = 0; paused = 0; length = 0; isRest.toggle()
    }
}

struct FocusSummary: View {
    let chapterID: UUID?
    @Query var chapters: [Chapter]
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @State private var exercises = 0
    @State private var saved = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Label("Séance enregistrée", systemImage: "checkmark.circle.fill")
                if let chapter = chapters.first(where: { $0.id == chapterID }) {
                    Text(chapter.name)
                    if chapter.kind == "TD", !chapter.completed {
                        Stepper("\(exercises) exercice(s) terminé(s) pendant cette séance", value: $exercises, in: 0...max(0, chapter.exerciseCount - chapter.exercisesDone))
                        Text("Seuls les exercices que tu confirmes sont ajoutés à ta progression.").font(.footnote)
                    } else { Text("Ta séance a été ajoutée au suivi de ce cours ou de ce rappel.") }
                }
                Button("Valider le bilan") {
                    guard !saved else { return }; saved = true
                    if let chapter = chapters.first(where: { $0.id == chapterID }), chapter.kind == "TD", !chapter.completed {
                        chapter.exercisesDone = min(chapter.exerciseCount, chapter.exercisesDone + exercises)
                    }
                    do { try db.save(); dismiss() } catch { db.rollback(); saved = false; message = error.localizedDescription }
                }.disabled(saved)
            }.studyScreen().navigationTitle("Bilan Focus").toolbar { Button("Fermer") { dismiss() } }
        }.alert("Enregistrement", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
}
