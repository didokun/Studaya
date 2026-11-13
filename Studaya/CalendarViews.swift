import SwiftUI
import SwiftData
import Charts

struct SessionRow: View {
    @Environment(\.modelContext) private var db
    @State private var saveError: String?
    @Bindable var session: Session
    @Query private var subjects: [Subject]
    @Query private var chapters: [Chapter]
    @State private var focus = false
    @State private var reschedule = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) { session.done.toggle() }
            do {
                try db.save()
                if session.done { SessionAdvertising.shared.showAtCompletion() }
            } catch { db.rollback(); saveError = error.localizedDescription }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: session.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 25, weight: .medium)).foregroundStyle(session.done ? StudyDesign.mint : StudyDesign.accent.opacity(0.45))
                VStack(alignment: .leading, spacing: 4) {
                    Text(StudyLabels.session(session, subjects: subjects, chapters: chapters)).font(.headline).foregroundStyle(StudyDesign.ink).strikethrough(session.done, color: StudyDesign.mint)
                    Text(String(localized: "\(L10n.activity(session.activity)) · \(session.start.formatted(date: .omitted, time: .shortened)) · \(session.minutes) min")).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(session.done ? String(localized: "Terminée") : String(localized: "À faire"))
        .alert(String(localized: "Enregistrement"), isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) { Button("OK") {} } message: { Text(saveError ?? "") }
        .contextMenu {
            if !session.done {
                Button(String(localized: "Travailler cette séance"), systemImage: "timer") { focus = true }
                Button(String(localized: "Reporter la séance"), systemImage: "calendar.badge.clock") { reschedule = true }
            }
        }
        .sheet(isPresented: $focus) { NavigationStack { Focus(initialSessionID: session.id).toolbar { ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Fermer")) { focus = false } } } } }
        .sheet(isPresented: $reschedule) { SessionReschedule(session: session) }
    }
}

struct Today: View {
    @State private var creatingPath = false
    @AppStorage("notificationPromptSeen") private var promptSeen = false
    @AppStorage("studentName") var name = ""
    @AppStorage("weeklyHours") var goal = 5
    @Query var logs: [FocusLog]
    @Query private var profiles: [AcademicProfile]
    @Binding var tab: Int
    @Query(sort: \Session.start) var sessions: [Session]
    @Query(sort: \Subject.exam) var subjects: [Subject]
    @Query var chapters: [Chapter]
    @Query(sort: \StudyDeadline.due) var deadlines: [StudyDeadline]
    @Query(sort: \SpacedReview.due) var reviews: [SpacedReview]
    private var today: [Session] { sessions.filter { Calendar.current.isDateInToday($0.start) } }
    private var remaining: [Session] { today.filter { !$0.done } }
    private var weeklyMinutes: Int { logs.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear) }.reduce(0) { $0 + $1.minutes } }
    private var recommended: Chapter? {
        chapters.filter { !$0.completed }.sorted { lhs, rhs in
            func due(_ unit: Chapter) -> Date {
                let subject = subjects.first { $0.id == unit.subjectID }
                let deadline = deadlines.filter { $0.subjectID == unit.subjectID && !$0.done && $0.hasDueDate }.map(\.due).min() ?? .distantFuture
                return min(deadline, subject?.hasExam == true ? subject!.exam : .distantFuture)
            }
            return (due(lhs), lhs.confidence, lhs.name) < (due(rhs), rhs.confidence, rhs.name)
        }.first
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                        .font(.caption.weight(.semibold)).tracking(1.4).foregroundStyle(.secondary)
                    Text(name.isEmpty ? String(localized: "Ta journée, à ton rythme.") : String(localized: "Salut \(name)."))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(StudyDesign.ink)
                }.studyReveal()
                dashboardHero.studyReveal()
                Button { creatingPath = true } label: {
                    HStack(spacing: 14) {
                        StudyBadge(symbol: "sparkles", size: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(localized: "Créer mon Parcours de révision")).font(.headline)
                            Text(String(localized: "Tes cours, tes TD, ton propre rythme.")).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.headline).foregroundStyle(StudyDesign.accent)
                    }.studyCard()
                }.buttonStyle(.plain).accessibilityLabel(String(localized: "Créer mon Parcours de révision"))
                HStack(spacing: 12) {
                    quickAction(String(localized: "Ouvrir mes matières"), detail: String(localized: "Mes matières"), symbol: "books.vertical.fill", color: StudyDesign.accent) { tab = 3 }
                    quickAction(String(localized: "Démarrer un Pomodoro"), detail: String(localized: "Un moment Focus"), symbol: "headphones", color: StudyDesign.mint) { tab = 2 }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        StudyBadge(symbol: "target", color: StudyDesign.coral)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(String(localized: "Ton objectif de la semaine")).font(.headline)
                            Text(String(localized: "\(weeklyMinutes) min sur \(goal) h visées")).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    ProgressView(value: Double(min(weeklyMinutes, max(1, goal) * 60)), total: Double(max(1, goal) * 60)).tint(StudyDesign.coral)
                }.studyCard()
                if !promptSeen && !profiles.isEmpty {
                    StudySection(title: String(localized: "Ne rate pas ta prochaine échéance")) { NotificationInvitation().studyCard() }
                }
                StudySection(title: String(localized: "Ton programme"), subtitle: String(localized: "\(remaining.reduce(0) { $0 + $1.minutes }) min restantes aujourd’hui")) {
                    if today.isEmpty {
                        StudyEmpty(title: String(localized: "Une journée qui respire"), detail: String(localized: "Ton prochain créneau apparaîtra ici. Tu peux aussi lancer un Focus quand tu veux."), symbol: "sun.horizon.fill")
                    } else {
                        VStack(spacing: 16) {
                            ForEach(Array(today.enumerated()), id: \.element.id) { index, session in
                                SessionRow(session: session)
                                if index == min(1, today.count - 1) { BrowsingBanner() }
                            }
                        }.studyCard()
                    }
                }
                if let unit = recommended {
                    StudySection(title: String(localized: "Ta prochaine étape")) {
                        NavigationLink { ChapterPage(chapter: unit) } label: {
                            HStack(alignment: .top, spacing: 14) {
                                StudyBadge(symbol: unit.kind == "TD" ? "pencil.and.outline" : "lightbulb.fill", color: StudyDesign.mint)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(unit.name).font(.headline).foregroundStyle(StudyDesign.ink)
                                    Text(StudyCoach.advice(unit, sessions: sessions)).font(.subheadline).foregroundStyle(.secondary)
                                    StudyPill(title: (subjects.first { $0.id == unit.subjectID }?.displayCode ?? "") + " · " + unit.kind, color: StudyDesign.mint)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.forward").font(.caption.bold()).foregroundStyle(.secondary)
                            }.studyCard()
                        }.buttonStyle(.plain)
                    }
                }
                StudySection(title: String(localized: "À l’horizon"), subtitle: String(localized: "Les échéances à garder en tête")) {
                    if deadlines.allSatisfy(\.done) {
                        StudyEmpty(title: String(localized: "Pas d’échéance à surveiller"), detail: String(localized: "Ajoute tes contrôles et présentations depuis une matière ou ton parcours."), symbol: "calendar.badge.checkmark")
                    } else {
                        ForEach(Array(deadlines.filter { !$0.done }.prefix(3))) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                DeadlineRow(item: item).listRowBackground(CalendarStudyKind.deadline(item.kind).color.opacity(0.12))
                                let done = sessions.filter { $0.deadlineID == item.id && $0.done }.count
                                ProgressView(value: Double(min(done, item.preparationSessions)), total: Double(max(1, item.preparationSessions))).tint(StudyDesign.accent)
                                Text(String(localized: "\(done) / \(item.preparationSessions) séances de préparation")).font(.caption).foregroundStyle(.secondary)
                            }.studyCard()
                        }
                    }
                }
                if let next = subjects.first(where: { $0.hasExam && $0.exam >= Calendar.current.startOfDay(for: .now) }) {
                    StudySection(title: String(localized: "Prochain examen")) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                StudyBadge(symbol: "graduationcap.fill", color: StudyDesign.coral)
                                VStack(alignment: .leading) { Text(next.displayCode).font(.headline); Text(next.exam, format: .dateTime.day().month(.wide)).font(.subheadline).foregroundStyle(.secondary) }
                                Spacer()
                                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: next.exam)).day ?? 0
                                StudyPill(title: days == 0 ? "Aujourd’hui" : "J−\(days)", color: StudyDesign.coral)
                            }
                            SubjectProgress(subject: next, chapters: chapters, sessions: sessions)
                        }.studyCard()
                    }
                }
                if reviews.contains(where: { !$0.done && $0.due <= Date.now.addingTimeInterval(86400) }) {
                    StudySection(title: String(localized: "Entretenir tes acquis")) {
                        ForEach(reviews.filter { !$0.done && $0.due <= Date.now.addingTimeInterval(86400) }) { review in
                            if let chapter = chapters.first(where: { $0.id == review.chapterID }) { ReviewRow(review: review, chapter: chapter).studyCard() }
                        }
                    }
                }
                if today.isEmpty, let session = sessions.first(where: { !$0.done && $0.start > .now }) {
                    StudySection(title: String(localized: "Prochaine séance")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(StudyLabels.session(session, subjects: subjects, chapters: chapters)).font(.headline)
                            Text(session.start, format: .dateTime.weekday(.wide).day().month().hour().minute()).foregroundStyle(.secondary)
                            Button(String(localized: "Voir le planning")) { tab = 1 }
                        }.studyCard()
                    }
                }
            }.padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 36).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.sheet(isPresented: $creatingPath) { RevisionPathBuilder { tab = 1 } }
    }
    private var dashboardHero: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 16) {
                Label(String(localized: "TON ÉLAN DU JOUR"), systemImage: "sparkles").font(.caption.weight(.bold)).tracking(1)
                    .foregroundStyle(.white.opacity(0.75))
                Text(remaining.isEmpty ? String(localized: "On prépare\nla suite ?") : String(localized: "Tes objectifs,\nun pas à la fois."))
                    .font(.system(.title, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text(String(localized: "\(remaining.count) séance(s) à faire")).font(.subheadline.weight(.semibold)).foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 9)
                Circle().trim(from: 0, to: Double(today.filter(\.done).count) / Double(max(1, today.count)))
                    .stroke(Color(red: 0.79, green: 0.94, blue: 0.67), style: StrokeStyle(lineWidth: 9, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 3) {
                    Text("\(today.filter(\.done).count)").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text(String(localized: "terminée(s)")).font(.caption2.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                }
            }.frame(width: 96, height: 96).accessibilityLabel(String(localized: "\(today.filter(\.done).count) séances terminées sur \(today.count)"))
        }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(StudyDesign.hero, in: RoundedRectangle(cornerRadius: 28))
    }
    private func quickAction(_ title: String, detail: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                StudyBadge(symbol: symbol, color: color)
                Text(detail).font(.subheadline.weight(.semibold)).foregroundStyle(StudyDesign.ink)
            }.frame(maxWidth: .infinity, alignment: .leading).studyCard()
        }.buttonStyle(.plain).accessibilityLabel(title)
    }
}

struct Planner: View {
    @Query var profiles: [AcademicProfile]
    @State var date = Date.now
    @State var month = false
    @State var message: String?
    @Query(sort: \Session.start) var sessions: [Session]
    @Query var subjects: [Subject]
    @Query(sort: \StudyDeadline.due) var deadlines: [StudyDeadline]
    @Query(sort: \SpacedReview.due) var reviews: [SpacedReview]
    @Query var chapters: [Chapter]
    @Query var blocks: [TimeBlock]
    @AppStorage("reminderEnabled") var dailyReminder = false
    @Environment(\.modelContext) var db
    var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    var body: some View {
        List {
            HStack(spacing: 14) {
                StudyBadge(symbol: "calendar.badge.clock", size: 48)
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "TON TEMPO")).font(.caption.weight(.semibold)).tracking(1.3).foregroundStyle(.secondary)
                    Text(String(localized: "Ton planning")).font(.system(.title2, design: .rounded, weight: .bold))
                }
            }.padding(.vertical, 8).listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            if let p = profiles.first {
                Section(p.program) {
                    Menu {
                        ForEach(0..<(p.years * (p.usesSemesters ? 2 : 1)), id: \.self) { i in
                            Button(p.usesSemesters ? String(localized: "Année \(i / 2 + 1) · Semestre \(i % 2 + 1)") : String(localized: "Année \(i + 1)")) {
                                date = calendar.date(byAdding: .month, value: i * (p.usesSemesters ? 6 : 12), to: p.firstDay)!
                            }
                        }
                    } label: { Label(p.usesSemesters ? String(localized: "Parcourir mes semestres") : String(localized: "Parcourir mes années"), systemImage: "graduationcap") }
                }
            }
            NavigationLink { CalendarSyncSettings() } label: { Label(String(localized: "Synchroniser avec Calendrier Apple"), systemImage: "calendar.badge.clock") }
            NavigationLink(String(localized: "Gérer mes indisponibilités")) { UnavailabilitySettings().navigationTitle(String(localized: "Indisponibilités")) }
            Picker(String(localized: "Vue"), selection: $month) { Text(String(localized: "Semaine")).tag(false); Text(String(localized: "Calendrier")).tag(true) }.pickerStyle(.segmented)
            if month {
                StudyMonth(selection: $date, marked: marked, markers: markers)
            } else {
                HStack {
                    Button(String(localized: "Précédente"), systemImage: "chevron.backward") { shift(-7) }
                    Spacer()
                    Text(date, format: .dateTime.month(.wide).year()).font(.headline)
                    Spacer()
                    Button(String(localized: "Suivante"), systemImage: "chevron.forward") { shift(7) }
                }.labelStyle(.iconOnly).buttonStyle(StudyIconButtonStyle())
                HStack {
                    ForEach(0..<7, id: \.self) { i in
                        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
                        let day = calendar.date(byAdding: .day, value: i, to: start)!
                        let dayMarkers = markers(day)
                        Button { date = day } label: {
                            VStack {
                                Text(day, format: .dateTime.weekday(.narrow)).font(.caption.weight(.medium)); Text(day, format: .dateTime.day()).font(.system(.title3, design: .rounded, weight: .bold))
                                CalendarDayIcons(markers: dayMarkers, showCode: true, selected: calendar.isDate(day, inSameDayAs: date))
                                Circle().fill(marked(day) ? (calendar.isDate(day, inSameDayAs: date) ? Color.white : StudyDesign.accent) : .clear).frame(width: 5, height: 5)
                            }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .foregroundStyle(calendar.isDate(day, inSameDayAs: date) ? .white : StudyDesign.ink)
                                .background(calendar.isDate(day, inSameDayAs: date) ? StudyDesign.accent : (dayMarkers.first?.kind.color ?? StudyDesign.canvas).opacity(dayMarkers.isEmpty ? 1 : 0.12), in: RoundedRectangle(cornerRadius: 16))
                        }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", " + dayMarkers.map { L10n.key($0.kind.rawValue) + " " + $0.code }.joined(separator: ", "))
                    }
                }
            }
            if !month { CalendarLegend() }
            Section(date.formatted(.dateTime.weekday(.wide).day().month())) {
                let day = sessions.filter { calendar.isDate($0.start, inSameDayAs: date) }
                ForEach(blocks.filter { $0.interval(on: date, calendar: calendar) != nil }) { block in
                    if let interval = block.interval(on: date, calendar: calendar) {
                        Label(block.title + " · " + interval.start.formatted(date: .omitted, time: .shortened) + " – " + interval.end.formatted(date: .omitted, time: .shortened), systemImage: "calendar.badge.minus")
                    }
                }
                ForEach(reviews.filter { !$0.done && calendar.isDate($0.due, inSameDayAs: date) }) { review in
                    if let chapter = chapters.first(where: { $0.id == review.chapterID }) { ReviewRow(review: review, chapter: chapter) }
                }
                ForEach(subjects.filter { $0.hasExam && calendar.isDate($0.exam, inSameDayAs: date) }) { subject in
                    Label(String(localized: "Examen · ") + subject.displayCode, systemImage: "graduationcap.fill")
                        .foregroundStyle(CalendarStudyKind.exam.color)
                        .listRowBackground(CalendarStudyKind.exam.color.opacity(0.12))
                }
                ForEach(deadlines.filter { !$0.done && $0.hasDueDate && (calendar.isDate($0.due, inSameDayAs: date) || calendar.isDate($0.reminderDate, inSameDayAs: date)) }) { item in
                    if calendar.isDate(item.reminderDate, inSameDayAs: date) { Label(String(localized: "Rappel · ") + (subjects.first { $0.id == item.subjectID }?.compactTitle(item.title) ?? item.title), systemImage: "bell.badge") }
                    DeadlineRow(item: item)
                }
                ForEach(ReminderPlan.make(subjects: subjects, deadlines: [], chapters: [], reviews: [], now: .distantPast).filter { calendar.isDate($0.date, inSameDayAs: date) && !$0.id.hasSuffix(".0") }, id: \.id) { reminder in
                    Label(reminder.title + " · " + reminder.body, systemImage: "bell.badge")
                }
                if dailyReminder { Label(String(localized: "Rappel quotidien de révision"), systemImage: "bell") }
                if day.isEmpty { Text(String(localized: "Aucune séance prévue.")).foregroundStyle(.secondary) }
                ForEach(Array(day.enumerated()), id: \.element.id) { index, session in
                    SessionRow(session: session).listRowBackground(CalendarStudyKind.revision.color.opacity(0.05))
                    if index == min(1, day.count - 1) { BrowsingBanner().listRowSeparator(.hidden) }
                }
            }
            Button(String(localized: "Replanifier les séances à faire"), systemImage: "arrow.clockwise") {
                do {
                    let n = try Scheduler.rebuild(db)
                    message = n == 0 ? String(localized: "Planning à jour.") : String(localized: "\(n) séance(s) sans créneau. Ajuste tes disponibilités.")
                } catch { message = error.localizedDescription }
            }
        }.alert(String(localized: "Replanification"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
    func markers(_ day: Date) -> [CalendarDayMarker] {
        CalendarDayPlan.markers(on: day, subjects: subjects, sessions: sessions, deadlines: deadlines, reviews: reviews, chapters: chapters, calendar: calendar)
    }
    func marked(_ day: Date) -> Bool {
        ReminderPlan.make(subjects: subjects, deadlines: deadlines, chapters: chapters, reviews: reviews, now: .distantPast).contains { calendar.isDate($0.date, inSameDayAs: day) } || dailyReminder || subjects.contains { $0.hasExam && calendar.isDate($0.exam, inSameDayAs: day) }
        || deadlines.contains { !$0.done && $0.hasDueDate && (calendar.isDate($0.due, inSameDayAs: day) || calendar.isDate($0.reminderDate, inSameDayAs: day)) }
    }
    func shift(_ days: Int) { date = calendar.date(byAdding: .day, value: days, to: date)! }
}

struct Stats: View {
    @State private var selectedInsight: PremiumInsight?
    @Query(sort: \Subject.exam) var subjects: [Subject]
    @Query var chapters: [Chapter]
    @Query var logs: [FocusLog]
    @Query var sessions: [Session]
    @Query var cards: [Flashcard]
    var body: some View {
        List {
            Banner(caption: String(localized: "CHAQUE EFFORT COMPTE"), value: String(localized: "\(logs.reduce(0) { $0 + $1.minutes }) min"), icon: "timer")
            Section(String(localized: "Focus · 7 derniers jours")) {
                Chart {
                    ForEach(-6...0, id: \.self) { i in
                        let day = Calendar.current.date(byAdding: .day, value: i, to: .now)!
                        let minutes = logs.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
                        BarMark(x: .value(String(localized: "Jour"), day, unit: .day), y: .value(String(localized: "Minutes"), minutes)).foregroundStyle(StudyDesign.accent.gradient)
                    }
                }.chartYAxisLabel("min").frame(height: 170)
            }
            Section(String(localized: "Préparation par examen")) {
                ForEach(subjects.filter(\.hasExam)) { subject in
                    let units = chapters.filter { $0.subjectID == subject.id }
                    let total = units.reduce(0) { $0 + $1.requiredSessions }
                    let finished = units.reduce(0) { value, unit in
                        value + min(unit.requiredSessions, sessions.filter { $0.chapterID == unit.id && $0.done }.count)
                    }
                    VStack(alignment: .leading) {
                        Text(subject.displayCode).font(.headline)
                        ProgressView(value: Double(finished), total: Double(max(1, total)))
                        Text(String(localized: "\(finished) / \(total) séances")).font(.caption)
                    }
                }
            }
            PremiumInsights { selectedInsight = $0 }
            Section(String(localized: "Progression")) {
                LabeledContent(String(localized: "Séances terminées"), value: String(localized: "\(sessions.filter(\.done).count) / \(sessions.count)"))
                LabeledContent(String(localized: "Cartes mémorisées"), value: String(localized: "\(cards.filter(\.known).count) / \(cards.count)"))
                LabeledContent(String(localized: "Pomodoros terminés"), value: "\(logs.count)")
            }
        }.sheet(item: $selectedInsight) { feature in
            PremiumAccess(title: L10n.key(feature.rawValue)) {
                PremiumInsightDetail(feature: feature, logs: logs, subjects: subjects)
            }
        }
    }
}
