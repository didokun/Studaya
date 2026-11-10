import SwiftUI
import SwiftData

extension Color {
    static let navy = StudyDesign.ink
    static let mintBrand = StudyDesign.mint
}

@main struct StudayaApp: App {
    private let storage: Result<ModelContainer, Error>
    private let preferences: UserDefaults
    init() {
        #if DEBUG
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-test")
        if testing {
            let suite = "Studaya.UITests"
            preferences = UserDefaults(suiteName: suite)!
            preferences.removePersistentDomain(forName: suite)
        } else { preferences = .standard }
        storage = Result { try Storage.container(memory: testing) }
        #else
        preferences = .standard
        storage = Result { try Storage.container() }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container): Home()
                .font(.body)
                .fontDesign(.rounded)
                .tint(StudyDesign.accent)
                .controlSize(.large)
                .textFieldStyle(StudyTextFieldStyle())
                .environment(\.defaultMinListRowHeight, 56)
                .defaultAppStorage(preferences).modelContainer(container).environment(\.locale, Locale(identifier: "fr_FR"))
            case .failure(let error): ContentUnavailableView("Stockage indisponible", systemImage: "externaldrive.badge.exclamationmark", description: Text(error.localizedDescription))
            }
        }
    }
}

struct Home: View {
    @Query var profiles: [AcademicProfile]
    @AppStorage("studentName") var studentName = ""
    @AppStorage("dataRevision") private var dataRevision = ""
    @State var tab = 0
    @State var settings = false
    @State var message: String?
    @Environment(\.modelContext) var db
    @Environment(\.scenePhase) var phase
    @Query var sessions: [Session]
    @Query var deadlines: [StudyDeadline]
    @Query var subjects: [Subject]
    @Query var chapters: [Chapter]
    @Query var reviews: [SpacedReview]
    @AppStorage("eventRemindersEnabled") private var eventRemindersEnabled = false
    var reminderRevision: String {
        String(eventRemindersEnabled) + subjects.map { "\($0.id):\($0.name):\($0.hasExam):\($0.exam)" }.sorted().joined()
        + deadlines.map { "\($0.id):\($0.title):\($0.kind):\($0.due):\($0.done):\($0.reminderDays)" }.sorted().joined()
        + chapters.map { "\($0.id):\($0.name):\($0.completed)" }.sorted().joined()
        + reviews.map { "\($0.id):\($0.due):\($0.done)" }.sorted().joined()
    }
    var body: some View {
        TabView(selection: $tab) {
            page("Accueil", "sun.max.fill", 0) { Today(tab: $tab) }
            page("Planning", "calendar", 1) { Planner() }
            page("Focus", "headphones", 2) { Focus() }
            page("Matières", "books.vertical.fill", 3) { Library(onPathCreated: { tab = 1 }) }
            page("Progrès", "chart.bar.xaxis", 4) { Stats() }
        }
        .id(dataRevision)
        .onChange(of: dataRevision) { _, _ in
            tab = 0; settings = false
            message = StudyPreferences.current.string(forKey: "dataChangeReason")
        }
        .tint(StudyDesign.accent).preferredColorScheme(.light)
        .task { await Membership.shared.refresh() }
        .task { await Membership.shared.observe() }
        .sheet(isPresented: $settings) { StudySettings() }
        .fullScreenCover(isPresented: Binding(get: { profiles.isEmpty && !settings }, set: { _ in })) {
            AcademicSetup { tab = 0 }
        }
        .task(id: reminderRevision) { await EventReminders.shared.refresh(db) }
        .onChange(of: phase, initial: true) { _, value in
            if value == .active { Task { await DailyReminder.sync(); await EventReminders.shared.refresh(db) } }
            if value == .active && sessions.contains(where: { !$0.done && !$0.pinned && $0.start.addingTimeInterval(Double($0.minutes * 60)) <= .now }) {
                do { try Scheduler.rebuild(db) } catch { message = error.localizedDescription }
            }
        }
        .alert("Planning", isPresented: Binding(get: { message != nil && !settings }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
    func page<V: View>(_ name: String, _ icon: String, _ index: Int, @ViewBuilder content: () -> V) -> some View {
        NavigationStack {
            content().studyScreen().navigationTitle(name).navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .frame(width: 44, height: 44, alignment: .center)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Réglages", systemImage: "slider.horizontal.3") { settings = true } }
            }
        }.tabItem { Label(name, systemImage: icon) }.tag(index)
    }
}

struct Primary: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.headline, design: .rounded, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 24).padding(18)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [StudyDesign.accent, Color(red: 0.31, green: 0.24, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: StudyDesign.accent.opacity(0.17), radius: 10, x: 0, y: 5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct Banner: View {
    let caption: String
    let value: String
    let icon: String
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(caption.uppercased()).font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.white.opacity(0.75))
                Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: icon).font(.system(size: 34, weight: .medium)).symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(red: 0.77, green: 0.93, blue: 0.66))
                .frame(width: 70, height: 80).rotationEffect(.degrees(-8))
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 23))
        }.padding(24).background {
            ZStack(alignment: .topTrailing) {
                StudyDesign.hero
                Circle().fill(.white.opacity(0.05)).frame(width: 180, height: 180).offset(x: 70, y: -70)
            }.clipShape(RoundedRectangle(cornerRadius: 28))
        }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
}
