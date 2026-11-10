import SwiftUI

enum StudyDesign {
    static let accent = Color(red: 0.39, green: 0.32, blue: 0.85)
    static let canvas = Color(red: 0.96, green: 0.96, blue: 0.985)
    static let ink = Color(red: 0.13, green: 0.14, blue: 0.23)
    static let mint = Color(red: 0.08, green: 0.57, blue: 0.43)
    static let coral = Color(red: 0.85, green: 0.33, blue: 0.30)
    static let line = Color(red: 0.88, green: 0.88, blue: 0.93)
    static let hero = LinearGradient(colors: [Color(red: 0.18, green: 0.14, blue: 0.35), Color(red: 0.36, green: 0.28, blue: 0.63)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static func color(for name: String) -> Color {
        let colors = [accent, mint, coral, Color(red: 0.18, green: 0.43, blue: 0.77), Color(red: 0.67, green: 0.28, blue: 0.53)]
        let index = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % colors.count }
        return colors[index]
    }
    static func symbol(for name: String) -> String {
        let text = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if text.contains("math") || text.contains("stat") { return "function" }
        if text.contains("bio") { return "leaf.fill" }
        if text.contains("chim") { return "flask.fill" }
        if text.contains("phys") { return "atom" }
        if text.contains("info") { return "curlybraces" }
        if text.contains("hist") { return "building.columns.fill" }
        if text.contains("lang") || text.contains("anglais") { return "character.bubble.fill" }
        return "book.closed.fill"
    }
}

struct StudyBadge: View {
    let symbol: String
    var color = StudyDesign.accent
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: symbol).font(.system(size: size * 0.43, weight: .semibold))
            .symbolRenderingMode(.hierarchical).foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: size * 0.31))
            .accessibilityHidden(true)
    }
}

struct StudyPill: View {
    let title: String
    var symbol: String? = nil
    var color = StudyDesign.accent
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(title)
        }.font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(color.opacity(0.1), in: Capsule())
    }
}

private struct StudyCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(StudyDesign.line.opacity(0.55)) }
            .shadow(color: StudyDesign.ink.opacity(0.035), radius: 14, x: 0, y: 6)
    }
}
private struct StudyReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    func body(content: Content) -> some View {
        content.opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true } }
    }
}
struct StudySection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(StudyDesign.ink)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
            }
            content()
        }
    }
}
struct StudyEmpty: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            StudyBadge(symbol: symbol)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.studyCard()
    }
}
extension View {
    func studyCard() -> some View { modifier(StudyCard()) }
    func studyReveal() -> some View { modifier(StudyReveal()) }
    func studyScreen() -> some View {
        self.scrollContentBackground(.hidden).background(StudyDesign.canvas)
            .tint(StudyDesign.accent).fontDesign(.rounded)
    }
}
