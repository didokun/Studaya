import SwiftUI
import SwiftData

struct AcademicSetup: View {
    var profile: AcademicProfile?
    var finished: () -> Void
    @Environment(\.modelContext) private var db
    @Environment(\.dismiss) private var dismiss
    @AppStorage("studentName") private var savedName = ""
    @State private var name = ""
    @State private var level = "Licence"
    @State private var program = ""
    @State private var school = ""
    @State private var start = Date()
    @State private var years = 1
    @State private var courseText = ""
    @State private var rhythm = Availability.saved
    @State private var step = 0
    @State private var error: String?
    @State private var loaded = false
    @FocusState private var typing: Bool
    private let titles = ["Ton année commence ici.", "Qu’étudies-tu ?", "Sur quelle période ?", "Quelles matières réviser ?", "Quand es-tu disponible ?", "Ton parcours de révision"]
    private let symbols = ["book.pages","graduationcap","calendar","books.vertical","clock","checkmark.seal"]
    private var courses: [String] {
        var seen = Set<String>()
        return courseText.components(separatedBy: CharacterSet(charactersIn: ",\n")).compactMap {
            let word = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !word.isEmpty && seen.insert(word.lowercased()).inserted ? word : nil
        }
    }
    private var valid: Bool {
        switch step {
        case 1: return !program.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return Calendar.current.date(byAdding: .year, value: years, to: start)! > Date.now
        case 3: return !courses.isEmpty
        case 4: return !rhythm.weekdays.isEmpty
        default: return true
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("Logo").resizable().frame(width: 32,height: 32)
                Text("Studaya").font(.title3.bold())
                Spacer()
                if profile != nil { Button("Fermer") { dismiss() } }
                else if step < 6 { Text("\(step + 1) sur 6").font(.subheadline.monospacedDigit()) }
            }.padding()
            if step == 6 {
                PremiumOptions { save() }.padding(.horizontal)
            } else {
                ProgressView(value: Double(step + 1), total: 6).tint(.mintBrand).padding(.horizontal)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: symbols[step]).font(.system(size: 38, weight: .medium)).foregroundStyle(Color.mintBrand)
                        Text(titles[step]).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        content
                    }.frame(maxWidth: 560, alignment: .leading).padding(24).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                HStack {
                    if step > 0 { Button("Retour") { typing = false; step -= 1 }.padding(.trailing, 8) }
                    Button(step == 0 ? "Commencer" : step == 5 ? "Valider mon planning" : "Continuer") {
                        typing = false
                        if step == 5 && profile != nil { save() } else { step += 1 }
                    }.buttonStyle(Primary()).disabled(!valid).opacity(valid ? 1 : 0.45)
                }.padding()
            }
        }.foregroundStyle(Color.navy).background(Color.white).tint(.navy)
        .interactiveDismissDisabled(profile == nil)
        .onAppear {
            guard !loaded else { return }; loaded = true; name = savedName
            if let profile {
                program = profile.program; school = profile.institution; level = profile.level
                years = profile.years; start = profile.firstDay; courseText = profile.courses.joined(separator: ", "); step = 1
            }
        }
        .alert("Enregistrement impossible", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            Text("De tes cours de la semaine aux examens de fin d’année, construis un programme qui suit tes études.").font(.title3)
            VStack(alignment: .leading, spacing: 14) {
                Image("Logo").resizable().frame(width: 76,height: 76)
                Text("Mon carnet de révision").font(.title2.bold())
                Label("Formation · Matières · Emploi du temps", systemImage: "bookmark")
            }.foregroundStyle(.white).padding(26).frame(maxWidth: .infinity, alignment: .leading).background(Color.navy, in: RoundedRectangle(cornerRadius: 24))
        case 1:
            entry("Prénom (facultatif)", $name)
            Picker("Niveau d’études", selection: $level) { ForEach(["Lycée","BTS / BUT","Licence","Master","Doctorat","Autre"], id: \.self) { Text($0) } }.pickerStyle(.menu)
            entry("Formation", $program)
            entry("Université ou établissement (facultatif)", $school)
        case 2:
            DatePicker("Début du planning", selection: $start, in: Calendar.current.date(byAdding: .year, value: -2, to: .now)!..., displayedComponents: .date)
            ForEach([1,2], id: \.self) { n in
                Button { years = n } label: {
                    HStack { Label(n == 1 ? "Une année" : "Deux années", systemImage: "calendar"); Spacer(); Image(systemName: years == n ? "checkmark.circle.fill" : "circle") }
                        .padding().background(Color.mintBrand.opacity(years == n ? 0.17 : 0.04), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        case 3:
            Text("Saisis tes matières, séparées par des virgules. Elles alterneront dans tes créneaux de révision.")
            entry("Matières", $courseText)
            Text("Exemple · Biologie, Chimie, Statistiques").font(.footnote).foregroundStyle(.secondary)
        case 4:
            RhythmFields(rhythm: $rhythm)
        default:
            VStack(alignment: .leading, spacing: 14) {
                Text(program).font(.title.bold())
                Text([level, school].filter { !$0.isEmpty }.joined(separator: " · "))
                Divider()
                Label("\(start.formatted(.dateTime.month().year())) – \(Calendar.current.date(byAdding: .year, value: years, to: start)!.formatted(.dateTime.month().year()))", systemImage: "calendar")
                Label("\(rhythm.weekdays.count) jours par semaine · \(rhythm.minutes) min par séance", systemImage: "clock")
                Text(courses.joined(separator: " · ")).font(.headline)
            }.padding(20).frame(maxWidth: .infinity,alignment: .leading).background(Color.mintBrand.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
            Text("Tes révisions de cours seront inscrites au calendrier. Quand tu ajouteras un examen, sa préparation prendra la priorité.")
        }
    }
    func entry(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.subheadline.bold()); TextField(title, text: binding).focused($typing).textFieldStyle(.roundedBorder).submitLabel(.done) }
    }
    func save() {
        let p = profile ?? AcademicProfile()
        if profile == nil { db.insert(p) }
        p.program = program; p.level = level; p.institution = school
        p.courses = courses; p.firstDay = start; p.years = years
        do {
            let library = try db.fetch(FetchDescriptor<Subject>())
            for course in courses where !library.contains(where: { $0.name.localizedCaseInsensitiveCompare(course) == .orderedSame }) {
                let subject = Subject(course, exam: start)
                subject.hasExam = false
                db.insert(subject)
            }
            try Scheduler.rebuild(db, availability: rhythm)
            rhythm.persist(); savedName = name
            finished()
        } catch { db.rollback(); self.error = error.localizedDescription }
    }
}

struct RhythmFields: View {
    @Binding var rhythm: Availability
    let days = ["Dim","Lun","Mar","Mer","Jeu","Ven","Sam"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Jours de révision").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))]) {
                ForEach([2,3,4,5,6,7,1], id: \.self) { d in
                    Button(days[d-1]) {
                        if rhythm.weekdays.contains(d) { rhythm.weekdays.remove(d) } else { rhythm.weekdays.insert(d) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 9).background(rhythm.weekdays.contains(d) ? Color.mintBrand.opacity(0.35) : Color.gray.opacity(0.1), in: Capsule()).buttonStyle(.plain)
                    .accessibilityAddTraits(rhythm.weekdays.contains(d) ? .isSelected : [])
                }
            }
            Stepper("À partir de \(rhythm.startHour) h", value: $rhythm.startHour, in: 0...(rhythm.endHour-1))
            Stepper("Jusqu’à \(rhythm.endHour) h", value: $rhythm.endHour, in: (rhythm.startHour+1)...23)
            Stepper("Séance de \(rhythm.minutes) min", value: $rhythm.minutes, in: 5...60, step: 5)
        }
    }
}
