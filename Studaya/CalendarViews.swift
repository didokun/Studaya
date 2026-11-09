import SwiftUI
import SwiftData
import Charts

struct SessionRow: View {
    @Bindable var session: Session
    var body: some View {
        Button { session.done.toggle() } label: {
            HStack(spacing: 14) {
                Image(systemName: session.done ? "checkmark.circle.fill" : "circle").foregroundStyle(session.done ? Color.mintBrand : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title).font(.headline)
                    Text("\(session.activity) · \(session.start.formatted(date: .omitted, time: .shortened)) · \(session.minutes) min").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }.accessibilityValue(session.done ? "Terminée" : "À faire")
    }
}

struct Today: View {
    @AppStorage("studentName") var name = ""
    @AppStorage("weeklyHours") var goal = 5
    @Query var logs: [FocusLog]
    @Binding var tab: Int
    @Query(sort: \Session.start) var sessions: [Session]
    @Query(sort: \Subject.exam) var subjects: [Subject]
    var body: some View {
        let today = sessions.filter { Calendar.current.isDateInToday($0.start) }
        List {
            Banner(caption: Date.now.formatted(.dateTime.locale(Locale(identifier: "fr")).weekday(.wide).day().month(.wide)), value: "\(today.filter { !$0.done }.count) séance(s) à faire", icon: "sun.max")
            Section(name.isEmpty ? "Objectif hebdomadaire" : "Objectif de " + name) {
                let minutes = logs.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear) }.reduce(0) { $0 + $1.minutes }
                ProgressView(value: Double(min(minutes, goal * 60)), total: Double(goal * 60))
                Text("\(minutes) min de Focus sur \(goal) h visées").font(.caption)
            }
            Section("Priorités · \(today.filter { !$0.done }.reduce(0) { $0 + $1.minutes }) min restantes") {
                ForEach(Array(today.filter { !$0.done }.prefix(3))) { SessionRow(session: $0) }
                if today.allSatisfy(\.done) { Text("Aucune priorité en attente.") }
            }
            Section("Aujourd’hui") {
                if today.isEmpty { Text("Aucune séance prévue aujourd’hui.").foregroundStyle(.secondary) }
                ForEach(today) { SessionRow(session: $0) }
            }
            if today.isEmpty, let session = sessions.first(where: { !$0.done && $0.start > .now }) {
                Section("Prochaine séance") {
                    Text(session.title).font(.headline)
                    Text(session.start, format: .dateTime.weekday(.wide).day().month().hour().minute())
                    Button("Voir le planning") { tab = 1 }
                }
            }
            if let next = subjects.first(where: { $0.hasExam && $0.exam >= Calendar.current.startOfDay(for: .now) }) {
                Section("Prochain examen") { LabeledContent(next.name) { Text(next.exam, format: .dateTime.day().month(.wide)) } }
            }
            Button("Ouvrir mes matières") { tab = 3 }
            Button("Démarrer un Pomodoro") { tab = 2 }
        }
    }
}

struct Planner: View {
    @Query var profiles: [AcademicProfile]
    @State var date = Date.now
    @State var month = false
    @State var message: String?
    @Query(sort: \Session.start) var sessions: [Session]
    @Query var subjects: [Subject]
    @Environment(\.modelContext) var db
    var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 2; return c }
    var body: some View {
        List {
            if let p = profiles.first {
                Section(p.program) {
                    Menu {
                        ForEach(0..<(p.years * 2), id: \.self) { i in
                            Button("Semestre \(i + 1)") { date = calendar.date(byAdding: .month, value: i * 6, to: p.firstDay)! }
                        }
                    } label: { Label("Parcourir mes semestres", systemImage: "graduationcap") }
                }
            }
            Picker("Vue", selection: $month) { Text("Semaine").tag(false); Text("Calendrier").tag(true) }.pickerStyle(.segmented)
            if month {
                DatePicker("Jour", selection: $date, displayedComponents: .date).datePickerStyle(.graphical)
            } else {
                HStack {
                    Button("Précédente", systemImage: "chevron.left") { shift(-7) }
                    Spacer()
                    Text(date, format: .dateTime.month(.wide).year()).font(.headline)
                    Spacer()
                    Button("Suivante", systemImage: "chevron.right") { shift(7) }
                }.labelStyle(.iconOnly).buttonStyle(.borderless)
                HStack {
                    ForEach(0..<7, id: \.self) { i in
                        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
                        let day = calendar.date(byAdding: .day, value: i, to: start)!
                        Button { date = day } label: {
                            VStack { Text(day, format: .dateTime.weekday(.narrow)); Text(day, format: .dateTime.day()).bold() }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(calendar.isDate(day, inSameDayAs: date) ? Color.mintBrand : .clear, in: Capsule())
                        }.buttonStyle(.plain).accessibilityLabel(Text(day, format: .dateTime.weekday(.wide).day().month()))
                    }
                }
            }
            Section(date.formatted(.dateTime.locale(Locale(identifier: "fr")).weekday(.wide).day().month())) {
                let day = sessions.filter { calendar.isDate($0.start, inSameDayAs: date) }
                ForEach(subjects.filter { $0.hasExam && calendar.isDate($0.exam, inSameDayAs: date) }) { Label("Examen · " + $0.name, systemImage: "graduationcap") }
                if day.isEmpty { Text("Aucune séance prévue.").foregroundStyle(.secondary) }
                ForEach(day) { SessionRow(session: $0) }
            }
            Button("Replanifier les séances à faire", systemImage: "arrow.clockwise") {
                do {
                    let n = try Scheduler.rebuild(db)
                    message = n == 0 ? "Planning à jour." : "\(n) séance(s) sans créneau. Ajuste tes disponibilités."
                } catch { message = error.localizedDescription }
            }
        }.alert("Replanification", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
    func shift(_ days: Int) { date = calendar.date(byAdding: .day, value: days, to: date)! }
}

struct Stats: View {
    @Query(sort: \Subject.exam) var subjects: [Subject]
    @Query var chapters: [Chapter]
    @Query var logs: [FocusLog]
    @Query var sessions: [Session]
    @Query var cards: [Flashcard]
    var body: some View {
        List {
            Banner(caption: "Temps de concentration", value: "\(logs.reduce(0) { $0 + $1.minutes }) min", icon: "timer")
            Section("Focus · 7 derniers jours") {
                Chart {
                    ForEach(-6...0, id: \.self) { i in
                        let day = Calendar.current.date(byAdding: .day, value: i, to: .now)!
                        let minutes = logs.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.minutes }
                        BarMark(x: .value("Jour", day, unit: .day), y: .value("Minutes", minutes)).foregroundStyle(Color.mintBrand)
                    }
                }.chartYAxisLabel("min").frame(height: 170)
            }
            Section("Préparation par examen") {
                ForEach(subjects.filter(\.hasExam)) { subject in
                    let units = chapters.filter { $0.subjectID == subject.id }
                    let total = units.reduce(0) { $0 + $1.requiredSessions }
                    let finished = units.reduce(0) { value, unit in
                        value + min(unit.requiredSessions, sessions.filter { $0.chapterID == unit.id && $0.done }.count)
                    }
                    VStack(alignment: .leading) {
                        Text(subject.name).font(.headline)
                        ProgressView(value: Double(finished), total: Double(max(1, total)))
                        Text("\(finished) / \(total) séances").font(.caption)
                    }
                }
            }
            PremiumInsights(logs: logs, subjects: subjects)
            Section("Progression") {
                LabeledContent("Séances terminées", value: "\(sessions.filter(\.done).count) / \(sessions.count)")
                LabeledContent("Cartes mémorisées", value: "\(cards.filter(\.known).count) / \(cards.count)")
                LabeledContent("Pomodoros terminés", value: "\(logs.count)")
            }
        }
    }
}
