import WidgetKit
import SwiftUI
import ActivityKit

@main struct StudayaFocusWidget: Widget {
    private let background = Color(red: 0.055, green: 0.065, blue: 0.105)
    private let accent = Color(red: 0.79, green: 0.73, blue: 1)
    private let mint = Color(red: 0.58, green: 0.94, blue: 0.79)
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            let resting = context.state.resting || context.isStale
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: resting ? "leaf.fill" : "headphones")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(resting ? mint : accent)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Studaya").font(.caption.weight(.semibold)).foregroundStyle(accent)
                        Text(context.state.paused ? String(localized: "Focus en pause") : resting ? String(localized: "Repos") : String(localized: "Révision"))
                            .font(.headline).foregroundStyle(.white)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "graduationcap.fill").font(.title3).foregroundStyle(accent)
                }
                HStack(alignment: .center, spacing: 16) {
                    Text(title(context.state)).font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.9)).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if context.state.paused {
                        Text(String(format: "%02d:%02d", context.state.pausedSeconds / 60, context.state.pausedSeconds % 60))
                            .font(.system(size: 38, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(.white)
                    } else {
                        countdown(resting ? context.state.restEnd : context.state.end, start: .distantPast)
                            .font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .frame(width: 150, alignment: .trailing).minimumScaleFactor(0.65)
                    }
                }
                if !context.state.paused && !resting {
                    HStack {
                        Label(String(localized: "Puis ta pause"), systemImage: "cup.and.saucer.fill")
                        Spacer()
                        countdown(context.state.restEnd, start: context.state.end).frame(width: 65)
                    }.font(.caption.weight(.medium)).foregroundStyle(mint)
                }
                if context.state.paused || resting {
                    Text(context.state.paused ? String(localized: "Ouvre Studaya pour reprendre") : String(localized: "Ouvre Studaya pour retrouver ta séance"))
                        .font(.caption).foregroundStyle(Color.white.opacity(0.78)).lineLimit(2)
                }
            }.padding(14).background(background)
            .activityBackgroundTint(background)
            .activitySystemActionForegroundColor(.white)
            .widgetURL(URL(string: "studaya://focus"))
        } dynamicIsland: { context in
            let resting = context.state.resting || context.isStale
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Label("Studaya", systemImage: "graduationcap.fill").foregroundStyle(accent) }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.paused ? String(localized: "En pause") : resting ? String(localized: "Repos") : "Focus").foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(title(context.state)).font(.caption).foregroundStyle(Color.white.opacity(0.9)).lineLimit(1)
                        if context.state.paused { Text(String(localized: "Ouvre l’app pour reprendre")).foregroundStyle(.white) }
                        else {
                            countdown(resting ? context.state.restEnd : context.state.end, start: .distantPast)
                                .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.paused ? "pause.fill" : resting ? "leaf.fill" : "headphones").foregroundStyle(resting ? mint : accent)
            } compactTrailing: {
                if context.state.paused { Image(systemName: "pause.fill").foregroundStyle(.white) }
                else { countdown(resting ? context.state.restEnd : context.state.end, start: .distantPast).foregroundStyle(.white).frame(width: 52) }
            } minimal: {
                Image(systemName: context.state.paused ? "pause.fill" : resting ? "leaf.fill" : "headphones").foregroundStyle(resting ? mint : accent)
            }
            .widgetURL(URL(string: "studaya://focus"))
            .keylineTint(accent)
        }
    }
    private func title(_ state: FocusActivityAttributes.ContentState) -> String {
        if state.isFreeFocus == true || (state.isFreeFocus == nil && state.title == "Focus libre") {
            return String(localized: "Focus libre")
        }
        return state.title
    }
    private func countdown(_ end: Date, start: Date) -> some View {
        Text(timerInterval: min(start, end)...end, countsDown: true).monospacedDigit()
    }
}
