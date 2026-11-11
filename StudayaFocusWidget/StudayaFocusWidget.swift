import WidgetKit
import SwiftUI
import ActivityKit

@main struct StudayaFocusWidget: Widget {
    private let violet = Color(red: 0.39, green: 0.32, blue: 0.85)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(context.state.paused ? "Focus en pause" : "Studaya · Focus et repos", systemImage: context.state.resting ? "leaf.fill" : "headphones")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "graduationcap.fill").foregroundStyle(violet)
                }
                Text(context.state.title).font(.subheadline).lineLimit(1)
                if context.state.paused {
                    Text(String(format: "%02d:%02d", context.state.pausedSeconds / 60, context.state.pausedSeconds % 60))
                        .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                } else if context.state.resting {
                    HStack { Text("Repos"); Spacer(); countdown(context.state.end, start: .distantPast) }
                } else {
                    HStack { Text("Révision"); Spacer(); countdown(context.state.end, start: .distantPast) }
                    HStack { Text("Puis ta pause").font(.caption); Spacer(); countdown(context.state.restEnd, start: context.state.end).font(.subheadline) }
                }
                Text(context.state.paused ? "Ouvre Studaya pour reprendre" : "Ouvre Studaya pour retrouver ta séance")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(18)
            .activityBackgroundTint(Color(red: 0.96, green: 0.95, blue: 1))
            .activitySystemActionForegroundColor(violet)
            .widgetURL(URL(string: "studaya://focus"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Studaya", systemImage: "graduationcap.fill").foregroundStyle(violet) }
                DynamicIslandExpandedRegion(.trailing) { Text(context.state.paused ? "En pause" : context.state.resting ? "Repos" : "Focus") }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(context.state.title).font(.caption).lineLimit(1)
                        if context.state.paused { Text("Ouvre l’app pour reprendre") }
                        else {
                            countdown(context.state.resting || context.isStale ? context.state.restEnd : context.state.end, start: .distantPast)
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.paused ? "pause.fill" : context.state.resting || context.isStale ? "leaf.fill" : "headphones").foregroundStyle(violet)
            } compactTrailing: {
                if context.state.paused { Image(systemName: "pause.fill") }
                else { countdown(context.state.resting || context.isStale ? context.state.restEnd : context.state.end, start: .distantPast).frame(width: 52) }
            } minimal: {
                Image(systemName: context.state.paused ? "pause.fill" : context.state.resting || context.isStale ? "leaf.fill" : "headphones")
            }
            .widgetURL(URL(string: "studaya://focus"))
            .keylineTint(violet)
        }
    }
    private func countdown(_ end: Date, start: Date) -> some View {
        Text(timerInterval: min(start, end)...end, countsDown: true).monospacedDigit()
    }
}
