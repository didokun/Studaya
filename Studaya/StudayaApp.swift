import SwiftUI
import SwiftData

extension Color {
    static let navy = Color(red: 16/255, green: 29/255, blue: 53/255)
    static let mintBrand = Color(red: 32/255, green: 200/255, blue: 120/255)
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
            case .success(let container): Home().defaultAppStorage(preferences).modelContainer(container).environment(\.locale, Locale(identifier: "fr_FR"))
            case .failure(let error): ContentUnavailableView("Stockage indisponible", systemImage: "externaldrive.badge.exclamationmark", description: Text(error.localizedDescription))
            }
        }
    }
}

struct Home: View {
    @Query var profiles: [AcademicProfile]
    @AppStorage("studentName") var studentName = ""
    @State var tab = 0
    @State var settings = false
    @State var message: String?
    @Environment(\.modelContext) var db
    @Environment(\.scenePhase) var phase
    @Query var sessions: [Session]
    var body: some View {
        TabView(selection: $tab) {
            page("Today", "sun.max", 0) { Today(tab: $tab) }
            page("Planner", "calendar", 1) { Planner() }
            page("Focus", "timer", 2) { Focus() }
            page("Révision", "books.vertical", 3) { Library() }
            page("Stats", "chart.bar", 4) { Stats() }
        }
        .tint(.navy).preferredColorScheme(.light)
        .task { await Membership.shared.refresh() }
        .task { await Membership.shared.observe() }
        .sheet(isPresented: $settings) { StudySettings() }
        .fullScreenCover(isPresented: Binding(get: { profiles.isEmpty && !settings }, set: { _ in })) {
            AcademicSetup { tab = 0 }
        }
        .onChange(of: phase, initial: true) { _, value in
            if value == .active && sessions.contains(where: { !$0.done && $0.start.addingTimeInterval(Double($0.minutes * 60)) <= .now }) {
                do { try Scheduler.rebuild(db) } catch { message = error.localizedDescription }
            }
        }
        .alert("Planning", isPresented: Binding(get: { message != nil && !settings }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
    }
    func page<V: View>(_ name: String, _ icon: String, _ index: Int, @ViewBuilder content: () -> V) -> some View {
        NavigationStack {
            content().navigationTitle(name).toolbar {
                ToolbarItem(placement: .topBarLeading) { Image("Logo").resizable().frame(width: 30, height: 30).accessibilityHidden(true) }
                ToolbarItem(placement: .topBarTrailing) { Button("Réglages", systemImage: "slider.horizontal.3") { settings = true } }
            }
        }.tabItem { Label(name, systemImage: icon) }.tag(index)
    }
}

struct Primary: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).padding().background(Color.mintBrand.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(Color.navy)
    }
}

struct Banner: View {
    let caption: String
    let value: String
    let icon: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(caption.uppercased()).font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(Color.mintBrand)
                Text(value).font(.title.bold()).foregroundStyle(.white)
            }
            Spacer()
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Color.mintBrand)
        }.padding(22).background(Color.navy, in: RoundedRectangle(cornerRadius: 22)).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
    }
}

