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
    @State private var organization = "Par semestre"
    @State private var examMode = "Par semestre"
    @State private var rhythm = Availability.saved
    @State private var step = 0
    @State private var error: String?
    @State private var loaded = false
    @FocusState private var typing: Bool
    private let titles = [String(localized: "Ton année commence ici."), String(localized: "Qu’étudies-tu ?"), String(localized: "Sur quelle période ?"), String(localized: "Quand es-tu disponible ?"), String(localized: "Garde une longueur d’avance."), String(localized: "Ton profil est prêt.")]
    private let symbols = ["book.pages","graduationcap","calendar","clock","bell.badge","checkmark.seal"]
    private var valid: Bool {
        switch step {
        case 1: return !program.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 2: return Calendar.current.date(byAdding: .year, value: years, to: start)! > Date.now
        case 3: return !rhythm.weekdays.isEmpty
        default: return true
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("Logo").resizable().frame(width: 32,height: 32).clipShape(RoundedRectangle(cornerRadius: 6.88, style: .continuous)).accessibilityIdentifier("onboarding.logo")
                Text("Studaya").font(.title3.bold())
                Spacer()
                if profile != nil { Button(String(localized: "Fermer")) { dismiss() } }
                else if step < 6 { Text(String(localized: "\(step + 1) sur 6")).font(.subheadline.monospacedDigit()).accessibilityIdentifier("onboarding.step").accessibilityIdentifier("onboarding.step") }
            }.padding()
            if step == 6 {
                PremiumOptions { save() }.padding(.horizontal)
            } else {
                ProgressView(value: Double(step + 1), total: 6).tint(.mintBrand).padding(.horizontal)
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        StudyBadge(symbol: symbols[step], size: 64)
                        Text(L10n.key(titles[step])).font(.system(.largeTitle, design: .rounded, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        content
                    }.frame(maxWidth: 560, alignment: .leading).padding(24).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                HStack {
                    if step > 0 { Button(String(localized: "Retour")) { typing = false; step -= 1 }.padding(.trailing, 8) }
                    Button(step == 0 ? String(localized: "Commencer") : step == 5 ? String(localized: "Valider mon profil") : String(localized: "Continuer")) {
                        typing = false
                        if step == 5 && profile != nil { save() } else { step += 1 }
                    }.buttonStyle(Primary()).disabled(!valid).opacity(valid ? 1 : 0.45)
                }.padding()
            }
        }.foregroundStyle(StudyDesign.ink).background(StudyDesign.canvas).tint(StudyDesign.accent)
        .interactiveDismissDisabled(profile == nil)
        .onAppear {
            guard !loaded else { return }; loaded = true; name = savedName
            if let profile {
                program = profile.program; school = profile.institution; level = profile.level
                years = profile.years; start = profile.firstDay
                organization = profile.organization; examMode = profile.examMode; step = 1
            }

        }
        .alert(String(localized: "Enregistrement impossible"), isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") {} } message: { Text(error ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0:
            Text(String(localized: "De tes cours de la semaine aux examens de fin d’année, construis un programme qui suit tes études.")).font(.title3)
            VStack(alignment: .leading, spacing: 14) {
                Image("Logo").resizable().frame(width: 76,height: 76).clipShape(RoundedRectangle(cornerRadius: 16.34, style: .continuous))
                Text(String(localized: "Mon carnet de révision")).font(.title2.bold())
                Label(String(localized: "Formation · Matières · Emploi du temps"), systemImage: "bookmark")
            }.foregroundStyle(.white).padding(26).frame(maxWidth: .infinity, alignment: .leading).background(StudyDesign.hero, in: RoundedRectangle(cornerRadius: 28))
        case 1:
            entry(String(localized: "Prénom (facultatif)"), $name)
            Picker(String(localized: "Niveau d’études"), selection: $level) { ForEach(["Lycée","BTS / BUT","Licence","Master","Doctorat","Autre"], id: \.self) { Text(L10n.key($0)) } }.studyMenu(String(localized: "Niveau d’études"), value: L10n.key(level))
            entry(String(localized: "Formation"), $program)
            entry(String(localized: "Université ou établissement (facultatif)"), $school)
        case 2:
            DatePicker(String(localized: "Début du planning"), selection: $start, in: Calendar.current.date(byAdding: .year, value: -2, to: .now)!..., displayedComponents: .date)
            Stepper(String(localized: "Parcours de \(years) année(s)"), value: $years, in: 1...8)
            Picker(String(localized: "Organisation"), selection: $organization) {
                Text("Par semestre").tag("Par semestre"); Text("Par matière").tag("Par matière")
            }.studyMenu(String(localized: "Organisation"), value: L10n.key(organization))
            Picker(String(localized: "Les examens ont lieu…"), selection: $examMode) {
                Text(String(localized: "En fin de semestre")).tag("Par semestre")
                Text(String(localized: "À la fin de chaque matière")).tag("En fin de matière")
            }.studyMenu(String(localized: "Les examens ont lieu…"), value: examMode == "Par semestre" ? String(localized: "En fin de semestre") : String(localized: "À la fin de chaque matière"))
            Text(String(localized: "Chaque matière garde sa propre date d’examen, même en organisation semestrielle.")).font(.footnote)
        case 3:
            RhythmFields(rhythm: $rhythm)
        case 4:
            NotificationInvitation()
        default:
            VStack(alignment: .leading, spacing: 14) {
                Text(program).font(.title.bold())
                Text([L10n.key(level), school].filter { !$0.isEmpty }.joined(separator: " · "))
                Divider()
                Label(String(localized: "\(start.formatted(.dateTime.month().year())) – \(Calendar.current.date(byAdding: .year, value: years, to: start)!.formatted(.dateTime.month().year()))"), systemImage: "calendar")
                Label(String(localized: "\(rhythm.weekdays.count) jours par semaine · \(rhythm.minutes) min par séance"), systemImage: "clock")
                Label(String(localized: "Matières et TD dans ton Parcours de révision"), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
            }.padding(20).frame(maxWidth: .infinity,alignment: .leading).background(Color.mintBrand.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
            Text(String(localized: "Ton profil est prêt. Crée ensuite ton Parcours de révision : matières, cours, TD, présentations, contrôles et examens."))
        }
    }
    func entry(_ title: String, _ binding: Binding<String>) -> some View {
        VStack(alignment: .leading) { Text(title).font(.body.weight(.medium)); TextField(title, text: binding).focused($typing).textFieldStyle(StudyTextFieldStyle(boxed: true)).submitLabel(.done) }
    }
    func save() {
        let p = profile ?? AcademicProfile()
        if profile == nil { db.insert(p) }
        p.program = program; p.level = level; p.institution = school
        p.firstDay = start; p.years = years
        p.organization = organization; p.examMode = examMode
        do {
            try Scheduler.rebuild(db, availability: rhythm)
            rhythm.persist(); savedName = name
            finished()
        } catch { db.rollback(); self.error = error.localizedDescription }
    }
}

struct RhythmFields: View {
    @Binding var rhythm: Availability
    let days = [String(localized: "Dim"),String(localized: "Lun"),String(localized: "Mar"),String(localized: "Mer"),String(localized: "Jeu"),String(localized: "Ven"),String(localized: "Sam")]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Jours de révision")).font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 65))]) {
                ForEach([2,3,4,5,6,7,1], id: \.self) { d in
                    Button(days[d-1]) {
                        if rhythm.weekdays.contains(d) { rhythm.weekdays.remove(d) } else { rhythm.weekdays.insert(d) }
                    }.frame(maxWidth: .infinity, minHeight: 48).background(rhythm.weekdays.contains(d) ? Color.mintBrand.opacity(0.35) : Color.gray.opacity(0.1), in: Capsule()).buttonStyle(.plain)
                    .accessibilityAddTraits(rhythm.weekdays.contains(d) ? .isSelected : [])
                }
            }
            Stepper(String(localized: "À partir de \(rhythm.startHour) h"), value: $rhythm.startHour, in: 0...(rhythm.endHour-1))
            Stepper(String(localized: "Jusqu’à \(rhythm.endHour) h"), value: $rhythm.endHour, in: (rhythm.startHour+1)...23)
            Stepper(String(localized: "Séance de \(rhythm.minutes) min"), value: $rhythm.minutes, in: 5...60, step: 5)
        }
    }
}
